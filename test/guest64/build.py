#!/usr/bin/env python3
"""Build freestanding PE32+ fixtures without a Windows SDK or CRT."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--clang', required=True)
parser.add_argument('--lld', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
source = Path(__file__).resolve().parent
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)

def run(*command):
    subprocess.run([str(x) for x in command], check=True)

for name in ('basic', 'dll', 'imports', 'tls', 'thread'):
    run(args.clang, '--target=x86_64-pc-windows-msvc', '-O2', '-ffreestanding',
        '-fno-stack-protector', '-c', source / (name + '.c'), '-o', out / (name + '.obj'))
link = (args.lld, '-flavor', 'link', '/nodefaultlib', '/machine:x64')
run(*link, '/dll', '/noentry', '/def:' + str(source / 'kernel32.def'),
    '/out:' + str(out / 'kernel32-imports.dll'), '/implib:' + str(out / 'kernel32.lib'))
run(*link, '/dll', '/entry:DllMain', '/base:0x140000000', '/def:' + str(source / 'dll.def'),
    '/out:' + str(out / 'guest64.dll'), '/implib:' + str(out / 'guest64.lib'), out / 'dll.obj')
for name in ('basic', 'imports', 'tls', 'thread'):
    libraries = [out / 'kernel32.lib']
    if name == 'tls':
        libraries.append('/include:_tls_used')
    if name == 'imports':
        libraries.append(out / 'guest64.lib')
    run(*link, '/entry:mainCRTStartup', '/subsystem:console', '/base:0x140000000',
        '/out:' + str(out / (name + '.exe')), out / (name + '.obj'), *libraries)

run(args.clang, '--target=i686-pc-windows-msvc', '-O2', '-ffreestanding',
    '-fno-stack-protector', '-c', source / 'compat32.c', '-o', out / 'compat32.obj')
link32 = (args.lld, '-flavor', 'link', '/nodefaultlib', '/machine:x86')
run(*link32, '/dll', '/noentry', '/def:' + str(source / 'kernel32.def'),
    '/out:' + str(out / 'kernel32-32.dll'), '/implib:' + str(out / 'kernel32-32.lib'))
run(*link32, '/entry:mainCRTStartup', '/subsystem:console', '/base:0x400000',
    '/out:' + str(out / 'compat32.exe'), out / 'compat32.obj', out / 'kernel32-32.lib')
