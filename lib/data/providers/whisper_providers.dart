/// Riverpod surface for Whisper STT model management. The
/// transcription path itself is not wired against the installed
/// fllama 0.0.1 (see WhisperSttService doc); these providers expose
/// the catalogue + download state so the Voice Settings screen works.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device/whisper_stt_service.dart';

final whisperModelsProvider = Provider<List<WhisperModel>>(
  (_) => kWhisperModels,
);

final whisperActiveModelIdProvider =
    FutureProvider<String?>((ref) async => whisperSttService.activeModelId());

final whisperModelDownloadedProvider =
    FutureProvider.family<bool, String>(
  (ref, modelId) => whisperSttService.isModelDownloaded(modelId),
);

final whisperModelSizeProvider = FutureProvider.family<int, String>(
  (ref, modelId) => whisperSttService.modelSizeOnDisk(modelId),
);
