/// Whether the on-disk download for a model matches the catalogue's pinned
/// version. Drives the "Update available" badge on the model card.
library;

enum ModelVersionStatus {
  /// No file on disk for this model.
  notDownloaded,

  /// On-disk file matches `hfCommitHash` from the allowlist.
  currentVersion,

  /// A file exists on disk but it was downloaded against a different
  /// `hfCommitHash` (i.e. the allowlist has bumped to a newer pin).
  updateAvailable,
}
