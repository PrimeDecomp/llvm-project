; REQUIRES: aarch64
; RUN: llvm-as %s -o %t.bc
; RUN: ld.lld %t.bc -o %t --entry=stop
; RUN: llvm-objdump -d %t | FileCheck %s

; LTO must use the same Switch trap lowering as the compiler.
target datalayout = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-decomp-switch-elf"

; CHECK-LABEL: stop:
; CHECK: fe de ff e7
define void @stop() {
  call void @llvm.trap()
  unreachable
}

declare void @llvm.trap() nounwind noreturn
