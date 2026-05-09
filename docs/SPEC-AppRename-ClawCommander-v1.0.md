# ClawCommander — App Rename Instruction
## From: Pocket Claw → To: ClawCommander

**Date:** 2026-05-09  
**Author:** CARMEN PTY LTD  
**Status:** Implement alongside or immediately after Phase 1  
**Estimated effort:** 2–3 hours  

---

## Why This Rename Is Required

"PocketClaw" (one word) exists on the iOS App Store as a claw machine game by Magic Cube. Apple will reject a submission with the same name. The rename to **ClawCommander** resolves this and positions the product correctly — a command centre for AI agents, not a chat wrapper.

---

## New Identity

| Property | Old | New |
|---|---|---|
| Display name | Pocket Claw | ClawCommander |
| Package name (Android) | `com.carmenlabs.pocketclaw` | `com.carmenlabs.clawcommander` |
| Flutter project name | `pocket_claw` | `clawcommander` |
| Bundle ID (iOS, when applicable) | `com.carmenlabs.pocketclaw` | `com.carmenlabs.clawcommander` |
| GitHub repo | `PocketClaw` | `ClawCommander` (rename in GitHub settings) |

---

## File-by-File Changes

### 1. `pubspec.yaml` (root)

```yaml
# Change:
name: pocket_claw
description: "Pocket Claw - Mobile AI Agent with OpenClaw Integration"

# To:
name: clawcommander
description: "ClawCommander - Mobile AI Agent Command Centre"
```

Also update any asset paths that reference `pocket_claw` in the filename (check `image_path` and `adaptive_icon_foreground` under `flutter_launcher_icons`):

```yaml
flutter_launcher_icons:
  image_path: "assets/icon/clawcommander_icon.png"
  adaptive_icon_foreground: "assets/icon/clawcommander_icon_foreground.png"
  # ... other fields unchanged
```

> Note: Rename the actual icon files in `assets/icon/` to match.

---

### 2. Android — `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Change: -->
android:label="Pocket Claw"

<!-- To: -->
android:label="ClawCommander"
```

---

### 3. Android — `android/app/build.gradle`

```groovy
// Change:
applicationId "com.carmenlabs.pocketclaw"

// To:
applicationId "com.carmenlabs.clawcommander"
```

---

### 4. Android — Kotlin package directory

The source package directory should match the application ID. If the Kotlin files are in `android/app/src/main/kotlin/com/carmenlabs/pocketclaw/`, rename the directory:

```bash
# In the android directory:
mkdir -p app/src/main/kotlin/com/carmenlabs/clawcommander
mv app/src/main/kotlin/com/carmenlabs/pocketclaw/MainActivity.kt \
   app/src/main/kotlin/com/carmenlabs/clawcommander/MainActivity.kt
# Update package declaration inside MainActivity.kt:
# package com.carmenlabs.pocketclaw  →  package com.carmenlabs.clawcommander
```

---

### 5. iOS — `ios/Runner/Info.plist` (when iOS build is set up)

```xml
<!-- Change: -->
<key>CFBundleName</key>
<string>Pocket Claw</string>
<key>CFBundleDisplayName</key>
<string>Pocket Claw</string>

<!-- To: -->
<key>CFBundleName</key>
<string>ClawCommander</string>
<key>CFBundleDisplayName</key>
<string>ClawCommander</string>
```

---

### 6. iOS — `ios/Runner.xcodeproj/project.pbxproj` (when iOS build is set up)

Search for `com.carmenlabs.pocketclaw` and replace all occurrences with `com.carmenlabs.clawcommander`.

---

### 7. In-App String References

Search the entire `lib/` directory for any hardcoded "Pocket Claw" strings and update them:

```bash
# Find all occurrences
grep -r "Pocket Claw\|pocket_claw\|PocketClaw\|pocketclaw" lib/ --include="*.dart"
```

Known locations to check:

| File | Current string | Replace with |
|---|---|---|
| `lib/features/onboarding/welcome_screen.dart` | "Pocket Claw" | "ClawCommander" |
| `lib/features/settings/settings_screen.dart` | Any "Pocket Claw" references | "ClawCommander" |
| `lib/core/hermes/acp/hermes_acp_client.dart` | `'clientInfo': {'name': 'PocketClaw', ...}` | `'name': 'ClawCommander'` |
| Any `DEVELOPER-BRIEFING.md` references | "Pocket Claw" | "ClawCommander" |

---

### 8. `CLAUDE.md` (if present)

Update any project name references. The Git repo root and protected path conventions remain unchanged — only the product name changes.

---

### 9. `README.md`

Update the project name and description in the README header.

---

### 10. Spec Documents (for future reference)

All previously written specs refer to "Pocket Claw" or "PocketClaw". These are reference documents — they do not need mass-editing. New specs from this point forward use "ClawCommander".

---

## Build Verification Checklist

After making all changes, verify the build is clean:

```bash
# Clean build artefacts
flutter clean
flutter pub get

# Verify no old references remain in Dart code
grep -r "pocket_claw\|PocketClaw\|Pocket Claw" lib/ --include="*.dart"
# Should return zero results (except any intentional legacy comments)

# Build debug APK
flutter build apk --debug

# Confirm app installs with new name on device
# Settings → Apps on Android should show "ClawCommander"
```

---

## What Does NOT Change

| Item | Notes |
|---|---|
| Tailscale setup | VPS hostnames, IPs unchanged |
| OpenClaw gateway token | Unchanged |
| Hermes API key | Unchanged |
| All feature specs | All existing specs remain valid — only product name changes |
| Git history | Keep all existing commits — just rename the repo on GitHub |
| SharedPreferences keys | Existing keys (`gateway_url`, `hermes_api_key`, etc.) — do NOT rename. Renaming would wipe saved settings on existing installs |

---

*CARMEN PTY LTD — ClawCommander App Rename Instruction v1.0 — 2026-05-09*
