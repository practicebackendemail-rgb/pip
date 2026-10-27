/// Represents an episodic memory with vector embeddings and recency weighting
class MemoryItem {
  final String id;
  final String text;
  final List<double>? embedding;
  final String embeddingModel;
  final double importance; // 0.0 to 1.0
  final DateTime createdAt;
  final DateTime lastUsedAt;

  MemoryItem({
    required this.id,
    required this.text,
    this.embedding,
    this.embeddingModel = 'text-embedding-004',
    this.importance = 0.5,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUsedAt = lastUsedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'embedding': embedding?.join(','),
        'embedding_model': embeddingModel,
        'importance': importance,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt.toIso8601String(),
      };

  factory MemoryItem.fromMap(Map<String, dynamic> map) {
    List<double>? emb;
    final embStr = map['embedding'] as String?;
    if (embStr != null && embStr.isNotEmpty) {
      emb = embStr.split(',').map((e) => double.tryParse(e) ?? 0.0).toList();
    }
    return MemoryItem(
      id: map['id'] as String,
      text: map['text'] as String,
      embedding: emb,
      embeddingModel: (map['embedding_model'] as String?) ?? 'text-embedding-004',
      importance: (map['importance'] as num?)?.toDouble() ?? 0.5,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastUsedAt: DateTime.parse(map['last_used_at'] as String),
    );
  }
}

/// Learned fact about user routines, preferences, and quirks
class ProfileFact {
  final String key;
  final String value;
  final double confidence; // 0.0 to 1.0
  final int evidenceCount;
  final DateTime updatedAt;

  ProfileFact({
    required this.key,
    required this.value,
    this.confidence = 0.5,
    this.evidenceCount = 1,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'key': key,
        'value': value,
        'confidence': confidence,
        'evidence_count': evidenceCount,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProfileFact.fromMap(Map<String, dynamic> map) => ProfileFact(
        key: map['key'] as String,
        value: map['value'] as String,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
        evidenceCount: (map['evidence_count'] as int?) ?? 1,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

/// Explicit and learned behavioral constraint or guideline
class PipRule {
  final String id;
  final String scope; // e.g. 'briefing', 'humor', 'tasks', 'general'
  final String instruction;
  final String source; // 'user_explicit' or 'learned'
  final bool active;

  PipRule({
    required this.id,
    required this.scope,
    required this.instruction,
    this.source = 'user_explicit',
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'scope': scope,
        'instruction': instruction,
        'source': source,
        'active': active ? 1 : 0,
      };

  factory PipRule.fromMap(Map<String, dynamic> map) => PipRule(
        id: map['id'] as String,
        scope: map['scope'] as String,
        instruction: map['instruction'] as String,
        source: (map['source'] as String?) ?? 'user_explicit',
        active: (map['active'] as int? ?? 1) == 1,
      );
}
