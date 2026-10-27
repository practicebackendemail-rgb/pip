/// Represents an episodic memory with vector embeddings, recency, and soft-delete tombstone
class MemoryItem {
  final String id;
  final String text;
  final List<double>? embedding;
  final String embeddingModel;
  final double importance; // 0.0 to 1.0
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime updatedAt;
  final bool isDeleted;

  MemoryItem({
    required this.id,
    required this.text,
    this.embedding,
    this.embeddingModel = 'text-embedding-004',
    this.importance = 0.5,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUsedAt = lastUsedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  MemoryItem copyWith({
    String? id,
    String? text,
    List<double>? embedding,
    String? embeddingModel,
    double? importance,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      MemoryItem(
        id: id ?? this.id,
        text: text ?? this.text,
        embedding: embedding ?? this.embedding,
        embeddingModel: embeddingModel ?? this.embeddingModel,
        importance: importance ?? this.importance,
        createdAt: createdAt ?? this.createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'embedding': embedding?.join(','),
        'embedding_model': embeddingModel,
        'importance': importance,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
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
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.parse(map['last_used_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }
}

/// Learned fact about user routines, preferences, and quirks with decay tracking and tombstones
class ProfileFact {
  final String key;
  final String value;
  final double confidence; // 0.0 to 1.0
  final int evidenceCount;
  final DateTime updatedAt;
  final DateTime lastReinforcedAt;
  final bool isDeleted;

  ProfileFact({
    required this.key,
    required this.value,
    this.confidence = 0.5,
    this.evidenceCount = 1,
    DateTime? updatedAt,
    DateTime? lastReinforcedAt,
    this.isDeleted = false,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        lastReinforcedAt = lastReinforcedAt ?? updatedAt ?? DateTime.now();

  ProfileFact copyWith({
    String? key,
    String? value,
    double? confidence,
    int? evidenceCount,
    DateTime? updatedAt,
    DateTime? lastReinforcedAt,
    bool? isDeleted,
  }) =>
      ProfileFact(
        key: key ?? this.key,
        value: value ?? this.value,
        confidence: confidence ?? this.confidence,
        evidenceCount: evidenceCount ?? this.evidenceCount,
        updatedAt: updatedAt ?? this.updatedAt,
        lastReinforcedAt: lastReinforcedAt ?? this.lastReinforcedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'value': value,
        'confidence': confidence,
        'evidence_count': evidenceCount,
        'updated_at': updatedAt.toIso8601String(),
        'last_reinforced_at': lastReinforcedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory ProfileFact.fromMap(Map<String, dynamic> map) => ProfileFact(
        key: map['key'] as String,
        value: map['value'] as String,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
        evidenceCount: (map['evidence_count'] as int?) ?? 1,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        lastReinforcedAt: map['last_reinforced_at'] != null
            ? DateTime.parse(map['last_reinforced_at'] as String)
            : DateTime.parse(map['updated_at'] as String),
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );
}

/// Explicit and learned behavioral constraint or guideline with sync and tombstone metadata
class PipRule {
  final String id;
  final String scope; // e.g. 'briefing', 'humor', 'tasks', 'general'
  final String instruction;
  final String source; // 'user_explicit' or 'learned'
  final bool active;
  final DateTime updatedAt;
  final bool isDeleted;

  PipRule({
    required this.id,
    required this.scope,
    required this.instruction,
    this.source = 'user_explicit',
    this.active = true,
    DateTime? updatedAt,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  PipRule copyWith({
    String? id,
    String? scope,
    String? instruction,
    String? source,
    bool? active,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      PipRule(
        id: id ?? this.id,
        scope: scope ?? this.scope,
        instruction: instruction ?? this.instruction,
        source: source ?? this.source,
        active: active ?? this.active,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'scope': scope,
        'instruction': instruction,
        'source': source,
        'active': active ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory PipRule.fromMap(Map<String, dynamic> map) => PipRule(
        id: map['id'] as String,
        scope: map['scope'] as String,
        instruction: map['instruction'] as String,
        source: (map['source'] as String?) ?? 'user_explicit',
        active: (map['active'] as int? ?? 1) == 1,
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );
}
