/// State machine for the Paperclip invite → claim-api-key onboarding flow.
///
/// Three calls, no client-visible polling endpoint, so we retry the final
/// claim on a timer until the board has approved (409 clears to 201).
/// Intermediate state (claimSecret + requestId) is persisted in
/// SharedPreferences so an app restart doesn't orphan a pending request.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gateway/paperclip_rest.dart';
import 'core_providers.dart';

enum OnboardingPhase {
  idle,
  accepting,
  awaitingApproval,
  claiming,
  success,
  error,
}

class PaperclipOnboardingState {
  final OnboardingPhase phase;
  final String? claimSecret;
  final String? requestId;
  final String? agentId;
  final String? apiKey;
  final String? errorMessage;
  final DateTime? lastCheckAt;

  const PaperclipOnboardingState({
    this.phase = OnboardingPhase.idle,
    this.claimSecret,
    this.requestId,
    this.agentId,
    this.apiKey,
    this.errorMessage,
    this.lastCheckAt,
  });

  bool get isWorking =>
      phase == OnboardingPhase.accepting ||
      phase == OnboardingPhase.awaitingApproval ||
      phase == OnboardingPhase.claiming;

  PaperclipOnboardingState copyWith({
    OnboardingPhase? phase,
    String? claimSecret,
    String? requestId,
    String? agentId,
    String? apiKey,
    String? errorMessage,
    DateTime? lastCheckAt,
    bool clearError = false,
  }) =>
      PaperclipOnboardingState(
        phase: phase ?? this.phase,
        claimSecret: claimSecret ?? this.claimSecret,
        requestId: requestId ?? this.requestId,
        agentId: agentId ?? this.agentId,
        apiKey: apiKey ?? this.apiKey,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      );
}

class PaperclipOnboardingNotifier
    extends StateNotifier<PaperclipOnboardingState> {
  static const _kClaimSecretPref = 'paperclip_onboarding_claim_secret';
  static const _kRequestIdPref = 'paperclip_onboarding_request_id';

  final Ref _ref;
  Timer? _pollTimer;

  PaperclipOnboardingNotifier(this._ref)
      : super(const PaperclipOnboardingState()) {
    _restoreFromPrefs();
  }

  void _restoreFromPrefs() {
    final prefs = _ref.read(sharedPrefsProvider);
    final secret = prefs.getString(_kClaimSecretPref);
    final reqId = prefs.getString(_kRequestIdPref);
    if (secret != null &&
        secret.isNotEmpty &&
        reqId != null &&
        reqId.isNotEmpty) {
      state = state.copyWith(
        phase: OnboardingPhase.awaitingApproval,
        claimSecret: secret,
        requestId: reqId,
      );
      _startPolling();
    }
  }

  Future<void> _persist() async {
    final prefs = _ref.read(sharedPrefsProvider);
    if (state.claimSecret == null || state.requestId == null) {
      await prefs.remove(_kClaimSecretPref);
      await prefs.remove(_kRequestIdPref);
    } else {
      await prefs.setString(_kClaimSecretPref, state.claimSecret!);
      await prefs.setString(_kRequestIdPref, state.requestId!);
    }
  }

  /// Step 1: accept the invite, persist the claim secret, start polling.
  Future<void> acceptInvite(String inviteToken) async {
    final baseUrl = _ref.read(paperclipBaseUrlProvider);
    if (baseUrl.isEmpty) {
      state = state.copyWith(
        phase: OnboardingPhase.error,
        errorMessage: 'Set the Paperclip base URL first.',
      );
      return;
    }
    state = state.copyWith(
      phase: OnboardingPhase.accepting,
      clearError: true,
    );
    final client = PaperclipOnboardingClient(baseUrl: baseUrl);
    try {
      final res = await client.acceptInvite(inviteToken.trim());
      if (res.claimSecret.isEmpty || res.requestId.isEmpty) {
        state = state.copyWith(
          phase: OnboardingPhase.error,
          errorMessage:
              'Paperclip accepted the invite but returned no claim secret.',
        );
        return;
      }
      state = state.copyWith(
        phase: OnboardingPhase.awaitingApproval,
        claimSecret: res.claimSecret,
        requestId: res.requestId,
        clearError: true,
      );
      await _persist();
      _startPolling();
      // Immediately probe — board might auto-approve.
      await checkApproval();
    } catch (e) {
      state = state.copyWith(
        phase: OnboardingPhase.error,
        errorMessage: friendlyPaperclipError(e),
      );
    } finally {
      client.dispose();
    }
  }

  /// Step 3: attempt the claim. 201 → success; 409 → stay pending.
  Future<void> checkApproval() async {
    if (state.claimSecret == null || state.requestId == null) return;
    if (state.phase == OnboardingPhase.success) return;

    final baseUrl = _ref.read(paperclipBaseUrlProvider);
    if (baseUrl.isEmpty) return;

    state = state.copyWith(
      phase: OnboardingPhase.claiming,
      lastCheckAt: DateTime.now(),
    );
    final client = PaperclipOnboardingClient(baseUrl: baseUrl);
    try {
      final outcome = await client.claimApiKey(
        requestId: state.requestId!,
        claimSecret: state.claimSecret!,
      );
      if (outcome.ready) {
        // Persist the key immediately — one-shot, can't be retried.
        final prefs = _ref.read(sharedPrefsProvider);
        await prefs.setString('paperclip_api_key', outcome.apiKey!);
        _ref.read(paperclipApiKeyProvider.notifier).state = outcome.apiKey!;

        state = state.copyWith(
          phase: OnboardingPhase.success,
          apiKey: outcome.apiKey,
          agentId: outcome.agentId,
          clearError: true,
        );
        _stopPolling();
        // Clear persisted onboarding state — the flow is complete.
        await prefs.remove(_kClaimSecretPref);
        await prefs.remove(_kRequestIdPref);
      } else if (outcome.pending) {
        state = state.copyWith(
          phase: OnboardingPhase.awaitingApproval,
          lastCheckAt: DateTime.now(),
          clearError: true,
        );
      } else {
        state = state.copyWith(
          phase: OnboardingPhase.error,
          errorMessage: outcome.errorMessage ?? 'Unknown claim failure.',
        );
        _stopPolling();
      }
    } catch (e) {
      state = state.copyWith(
        phase: OnboardingPhase.awaitingApproval,
        errorMessage: friendlyPaperclipError(e),
        lastCheckAt: DateTime.now(),
      );
    } finally {
      client.dispose();
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => checkApproval(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Abandon the pending invite. Persisted secret is cleared so a fresh
  /// invite can be accepted next time.
  Future<void> cancel() async {
    _stopPolling();
    final prefs = _ref.read(sharedPrefsProvider);
    await prefs.remove(_kClaimSecretPref);
    await prefs.remove(_kRequestIdPref);
    state = const PaperclipOnboardingState();
  }

  /// Clear error state so the UI can return to idle / retry.
  void dismissError() {
    state = state.copyWith(
      phase: state.claimSecret != null && state.requestId != null
          ? OnboardingPhase.awaitingApproval
          : OnboardingPhase.idle,
      clearError: true,
    );
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

final paperclipOnboardingProvider = StateNotifierProvider<
    PaperclipOnboardingNotifier, PaperclipOnboardingState>((ref) {
  return PaperclipOnboardingNotifier(ref);
});
