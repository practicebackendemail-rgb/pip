/// Provider-qualified embedding model ids stored with each memory, so vectors
/// are only ever compared with vectors from the same model.
class EmbeddingTags {
  static const String none = 'none';
  static const String gemini = 'gemini:text-embedding-004';
  static const String openai = 'openai:text-embedding-3-small';
  static const String ollama = 'ollama:nomic-embed-text';

  /// Tag for vectors produced by the provider with [providerId].
  static String forProvider(String providerId) {
    switch (providerId) {
      case 'gemini':
        return gemini;
      case 'openai':
        return openai;
      case 'ollama':
        return ollama;
      default:
        return '$providerId:default';
    }
  }

  /// Maps a v1/v2 tag to a qualified one. Old builds stamped every memory with
  /// 'text-embedding-004' whatever produced it; 1536-dim vectors can only have
  /// come from OpenAI, other lengths are assumed to be Gemini.
  static String migrateLegacy(String? tag, int vectorLength) {
    if (vectorLength == 0) return none;
    if (tag != null && tag.contains(':')) return tag;
    if (vectorLength == 1536) return openai;
    return gemini;
  }
}
