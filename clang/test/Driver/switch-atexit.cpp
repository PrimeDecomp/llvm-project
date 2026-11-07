// RUN: %clang -target aarch64-decomp-switch -femit-switch-atexit -### -c %s 2>&1 | FileCheck %s
// CHECK: "-femit-switch-atexit"
