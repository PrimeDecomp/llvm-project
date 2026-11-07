// RUN: %clang_cc1 -triple aarch64-unknown-linux-gnu -femit-switch-atexit -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple aarch64-unknown-linux-gnu -femit-switch-atexit -fregister-global-dtors-with-atexit -emit-llvm -o - %s | FileCheck %s --check-prefix=ATTR
struct A { ~A(); };
A global;
A &local() { static A object; return object; }
thread_local A thread_object;
__attribute__((destructor)) void fini() {}

// CHECK: @__horizon_atexit_entries = internal global [2 x
// CHECK-SAME: @global
// CHECK-SAME: @_ZZ5localvE6object
// CHECK-SAME: section ".atexit"
// ATTR: @__horizon_atexit_entries = internal global [3 x
// ATTR-SAME: @_Z4finiv
// ATTR-SAME: i8* null
// ATTR-SAME: section ".atexit"
