// An explicit path uses the ELF linker directly, including for the Switch triple.
// RUN: %clang -### --target=aarch64-decomp-switch-elf -nostdlib -shared %s \
// RUN:   --ld-path=%S/Inputs/basic_freebsd_tree/usr/bin/ld.bfd -fuse-ld=gold -Werror 2>&1 \
// RUN:   | FileCheck %s --check-prefix=DIRECT --implicit-check-not=error: --implicit-check-not=warning:
// RUN: %clang -### --target=aarch64-none-elf -nostdlib -shared %s \
// RUN:   --ld-path=%S/Inputs/basic_freebsd_tree/usr/bin/ld.bfd 2>&1 \
// RUN:   | FileCheck %s --check-prefix=DIRECT
// DIRECT: "{{.*}}Inputs/basic_freebsd_tree/usr/bin{{/|\\+}}ld.bfd" "-EL" "--eh-frame-hdr" "-m" "aarch64linux" "-shared" "-o"
// DIRECT-NOT: --ld-path
// DIRECT-NOT: -fuse-ld

// Bare linker names use the same -B search as other toolchains.
// RUN: %clang -### --target=aarch64-decomp-switch-elf -nostdlib -shared %s \
// RUN:   -B%S/Inputs/basic_freebsd_tree/usr/bin --ld-path=ld.bfd 2>&1 \
// RUN:   | FileCheck %s --check-prefix=DIRECT

// Invalid paths are diagnosed by Clang rather than forwarded to GCC.
// RUN: %clang -### --target=aarch64-decomp-switch-elf -nostdlib %s --ld-path= 2>&1 \
// RUN:   | FileCheck %s --check-prefix=INVALID
// INVALID: error: invalid linker name in argument '--ld-path='

// Keep the existing GCC-driver fallback when no explicit path is requested.
// RUN: %clang -### --target=aarch64-decomp-switch-elf -nostdlib %s -ccc-gcc-name ld-path-gcc 2>&1 \
// RUN:   | FileCheck %s --check-prefix=GCC
// GCC: "{{.*}}ld-path-gcc" "-nostdlib"
