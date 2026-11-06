; RUN: llc -O3 -mcpu=cortex-a57 -mtriple=aarch64-decomp-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefix=SWITCH
; RUN: llc -O3 -mcpu=cortex-a57 -mtriple=aarch64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s --check-prefix=GENERIC
; RUN: llc -O3 -mcpu=cortex-a57 -mtriple=aarch64-unknown-switch-elf -verify-machineinstrs < %s | FileCheck %s --check-prefix=GENERIC
;
; Expand the scalar induction use before its scaled address. The original
; count can then share a register with the address after the scale, instead
; of keeping a fourth callee-saved register live through the loop.
;
; SWITCH-LABEL: shift:
; SWITCH: str x21, [sp, #16]
; SWITCH: sub x21, x20, x21
; SWITCH-NEXT: lsl x20, x20, #6
; SWITCH: add x8, x8, x20
; SWITCH: bl destroy
; SWITCH-NEXT: sub x21, x21, #1
; SWITCH-NEXT: sub x20, x20, #64
; SWITCH-NEXT: cmp x21, #0
; SWITCH: ldr x21, [sp, #16]
;
; GENERIC-LABEL: shift:
; GENERIC: stp x22, x21, [sp, #16]
; GENERIC: lsl x22, x20, #6
; GENERIC-NEXT: sub x20, x20, x21
; GENERIC: add x8, x8, x22
; GENERIC: bl destroy
; GENERIC-NEXT: sub x20, x20, #1
; GENERIC-NEXT: sub x22, x22, #64
; GENERIC-NEXT: cmp x20, #0
; GENERIC: ldp x22, x21, [sp, #16]

%Item = type { i64, i64, [6 x i64] }

; Function Attrs: noimplicitfloat nounwind
define void @shift(%Item** %0, i64 %1, i64 %2) local_unnamed_addr #0 {
  tail call void @prepare(%Item** %0) #3
  %4 = xor i64 %1, -1
  %5 = add i64 %4, %2
  %6 = icmp sgt i64 %5, -1
  br i1 %6, label %8, label %7

7:                                                ; preds = %8, %3
  ret void

8:                                                ; preds = %3, %8
  %9 = phi i64 [ %21, %8 ], [ %5, %3 ]
  %10 = load %Item*, %Item** %0, align 8
  %11 = getelementptr inbounds %Item, %Item* %10, i64 %1
  %12 = getelementptr inbounds %Item, %Item* %11, i64 %9
  %13 = getelementptr inbounds %Item, %Item* %12, i64 1
  %14 = getelementptr inbounds %Item, %Item* %12, i64 0, i32 0
  %15 = load i64, i64* %14, align 8
  %16 = getelementptr inbounds %Item, %Item* %13, i64 0, i32 0
  store i64 %15, i64* %16, align 8
  %17 = getelementptr inbounds %Item, %Item* %12, i64 0, i32 1
  %18 = load i64, i64* %17, align 8
  %19 = getelementptr inbounds %Item, %Item* %13, i64 0, i32 1
  store i64 %18, i64* %19, align 8
  %20 = bitcast %Item* %12 to i8*
  call void @llvm.memset.p0i8.i64(i8* nonnull align 8 dereferenceable(16) %20, i8 0, i64 16, i1 false)
  tail call void @destroy(%Item* %12) #3
  %21 = add nsw i64 %9, -1
  %22 = icmp sgt i64 %9, 0
  br i1 %22, label %8, label %7

; Exercise address-first use discovery independently of instruction order.
  uselistorder i64 %9, { 2, 0, 1 }
  uselistorder %Item* %13, { 1, 0 }
  uselistorder %Item* %12, { 1, 0, 4, 3, 2 }
  uselistorder i64 -1, { 2, 0, 1 }
  uselistorder i64 %1, { 1, 0 }
  uselistorder %Item** %0, { 1, 0 }
  uselistorder label %8, { 1, 0 }
}

; Function Attrs: noimplicitfloat
declare void @prepare(%Item**) local_unnamed_addr #1

; Function Attrs: noimplicitfloat
declare void @destroy(%Item*) local_unnamed_addr #1

; Function Attrs: argmemonly nounwind willreturn
declare void @llvm.memset.p0i8.i64(i8* nocapture writeonly, i8, i64, i1 immarg) #2

attributes #0 = { noimplicitfloat nounwind "frame-pointer"="non-leaf" }
attributes #1 = { noimplicitfloat }
attributes #2 = { argmemonly nounwind willreturn }
attributes #3 = { noimplicitfloat nounwind }
