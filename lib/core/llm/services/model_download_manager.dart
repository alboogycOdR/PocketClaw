/// Coordinates model downloads across engines, surfaces progress via streams
library;

import 'dart:async';

import '../engines/llm_engine_factory.dart';
import '../models/local_model_config.dart';
import '../models/model_download_state.dart';
import 'download_notifier.dart';
import 'hf_token_service.dart';
import 'license_service.dart';

class ModelDownloadManager {
  final HFTokenService _tokenService;
  final LicenseService _licenseService;
  final ModelDownloadNotifier _notifier;
  final Map<String, StreamController<ModelDownloadState>> _controllers = {};

  ModelDownloadManager({
    required HFTokenService tokenService,
    required LicenseService licenseService,
    ModelDownloadNotifier? notifier,
  })  : _tokenService = tokenService,
        _licenseService = licenseService,
        _notifier = notifier ?? ModelDownloadNotifier();

  Stream<ModelDownloadState> watchDownload(String modelId) {
    _controllers.putIfAbsent(
      modelId,
      () => StreamController<ModelDownloadState>.broadcast(),
    );
    return _controllers[modelId]!.stream;
  }

  Future<void> startDownload(LocalModelConfig model) async {
    final token = await _tokenService.getToken();

    // Require token for gated models
    if (model.requiresLicense && token == null) {
      _emit(
        model.id,
        DownloadStatus.error,
        errorMessage:
            'HuggingFace token required. Add it in Settings \u2192 API Keys.',
      );
      return;
    }

    // Check license acceptance
    if (model.requiresLicense && !_licenseService.isAccepted(model.id)) {
      _emit(
        model.id,
        DownloadStatus.error,
        errorMessage:
            'License not accepted. Visit ${model.licenseUrl} to agree.',
      );
      return;
    }

    _emit(model.id, DownloadStatus.downloading, progress: 0.0);
    // Fire-and-forget — never block the download on a notification call.
    // ignore: unawaited_futures
    _notifier.start(modelId: model.id, displayName: model.displayName);

    try {
      final engine = LLMEngineFactory.forModel(model);
      await engine.downloadModel(
        model,
        huggingFaceToken: token,
        onProgress: (progress) {
          _emit(model.id, DownloadStatus.downloading, progress: progress);
          // ignore: unawaited_futures
          _notifier.update(
            modelId: model.id,
            displayName: model.displayName,
            progress: progress,
          );
        },
      );
      _emit(model.id, DownloadStatus.downloaded, progress: 1.0);
      // ignore: unawaited_futures
      _notifier.complete(
        modelId: model.id,
        displayName: model.displayName,
      );
    } catch (e) {
      _emit(model.id, DownloadStatus.error, errorMessage: e.toString());
      // ignore: unawaited_futures
      _notifier.fail(modelId: model.id);
    }
  }

  void _emit(
    String modelId,
    DownloadStatus status, {
    double progress = 0.0,
    String? errorMessage,
  }) {
    _controllers.putIfAbsent(
      modelId,
      () => StreamController<ModelDownloadState>.broadcast(),
    );
    _controllers[modelId]!.add(ModelDownloadState(
      modelId: modelId,
      status: status,
      progress: progress,
      errorMessage: errorMessage,
    ));
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }
}
