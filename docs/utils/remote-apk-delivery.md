# Remote APK Delivery via Gofile + Telegram

This repo ships HermesCommander APKs to Telegram by:

1. uploading the file to Gofile
2. sending the public download link to a Telegram chat via bot

This is a developer handoff path, not a release channel.

## One-time setup

1. Create a Telegram bot with `@BotFather` and save the token.
2. Get your numeric chat ID from `@userinfobot`.
3. Send your bot one message first so it can DM you back.
4. Create a project-root `.env` file:

```dotenv
TELEGRAM_BOT_TOKEN=1234567890:AAAA...
TELEGRAM_CHAT_ID=123456789
```

`.env` must stay gitignored.

## Build and send the default HermesCommander APK

Windows:

```bat
scripts\release-remote.bat
```

macOS / Linux:

```bash
./scripts/release-remote.sh
```

Both wrappers:

- build `app-release.apk`
- upload it to Gofile
- send the link to Telegram

## Send any file

```bash
dart scripts/release_remote.dart path/to/file
```

or:

```bash
dart scripts/send_file_remote.dart path/to/file
```

If no path is passed to `release_remote.dart`, it defaults to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## HTTP flow

### 1. Pick a Gofile server

```http
GET https://api.gofile.io/servers
```

Use `data.servers[0].name`.

### 2. Upload the file

```http
POST https://<server>.gofile.io/contents/uploadfile
Content-Type: multipart/form-data
field "file" = binary
```

Read `data.downloadPage` from the response.

### 3. Post the link to Telegram

```http
POST https://api.telegram.org/bot<TOKEN>/sendMessage
Content-Type: application/json
```

Body:

```json
{
  "chat_id": "<CHAT_ID>",
  "text": "Build ready: app-release.apk\n\nSize: 290.1 MB\nCommit: abc1234\n\nhttps://gofile.io/d/AbCdEf\n\nLink expires in ~10 days.",
  "disable_web_page_preview": false
}
```

## Important behavior

- No `parse_mode` is sent to Telegram.
- Message text is plain text only.
- URLs still auto-link in Telegram.
- This avoids failures when commit messages contain `_`, `*`, or backticks.

## Caveats

- Gofile links expire in about 10 days.
- Telegram bot delivery here is link-only by design.
- Bot tokens are secrets. Revoke immediately if leaked.
- For long-lived release distribution, use a real release channel instead.
