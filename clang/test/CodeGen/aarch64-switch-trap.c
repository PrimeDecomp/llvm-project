// RUN: %clang_cc1 -triple aarch64-decomp-switch-elf -S -O0 -o - %s | FileCheck %s --check-prefix=SWITCH
// RUN: %clang_cc1 -triple aarch64-decomp-switch-elf -S -O2 -o - %s | FileCheck %s --check-prefix=SWITCH
// RUN: %clang_cc1 -triple aarch64-none-elf -S -O2 -o - %s | FileCheck %s --check-prefix=GENERIC

// SWITCH-LABEL: stop:
// SWITCH: .word 3892305662
// SWITCH-NOT: brk
// GENERIC-LABEL: stop:
// GENERIC: brk #0x1
void stop(void) {
  __builtin_trap();
}
