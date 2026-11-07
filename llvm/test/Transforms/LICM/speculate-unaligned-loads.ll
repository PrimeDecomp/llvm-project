; RUN: opt -S -licm < %s | FileCheck %s --check-prefixes=CHECK,DEFAULT
; RUN: opt -S -licm -licm-speculate-unaligned-loads=false < %s | FileCheck %s --check-prefixes=CHECK,RESTRICTED
; RUN: opt -S -aa-pipeline=basic-aa -passes='require<opt-remark-emit>,loop(licm)' < %s | FileCheck %s --check-prefixes=CHECK,DEFAULT
; RUN: opt -S -aa-pipeline=basic-aa -passes='require<opt-remark-emit>,loop(licm)' -licm-speculate-unaligned-loads=false < %s | FileCheck %s --check-prefixes=CHECK,RESTRICTED
; RUN: opt -S -licm -enable-mssa-loop-dependency=true -verify-memoryssa < %s | FileCheck %s --check-prefixes=CHECK,DEFAULT
; RUN: opt -S -licm -enable-mssa-loop-dependency=true -verify-memoryssa -licm-speculate-unaligned-loads=false < %s | FileCheck %s --check-prefixes=CHECK,RESTRICTED

; Restrict only speculative load motion lacking proven ABI alignment.
; Default behavior and guaranteed-to-execute motion remain available.

target datalayout = "e-m:e-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-unknown-linux-gnu"

; CHECK-LABEL: @conditional(
; CHECK: entry:
; DEFAULT-NEXT: %value = load i64, i64* %p, align 4
; RESTRICTED-NOT: %value = load
; CHECK: br label %loop
; CHECK: use:
; RESTRICTED-NEXT: %value = load i64, i64* %p, align 4
; DEFAULT-NOT: %value = load
; CHECK: store i64 %value
define void @conditional(i64* noalias readonly align 4 dereferenceable(8) %p, i64* noalias %out, i32* noalias %conditions, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]

  %condition.ptr = getelementptr i32, i32* %conditions, i64 %i
  %condition = load i32, i32* %condition.ptr, align 4
  %test = icmp ne i32 %condition, 0
  br i1 %test, label %use, label %latch
use:
  %value = load i64, i64* %p, align 4
  %out.ptr = getelementptr i64, i64* %out, i64 %i
  store i64 %value, i64* %out.ptr, align 8
  br label %latch
latch:
  %next = add nuw i64 %i, 1
  %again = icmp ult i64 %next, %n
  br i1 %again, label %loop, label %exit
exit:
  ret void
}

; CHECK-LABEL: @proven(
; CHECK: entry:
; CHECK-NEXT: %value = load i64, i64* %p, align 4
; CHECK-NEXT: br label %loop
; CHECK: use:
; CHECK-NOT: %value = load
; CHECK: store i64 %value
define void @proven(i64* noalias readonly align 8 dereferenceable(8) %p, i64* noalias %out, i32* noalias %conditions, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]

  %condition.ptr = getelementptr i32, i32* %conditions, i64 %i
  %condition = load i32, i32* %condition.ptr, align 4
  %test = icmp ne i32 %condition, 0
  br i1 %test, label %use, label %latch
use:
  %value = load i64, i64* %p, align 4
  %out.ptr = getelementptr i64, i64* %out, i64 %i
  store i64 %value, i64* %out.ptr, align 8
  br label %latch
latch:
  %next = add nuw i64 %i, 1
  %again = icmp ult i64 %next, %n
  br i1 %again, label %loop, label %exit
exit:
  ret void
}

; CHECK-LABEL: @aligned(
; CHECK: entry:
; CHECK-NEXT: %value = load i64, i64* %p, align 8
; CHECK-NEXT: br label %loop
; CHECK: use:
; CHECK-NOT: %value = load
; CHECK: store i64 %value
define void @aligned(i64* noalias readonly align 8 dereferenceable(8) %p, i64* noalias %out, i32* noalias %conditions, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]

  %condition.ptr = getelementptr i32, i32* %conditions, i64 %i
  %condition = load i32, i32* %condition.ptr, align 4
  %test = icmp ne i32 %condition, 0
  br i1 %test, label %use, label %latch
use:
  %value = load i64, i64* %p, align 8
  %out.ptr = getelementptr i64, i64* %out, i64 %i
  store i64 %value, i64* %out.ptr, align 8
  br label %latch
latch:
  %next = add nuw i64 %i, 1
  %again = icmp ult i64 %next, %n
  br i1 %again, label %loop, label %exit
exit:
  ret void
}

; CHECK-LABEL: @guaranteed(
; CHECK: entry:
; CHECK-NEXT: %value = load i64, i64* %p, align 4
; CHECK-NEXT: br label %loop
; CHECK: use:
; CHECK-NOT: %value = load
; CHECK: store i64 %value
define void @guaranteed(i64* noalias readonly align 4 dereferenceable(8) %p, i64* noalias %out, i32* noalias %conditions, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %value = load i64, i64* %p, align 4
  %condition.ptr = getelementptr i32, i32* %conditions, i64 %i
  %condition = load i32, i32* %condition.ptr, align 4
  %test = icmp ne i32 %condition, 0
  br i1 %test, label %use, label %latch
use:

  %out.ptr = getelementptr i64, i64* %out, i64 %i
  store i64 %value, i64* %out.ptr, align 8
  br label %latch
latch:
  %next = add nuw i64 %i, 1
  %again = icmp ult i64 %next, %n
  br i1 %again, label %loop, label %exit
exit:
  ret void
}

; CHECK-LABEL: @volatile(
; CHECK: entry:
; CHECK-NOT: %value = load
; CHECK: use:
; CHECK-NEXT: %value = load volatile i64, i64* %p, align 4
; CHECK: store i64 %value
define void @volatile(i64* noalias readonly align 4 dereferenceable(8) %p, i64* noalias %out, i32* noalias %conditions, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]

  %condition.ptr = getelementptr i32, i32* %conditions, i64 %i
  %condition = load i32, i32* %condition.ptr, align 4
  %test = icmp ne i32 %condition, 0
  br i1 %test, label %use, label %latch
use:
  %value = load volatile i64, i64* %p, align 4
  %out.ptr = getelementptr i64, i64* %out, i64 %i
  store i64 %value, i64* %out.ptr, align 8
  br label %latch
latch:
  %next = add nuw i64 %i, 1
  %again = icmp ult i64 %next, %n
  br i1 %again, label %loop, label %exit
exit:
  ret void
}

