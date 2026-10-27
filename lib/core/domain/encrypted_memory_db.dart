import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'memory_models.dart';
import 'event_log.dart';

/// Concrete local SQLite store encrypted with SQLCipher via sqflite_sqlcipher.
/// Stores episodic memories, profile facts, behavioral rules, and raw interaction events.
class EncryptedMemoryDatabase {
  static const String _dbFileName = 'pip_encrypted_brain_v1.db';
  static const String _passphraseKey = 'pip_db_sqlcipher_secret_key';
  static final EncryptedMemoryDatabase instance = EncryptedMemoryDatabase._();

  Database? _db;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  EncryptedMemoryDatabase._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<String> _getOrCreateEncryptionKey() async {
    String? key = await _secureStorage.read(key: _passphraseKey);
    if (key == null || key.isEmpty) {
      final random = math.Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = base64Url.encode(bytes);
      await _secureStorage.write(key: _passphraseKey, value: key);
    }
    return key;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbFileName);
    final key = await _getOrCreateEncryptionKey();

    return await openDatabase(
      dbPath,
      password: key,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            ts TEXT NOT NULL,
            device_id TEXT NOT NULL
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
            last_used_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE profile_facts (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            confidence REAL NOT NULL,
            evidence_count INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE rules (
            id TEXT PRIMARY KEY,
            scope TEXT NOT NULL,
            instruction TEXT NOT NULL,
            source TEXT NOT NULL,
            active INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // --- CRUD Operations ---

  Future<void> logEvent(PipEvent event) async {
    final db = await database;
    await db.insert(
      'events',
      {
        'id': event.id,
        'type': event.type,
        'payload_json': jsonEncode(event.payload),
        'ts': event.timestamp.toIso8601String(),
        'device_id': event.deviceId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PipEvent>> getEvents({int limit = 200, DateTime? since}) async {
    final db = await database;
    final where = since != null ? 'ts > ?' : null;
    final whereArgs = since != null ? [since.toIso8601String()] : null;
    final rows = await db.query(
      'events',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'ts DESC',
      limit: limit,
    );
    return rows.map((r) => PipEvent(
      id: r['id'] as String,
      type: r['type'] as String,
      payload: (jsonDecode(r['payload_json'] as String) as Map<String, dynamic>?) ?? {},
      timestamp: DateTime.parse(r['ts'] as String),
      deviceId: (r['device_id'] as String?) ?? 'unknown',
    )).toList().reversed.toList();
  }

  Future<void> pruneEventsOlderThan(DateTime threshold) async {
    final db = await database;
    await db.delete('events', where: 'ts < ?', whereArgs: [threshold.toIso8601String()]);
  }

  Future<void> upsertMemory(MemoryItem memory) async {
    final db = await database;
    await db.insert('memories', memory.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MemoryItem>> getAllMemories() async {
    final db = await database;
    final rows = await db.query('memories', orderBy: 'last_used_at DESC');
    return rows.map((r) => MemoryItem.fromMap(r)).toList();
  }

  Future<void> deleteMemory(String id) async {
    final db = await database;
    await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFact(ProfileFact fact) async {
    final db = await database;
    await db.insert('profile_facts', fact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProfileFact>> getAllFacts() async {
    final db = await database;
    final rows = await db.query('profile_facts', orderBy: 'confidence DESC');
    return rows.map((r) => ProfileFact.fromMap(r)).toList();
  }

  Future<void> deleteFact(String key) async {
    final db = await database;
    await db.delete('profile_facts', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> upsertRule(PipRule rule) async {
    final db = await database;
    await db.insert('rules', rule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PipRule>> getAllRules() async {
    final db = await database;
    final rows = await db.query('rules', where: 'active = 1');
    return rows.map((r) => PipRule.fromMap(r)).toList();
  }

  Future<void> deleteRule(String id) async {
    final db = await database;
    await db.delete('rules', where: 'id = ?', whereArgs: [id]);
  }

  /// Wipes all learned memories and facts for the "Forget Everything" user control
  Future<void> forgetEverything() async {
    final db = await database;
    await db.delete('memories');
    await db.delete('profile_facts');
    await db.delete('rules', where: 'source = ?', whereArgs: ['learned']);
  }
}
