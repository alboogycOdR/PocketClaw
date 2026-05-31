/// Classifies a user prompt as `text` or `image` intent using fast
/// regex patterns. Used by the local-model send path to decide
/// whether to route to text generation or (when a local image model
/// is installed) image generation.
library;

enum MessageIntent { text, image }

class IntentClassifier {
  static final _imagePatterns = [
    RegExp(
        r'\b(draw|paint|sketch|create|generate|make|design|render|produce)\b.{0,30}\b(image|picture|art|illustration|portrait|landscape|photo|artwork|graphic|visual)\b',
        caseSensitive: false),
    RegExp(
        r'\b(image|picture|art|illustration|portrait|photo|graphic)\b.{0,20}\b(of|showing|depicting|with|featuring)\b',
        caseSensitive: false),
    RegExp(
        r'\b(can you|could you|please|pls)\b.{0,20}\b(draw|paint|sketch)\b',
        caseSensitive: false),
    RegExp(r'\b(visualize|illustrate|depict)\b.{0,10}\b(a|an|the)\b',
        caseSensitive: false),
    RegExp(
        r'\b(give|gimme|get)\b.{0,10}\b(me|us)\b.{0,20}\b(image|picture|pic|photo|art|illustration|drawing)\b',
        caseSensitive: false),
    RegExp(
        r'\b(wallpaper|avatar|logo|icon|banner|poster|thumbnail)\b.{0,20}\b(of|for|with)\b',
        caseSensitive: false),
    RegExp(
        r'\b(create|make|generate|design)\b.{0,20}\b(wallpaper|avatar|logo|icon|banner)\b',
        caseSensitive: false),
    RegExp(
        r'\b(digital art|oil painting|watercolor|pencil drawing|charcoal sketch)\b',
        caseSensitive: false),
    RegExp(
        r'\b(4k|8k|hd|high resolution|ultra detailed)\b.{0,20}\b(image|picture|art|render)\b',
        caseSensitive: false),
    RegExp(
        r'\b(photorealistic|hyperrealistic)\b.{0,20}\b(image|render|of)\b',
        caseSensitive: false),
    RegExp(r'\bstable diffusion\b', caseSensitive: false),
  ];

  static final _explicitTextPatterns = [
    RegExp(
        r'\b(explain|describe|tell me|what is|how does|write|summarize|list|compare|analyze|calculate)\b',
        caseSensitive: false),
  ];

  final _cache = <String, MessageIntent>{};
  static const _cacheMax = 100;

  MessageIntent classify(String text) {
    final cached = _cache[text];
    if (cached != null) return cached;

    for (final pat in _explicitTextPatterns) {
      if (pat.hasMatch(text)) {
        _store(text, MessageIntent.text);
        return MessageIntent.text;
      }
    }
    for (final pat in _imagePatterns) {
      if (pat.hasMatch(text)) {
        _store(text, MessageIntent.image);
        return MessageIntent.image;
      }
    }
    _store(text, MessageIntent.text);
    return MessageIntent.text;
  }

  void _store(String key, MessageIntent value) {
    if (_cache.length >= _cacheMax) _cache.remove(_cache.keys.first);
    _cache[key] = value;
  }
}

final intentClassifier = IntentClassifier();
