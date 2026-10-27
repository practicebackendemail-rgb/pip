import 'package:flutter/foundation.dart';
import '../domain/embedding_tags.dart';
import '../domain/llm_provider.dart';
import '../domain/memory_repository.dart';

/// Embeds memories that have no vector from the current embedding model, in
/// batches, so they become reachable by vector search. Runs after startup and
/// whenever the embedding provider changes; stops quietly when no provider
/// can embed or a call fails (it resumes on the next run).
class EmbeddingBackfillService {
  final MemoryRepository memoryRepository;
  final LlmProvider Function() embeddingProvider;
  final int batchSize;
  final int maxBatches;
  bool _running = false;

  EmbeddingBackfillService({
    required this.memoryRepository,
    required this.embeddingProvider,
    this.batchSize = 20,
    this.maxBatches = 10,
  });

  /// Returns the number of memories embedded.
  Future<int> run() async {
    if (_running) return 0;
    _running = true;
    var done = 0;
    try {
      final provider = embeddingProvider();
      if (!provider.capabilities.supportsEmbeddings) return 0;
      final tag = EmbeddingTags.forProvider(provider.id);
      final failed = <String>{};

      for (var batch = 0; batch < maxBatches; batch++) {
        final pending = (await memoryRepository.getMemoriesNeedingEmbedding(tag, limit: batchSize + failed.length))
            .where((m) => !failed.contains(m.id))
            .take(batchSize)
            .toList();
        if (pending.isEmpty) break;

        final vectors = await provider.embed(pending.map((m) => m.text).toList());
        if (vectors.length != pending.length) return done; // provider unavailable or partial
        for (var i = 0; i < pending.length; i++) {
          if (vectors[i].isEmpty) {
            failed.add(pending[i].id);
            continue;
          }
          await memoryRepository.updateMemoryEmbedding(pending[i].id, vectors[i], tag);
          done++;
        }
      }
    } catch (e) {
      debugPrint('EmbeddingBackfillService: stopped: $e');
    } finally {
      _running = false;
    }
    return done;
  }
}
