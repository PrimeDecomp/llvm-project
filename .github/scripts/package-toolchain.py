#!/usr/bin/env python3
"""Package and smoke-test an installed Switch decompilation toolchain."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tarfile
import tempfile


def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def check_linux_dependencies(root):
    env = os.environ.copy()
    env.pop('LD_LIBRARY_PATH', None)
    env.pop('LD_PRELOAD', None)
    env['LC_ALL'] = 'C'
    for path in sorted(root.rglob('*')):
        if not path.is_file():
            continue
        with path.open('rb') as data:
            if data.read(4) != b'\x7fELF':
                continue
        dynamic = run('readelf', '-d', path, capture_output=True, text=True, env=env)
        if '(NEEDED)' not in dynamic.stdout:
            continue
        dependencies = run('ldd', path, capture_output=True, text=True, env=env)
        if 'not found' in dependencies.stdout:
            raise RuntimeError('Unresolved dependencies for {}:\n{}'.format(
                path, dependencies.stdout))
        for line in dependencies.stdout.splitlines():
            name, separator, target = line.strip().partition(' => ')
            if name.startswith('libtinfo.so'):
                resolved = Path(target.rsplit(' (', 1)[0]).resolve()
                if not separator or not resolved.is_relative_to(root.resolve()):
                    raise RuntimeError('libtinfo is not bundled for ' + str(path))


def elf_sections(path):
    data = path.read_bytes()
    offset = struct.unpack_from('<Q', data, 40)[0]
    size, count, names_index = struct.unpack_from('<HHH', data, 58)
    headers = [struct.unpack_from('<IIQQQQIIQQ', data, offset + i * size)
               for i in range(count)]
    names_header = headers[names_index]
    names = data[names_header[4]:names_header[4] + names_header[5]]
    return {names[h[0]:].split(b'\0', 1)[0].decode():
            (h[2], h[8], data[h[4]:h[4] + h[5]]) for h in headers}


def smoke_test(root):
    suffix = '.exe' if os.name == 'nt' else ''
    clang = root / 'bin' / ('clang' + suffix)
    linker = root / 'bin' / ('ld.lld' + suffix)
    for executable, version in ((clang, '10.0.1'), (linker, '10.0.1')):
        result = run(executable, '--version', capture_output=True, text=True)
        print(result.stdout, end='')
        if version not in result.stdout:
            raise RuntimeError('Unexpected tool version: ' + str(executable))
    with tempfile.TemporaryDirectory(prefix='switch-smoke-') as temporary:
        work = Path(temporary)
        source = work / 'test.cpp'
        source.write_text('#include <stdint.h>\n'
                          'extern "C" uint64_t entry(uint64_t x) { return x + 1; }\n')
        obj = work / 'test.o'
        elf = work / 'test.elf'
        run(clang, '--target=aarch64-none-elf', '-ffreestanding', '-O2',
            '-c', source, '-o', obj)
        run(linker, '-m', 'aarch64elf', '-e', 'entry', obj, '-o', elf)
        header = elf.read_bytes()[:20]
        if header[:6] != b'\x7fELF\x02\x01' or struct.unpack('<H', header[18:20])[0] != 183:
            raise RuntimeError('Packaged compiler/linker did not produce AArch64 ELF')

        # The generic Switch target must invoke the requested linker directly,
        # without depending on an installed GCC driver or cross toolchain.
        for target in ('aarch64-decomp-switch-elf', 'aarch64-none-elf'):
            run(clang, '--target=' + target, '--ld-path=' + str(linker),
                '-nostdlib', '-static', '-Wl,-e,entry', obj, '-o', elf)
            header = elf.read_bytes()[:20]
            if header[:6] != b'\x7fELF\x02\x01' or struct.unpack('<H', header[18:20])[0] != 183:
                raise RuntimeError('Packaged Clang --ld-path did not produce AArch64 ELF')

        # Verify the compiler backend in the shipped binary, then link its
        # output with the shipped LLD. No disassembler is needed in the archive.
        source.write_text('extern "C" void stop() { __builtin_trap(); }\n')
        binary = work / 'trap.bin'
        for flags in (('-O0',), ('-O2',), ('-O2', '-flto')):
            run(clang, '--target=aarch64-decomp-switch-elf', '-ffreestanding',
                *flags, '-fno-unwind-tables', '-fno-asynchronous-unwind-tables',
                '-c', source, '-o', obj)
            run(linker, '-m', 'aarch64elf', '-Ttext=0', '--oformat', 'binary',
                '-e', 'stop', obj, '-o', binary)
            # LLD 10 pads binary output to the target word size (eight bytes).
            trailing = 0xd65f03c0 if flags == ('-O0',) else 0  # O0 retains RET.
            if binary.read_bytes() != struct.pack('<II', 0xe7ffdefe, trailing):
                raise RuntimeError('Packaged compiler/linker lost the Switch trap encoding')


        source.write_text('struct A { ~A(); }; A object;\n')
        ir = work / 'atexit.ll'
        for extra in ((), ('-femit-switch-atexit',)):
            run(clang, '--target=aarch64-decomp-switch-elf', *extra,
                '-S', '-emit-llvm', source, '-o', ir)
            present = 'section ".atexit"' in ir.read_text()
            if present != bool(extra):
                raise RuntimeError('Unexpected static destructor metadata')

        assembly = work / 'metadata.s'
        assembly.write_text('.globl _start\n_start: ret\n'
                            '.section .nx_script,"e",@progbits\n'
                            '.asciz "embedded_symbol = 0x1234;"\n'
                            '.section .nx.hashed_string,"e",@progbits\n'
                            '.Lstr: .asciz "hello"\n'
                            '.section .nx.hashed_string_table,"e",@progbits\n'
                            '.quad 0x599d96bf032ea74b, 1, .Lstr\n')
        run(clang, '--target=aarch64-decomp-switch-elf', '-c', assembly, '-o', obj)
        run(linker, '-m', 'aarch64elf', '-e', '_start', obj, '-o', elf)
        if any(name.startswith('.nx') for name in elf_sections(elf)):
            raise RuntimeError('Compatibility metadata changed default linking')
        run(linker, '-m', 'aarch64elf', '-e', 'embedded_symbol',
            '--switch-embedded-scripts', '--switch-keep-hashed-strings',
            '--add-switch-debuglink=probe.debug', obj, '-o', elf)
        sections = elf_sections(elf)
        expected = struct.pack('<II', 0, 11) + b'probe.debug'
        if sections.get('.nx_debuglink') != (2, 4, expected):
            raise RuntimeError('Incorrect allocated debug-link record')
        if sections['.nx.hashed_string'][2] != b'hello\0':
            raise RuntimeError('Hashed string was not retained')
        if sections['.nx.hashed_string_table'][2][:16] != struct.pack(
                '<QQ', 0x599d96bf032ea74b, 1):
            raise RuntimeError('Hash table was not retained')
        if struct.unpack_from('<Q', elf.read_bytes(), 24)[0] != 0x1234:
            raise RuntimeError('Embedded linker script was not evaluated')



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, required=True)
    parser.add_argument('--platform', required=True,
                        choices=['linux-x86_64', 'macos-x86_64', 'windows-x86_64'])
    parser.add_argument('--revision', required=True)
    parser.add_argument('--output', type=Path, default=Path('dist'))
    args = parser.parse_args()
    installed = args.install.resolve()
    root = installed.parent / 'minimal'
    if root.exists():
        shutil.rmtree(root)
    root.mkdir()
    args.output.mkdir(parents=True, exist_ok=True)
    source = Path(__file__).resolve().parents[2]
    (root / 'bin').mkdir()
    suffix = '.exe' if os.name == 'nt' else ''
    shutil.copy2(installed / 'bin' / ('clang' + suffix), root / 'bin' / ('clang' + suffix))
    shutil.copy2(installed / 'bin' / ('lld' + suffix), root / 'bin' / ('ld.lld' + suffix))
    shutil.copytree(installed / 'lib' / 'clang', root / 'lib' / 'clang')
    licenses = root / 'licenses'
    licenses.mkdir(parents=True, exist_ok=True)
    for project in ('llvm', 'clang', 'lld'):
        shutil.copyfile(source / project / 'LICENSE.TXT', licenses / (project + '-10.0.1.txt'))
    archive = args.output / (args.platform + '.tar.xz')
    # Store regular files only, including aliases: the existing toolchain
    # installer rejects links, and Windows cannot reliably restore symlinks.
    with tarfile.open(archive, 'w:xz', dereference=True, preset=6) as output:
        for path in sorted(root.rglob('*')):
            if path.is_file():
                info = output.gettarinfo(str(path), arcname=path.relative_to(root).as_posix())
                info.uid = info.gid = info.mtime = 0
                info.uname = info.gname = ''
                info.pax_headers = {}
                with path.open('rb') as data:
                    output.addfile(info, data)
    # Exercise the extracted archive, not binaries from the build directory.
    with tempfile.TemporaryDirectory(prefix='switch-package-') as temporary:
        extracted = Path(temporary)
        with tarfile.open(archive, 'r:xz') as package:
            package.extractall(extracted)
        if args.platform == 'linux-x86_64':
            check_linux_dependencies(extracted)
        smoke_test(extracted)
    digest = hashlib.sha256()
    with archive.open('rb') as data:
        for block in iter(lambda: data.read(1024 * 1024), b''):
            digest.update(block)
    # Keep checksum files LF-terminated for sha256sum on the Linux release runner.
    (args.output / (archive.name + '.sha256')).write_bytes(
        '{}  {}\n'.format(digest.hexdigest(), archive.name).encode('ascii'))
    (args.output / (args.platform + '.json')).write_text(json.dumps({
        'archive': archive.name,
        'sha256': digest.hexdigest(),
        'clang': '10.0.1',
        'lld': '10.0.1',
        'revision': args.revision,
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
