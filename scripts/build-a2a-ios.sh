#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRATE="$ROOT/rust/a2a-bridge"
OUT="$ROOT/Generated/A2ABridge"
RUSTUP_CARGO="${RUSTUP_CARGO:-$HOME/.cargo/bin/cargo}"
RUSTUP_RUSTUP="${RUSTUP_RUSTUP:-$HOME/.cargo/bin/rustup}"

if [[ ! -x "$RUSTUP_CARGO" || ! -x "$RUSTUP_RUSTUP" ]]; then
  echo "error: rustup-managed cargo/rustup required under ~/.cargo/bin" >&2
  echo "Do not use Homebrew cargo for this build; install/select rustup first." >&2
  exit 2
fi

"$RUSTUP_RUSTUP" target add aarch64-apple-ios aarch64-apple-ios-sim

pushd "$CRATE" >/dev/null
"$RUSTUP_CARGO" build --release --target aarch64-apple-ios
"$RUSTUP_CARGO" build --release --target aarch64-apple-ios-sim
rm -rf "$OUT"
mkdir -p "$OUT/swift"
"$RUSTUP_CARGO" run --quiet --bin uniffi-bindgen -- generate src/bitchat_a2a.udl --language swift --out-dir "$OUT/swift" 2>/dev/null || \
  "$RUSTUP_CARGO" run --quiet --features uniffi/cli -- generate src/bitchat_a2a.udl --language swift --out-dir "$OUT/swift"
popd >/dev/null

xcodebuild -create-xcframework \
  -library "$CRATE/target/aarch64-apple-ios/release/libbitchat_a2a_bridge.a" \
  -headers "$OUT/swift" \
  -library "$CRATE/target/aarch64-apple-ios-sim/release/libbitchat_a2a_bridge.a" \
  -headers "$OUT/swift" \
  -output "$OUT/BitchatA2ABridge.xcframework"

echo "Built $OUT/BitchatA2ABridge.xcframework"
