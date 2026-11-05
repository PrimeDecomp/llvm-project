; RUN: llc -mtriple=aarch64-decomp-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefix=SWITCH
; RUN: llc -mtriple=aarch64-linux-gnu -verify-machineinstrs < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-unknown-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64-decomp-unknown-elf -verify-machineinstrs < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=aarch64_be-decomp-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefix=GENERIC

; A conditional signed 32-bit offset can use SUB's extended register operand.
; SWITCH-LABEL: sub_offset:
; SWITCH-NOT: sxtw {{x[0-9]+}},
; SWITCH: sub {{x[0-9]+}}, x0, w1, sxtw
; SWITCH: csel
; SWITCH: ret
; GENERIC-LABEL: sub_offset:
; GENERIC: sxtw
; GENERIC: csel
; GENERIC: sub
define i64 @sub_offset(i64 %base, i64 %offset) {
  %low = trunc i64 %offset to i32
  %extended = sext i32 %low to i64
  %positive = icmp sgt i64 %offset, 0
  %selected = select i1 %positive, i64 %extended, i64 0
  %result = sub i64 %base, %selected
  ret i64 %result
}

; Handle the opposite select arm too.
; SWITCH-LABEL: sub_offset_false:
; SWITCH-NOT: sxtw {{x[0-9]+}},
; SWITCH: sub {{x[0-9]+}}, x0, w1, sxtw
; SWITCH: csel
; SWITCH: ret
define i64 @sub_offset_false(i64 %base, i64 %offset, i1 %condition) {
  %low = trunc i64 %offset to i32
  %extended = sext i32 %low to i64
  %selected = select i1 %condition, i64 0, i64 %extended
  %result = sub i64 %base, %selected
  ret i64 %result
}

; Do not duplicate a sign extension that another instruction also needs.
; SWITCH-LABEL: shared_extension:
; SWITCH: sxtw
; SWITCH: csel
define i64 @shared_extension(i64 %base, i64 %offset, i1 %condition, i64* %out) {
  %low = trunc i64 %offset to i32
  %extended = sext i32 %low to i64
  store i64 %extended, i64* %out
  %selected = select i1 %condition, i64 %extended, i64 0
  %result = sub i64 %base, %selected
  ret i64 %result
}

; Do not duplicate a select used outside the subtraction.
; SWITCH-LABEL: shared_select:
; SWITCH: sxtw
; SWITCH: csel
define i64 @shared_select(i64 %base, i64 %offset, i1 %condition, i64* %out) {
  %low = trunc i64 %offset to i32
  %extended = sext i32 %low to i64
  %selected = select i1 %condition, i64 %extended, i64 0
  store i64 %selected, i64* %out
  %result = sub i64 %base, %selected
  ret i64 %result
}

; Both arms would need arithmetic when the other arm is nonzero.
; SWITCH-LABEL: nonzero_alternative:
; SWITCH: sxtw
; SWITCH: csel
define i64 @nonzero_alternative(i64 %base, i64 %offset, i1 %condition) {
  %low = trunc i64 %offset to i32
  %extended = sext i32 %low to i64
  %selected = select i1 %condition, i64 %extended, i64 7
  %result = sub i64 %base, %selected
  ret i64 %result
}

; Keep the zero-base case available for conditional negation.
; SWITCH-LABEL: zero_base:
; SWITCH-NOT: sub
; SWITCH: ret
define i64 @zero_base(i64 %offset, i1 %condition) {
  %low = trunc i64 %offset to i32
  %extended = sext i32 %low to i64
  %selected = select i1 %condition, i64 %extended, i64 0
  %result = sub i64 0, %selected
  ret i64 %result
}

; Other extension widths are outside this combine.
; SWITCH-LABEL: short_offset:
; SWITCH: sxth
; SWITCH: csel
; SWITCH: sub
define i64 @short_offset(i64 %base, i64 %offset, i1 %condition) {
  %low = trunc i64 %offset to i16
  %extended = sext i16 %low to i64
  %selected = select i1 %condition, i64 %extended, i64 0
  %result = sub i64 %base, %selected
  ret i64 %result
}
