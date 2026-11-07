# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64 %s -o %t.o
# RUN: ld.lld %t.o -o %t.default
# RUN: llvm-readobj --sections %t.default | FileCheck %s --check-prefix=DEFAULT
# RUN: ld.lld --add-switch-debuglink=probe.debug %t.o -o %t
# RUN: llvm-readobj --sections --section-data %t | FileCheck %s
# RUN: not ld.lld --add-switch-debuglink= %t.o -o %t.bad 2>&1 | FileCheck %s --check-prefix=ERROR
# DEFAULT-NOT: .nx_debuglink
# CHECK: Name: .nx_debuglink
# CHECK: Type: SHT_PROGBITS
# CHECK: SHF_ALLOC
# CHECK: Size: 19
# CHECK: AddressAlignment: 4
# CHECK: 0000: 00000000 0B000000 70726F62 652E6465
# CHECK: 0010: 627567
# ERROR: --add-switch-debuglink requires a nonempty filename
.globl _start
_start:
  ret
