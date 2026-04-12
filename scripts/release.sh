#!/bin/bash
# Build the release APK and serve it to your phone over the local network.
# Usage: ./scripts/release.sh
set -e

cd "$(dirname "$0")/.."

echo "============================================================"
echo "  Building Pocket Claw release APK (arm64-v8a)"
echo "============================================================"
echo ""

flutter build apk --release --target-platform android-arm64

echo ""
echo "Build complete. Starting local download server..."
echo ""

dart scripts/serve_apk.dart
