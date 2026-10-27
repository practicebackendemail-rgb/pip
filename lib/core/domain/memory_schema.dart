import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'embedding_tags.dart';

/// Schema and migrations for the encrypted memory database.
/// Kept apart from [EncryptedMemoryDatabase] so migrations can be tested
/// against a plain SQLite database without SQLCipher or platform channels.
class MemorySchema {
  static const int version = 3;

  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        ts TEXT NOT NULL,
        device_id TEXT NOT NULL,
        processed_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE memories (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        embedding TEXT,
        embedding_model TEXT NOT NULL,
        importance REAL NOT NULL,
        created_at TEXT NOT NULL,
        last_used_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE profile_facts (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        confidence REAL NOT NULL,
        evidence_count INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        last_reinforced_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE rules (
        id TEXT PRIMARY KEY,
        scope TEXT NOT NULL,
        instruction TEXT NOT NULL,
        source TEXT NOT NULL,
        active INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts)');
  }

  /// Runs every step between [oldVersion] and [version]. Errors are logged and
  /// rethrown so a failed migration aborts the open instead of failing silently.
  static Future<void> upgrade(DatabaseExecutor db, int oldVersion) async {
    try {
      if (oldVersion < 2) await _toV2(db);
      if (oldVersion < 3) await _toV3(db);
    } catch (e, st) {
      debugPrint('MemorySchema: migration from v$oldVersion failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> _toV2(DatabaseExecutor db) async {
    final nowIso = DateTime.now().toIso8601String();
    await db.execute('ALTER TABLE events ADD COLUMN processed_at TEXT');
    await db.execute('ALTER TABLE memories ADD COLUMN updated_at TEXT');
    await db.execute('ALTER TABLE memories ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    await db.execute('UPDATE memories SET updated_at = created_at WHERE updated_at IS NULL');
    await db.execute('ALTER TABLE profile_facts ADD COLUMN last_reinforced_at TEXT');
    await db.execute('ALTER TABLE profile_facts ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    await db.execute('UPDATE profile_facts SET last_reinforced_at = updated_at WHERE last_reinforced_at IS NULL');
    await db.execute('ALTER TABLE rules ADD COLUMN updated_at TEXT');
    await db.execute('ALTER TABLE rules ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    await db.execute('UPDATE rules SET updated_at = ? WHERE updated_at IS NULL', [nowIso]);
    await db.execute('CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  /// v3: events(ts) index, and re-tag memories from the old bare
  /// 'text-embedding-004' default to provider-qualified tags.
  static Future<void> _toV3(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts)');
    final rows = await db.query('memories', columns: ['id', 'embedding', 'embedding_model']);
    for (final r in rows) {
      final raw = r['embedding'] as String?;
      List<dynamic>? vector;
      if (raw != null && raw.isNotEmpty) {
        try {
          vector = jsonDecode(raw) as List<dynamic>;
        } catch (_) {}
      }
      final tag = EmbeddingTags.migrateLegacy(r['embedding_model'] as String?, vector?.length ?? 0);
      if (tag != r['embedding_model']) {
        await db.update('memories', {'embedding_model': tag}, where: 'id = ?', whereArgs: [r['id']]);
      }
    }
  }
}
