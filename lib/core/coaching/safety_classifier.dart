/// Safety classifier — fast local keyword pre-filter + crisis response
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Classification Enum ──

enum SafetyClassification { normal, crisis, therapyDrift, highRisk }

// ── Classifier ──

class SafetyClassifier {
  /// System prompt for the server-side LLM safety classifier.
  static const classifierPrompt = '''
You are a safety classifier for a coaching AI assistant. Analyse the user's
message and classify it into exactly one category:

- NORMAL: Everyday coaching, productivity, or general questions.
- CRISIS: The user expresses suicidal ideation, self-harm intent, or immediate
  danger to themselves or others. Respond with empathy and provide crisis
  resources — do NOT attempt to coach.
- THERAPY_DRIFT: The user is seeking therapeutic or clinical mental health
  support (e.g., processing trauma, managing a diagnosed condition). Gently
  redirect to a qualified professional.
- HIGH_RISK: The user describes a medical emergency, overdose, or acute
  physical danger. Urge them to contact emergency services immediately.

Return ONLY the category label (NORMAL, CRISIS, THERAPY_DRIFT, or HIGH_RISK)
with no other text.
''';

  // ── Keyword lists ──

  static const _crisisKeywords = [
    'suicide',
    'kill myself',
    'self-harm',
    'want to die',
    'end it all',
    'no reason to live',
  ];

  static const _highRiskKeywords = [
    'overdose',
    'medical emergency',
    'chest pain',
    "can't breathe",
  ];

  static const _therapyDriftKeywords = [
    'my therapist',
    'diagnosed with',
    'my psychiatrist',
    'trauma processing',
  ];

  /// Fast local keyword scan as a pre-filter before calling the LLM.
  SafetyClassification classifyLocally(String message) {
    final lower = message.toLowerCase();

    for (final kw in _crisisKeywords) {
      if (lower.contains(kw)) return SafetyClassification.crisis;
    }
    for (final kw in _highRiskKeywords) {
      if (lower.contains(kw)) return SafetyClassification.highRisk;
    }
    for (final kw in _therapyDriftKeywords) {
      if (lower.contains(kw)) return SafetyClassification.therapyDrift;
    }

    return SafetyClassification.normal;
  }

  /// User-facing copy for blocked turns (British English).
  String responseFor(SafetyClassification c) {
    switch (c) {
      case SafetyClassification.crisis:
        return getCrisisResponse();
      case SafetyClassification.highRisk:
        return 'If you believe you are in immediate danger, call your local '
            'emergency number now (999, 112, or 911). This assistant cannot '
            'assess medical emergencies.';
      case SafetyClassification.therapyDrift:
        return 'I am not a substitute for a qualified mental health '
            'professional. If you need clinical support, please speak with your '
            'GP or a registered therapist who can work with you properly.';
      case SafetyClassification.normal:
        return '';
    }
  }

  /// Returns a compassionate crisis response with hotline numbers.
  String getCrisisResponse() {
    return 'I hear you, and I want you to know that you matter. What you\'re '
        'feeling right now is real, and there are people who care and want to '
        'help.\n\n'
        'Please reach out to one of these resources — they\'re free, '
        'confidential, and available right now:\n\n'
        '  - **International Association for Suicide Prevention**: '
        'https://www.iasp.info/resources/Crisis_Centres/\n'
        '  - **Crisis Text Line** (US): Text HOME to 741741\n'
        '  - **Samaritans** (UK/IE): Call 116 123\n'
        '  - **Befrienders Worldwide**: https://befrienders.org\n\n'
        'If you\'re in immediate danger, please call your local emergency '
        'number (e.g. 999, 911, 112).\n\n'
        'I\'m an AI coaching assistant and I\'m not equipped to provide the '
        'support you deserve right now. A trained counsellor can help — '
        'please reach out.';
  }
}

// ── Provider ──

final safetyClassifierProvider = Provider<SafetyClassifier>(
  (_) => SafetyClassifier(),
);
