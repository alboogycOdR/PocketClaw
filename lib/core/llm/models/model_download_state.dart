/// Download state tracking for model files
library;

enum DownloadStatus { notDownloaded, downloading, downloaded, error }

class ModelDownloadState {
  final String modelId;
  final DownloadStatus status;
  final double progress; // 0.0 - 1.0
  final String? errorMessage;
  final String? localPath;
  final DateTime? downloadedAt;

  const ModelDownloadState({
    required this.modelId,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.localPath,
    this.downloadedAt,
  });

  ModelDownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
    String? localPath,
    DateTime? downloadedAt,
  }) {
    return ModelDownloadState(
      modelId: modelId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      localPath: localPath ?? this.localPath,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }
}
