# Model Distribution Strategy

**Date:** 2026-04-10
**Status:** Under Consideration
**Author:** Alister Witbooy / CARMEN PTY LTD

---

## The Problem

Pocket Claw uses Google's Gemma models for on-device LLM inference. These models are hosted on HuggingFace as **gated models**, meaning:

1. Users must create a HuggingFace account
2. Users must visit each model's page and accept Google's license agreement
3. Users must generate a personal API token
4. Users must enter that token in Pocket Claw's Settings

This is acceptable for a developer/power user but creates unacceptable friction for consumer or enterprise distribution.

## Current Implementation

- The app stores a user-provided HuggingFace token in `SharedPreferences` (key: `huggingface_token`)
- The token is passed to `FlutterGemma.initialize(huggingFaceToken: token)` on app startup
- Model downloads use `FlutterGemma.installModel().fromNetwork(url, token: hfToken)`
- **No email address or personal data is hardcoded** — each device enters its own token
- Model download URLs point to HuggingFace:
  - Gemma 4 E2B: `https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task`
  - Gemma 3 1B: `https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task`
  - Gemma 3 270M: `https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task`

## HuggingFace License Pages (Must Accept Before Download)

- Gemma 4 E2B / 3n E2B: https://huggingface.co/google/gemma-3n-E2B-it-litert-preview
- Gemma 3 1B: https://huggingface.co/litert-community/Gemma3-1B-IT
- Gemma 3 270M: https://huggingface.co/litert-community/gemma-3-270m-it

## Distribution Options

### Option 1: Self-Hosted Models (Recommended for Production)

Upload the `.task` model files to infrastructure under CARMEN's control. Change the download URLs in the app to point there.

**Hosting options:**
- Google Cloud Storage bucket (pay per GB transferred)
- AWS S3 bucket
- OpenClaw VPS (if bandwidth allows)
- Cloudflare R2 (free egress)

**Pros:**
- Zero friction for users — tap Download and it works
- No HuggingFace dependency
- No token required
- Full control over availability and versioning

**Cons:**
- CARMEN bears hosting/bandwidth costs (~0.3–1.5 GB per user per model)
- Must comply with Google's Gemma license terms for redistribution
- Must update model files manually when new versions release

**Implementation:** Change the `downloadUrl` fields in `model_config.dart` and `model_download.dart` to point to the self-hosted URLs. Remove the HuggingFace token requirement from the download flow.

### Option 2: Bundled Models in APK

Include the smallest model (Gemma 3 270M, ~300 MB) as a Flutter asset bundled inside the APK.

**Pros:**
- Works immediately after install — no download step at all
- Fully offline from the start

**Cons:**
- APK size increases from 267 MB to ~567 MB
- Google Play Store has a 150 MB APK limit (would need Android App Bundle with asset packs)
- Larger models (1B, E2B) still need separate download
- Every app update re-downloads the model

### Option 3: Dedicated Service Account Token

Create a dedicated HuggingFace account (e.g. `carmen-ai-distribution@...`), accept all Gemma licenses on that account, generate a read-only token, and embed it in the app as a fallback default.

**Pros:**
- Minimal code change — just set a default token
- Users never interact with HuggingFace

**Cons:**
- Token is embedded in the APK (can be extracted by reverse engineering)
- Violates HuggingFace ToS if the token is used by many users
- HuggingFace could rate-limit or ban the account
- Single point of failure

### Option 4: Server-Assisted Download

When a user connects their OpenClaw server, the server downloads the model from HuggingFace (using its own token) and serves it to the phone over the local network or Tailscale tunnel.

**Pros:**
- Server handles authentication once
- Users get the model transparently
- Works well with Tailscale-secured setups

**Cons:**
- Requires an OpenClaw server (not suitable for offline-only users)
- Server needs sufficient bandwidth and storage
- Adds complexity to the server-side setup

## Recommendation

For **developer/power user distribution** (current phase): the HuggingFace token approach is acceptable. Document the setup steps clearly.

For **consumer/enterprise distribution** (future phase): **self-host the models** on Cloudflare R2 or GCS. This is the cleanest solution — zero user friction, full control, reasonable cost.

## Files to Modify When Switching Strategy

| File | What to Change |
|---|---|
| `lib/features/settings/model_config.dart` | `downloadUrl` fields for all 3 models |
| `lib/features/onboarding/model_download.dart` | `downloadUrl` fields for all 3 models |
| `lib/features/settings/settings_screen.dart` | Remove or hide HuggingFace token section (if self-hosted) |
| `lib/main.dart` | Remove `huggingFaceToken` from `FlutterGemma.initialize()` (if self-hosted) |

---

*CARMEN PTY LTD — April 2026*
