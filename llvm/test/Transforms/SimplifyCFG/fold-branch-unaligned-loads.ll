; RUN: opt -S -simplifycfg < %s | FileCheck %s --check-prefixes=CHECK,DEFAULT
; RUN: opt -S -simplifycfg -simplifycfg-fold-branch-unaligned-loads=false < %s | FileCheck %s --check-prefixes=CHECK,LIMITED
; RUN: opt -S -passes=simplify-cfg < %s | FileCheck %s --check-prefixes=CHECK,DEFAULT
; RUN: opt -S -passes=simplify-cfg -simplifycfg-fold-branch-unaligned-loads=false < %s | FileCheck %s --check-prefixes=CHECK,LIMITED
;
; Keep the second sub-ABI-aligned load conditional only when requested.
; DEFAULT-LABEL: define void @unaligned(
; DEFAULT: entry:
; DEFAULT: %y = load i64, {{.*}}, align 4
; DEFAULT-NEXT: %d = icmp eq i64 %b, %y
; DEFAULT-NEXT: %or.cond = and i1 %c, %d
; DEFAULT-NEXT: br i1 %or.cond, label %true, label %false
; LIMITED-LABEL: define void @unaligned(
; LIMITED: br i1 %c, label %second, label %false
; LIMITED: second:
; LIMITED-NEXT: %y = load i64, {{.*}}, align 4
; LIMITED-NEXT: %d = icmp eq i64 %b, %y
; LIMITED-NEXT: br i1 %d, label %true, label %false

target datalayout = "e-m:e-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-decomp-switch-elf"
@words = external global [2 x i64], align 4
@aligned_words = external global [2 x i64], align 8
declare void @yes()
declare void @no()
define void @unaligned(i64 %a, i64 %b) {
entry:
  %x = load i64, i64* getelementptr ([2 x i64], [2 x i64]* @words, i64 0, i64 0), align 4
  %c = icmp eq i64 %a, %x
  br i1 %c, label %second, label %false
second:
  %y = load i64, i64* getelementptr ([2 x i64], [2 x i64]* @words, i64 0, i64 1), align 4
  %d = icmp eq i64 %b, %y
  br i1 %d, label %true, label %false
true:
  call void @yes()
  ret void
false:
  call void @no()
  ret void
}

; CHECK-LABEL: define void @aligned(
; CHECK: %or.cond = and i1 %c, %d
; CHECK-NEXT: br i1 %or.cond, label %true, label %false
define void @aligned(i64 %a, i64 %b) {
entry:
  %x = load i64, i64* getelementptr ([2 x i64], [2 x i64]* @aligned_words, i64 0, i64 0), align 8
  %c = icmp eq i64 %a, %x
  br i1 %c, label %second, label %false
second:
  %y = load i64, i64* getelementptr ([2 x i64], [2 x i64]* @aligned_words, i64 0, i64 1), align 8
  %d = icmp eq i64 %b, %y
  br i1 %d, label %true, label %false
true:
  call void @yes()
  ret void
false:
  call void @no()
  ret void
}

; CHECK-LABEL: define void @implicit_alignment(
; CHECK: %or.cond = and i1 %c, %d
; CHECK-NEXT: br i1 %or.cond, label %true, label %false
define void @implicit_alignment(i64 %a, i64 %b) {
entry:
  %x = load i64, i64* getelementptr ([2 x i64], [2 x i64]* @aligned_words, i64 0, i64 0)
  %c = icmp eq i64 %a, %x
  br i1 %c, label %second, label %false
second:
  %y = load i64, i64* getelementptr ([2 x i64], [2 x i64]* @aligned_words, i64 0, i64 1)
  %d = icmp eq i64 %b, %y
  br i1 %d, label %true, label %false
true:
  call void @yes()
  ret void
false:
  call void @no()
  ret void
}

; CHECK-LABEL: define void @volatile_load(
; CHECK: br i1 %c, label %second, label %false
; CHECK: second:
; CHECK-NEXT: %y = load volatile i64
define void @volatile_load(i64 %a, i64 %b) {
entry:
  %x = load volatile i64, i64* getelementptr ([2 x i64], [2 x i64]* @words, i64 0, i64 0), align 4
  %c = icmp eq i64 %a, %x
  br i1 %c, label %second, label %false
second:
  %y = load volatile i64, i64* getelementptr ([2 x i64], [2 x i64]* @words, i64 0, i64 1), align 4
  %d = icmp eq i64 %b, %y
  br i1 %d, label %true, label %false
true:
  call void @yes()
  ret void
false:
  call void @no()
  ret void
}
