# Code Findings Report - 2026-05-24

Project: `AI_PocketClaw` / `clawcommander`

## Commands Run

- `flutter analyze --no-pub`: completed with 86 analyzer issues.
- `dart analyze lib test`: completed with 85 analyzer issues.
- `flutter test --no-pub -r expanded`: passed, but only one trivial smoke test exists.
- `flutter build apk --debug --no-pub`: passed after clearing stale build/test processes.
- `flutter build apk --release --no-pub`: passed and produced `build/app/outputs/flutter-apk/app-release.apk`.
- Hugging Face model API checks against `assets/model_allowlist.json`: two configured repos returned `401`; the default repo is one of them.

## Executive Summary

The app currently compiles and Android APKs can be built, so the dominant problems are not Dart syntax errors. The risk is higher-level: several user-facing paths are still wired to stubs or retired APIs, the analyzer is reporting real cleanup items, Android build configuration is inconsistent with plugin NDK requirements, and test coverage does not exercise the app.

## Findings

### High - Default model allowlist entry likely cannot be downloaded

Evidence:

- `assets/model_allowlist.json` sets the default selected model ID to `gemma-4-2b`.
- `lib/data/providers/core_providers.dart:101` defaults `selectedModelIdProvider` to `gemma-4-2b`.
- The configured repo is `bartowski/gemma-4-2b-it-GGUF`.
- A Hugging Face API check for `https://huggingface.co/api/models/bartowski/gemma-4-2b-it-GGUF` returned `401`.
- The similarly named current repo `bartowski/google_gemma-4-E2B-it-GGUF` returned `200`, and Hugging Face search shows `bartowski/google_gemma-4-E2B-it-GGUF`.

Impact:

First-run local model download can fail for the recommended/default model before the user ever reaches a working local chat flow.

Recommendation:

Validate every allowlist repo and filename at release time. Replace `bartowski/gemma-4-2b-it-GGUF` / `gemma-4-2b-it-Q4_K_M.gguf` with a real repo+filename pair, or change the default model to a known-good existing allowlist entry. Keep `requiresLicense` separate from "repo exists" validation so gated models can still be handled cleanly.

Why:

Model download is a core onboarding path. If the default model points to an unavailable repo, the rest of the local inference stack is irrelevant for new users.

### High - Legacy `LlmEngine` stub still drives app state and UI

Evidence:

- `lib/core/local_agent/llm_engine.dart:36` has `loadModel`, but line 44 explicitly sets `_isLoaded = false`.
- `lib/core/local_agent/llm_engine.dart:53` returns an empty string from `generateCompleteText`.
- `lib/core/local_agent/llm_engine.dart:55` returns a zero vector for embeddings.
- `lib/data/providers/core_providers.dart:346` exposes this stub via `llmEngineProvider`.
- `lib/data/providers/core_providers.dart:358` uses the stub in `modelInitProvider` and returns `true` after calling `loadModel`, even though the engine remains unloaded.
- `lib/features/chat/chat_screen.dart:355` and `lib/features/chat/chat_screen.dart:573` still read this stub for voice/model UI state.
- `lib/core/memory/memory_service.dart:45` uses `_llm.isLoaded`, so LLM-based memory consolidation never runs through this path.

Impact:

The app has two local model systems: the old `LlmEngine` stub and the newer `AbstractLLMEngine` / `LlamaCppEngine`. Local chat mostly uses the newer engine, but voice indicators, memory consolidation, local agent surfaces, and camera/vision checks still use the stub. This creates false UI states and silent feature degradation.

Recommendation:

Remove the legacy `LlmEngine` provider or replace it with an adapter over `AbstractLLMEngine`. Make `modelInitProvider`, chat UI indicators, `MemoryService`, `CameraService`, and `LocalAgent` consume the same source of truth. If a feature is not supported by GGUF/llamadart, expose that explicitly instead of routing through a fake loaded state.

Why:

Two incompatible engine abstractions make it hard to know whether a model is actually available. A single engine contract will prevent "downloaded but unavailable" states and make tests meaningful.

### High - Registered or advertised features are still hard stubs

Evidence:

- `lib/core/tools/tool_executor.dart:41` registers `web_search` but always returns "not yet wired".
- `lib/core/tools/tool_executor.dart:119` reports battery data as "not yet wired".
- `lib/core/device/camera_service.dart:89` documents flutter_gemma vision support, but lines 102-112 say on-device vision is unavailable and instruct users to use cloud mode.
- `lib/data/providers/chat_mode_providers.dart:5` says cloud mode was removed.
- `lib/features/chat/chat_screen.dart:366` tells users voice input requires Gemma 4 E2B, but `lib/core/local_agent/model_selector.dart` references legacy E2B `.task`-style capabilities that are no longer in the active GGUF allowlist.

Impact:

The model/tool layer can advertise tools that fail deterministically. The UI also points users to modes that no longer exist. This will look like runtime breakage even though the app compiles.

Recommendation:

Hide unavailable tools from registries and prompts until implemented. Remove stale cloud/flutter_gemma/E2B copy, or implement the missing flow behind a feature flag. If web search, OCR, battery info, and voice capture are roadmap items, keep them out of the active tool list and render a disabled UI state with accurate copy.

Why:

LLMs will call tools they are told exist. A registered stub is worse than no tool because it creates a predictable failed turn.

### Medium - Android NDK version is inconsistent with plugin requirements

Evidence:

- `android/app/build.gradle.kts:10` uses `ndkVersion = flutter.ndkVersion`.
- Both debug and release Android builds warn that the project is configured with NDK `28.2.13676358`.
- `whisper_ggml` requires NDK `29.0.13113456`; many other plugins require NDK `27.0.12077973`.
- Flutter recommends using the highest required NDK version: `29.0.13113456`.

Impact:

Current builds pass, but the build is relying on a mismatch that can become a CI, release, or plugin-update failure.

Recommendation:

Pin the Android app to:

```kotlin
android {
    ndkVersion = "29.0.13113456"
}
```

Why:

NDK versions are backward-compatible for these plugins, and pinning removes nondeterminism from native builds.

### Medium - Async `BuildContext` usage can crash after navigation/disposal

Evidence:

- `lib/app/app.dart:48` uses `rootNavigatorKey.currentContext` in a dialog flow after an async gap.
- `lib/features/settings/gateway_config.dart:357` awaits a confirmation dialog and then uses `context` again at line 383 without a mounted guard between those steps.
- Analyzer reports `use_build_context_synchronously` in both files.

Impact:

If the user navigates away or the widget is disposed while an async operation is pending, these paths can try to use a dead context.

Recommendation:

Add `if (!mounted) return;` immediately after awaited dialogs and long operations before using `context`. For contexts obtained from keys or builders, check `ctx.mounted` where available, or capture `NavigatorState` / `ScaffoldMessengerState` before awaiting.

Why:

These are intermittent runtime bugs that appear under normal mobile behavior: backgrounding, route changes, and slow network/SSH operations.

### Medium - Analyzer warnings show dead code and retired UI paths

Evidence:

- `lib/features/settings/model_config.dart:257` and `:258` define optional parameters that are never passed.
- `lib/features/settings/model_config.dart:312` has a literal `if (false && ...)` block.
- `lib/features/settings/model_config.dart:431` still labels model ID editing as "cloud models only".
- Analyzer reports 7 warnings, including unused imports, dead code, and unused optional parameters.

Impact:

This is not a compile failure, but it is a sign that removed cloud/model code was not fully cleaned up. It increases maintenance risk and makes it harder to tell which model features are real.

Recommendation:

Delete retired cloud-only UI branches and unused constructor parameters, or reintroduce the feature intentionally with tests. Remove unused imports in `chat_providers.dart`, `device_info_screen.dart`, and `voice_settings_screen.dart`.

Why:

Dead branches are where future changes accidentally get wired into unsupported code.

### Low - Test coverage is effectively absent

Evidence:

- `test/widget_test.dart` only asserts `1 + 1 == 2`.
- `flutter test --no-pub -r expanded` passes, but it does not instantiate the app, providers, router, model catalogue, chat modes, or native-service fallback paths.

Impact:

The project can report green tests while core user flows are broken.

Recommendation:

Add focused tests for:

- app startup with `sharedPrefsProvider` and `modelCatalogueProvider` overrides;
- selected model fallback behavior;
- local mode when a model is not downloaded;
- chat mode availability for local/OpenClaw/Hermes;
- model download URL construction;
- unavailable feature handling for OCR, voice, and web search.

Why:

These tests would catch most of the issues above without needing a physical device.

### Low - Lints and deprecated Flutter APIs should be cleaned up

Evidence:

- `flutter analyze --no-pub` reports 86 issues.
- Deprecations include `Switch.activeColor` and `Radio.groupValue` / `Radio.onChanged`.
- There are many `unnecessary_underscores`, doc comment angle-bracket warnings, and style-only issues.

Impact:

These are mostly not user-visible today, but they create noise that hides real warnings.

Recommendation:

After fixing the functional issues, clean analyzer output to zero or near-zero. Consider treating analyzer warnings as CI failures while leaving style infos as non-blocking until the backlog is cleaned.

Why:

A noisy analyzer makes future regressions easy to miss.

## Verification Notes

- Android debug APK builds successfully.
- Android release APK builds successfully.
- Tests pass, but coverage is not meaningful.
- iOS build was not verified because this was run on Windows.
- Running `flutter test` and `flutter build` in parallel can contend on `.dart_tool/hooks_runner/shared/llamadart/.lock`; serialize those jobs in CI.

## Recommended Fix Order

1. Fix/validate the default model allowlist entry.
2. Collapse the old `LlmEngine` stub and new `AbstractLLMEngine` stack into one runtime model state.
3. Hide or implement stubbed tools/features.
4. Pin Android NDK to `29.0.13113456`.
5. Fix async context warnings.
6. Remove dead/retired cloud UI code and unused imports.
7. Add real tests around startup, model selection, chat mode availability, and unavailable feature behavior.
8. Clean remaining analyzer lints and deprecated APIs.
