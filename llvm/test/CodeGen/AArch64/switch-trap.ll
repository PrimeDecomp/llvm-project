; RUN: llc -mtriple=aarch64-decomp-switch-elf -O2 < %s | FileCheck %s --check-prefix=SWITCH
; RUN: llc -mtriple=aarch64-decomp-switch-elf -O0 -fast-isel -fast-isel-abort=1 < %s | FileCheck %s --check-prefix=SWITCH
; RUN: llc -mtriple=aarch64-decomp-switch-elf -O0 -global-isel -global-isel-abort=1 < %s | FileCheck %s --check-prefix=SWITCH
; RUN: llc -mtriple=aarch64_be-decomp-switch-elf -O2 < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-unknown-switch-elf -O2 < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-decomp-unknown-elf -O2 < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-linux-gnu -O2 < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-linux-gnu -O0 -fast-isel -fast-isel-abort=1 < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-linux-gnu -O0 -global-isel -global-isel-abort=1 < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-decomp-switch-elf -filetype=obj < %s | llvm-objdump -d - | FileCheck %s --check-prefix=BYTES

; Check the Switch software trap encoding.
; SWITCH-LABEL: stop:
; SWITCH: .word 3892305662
; SWITCH-NOT: brk
; GENERIC-LABEL: stop:
; GENERIC: brk #0x1
; BYTES-LABEL: stop:
; BYTES: fe de ff e7

define void @stop() {
  call void @llvm.trap()
  unreachable
}

declare void @llvm.trap() nounwind noreturn
