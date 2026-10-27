import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_ranker.dart';

void main() {
  group('MemoryRanker Unit Tests', () {
    test('cosineSimilarity calculates exact dot product over norms', () {
      final vecA = [1.0, 0.0, 0.0];
      final vecB = [1.0, 0.0, 0.0];
      final vecC = [0.0, 1.0, 0.0];
      final vecD = [0.5, 0.5, 0.0];

      expect(MemoryRanker.cosineSimilarity(vecA, vecB), closeTo(1.0, 0.0001));
      expect(MemoryRanker.cosineSimilarity(vecA, vecC), closeTo(0.0, 0.0001));
      expect(MemoryRanker.cosineSimilarity(vecA, vecD), closeTo(0.7071, 0.001));
    });

    test('cosineSimilarity returns 0.0 on zero norm or mismatched vector length', () {
      expect(MemoryRanker.cosineSimilarity([0.0, 0.0], [1.0, 1.0]), equals(0.0));
      expect(MemoryRanker.cosineSimilarity([1.0], [1.0, 2.0]), equals(0.0));
      expect(MemoryRanker.cosineSimilarity([], []), equals(0.0));
    });

    test('computeScore combines similarity and importance with 75/25 weighting', () {
      // 0.8 * 0.75 = 0.60; 0.4 * 0.25 = 0.10 => sum = 0.70
      final score = MemoryRanker.computeScore(0.8, 0.4);
      expect(score, closeTo(0.70, 0.0001));
    });

    test('rankMemories filters out soft-deleted items', () {
      final memActive = MemoryItem(
        id: '1',
        text: 'User drinks espresso',
        embedding: [1.0, 0.0],
        isDeleted: false,
      );
      final memDeleted = MemoryItem(
        id: '2',
        text: 'User drinks latte',
        embedding: [1.0, 0.0],
        isDeleted: true,
      );

      final results = MemoryRanker.rankMemories(
        memories: [memActive, memDeleted],
        queryEmbedding: [1.0, 0.0],
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals('1'));
    });

    test('rankMemories rejects embeddings from different model IDs to prevent dimension mismatch', () {
      final geminiMem = MemoryItem(
        id: '1',
        text: 'Gemini embedding fact',
        embedding: [1.0, 0.0],
        embeddingModel: 'text-embedding-004',
      );
      final ollamaMem = MemoryItem(
        id: '2',
        text: 'Ollama embedding fact',
        embedding: [1.0, 0.0],
        embeddingModel: 'nomic-embed-text',
      );

      final results = MemoryRanker.rankMemories(
        memories: [geminiMem, ollamaMem],
        queryEmbedding: [1.0, 0.0],
        targetEmbeddingModel: 'text-embedding-004',
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals('1'));
    });

    test('rankMemories enforces minSimilarity threshold', () {
      final memHigh = MemoryItem(
        id: '1',
        text: 'High similarity',
        embedding: [1.0, 0.0],
      );
      final memLow = MemoryItem(
        id: '2',
        text: 'Low similarity',
        embedding: [0.1, 0.9], // dot product with [1.0, 0.0] is ~0.11 < 0.35
      );

      final results = MemoryRanker.rankMemories(
        memories: [memHigh, memLow],
        queryEmbedding: [1.0, 0.0],
        minSimilarity: 0.35,
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals('1'));
    });

    test('rankMemories gracefully falls back to text overlap when query vector is empty', () {
      final memA = MemoryItem(
        id: '1',
        text: 'User likes black coffee every morning',
        embedding: null,
        importance: 0.8,
      );
      final memB = MemoryItem(
        id: '2',
        text: 'User writes code in Dart and Python',
        embedding: null,
        importance: 0.5,
      );

      final results = MemoryRanker.rankMemories(
        memories: [memA, memB],
        queryEmbedding: [],
        queryText: 'morning coffee',
      );

      expect(results.first.id, equals('1'));
    });
  });
}
