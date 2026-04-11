/// Model provider / organisation identifiers with display metadata
library;

import 'package:flutter/painting.dart';

enum ModelProvider {
  google,
  meta,
  microsoft,
  alibaba,
  huggingFace,
  apple,
  tii,
  anthropic,
  openAI,
  googleAI,
}

extension ModelProviderLabel on ModelProvider {
  String get displayName => switch (this) {
    ModelProvider.google      => 'Google',
    ModelProvider.meta        => 'Meta',
    ModelProvider.microsoft   => 'Microsoft',
    ModelProvider.alibaba     => 'Alibaba',
    ModelProvider.huggingFace => 'HuggingFace',
    ModelProvider.apple       => 'Apple',
    ModelProvider.tii         => 'TII UAE',
    ModelProvider.anthropic   => 'Anthropic',
    ModelProvider.openAI      => 'OpenAI',
    ModelProvider.googleAI    => 'Google AI',
  };

  Color get badgeColor => switch (this) {
    ModelProvider.google      => const Color(0xFF4285F4),
    ModelProvider.meta        => const Color(0xFF0081FB),
    ModelProvider.microsoft   => const Color(0xFF00A4EF),
    ModelProvider.alibaba     => const Color(0xFFFF6A00),
    ModelProvider.huggingFace => const Color(0xFFFFD21E),
    ModelProvider.apple       => const Color(0xFF555555),
    ModelProvider.tii         => const Color(0xFF009688),
    ModelProvider.anthropic   => const Color(0xFFD4A574),
    ModelProvider.openAI      => const Color(0xFF10A37F),
    ModelProvider.googleAI    => const Color(0xFF4285F4),
  };
}
