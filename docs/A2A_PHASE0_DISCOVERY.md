# Phase 0 — a2a-rs / UniFFI iOS discovery spike

## Objective

Prove the narrowest risky boundary before implementing BLE A2A: compile Rust containing the upstream A2A core for both Apple ARM targets, generate Swift with UniFFI, link it into the existing SafeGuardian iOS app target, and execute Swift -> Rust -> Swift once.

Upstream is pinned to `a2aproject/a2a-rs` commit `fc7caf3aa4e000e7a22dc369335babfb3ea300e4`. Its workspace declares Rust 1.85 and A2A 1.0.

## Toolchain invariant

Use rustup-managed tools explicitly:

```sh
$HOME/.cargo/bin/rustup target add aarch64-apple-ios aarch64-apple-ios-sim
$HOME/.cargo/bin/cargo --version
```

Do not let `/opt/homebrew/bin/cargo` select a different toolchain. `scripts/build-a2a-ios.sh` fails early unless the rustup-managed executables exist.

## Probe

Rust exports two UniFFI functions:

- `round_trip("swift") -> "rust:swift"`
- `a2a_version() -> a2a::VERSION` (currently `1.0`)

`SafeGuardian/Services/A2A/A2ADiscoverySpike.swift` calls both. This intentionally touches an upstream `a2a-rs` symbol so a green result proves more than an isolated Rust toy library.

## Build/run

```sh
./scripts/build-a2a-ios.sh
```

Then add/link the generated `Generated/A2ABridge/BitchatA2ABridge.xcframework` and generated Swift binding to the existing `SafeGuardian_iOS` target. Invoke `A2ADiscoverySpike.verifyRoundTrip()` from a debug-only startup/test path. Expected value:

```text
rust:swift;a2a=1.0
```

The existing project uses a file-system-synchronized `SafeGuardian` source root, so the Swift probe is discovered automatically by the iOS target. The generated XCFramework still needs an explicit framework reference/link entry because generated binary products live outside that synchronized source root.

## Exit criteria

Phase 0 is green only when all are true on an Apple/Xcode host:

1. `aarch64-apple-ios` release library builds.
2. `aarch64-apple-ios-sim` release library builds.
3. UniFFI emits Swift bindings/header/modulemap.
4. Xcode links the XCFramework into `SafeGuardian_iOS`.
5. Simulator executes `verifyRoundTrip()` and returns `rust:swift;a2a=1.0`.
6. A physical iOS build links successfully (execution is preferred but link success is the minimum architecture gate).

## Interpretation

If 1–3 fail, Phase 2/3 risk is primarily Rust dependency/platform compatibility. If 4 fails, risk is Xcode packaging/linkage. If 5–6 fail after successful linking, risk is FFI/runtime integration. Only after all six pass should the project estimate BLE A2A implementation from protocol work rather than from unresolved toolchain risk.

This repository-writing environment cannot execute Xcode or the local rustup toolchain, so the branch establishes the exact spike and integration point but does not claim those six runtime gates have passed. They must be run on the project's Apple build host before Phase 0 is called complete.
