; RUN: llc -mtriple=aarch64-decomp-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,SWITCH
; RUN: llc -mtriple=aarch64-linux-elf -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,OTHER
; RUN: llc -mtriple=aarch64-unknown-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,OTHER
; RUN: llc -mtriple=aarch64-decomp-unknown-elf -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,OTHER
; RUN: llc -mtriple=aarch64_be-decomp-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,OTHER

define i32 @masked_lsr(i32 %x, i32 %n) {
; CHECK-LABEL: masked_lsr:
; SWITCH: neg w8, w1
; OTHER: mov w8, #32
; OTHER: sub w8, w8, w1
; CHECK: lsr w0, w0, w8
; CHECK: ret
  %neg = sub i32 32, %n
  %mask = and i32 %neg, 31
  %r = lshr i32 %x, %mask
  ret i32 %r
}

define i32 @masked_lsl(i32 %x, i32 %n) {
; CHECK-LABEL: masked_lsl:
; SWITCH: neg w8, w1
; OTHER: mov w8, #64
; OTHER: sub w8, w8, w1
; CHECK: lsl w0, w0, w8
; CHECK: ret
  %neg = sub i32 64, %n
  %mask = and i32 %neg, 31
  %r = shl i32 %x, %mask
  ret i32 %r
}

define i32 @masked_asr(i32 %x, i32 %n) {
; CHECK-LABEL: masked_asr:
; SWITCH: neg w8, w1
; OTHER: mov w8, #32
; OTHER: sub w8, w8, w1
; CHECK: asr w0, w0, w8
; CHECK: ret
  %neg = sub i32 32, %n
  %mask = and i32 %neg, 31
  %r = ashr i32 %x, %mask
  ret i32 %r
}

define i32 @shared_sub(i32 %x, i32 %n, i32* %p) {
; CHECK-LABEL: shared_sub:
; CHECK: mov w8, #32
; SWITCH: neg w9, w1
; CHECK: sub w8, w8, w1
; SWITCH: lsr w0, w0, w9
; OTHER: lsr w0, w0, w8
; CHECK: str w8, [x2]
; CHECK: ret
  %neg = sub i32 32, %n
  %mask = and i32 %neg, 31
  store i32 %neg, i32* %p
  %r = lshr i32 %x, %mask
  ret i32 %r
}

define i32 @shared_mask(i32 %x, i32 %n, i32* %p) {
; CHECK-LABEL: shared_mask:
; CHECK: and
; CHECK: str
; CHECK: ret
  %neg = sub i32 32, %n
  %mask = and i32 %neg, 31
  store i32 %mask, i32* %p
  %r = lshr i32 %x, %mask
  ret i32 %r
}

define i32 @narrow_mask(i32 %x, i32 %n) {
; CHECK-LABEL: narrow_mask:
; CHECK: and
; CHECK: lsr
; CHECK: ret
  %neg = sub i32 32, %n
  %mask = and i32 %neg, 15
  %r = lshr i32 %x, %mask
  ret i32 %r
}

define i32 @nonmultiple(i32 %x, i32 %n) {
; CHECK-LABEL: nonmultiple:
; CHECK: mov w8, #33
; CHECK: sub w8, w8, w1
; CHECK: lsr w0, w0, w8
; CHECK: ret
  %neg = sub i32 33, %n
  %mask = and i32 %neg, 31
  %r = lshr i32 %x, %mask
  ret i32 %r
}

define i32 @variable_sub(i32 %x, i32 %n, i32 %m) {
; CHECK-LABEL: variable_sub:
; CHECK: sub w8, w2, w1
; CHECK: lsr w0, w0, w8
; CHECK: ret
  %neg = sub i32 %m, %n
  %mask = and i32 %neg, 31
  %r = lshr i32 %x, %mask
  ret i32 %r
}

; Both uses need only a shift count, including legalization's count extension.
define i32 @two_shifts(i32 %x, i32 %n, i32 %y) {
; CHECK-LABEL: two_shifts:
; SWITCH: neg w8, w1
; SWITCH-NOT: sub
; SWITCH: lsr w9, w0, w8
; SWITCH: lsl w8, w2, w8
; OTHER: mov w8, #32
; OTHER: neg w9, w1
; OTHER: sub w8, w8, w1
; CHECK: eor
; CHECK: ret
  %neg = sub i32 32, %n
  %mask = and i32 %neg, 31
  %a = lshr i32 %x, %mask
  %b = shl i32 %y, %neg
  %r = xor i32 %a, %b
  ret i32 %r
}

; Additive offsets preserve the low hardware shift-count bits.
define i32 @masked_add32(i32 %x, i32 %n) {
; CHECK-LABEL: masked_add32:
; SWITCH: lsr w0, w0, w1
; OTHER: add w8, w1, #32
; OTHER: lsr w0, w0, w8
; CHECK: ret
  %count = add i32 %n, 32
  %mask = and i32 %count, 31
  %r = lshr i32 %x, %mask
  ret i32 %r
}
define i32 @masked_sub32_shared(i32 %x, i32 %n, i32* %p) {
; CHECK-LABEL: masked_sub32_shared:
; CHECK: sub w8, w1, #32
; SWITCH: lsl w0, w0, w1
; OTHER: lsl w0, w0, w8
; CHECK: str w8, [x2]
; CHECK: ret
  %count = sub i32 %n, 32
  %mask = and i32 %count, 31
  store i32 %count, i32* %p
  %r = shl i32 %x, %mask
  ret i32 %r
}
define i64 @masked_add64(i64 %x, i64 %n) {
; CHECK-LABEL: masked_add64:
; CHECK: add w8, w1, #128
; CHECK: lsl x0, x0, x8
; CHECK: ret
  %count = add i64 %n, 128
  %mask = and i64 %count, 63
  %r = shl i64 %x, %mask
  ret i64 %r
}
define i64 @masked_sub64(i64 %x, i64 %n) {
; CHECK-LABEL: masked_sub64:
; CHECK: sub w8, w1, #64
; CHECK: asr x0, x0, x8
; CHECK: ret
  %count = sub i64 %n, 64
  %mask = and i64 %count, 63
  %r = ashr i64 %x, %mask
  ret i64 %r
}
define i32 @masked_add_negative(i32 %x, i32 %n) {
; CHECK-LABEL: masked_add_negative:
; SWITCH: asr w0, w0, w1
; OTHER: sub w8, w1, #64
; OTHER: asr w0, w0, w8
; CHECK: ret
  %count = add i32 %n, -64
  %mask = and i32 %count, 31
  %r = ashr i32 %x, %mask
  ret i32 %r
}
define i32 @masked_add_nonmultiple(i32 %x, i32 %n) {
; CHECK-LABEL: masked_add_nonmultiple:
; CHECK: add w8, w1, #33
; CHECK: lsr w0, w0, w8
; CHECK: ret
  %count = add i32 %n, 33
  %mask = and i32 %count, 31
  %r = lshr i32 %x, %mask
  ret i32 %r
}
define i64 @masked_add64_narrow(i64 %x, i64 %n) {
; CHECK-LABEL: masked_add64_narrow:
; CHECK: and x8, x8, #0x1f
; CHECK: lsr x0, x0, x8
; CHECK: ret
  %count = add i64 %n, 64
  %mask = and i64 %count, 31
  %r = lshr i64 %x, %mask
  ret i64 %r
}
define i32 @masked_add_shared_mask(i32 %x, i32 %n, i32* %p) {
; CHECK-LABEL: masked_add_shared_mask:
; CHECK: add w8, w1, #32
; CHECK: and w9, w8, #0x1f
; CHECK: lsr w0, w0, w8
; CHECK: str w9, [x2]
; CHECK: ret
  %count = add i32 %n, 32
  %mask = and i32 %count, 31
  store i32 %mask, i32* %p
  %r = lshr i32 %x, %mask
  ret i32 %r
}
define i64 @masked_add32_for64(i64 %x, i32 %n) {
; CHECK-LABEL: masked_add32_for64:
; SWITCH: lsr x0, x0, x1
; OTHER: add w8, w1, #64
; OTHER: lsr x0, x0, x8
; CHECK: ret
  %count = add i32 %n, 64
  %mask = and i32 %count, 63
  %wide = zext i32 %mask to i64
  %r = lshr i64 %x, %wide
  ret i64 %r
}
