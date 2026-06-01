#!/bin/bash
# Build the HermesCommander release APK, upload it to Gofile.io,
# and notify via Telegram.
#
# Usage: ./scripts/release-remote.sh
#
# Requires .env file at project root with:
#   TELEGRAM_BOT_TOKEN=...
#   TELEGRAM_CHAT_ID=...
set -e

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Error: .env file missing."
  echo ""
  echo "Create .env in the project root with:"
  echo "  TELEGRAM_BOT_TOKEN=your-bot-token"
  echo "  TELEGRAM_CHAT_ID=your-chat-id"
  echo ""
  echo "See scripts/release_remote.dart for full setup instructions."
  exit 1
fi

echo "============================================================"
echo "  Building HermesCommander release APK (arm64-v8a)"
echo "============================================================"
echo ""

flutter build apk --release --target-platform android-arm64 --dart-define=APP_FLAVOR=hermesCommander

echo ""
echo "Build complete. Uploading + notifying..."
echo ""

dart scripts/release_remote.dart build/app/outputs/flutter-apk/app-release.apk
