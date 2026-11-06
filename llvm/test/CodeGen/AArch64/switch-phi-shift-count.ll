; RUN: opt -codegenprepare -mtriple=aarch64-decomp-switch-elf -S < %s | FileCheck %s --check-prefix=SWITCH
; RUN: opt -codegenprepare -mtriple=aarch64-linux-elf -S < %s | FileCheck %s --check-prefix=OTHER
; RUN: opt -codegenprepare -mtriple=aarch64-unknown-switch-elf -S < %s | FileCheck %s --check-prefix=OTHER
; RUN: opt -codegenprepare -mtriple=aarch64-decomp-unknown-elf -S < %s | FileCheck %s --check-prefix=OTHER
; RUN: opt -codegenprepare -mtriple=aarch64_be-decomp-switch-elf -S < %s | FileCheck %s --check-prefix=OTHER
; RUN: llc -mtriple=aarch64-decomp-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM

; Volatile stores keep the incoming blocks separate and check that non-shift
; uses of the original masks retain their full value.
define i32 @masked_phi32(i1 %c, i32 %x, i32 %a, i32 %b, i32* %p) {
; SWITCH-LABEL: @masked_phi32(
; SWITCH: %count = phi i32 [ %a, %left ], [ %b, %right ]
; SWITCH: %[[MASK:.*]] = and i32 %count, 31
; SWITCH: %r = lshr i32 %x, %[[MASK]]
; OTHER-LABEL: @masked_phi32(
; OTHER: %count = phi i32 [ %am, %left ], [ %bm, %right ]
; OTHER: %r = lshr i32 %x, %count
; ASM-LABEL: masked_phi32:
; ASM: lsr
; ASM: ret
  br i1 %c, label %left, label %right
left:
  %am = and i32 %a, 31
  store volatile i32 %am, i32* %p
  br label %join
right:
  %bm = and i32 %b, 31
  store volatile i32 %bm, i32* %p
  br label %join
join:
  %count = phi i32 [ %am, %left ], [ %bm, %right ]
  %r = lshr i32 %x, %count
  ret i32 %r
}

; The unmasked edge is unchanged for every defined shift count.
define i64 @mixed_phi64(i1 %c, i64 %x, i64 %a, i64 %b, i64* %p) {
; SWITCH-LABEL: @mixed_phi64(
; SWITCH: %count = phi i64 [ %a, %left ], [ %b, %right ]
; SWITCH: %[[MASK:.*]] = and i64 %count, 63
; SWITCH: %r = ashr i64 %x, %[[MASK]]
; OTHER-LABEL: @mixed_phi64(
; OTHER: %count = phi i64 [ %am, %left ], [ %b, %right ]
; OTHER: %r = ashr i64 %x, %count
; ASM-LABEL: mixed_phi64:
; ASM: asr
; ASM: ret
  br i1 %c, label %left, label %right
left:
  %am = and i64 %a, 63
  store volatile i64 %am, i64* %p
  br label %join
right:
  store volatile i64 %b, i64* %p
  br label %join
join:
  %count = phi i64 [ %am, %left ], [ %b, %right ]
  %r = ashr i64 %x, %count
  ret i64 %r
}

; A shared PHI must retain the original masked value for its store.
define i32 @shared_phi(i1 %c, i32 %x, i32 %a, i32 %b, i32* %p) {
; SWITCH-LABEL: @shared_phi(
; SWITCH: %count = phi i32 [ %am, %left ], [ %b, %right ]
; SWITCH: store volatile i32 %count
; SWITCH: %r = shl i32 %x, %count
; OTHER-LABEL: @shared_phi(
; OTHER: %count = phi i32 [ %am, %left ], [ %b, %right ]
  br i1 %c, label %left, label %right
left:
  %am = and i32 %a, 31
  store volatile i32 %am, i32* %p
  br label %join
right:
  store volatile i32 %b, i32* %p
  br label %join
join:
  %count = phi i32 [ %am, %left ], [ %b, %right ]
  store volatile i32 %count, i32* %p
  %r = shl i32 %x, %count
  ret i32 %r
}

; A 31 mask is not redundant for a 64-bit shift.
define i64 @narrow_mask64(i1 %c, i64 %x, i64 %a, i64 %b, i64* %p) {
; SWITCH-LABEL: @narrow_mask64(
; SWITCH: %count = phi i64 [ %am, %left ], [ %b, %right ]
; SWITCH: %r = shl i64 %x, %count
; OTHER-LABEL: @narrow_mask64(
; OTHER: %count = phi i64 [ %am, %left ], [ %b, %right ]
  br i1 %c, label %left, label %right
left:
  %am = and i64 %a, 31
  store volatile i64 %am, i64* %p
  br label %join
right:
  store volatile i64 %b, i64* %p
  br label %join
join:
  %count = phi i64 [ %am, %left ], [ %b, %right ]
  %r = shl i64 %x, %count
  ret i64 %r
}
