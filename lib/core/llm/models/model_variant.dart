/// An alternate downloadable variant of a parent model — e.g. a Q8 quant of
/// the same Gemma 4 4B. The variant inherits everything from its parent
/// `LocalModelConfig` (hfRepo, hfCommitHash, chatTemplate, license, tags…)
/// and only overrides the file, size, and RAM requirement.
library;

class ModelVariant {
  final String id;
  final String variantLabel;
  final String hfFilename;
  final int sizeBytes;
  final int minRamBytes;

  const ModelVariant({
    required this.id,
    required this.variantLabel,
    required this.hfFilename,
    required this.sizeBytes,
    required this.minRamBytes,
  });

  double get sizeGB => sizeBytes / (1024 * 1024 * 1024);
  double get minRamGB => minRamBytes / (1024 * 1024 * 1024);
}
