; RUN: llc -O3 -mtriple=aarch64-decomp-switch-elf -o - %s | FileCheck %s --check-prefixes=ALL,SWITCH
; RUN: llc -O3 -mtriple=aarch64-unknown-linux-gnu -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC
; RUN: llc -O3 -mtriple=aarch64-unknown-switch-elf -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC
; RUN: llc -O3 -mtriple=aarch64-decomp-linux-gnu -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC

target triple = "aarch64-decomp-switch-elf"
%record = type { i64, i8*, i8*, i64, i32, [96 x i8] }
declare void @consume_field(i8**)
; Only zero-initializing writeback stores use the Switch clustering policy.
; ALL-LABEL: initialize:
; ALL: str x2, [x0]
; GENERIC-NEXT: neg x11, x1
; ALL-NEXT: str xzr, [x8, #8]!
; ALL-NEXT: str w9, [x0, #32]
; ALL-NEXT: add x9, x10, #35
; SWITCH-NEXT: neg x10, x1
; SWITCH-NEXT: and x9, x9, x10
; GENERIC-NEXT: and x9, x9, x11
; ALL-NEXT: stp x9, xzr, [x0, #16]
define void @initialize(%record* %object, i64 %alignment, i64 %initial) {
entry:
  %first = getelementptr %record, %record* %object, i64 0, i32 0
  store i64 %initial, i64* %first
  %field = getelementptr %record, %record* %object, i64 0, i32 1
  store i8* null, i8** %field
  %position = getelementptr %record, %record* %object, i64 0, i32 3
  store i64 0, i64* %position
  %flag = getelementptr %record, %record* %object, i64 0, i32 4
  store i32 1, i32* %flag
  %local = getelementptr %record, %record* %object, i64 0, i32 5, i64 0
  %ptr = ptrtoint i8* %local to i64
  %bias = add i64 %alignment, -1
  %add = add i64 %bias, %ptr
  %mask = sub i64 0, %alignment
  %aligned = and i64 %add, %mask
  %buffer = inttoptr i64 %aligned to i8*
  %slot = getelementptr %record, %record* %object, i64 0, i32 2
  store i8* %buffer, i8** %slot
  call void @consume_field(i8** %field)
  ret void
}

; ALL-LABEL: initialize_nonzero:
; ALL: str x2, [x0]
; ALL-NEXT: neg x11, x1
; ALL-NEXT: str x2, [x8, #8]!
; ALL-NEXT: str w9, [x0, #32]
; ALL-NEXT: add x9, x10, #35
; ALL-NEXT: and x9, x9, x11
; ALL-NEXT: stp x9, xzr, [x0, #16]
define void @initialize_nonzero(%record* %object, i64 %alignment, i64 %initial) {
entry:
  %first = getelementptr %record, %record* %object, i64 0, i32 0
  store i64 %initial, i64* %first
  %field = getelementptr %record, %record* %object, i64 0, i32 1
  %initialptr = inttoptr i64 %initial to i8*
  store i8* %initialptr, i8** %field
  %position = getelementptr %record, %record* %object, i64 0, i32 3
  store i64 0, i64* %position
  %flag = getelementptr %record, %record* %object, i64 0, i32 4
  store i32 1, i32* %flag
  %local = getelementptr %record, %record* %object, i64 0, i32 5, i64 0
  %ptr = ptrtoint i8* %local to i64
  %bias = add i64 %alignment, -1
  %add = add i64 %bias, %ptr
  %mask = sub i64 0, %alignment
  %aligned = and i64 %add, %mask
  %buffer = inttoptr i64 %aligned to i8*
  %slot = getelementptr %record, %record* %object, i64 0, i32 2
  store i8* %buffer, i8** %slot
  call void @consume_field(i8** %field)
  ret void
}

; ALL-LABEL: initialize_plain:
; ALL: mov w8, #1
; ALL-NEXT: add x9, x0, x1
; ALL-NEXT: neg x10, x1
; ALL-NEXT: str w8, [x0, #32]
; ALL-NEXT: add x8, x9, #35
; ALL-NEXT: and x8, x8, x10
; ALL-NEXT: stp x2, xzr, [x0]
; ALL-NEXT: stp x8, xzr, [x0, #16]
; ALL-NEXT: ret
define void @initialize_plain(%record* %object, i64 %alignment, i64 %initial) {
entry:
  %first = getelementptr %record, %record* %object, i64 0, i32 0
  store i64 %initial, i64* %first
  %field = getelementptr %record, %record* %object, i64 0, i32 1
  store i8* null, i8** %field
  %position = getelementptr %record, %record* %object, i64 0, i32 3
  store i64 0, i64* %position
  %flag = getelementptr %record, %record* %object, i64 0, i32 4
  store i32 1, i32* %flag
  %local = getelementptr %record, %record* %object, i64 0, i32 5, i64 0
  %ptr = ptrtoint i8* %local to i64
  %bias = add i64 %alignment, -1
  %add = add i64 %bias, %ptr
  %mask = sub i64 0, %alignment
  %aligned = and i64 %add, %mask
  %buffer = inttoptr i64 %aligned to i8*
  %slot = getelementptr %record, %record* %object, i64 0, i32 2
  store i8* %buffer, i8** %slot
  ret void
}
