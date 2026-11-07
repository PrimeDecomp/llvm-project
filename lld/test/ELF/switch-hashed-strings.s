# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64 %s -o %t.o
# RUN: ld.lld %t.o -o %t.default
# RUN: llvm-readobj --sections %t.default | FileCheck %s --check-prefix=DEFAULT
# RUN: ld.lld --switch-keep-hashed-strings %t.o -o %t
# RUN: llvm-readobj --sections %t | FileCheck %s
# DEFAULT-NOT: .nx.hashed_string
# CHECK: Name: .nx.hashed_string (
# CHECK: Name: .nx.hashed_string_table (
# CHECK-NOT: .other_excluded
.globl _start
_start:
  ret
.section .nx.hashed_string,"e",@progbits
.Lstr:
.asciz "hello"
.section .nx.hashed_string_table,"e",@progbits
.quad 0x599d96bf032ea74b, 1, .Lstr
.section .other_excluded,"e",@progbits
.byte 1
