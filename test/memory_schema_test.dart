import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/embedding_tags.dart';
import 'package:personal_assistant/core/domain/memory_ranker.dart';
import 'package:personal_assistant/core/domain/memory_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The exact v1 schema shipped before remediation (tag pre-remediation-v2).
Future<void> _createV1(Database db) async {
  await db.execute('CREATE TABLE events (id TEXT PRIMARY KEY, type TEXT NOT NULL, '
      'payload_json TEXT NOT NULL, ts TEXT NOT NULL, device_id TEXT NOT NULL)');
  await db.execute('CREATE TABLE memories (id TEXT PRIMARY KEY, text TEXT NOT NULL, embedding TEXT, '
      'embedding_model TEXT NOT NULL, importance REAL NOT NULL, created_at TEXT NOT NULL, '
      'last_used_at TEXT NOT NULL)');
  await db.execute('CREATE TABLE profile_facts (key TEXT PRIMARY KEY, value TEXT NOT NULL, '
      'confidence REAL NOT NULL, evidence_count INTEGER NOT NULL, updated_at TEXT NOT NULL)');
  await db.execute('CREATE TABLE rules (id TEXT PRIMARY KEY, scope TEXT NOT NULL, '
      'instruction TEXT NOT NULL, source TEXT NOT NULL, active INTEGER NOT NULL)');
}

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  test('v1 database upgrades to current version keeping all data', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (db, _) => _createV1(db)));
    const created = '2026-01-01T00:00:00.000';
    await db.insert('events', {'id': 'e1', 'type': 't', 'payload_json': '{}', 'ts': created, 'device_id': 'd'});
    await db.insert('memories', {
      'id': 'm_gem', 'text': 'likes tea', 'embedding': jsonEncode(List.filled(768, 0.1)),
      'embedding_model': 'text-embedding-004', 'importance': 0.5, 'created_at': created, 'last_used_at': created,
    });
    await db.insert('memories', {
      'id': 'm_oai', 'text': 'likes jazz', 'embedding': jsonEncode(List.filled(1536, 0.1)),
      'embedding_model': 'text-embedding-004', 'importance': 0.5, 'created_at': created, 'last_used_at': created,
    });
    await db.insert('memories', {
      'id': 'm_none', 'text': 'note', 'embedding': null,
      'embedding_model': 'text-embedding-004', 'importance': 0.5, 'created_at': created, 'last_used_at': created,
    });
    await db.insert('profile_facts',
        {'key': 'k', 'value': 'v', 'confidence': 0.6, 'evidence_count': 1, 'updated_at': created});
    await db.insert('rules', {'id': 'r', 'scope': 'g', 'instruction': 'be brief', 'source': 'user', 'active': 1});

    await MemorySchema.upgrade(db, 1);

    final mems = {for (final r in await db.query('memories')) r['id']: r};
    expect(mems, hasLength(3));
    expect(mems['m_gem']!['embedding_model'], EmbeddingTags.gemini);
    expect(mems['m_oai']!['embedding_model'], EmbeddingTags.openai);
    expect(mems['m_none']!['embedding_model'], EmbeddingTags.none);
    expect(mems['m_gem']!['updated_at'], created);
    expect(mems['m_gem']!['is_deleted'], 0);

    final fact = (await db.query('profile_facts')).single;
    expect(fact['last_reinforced_at'], created);
    expect(fact['is_deleted'], 0);
    final rule = (await db.query('rules')).single;
    expect(rule['updated_at'], isNotNull);
    expect((await db.query('events')).single['processed_at'], isNull);

    final idx = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND name='idx_events_ts'");
    expect(idx, hasLength(1));
    await db.insert('meta', {'key': 'a', 'value': 'b'});
    await db.close();
  });

  test('fresh create matches upgraded schema columns', () async {
    final fresh = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: MemorySchema.version, onCreate: (db, _) => MemorySchema.create(db)));
    final upgraded = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (db, _) => _createV1(db), singleInstance: false));
    await MemorySchema.upgrade(upgraded, 1);

    for (final table in ['events', 'memories', 'profile_facts', 'rules', 'meta']) {
      Future<Set<Object?>> cols(Database d) async =>
          (await d.rawQuery('PRAGMA table_info($table)')).map((r) => r['name']).toSet();
      expect(await cols(upgraded), await cols(fresh), reason: table);
    }
    await fresh.close();
    await upgraded.close();
  });

  test('failed migration is rethrown, not swallowed', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, singleInstance: false));
    expect(() => MemorySchema.upgrade(db, 1), throwsA(anything));
    await db.close();
  });

  test('embedding tags', () {
    expect(EmbeddingTags.forProvider('gemini'), EmbeddingTags.gemini);
    expect(EmbeddingTags.forProvider('ollama'), EmbeddingTags.ollama);
    expect(EmbeddingTags.migrateLegacy('ollama:nomic-embed-text', 768), EmbeddingTags.ollama);
    expect(EmbeddingTags.migrateLegacy('text-embedding-004', 0), EmbeddingTags.none);
  });

  test('normalizeMemoryText collapses case and whitespace', () {
    expect(normalizeMemoryText('  Likes   Tea \n'), normalizeMemoryText('likes tea'));
  });
}
