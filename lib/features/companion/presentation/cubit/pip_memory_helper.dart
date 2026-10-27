import 'package:flutter/foundation.dart';
import '../../../../core/domain/llm_provider.dart';
import '../../../../core/domain/memory_models.dart';
import '../../../../core/domain/memory_repository.dart';

/// Helper to encapsulate semantic retrieval, embedding generation, and memory storage
class PipMemoryHelper {
  final MemoryRepository memoryRepository;

  const PipMemoryHelper(this.memoryRepository);

  Future<List<MemoryItem>> retrieveRelevantMemories({
    required String queryText,
    required LlmProvider embeddingProvider,
  }) async {
    List<double> queryVector = const [];
    if (queryText.trim().split(RegExp(r'\s+')).length > 2 &&
        embeddingProvider.capabilities.supportsEmbeddings) {
      try {
        final embList = await embeddingProvider.embed([queryText.trim()]);
        if (embList.isNotEmpty && embList.first.isNotEmpty) {
          queryVector = embList.first;
        }
      } catch (e) {
        debugPrint('Query embedding error: $e');
      }
    }

    return await memoryRepository.searchMemories(
      queryVector,
      limit: 3,
      queryText: queryText,
    );
  }

  Future<void> saveLearnedMemories(
    List<String> candidates,
    LlmProvider embeddingProvider,
  ) async {
    for (final candidate in candidates) {
      List<double>? candidateVector;
      if (embeddingProvider.capabilities.supportsEmbeddings) {
        try {
          final emb = await embeddingProvider.embed([candidate]);
          if (emb.isNotEmpty && emb.first.isNotEmpty) candidateVector = emb.first;
        } catch (_) {}
      }
      await memoryRepository.recordMemory(
        candidate,
        embedding: candidateVector,
        importance: 0.8,
      );
    }
  }
}
