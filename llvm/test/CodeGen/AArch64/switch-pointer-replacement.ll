; RUN: llc -mtriple=aarch64-decomp-linux-gnu -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC
; RUN: llc -mtriple=aarch64-decomp-switch-elf -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,SWITCH
; RUN: llc -mtriple=aarch64-unknown-linux-gnu -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC
; RUN: llc -mtriple=aarch64-unknown-switch-elf -stop-after=codegenprepare -o - %s | FileCheck %s --check-prefixes=ALL,GENERIC

%holder = type { i64, i8* }
declare i8* @allocate()
declare void @release(i8*)
declare void @consume(i8*)

; ALL-LABEL: define void @checked_replacement(
; ALL: %field = getelementptr
; SWITCH: %old = load i8*, i8** %field
; GENERIC: %old = load i8*, i8** %{{[0-9]+}}
; SWITCH: store i8* %incoming, i8** %field
; GENERIC: store i8* %incoming, i8** %{{[0-9]+}}
define void @checked_replacement(%holder* %object, i1 %condition) {
entry:
  %field = getelementptr %holder, %holder* %object, i64 0, i32 1
  store i8* null, i8** %field
  br i1 %condition, label %update, label %exit
update:
  %incoming = call i8* @allocate()
  %old = load i8*, i8** %field
  %same = icmp eq i8* %old, %incoming
  br i1 %same, label %exit, label %replace
replace:
  store i8* %incoming, i8** %field
  call void @release(i8* %old)
  %current = load i8*, i8** %field
  call void @consume(i8* %current)
  br label %exit
exit:
  ret void
}

; A null-initialized output parameter without a replacement equality check
; keeps normal address sinking on every target.
; ALL-LABEL: define void @unchecked_replacement(
; ALL: %old = load i8*, i8** %{{[0-9]+}}
; ALL: store i8* %incoming, i8** %{{[0-9]+}}
define void @unchecked_replacement(%holder* %object, i1 %condition) {
entry:
  %field = getelementptr %holder, %holder* %object, i64 0, i32 1
  store i8* null, i8** %field
  br i1 %condition, label %update, label %exit
update:
  %incoming = call i8* @allocate()
  %old = load i8*, i8** %field
  store i8* %incoming, i8** %field
  call void @release(i8* %old)
  %current = load i8*, i8** %field
  call void @consume(i8* %current)
  br label %exit
exit:
  ret void
}

; A nonnull initializer is not the null-initialization pattern.
; ALL-LABEL: define void @nonnull_replacement(
; ALL: %old = load i8*, i8** %{{[0-9]+}}
define void @nonnull_replacement(%holder* %object, i8* %initial, i1 %condition) {
entry:
  %field = getelementptr %holder, %holder* %object, i64 0, i32 1
  store i8* %initial, i8** %field
  br i1 %condition, label %update, label %exit
update:
  %incoming = call i8* @allocate()
  %old = load i8*, i8** %field
  %same = icmp eq i8* %old, %incoming
  br i1 %same, label %exit, label %replace
replace:
  store i8* %incoming, i8** %field
  call void @release(i8* %old)
  %current = load i8*, i8** %field
  call void @consume(i8* %current)
  br label %exit
exit:
  ret void
}
