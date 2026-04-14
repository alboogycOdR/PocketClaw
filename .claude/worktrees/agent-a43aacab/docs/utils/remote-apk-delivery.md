# Remote APK delivery via Gofile.io + Telegram

Let any teammate grab the latest release build from anywhere — no LAN, no Play
Store, no CI service required. Works for Flutter, React Native, or any project
that produces an APK.

Originally built for **Pocket Claw** (Flutter). This recipe is portable.

---

## One-time setup (per machine)

1. **Create a Telegram bot** — message `@BotFather`, run `/newbot`, follow the
   prompts, save the token it gives you.
2. **Get your chat ID**:
   - Message `@userinfobot` on Telegram — it replies with your numeric chat ID, **or**
   - Message your new bot once, then `curl https://api.telegram.org/bot<TOKEN>/getUpdates`
     and read `result[0].message.chat.id`.
3. **Project root `.env`** (must be gitignored):
   ```
   TELEGRAM_BOT_TOKEN=1234567890:AAAA...
   TELEGRAM_CHAT_ID=123456789
   ```
4. **Add `.env` to `.gitignore`** if it isn't already.

---

## Script behaviour

Drop `scripts/release_remote.dart` (or `.js` / `.py` — any language with an
HTTP client works) that does:

### 1. Locate the APK

Platform-standard paths:

| Framework | Default APK path |
|---|---|
| Flutter | `build/app/outputs/flutter-apk/app-release.apk` |
| React Native | `android/app/build/outputs/apk/release/app-release.apk` |
| Gradle (bare Android) | `app/build/outputs/apk/release/app-release.apk` |

### 2. Upload to Gofile.io

Free, no account, ~10-day expiry, any file size.

- `GET https://api.gofile.io/servers` → pick `data.servers[0].name`.
- `POST https://<server>.gofile.io/contents/uploadfile` as
  `multipart/form-data` with the APK as the `file` field.
- Read `data.downloadPage` from the JSON response.

### 3. Post to Telegram

```
POST https://api.telegram.org/bot<TOKEN>/sendMessage
Content-Type: application/json

{
  "chat_id": "<CHAT_ID>",
  "text": "🦀 *App build ready*\n\n_<commit message>_\n\nSize: <N> MB\nCommit: `<short sha>`\n\n[Download APK](<downloadPage>)\n\n_Link expires in approx 10 days._",
  "parse_mode": "Markdown",
  "disable_web_page_preview": false
}
```

Populate:
- Commit hash via `git rev-parse --short HEAD`
- Commit message via `git log -1 --pretty=%s`
- File size via `stat`/file-length divided by `1024*1024`

---

## Wrapper scripts

Two shell wrappers so CI or a developer can run one command:

### `scripts/release-remote.sh` (Linux / macOS)

```bash
#!/usr/bin/env bash
set -e

if [ ! -f .env ]; then
  echo ".env not found. See utils/remote-apk-delivery.md for setup."
  exit 1
fi

flutter build apk --release --target-platform android-arm64
dart scripts/release_remote.dart
```

### `scripts/release-remote.bat` (Windows)

```batch
@echo off
if not exist .env (
  echo .env not found. See utils\remote-apk-delivery.md for setup.
  exit /b 1
)

flutter build apk --release --target-platform android-arm64
dart scripts/release_remote.dart
```

Swap `flutter build apk ...` for your framework's build command.

---

## Reference implementation (Dart, ~250 lines)

Lives in the Pocket Claw repo at commit `a9b2079`. Retrieve with:

```bash
git show a9b2079:scripts/release_remote.dart > release_remote.dart
```

Only external dep: `http` (`dart pub add http`). Translates to ~80 lines of
Node.js with `axios` + `form-data`, or ~60 lines of Python with `requests`.

### Minimal Node.js port (for reference)

```js
// scripts/release_remote.js  (requires: npm i axios form-data dotenv)
const fs = require('fs');
const { execSync } = require('child_process');
const axios = require('axios');
const FormData = require('form-data');
require('dotenv').config();

const APK = 'android/app/build/outputs/apk/release/app-release.apk';
const { TELEGRAM_BOT_TOKEN: token, TELEGRAM_CHAT_ID: chatId } = process.env;

(async () => {
  if (!token || !chatId) throw new Error('Missing .env vars');
  if (!fs.existsSync(APK)) throw new Error(`APK not found: ${APK}`);

  const { data: srv } = await axios.get('https://api.gofile.io/servers');
  const server = srv.data.servers[0].name;

  const form = new FormData();
  form.append('file', fs.createReadStream(APK));
  const { data: up } = await axios.post(
    `https://${server}.gofile.io/contents/uploadfile`,
    form,
    { headers: form.getHeaders(), maxBodyLength: Infinity },
  );
  const url = up.data.downloadPage;

  const sha = execSync('git rev-parse --short HEAD').toString().trim();
  const msg = execSync('git log -1 --pretty=%s').toString().trim();
  const sizeMb = (fs.statSync(APK).size / 1024 / 1024).toFixed(1);

  const text =
    `📱 *Build ready*\n\n_${msg}_\n\nSize: ${sizeMb} MB\n` +
    `Commit: \`${sha}\`\n\n[Download APK](${url})\n\n` +
    `_Link expires in approx 10 days._`;

  await axios.post(`https://api.telegram.org/bot${token}/sendMessage`, {
    chat_id: chatId, text, parse_mode: 'Markdown',
  });

  console.log('✓ Sent. Download:', url);
})();
```

---

## Caveats

- **Gofile links expire in ~10 days.** This is a dev/handoff workflow, not a
  release channel. For long-lived distribution use Firebase App Distribution,
  TestFlight, or a Play Store internal track.
- **Bot token is a secret** — `.env` must be gitignored. If leaked, revoke
  immediately via `@BotFather` → `/revoke`.
- **Telegram `sendDocument` has a 50 MB limit** — that's why we upload to
  Gofile first and post the link, not the APK itself. If your APK is under
  50 MB you can skip Gofile and attach the file directly via
  `sendDocument`.
- **iOS/`.ipa`** — same flow works for iOS builds, but unsigned `.ipa` files
  are useless to recipients; only share signed ad-hoc or enterprise builds.

---

*Last updated: 2026-04-14*
