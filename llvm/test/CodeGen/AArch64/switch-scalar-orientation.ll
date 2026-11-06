; RUN: opt -mtriple=x86_64-decomp-switch-elf -codegenprepare -S %s | FileCheck %s --check-prefixes=ALL,GENERIC
; RUN: llc -mtriple=aarch64-decomp-linux-gnu -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC
; RUN: llc -mtriple=aarch64-decomp-switch-elf -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,SWITCH
; RUN: llc -mtriple=aarch64-unknown-linux-gnu -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC
; RUN: llc -mtriple=aarch64-unknown-switch-elf -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC

; ALL-LABEL: define i64 @positive_narrow(
; SWITCH: %positive = icmp sle i64 %delta, 0
; GENERIC: %positive = icmp sgt i64 %delta, 0
; SWITCH: %amount = select i1 %positive, i64 0, i64 %wide
; GENERIC: %amount = select i1 %positive, i64 %wide, i64 0
define i64 @positive_narrow(i64 %size, i64 %delta) {
  %positive = icmp sgt i64 %delta, 0
  %small = trunc i64 %delta to i32
  %wide = sext i32 %small to i64
  %amount = select i1 %positive, i64 %wide, i64 0
  %result = sub i64 %size, %amount
  ret i64 %result
}

; Ordinary positive clamping retains its existing comparison.
; ALL-LABEL: define i64 @positive_plain(
; ALL: %positive = icmp sgt i64 %delta, 0
; ALL: %amount = select i1 %positive, i64 %delta, i64 0
define i64 @positive_plain(i64 %size, i64 %delta) {
  %positive = icmp sgt i64 %delta, 0
  %amount = select i1 %positive, i64 %delta, i64 0
  %result = sub i64 %size, %amount
  ret i64 %result
}

; Do not invert a comparison with another user.
; ALL-LABEL: define i64 @shared_comparison(
; ALL: %positive = icmp sgt i64 %delta, 0
define i64 @shared_comparison(i64 %size, i64 %delta, i1* %flag) {
  %positive = icmp sgt i64 %delta, 0
  store i1 %positive, i1* %flag
  %small = trunc i64 %delta to i32
  %wide = sext i32 %small to i64
  %amount = select i1 %positive, i64 %wide, i64 0
  %result = sub i64 %size, %amount
  ret i64 %result
}

declare i64 @left()
declare i64 @right()

; ALL-LABEL: define i64 @align_phi(
; SWITCH: %sum = add i64 %bias, %value
; GENERIC: %sum = add i64 %value, %bias
define i64 @align_phi(i64 %alignment, i1 %condition) {
entry:
  %bias = add i64 %alignment, -1
  %mask = sub i64 0, %alignment
  br i1 %condition, label %a, label %b
a:
  %x = call i64 @left()
  br label %join
b:
  %y = call i64 @right()
  br label %join
join:
  %value = phi i64 [ %x, %a ], [ %y, %b ]
  %sum = add i64 %value, %bias
  %result = and i64 %sum, %mask
  ret i64 %result
}

; Do not commute an unrelated PHI addition.
; ALL-LABEL: define i64 @plain_phi_add(
; ALL: %sum = add i64 %value, %bias
define i64 @plain_phi_add(i64 %bias, i1 %condition) {
entry:
  br i1 %condition, label %a, label %b
a:
  %x = call i64 @left()
  br label %join
b:
  %y = call i64 @right()
  br label %join
join:
  %value = phi i64 [ %x, %a ], [ %y, %b ]
  %sum = add i64 %value, %bias
  ret i64 %sum
}
