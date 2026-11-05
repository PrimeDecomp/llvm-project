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


def smoke_test(root):
    suffix = '.exe' if os.name == 'nt' else ''
    clang = root / 'bin' / ('clang' + suffix)
    linker = root / 'bin' / ('ld.lld' + suffix)
    for executable, version in ((clang, '10.0.1'), (linker, '18.1.8')):
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, required=True)
    parser.add_argument('--platform', required=True,
                        choices=['linux-x86_64', 'macos-x86_64', 'windows-x86_64'])
    parser.add_argument('--revision', required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('dist'))
    args = parser.parse_args()
    installed = args.install.resolve()
    root = installed.parent / 'minimal'
    if root.exists():
        shutil.rmtree(root)
    root.mkdir()
    args.output.mkdir(parents=True, exist_ok=True)
    source = Path(__file__).resolve().parents[2]
    # Keep the established LLD 18 binary and its runtime dependencies, pinned
    # by the workflow to a specific llvm-toolchains commit and LFS digest.
    with tarfile.open(args.baseline, 'r:xz') as baseline:
        for member in baseline:
            path = Path(member.name)
            if (not member.isfile() or path.is_absolute() or '..' in path.parts
                    or '\\' in member.name or ':' in member.name):
                raise RuntimeError('Invalid baseline member: ' + member.name)
            if member.name.startswith('lib/clang/') or member.name in ('bin/clang', 'bin/clang.exe'):
                continue
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            with baseline.extractfile(member) as data, target.open('wb') as output:
                shutil.copyfileobj(data, output)
            target.chmod(member.mode & 0o777)
    suffix = '.exe' if os.name == 'nt' else ''
    shutil.copy2(installed / 'bin' / ('clang' + suffix), root / 'bin' / ('clang' + suffix))
    shutil.copytree(installed / 'lib' / 'clang', root / 'lib' / 'clang')
    licenses = root / 'licenses'
    licenses.mkdir(parents=True, exist_ok=True)
    for project in ('llvm', 'clang'):
        shutil.copyfile(source / project / 'LICENSE.TXT', licenses / (project + '-10.0.1.txt'))
    for project in ('llvm', 'clang'):
        (licenses / (project + '-10.0.0.txt')).unlink(missing_ok=True)
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
        'lld': '18.1.8',
        'revision': args.revision,
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
