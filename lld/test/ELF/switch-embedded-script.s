# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64 %s -o %t.o
# RUN: ld.lld %t.o -o %t.default
# RUN: llvm-readobj --symbols %t.default | FileCheck %s --check-prefix=DEFAULT
# RUN: ld.lld --switch-embedded-scripts %t.o -o %t
# RUN: llvm-readobj --symbols --sections %t | FileCheck %s
# RUN: ld.lld -r --switch-embedded-scripts %t.o -o %t.partial
# RUN: llvm-readobj --sections %t.partial | FileCheck %s --check-prefix=PARTIAL
# RUN: ld.lld --switch-embedded-scripts %t.partial -o %t.final
# RUN: llvm-readobj --symbols %t.final | FileCheck %s --check-prefix=SYMBOL
# RUN: llvm-mc -filetype=obj -triple=aarch64 -defsym LIVE=1 %s -o %t.live.o
# RUN: ld.lld --switch-embedded-scripts %t.live.o -o %t.live
# RUN: llvm-readobj --symbols %t.live | FileCheck %s --check-prefix=DEFAULT
# RUN: llvm-mc -filetype=obj -triple=aarch64 -defsym BAD=1 %s -o %t.bad.o
# RUN: not ld.lld --switch-embedded-scripts %t.bad.o -o %t.bad 2>&1 | FileCheck %s --check-prefix=ERROR
# DEFAULT-NOT: Name: embedded_symbol
# CHECK-NOT: Name: .nx_script
# CHECK: Name: embedded_symbol
# CHECK-NEXT: Value: 0x1234
# CHECK: Section: Absolute
# SYMBOL: Name: embedded_symbol
# SYMBOL-NEXT: Value: 0x1234
# PARTIAL: Name: .nx_script
# ERROR: (.nx_script):

.globl _start
_start:
  ret
.ifdef LIVE
.section .nx_script,"",@progbits
.else
.section .nx_script,"e",@progbits
.endif
.ifdef BAD
.asciz "embedded_symbol = ;"
.else
.asciz "embedded_symbol = 0x1234;"
.endif
