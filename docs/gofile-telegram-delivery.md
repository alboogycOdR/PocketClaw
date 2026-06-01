# Gofile + Telegram File Delivery

Use this flow to send build artifacts or other files to a Telegram chat without
setting up CI artifact hosting.

## Setup

1. Create a bot with `@BotFather`.
2. Get your chat ID from `@userinfobot`.
3. Send your bot one message first.
4. Create a root `.env`:

```dotenv
TELEGRAM_BOT_TOKEN=1234567890:AAAA...
TELEGRAM_CHAT_ID=123456789
```

## Script

```bash
dart scripts/release_remote.dart [path-to-file]
```

Default path:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Behavior

1. `GET https://api.gofile.io/servers`
2. `POST https://<server>.gofile.io/contents/uploadfile`
3. `POST https://api.telegram.org/bot<TOKEN>/sendMessage`

Telegram is sent plain text only. No `parse_mode`.

## Notes

- links expire in about 10 days
- intended for developer handoff, not full release distribution
- token must remain secret
