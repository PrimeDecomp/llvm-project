// RUN: llvm-mc -triple=aarch64 -show-encoding < %s | FileCheck %s
// RUN: llvm-mc -triple=aarch64 -filetype=obj < %s | llvm-objdump -d - | FileCheck %s --check-prefix=DISASM

// Check the software trap mnemonic and its exact encoding.
trap
// CHECK: trap // encoding: [0xfe,0xde,0xff,0xe7]
// DISASM: fe de ff e7{{.*}}trap

// Standard AArch64 traps keep their original encodings.
brk #1
// CHECK: brk #0x1 // encoding: [0x20,0x00,0x20,0xd4]
udf #0xdead
// CHECK: udf #57005 // encoding: [0xad,0xde,0x00,0x00]
