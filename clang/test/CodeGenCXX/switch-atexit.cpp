// RUN: %clang_cc1 -triple aarch64-unknown-linux-gnu -emit-llvm -o - %s | FileCheck %s --check-prefix=DEFAULT
// RUN: %clang_cc1 -triple aarch64-unknown-linux-gnu -femit-switch-atexit -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple aarch64-unknown-linux-gnu -femit-switch-atexit -fno-use-cxa-atexit -emit-llvm -o - %s | FileCheck %s --check-prefix=DEFAULT

// RUN: not %clang_cc1 -triple arm64-apple-darwin -femit-switch-atexit -emit-llvm -o - %s 2>&1 | FileCheck %s --check-prefix=ERROR
// ERROR: unsupported option '-femit-switch-atexit' for target 'arm64-apple-darwin'

struct A { ~A(); };
A first;
A second;
thread_local A per_thread;

// DEFAULT-NOT: __horizon_atexit_entries
// DEFAULT-NOT: section ".atexit"
// CHECK: @__horizon_atexit_entries = internal global [2 x { void (i8*)*, i8*, i8* }]
// CHECK-SAME: @first
// CHECK-SAME: @__dso_handle
// CHECK-SAME: @second
// CHECK-SAME: @__dso_handle
// CHECK-SAME: section ".atexit"
// CHECK: @llvm.used = {{.*}}@__horizon_atexit_entries
// CHECK: call i32 @__cxa_atexit
// CHECK: call i32 @__cxa_atexit
// CHECK: call i32 @__cxa_thread_atexit
