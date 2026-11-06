; RUN: opt -inline -mtriple=aarch64-decomp-switch-elf -S < %s | FileCheck %s --check-prefixes=CHECK,SWITCH
; RUN: opt -inline -mtriple=aarch64-unknown-linux-gnu -S < %s | FileCheck %s --check-prefixes=CHECK,GENERIC
; RUN: opt -inline -mtriple=aarch64-unknown-switch-elf -S < %s | FileCheck %s --check-prefixes=CHECK,GENERIC
; RUN: opt -inline -mtriple=x86_64-decomp-switch-elf -S < %s | FileCheck %s --check-prefixes=CHECK,GENERIC

; Removing the empty call must not move the last call ahead of an earlier call
; to the same callee in another block on Switch. Inlined alloca order exposes
; the worklist order without depending on register allocation.

declare void @consume(i32*)

define internal void @empty() {
  ret void
}

define internal void @emit(i32 %value) {
  %slot = alloca i32, align 4
  store i32 %value, i32* %slot, align 4
  call void @consume(i32* %slot)
  ret void
}

define internal void @other_emit(i32 %value) {
  %other_slot = alloca i32, align 4
  store i32 %value, i32* %other_slot, align 4
  call void @consume(i32* %other_slot)
  ret void
}

; CHECK-LABEL: define void @different_blocks(
; CHECK: %[[FIRST:.*]] = alloca i32, align 4
; CHECK-NEXT: %[[SECOND:.*]] = alloca i32, align 4
; SWITCH: store i32 17, i32* %[[SECOND]], align 4
; GENERIC: store i32 17, i32* %[[FIRST]], align 4
; CHECK: then:
; SWITCH: store i32 23, i32* %[[FIRST]], align 4
; GENERIC: store i32 23, i32* %[[SECOND]], align 4
define void @different_blocks(i1 %condition) {
entry:
  call void @empty()
  call void @emit(i32 17)
  br i1 %condition, label %then, label %exit
then:
  call void @emit(i32 23)
  br label %exit
exit:
  ret void
}

; Calls within one block retain the existing behavior on every target.
; CHECK-LABEL: define void @same_block(
; CHECK: %[[SAME_FIRST:.*]] = alloca i32, align 4
; CHECK-NEXT: %[[SAME_SECOND:.*]] = alloca i32, align 4
; CHECK: store i32 17, i32* %[[SAME_FIRST]], align 4
; CHECK: store i32 23, i32* %[[SAME_SECOND]], align 4
define void @same_block() {
  call void @empty()
  call void @emit(i32 17)
  call void @emit(i32 23)
  ret void
}

; Calls to distinct callees retain the existing behavior, even across blocks.
; CHECK-LABEL: define void @different_callees(
; CHECK: %[[DISTINCT_FIRST:.*]] = alloca i32, align 4
; CHECK-NEXT: %[[DISTINCT_SECOND:.*]] = alloca i32, align 4
; CHECK: store i32 17, i32* %[[DISTINCT_FIRST]], align 4
; CHECK: then:
; CHECK: store i32 23, i32* %[[DISTINCT_SECOND]], align 4
define void @different_callees(i1 %condition) {
entry:
  call void @empty()
  call void @emit(i32 17)
  br i1 %condition, label %then, label %exit
then:
  call void @other_emit(i32 23)
  br label %exit
exit:
  ret void
}
