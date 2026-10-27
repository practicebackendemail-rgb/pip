import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'event_log.dart';
import 'memory_models.dart';
import 'memory_schema.dart';

/// Concrete local SQLite store encrypted with SQLCipher via sqflite_sqlcipher.
/// Stores episodic memories, profile facts, behavioral rules, and raw interaction events.
class EncryptedMemoryDatabase {
  static const String _dbFileName = 'pip_encrypted_brain_v1.db';
  static const String _passphraseKey = 'pip_db_sqlcipher_secret_key';
  static final EncryptedMemoryDatabase instance = EncryptedMemoryDatabase._();

  Database? _db;
  Future<Database>? _opening;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Set when an existing database could not be decrypted and was moved
  /// aside so Pip could start fresh. Holds the path of the kept file.
  String? quarantinedPath;

  EncryptedMemoryDatabase._();

  /// Opens once and shares the result. Concurrent callers wait on the same
  /// attempt instead of each retrying a slow failing open.
  Future<Database> get database {
    if (_db != null) return Future.value(_db!);
    return _opening ??= _initDatabase().then((db) => _db = db).whenComplete(() => _opening = null);
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

    Future<Database> open() => openDatabase(
          dbPath,
          password: key,
          version: MemorySchema.version,
          onCreate: (db, version) => MemorySchema.create(db),
          onUpgrade: (db, oldVersion, newVersion) => MemorySchema.upgrade(db, oldVersion),
        );

    try {
      return await open();
    } on DatabaseException catch (e) {
      // A file that exists but won't decrypt means the key was lost (for
      // example the file came back from a device backup but the hardware-bound
      // key did not). Keep the file, renamed, and start a fresh database
      // rather than failing every read forever.
      final file = File(dbPath);
      if (!e.toString().contains('open_failed') || !await file.exists()) rethrow;
      final kept = '$dbPath.unreadable-${DateTime.now().millisecondsSinceEpoch}';
      await file.rename(kept);
      quarantinedPath = kept;
      debugPrint('EncryptedMemoryDatabase: could not decrypt existing database; moved to $kept and starting fresh.');
      return await open();
    }
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
        'processed_at': null,
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

  Future<List<PipEvent>> getUnprocessedEvents({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'events',
      where: 'processed_at IS NULL',
      orderBy: 'ts ASC',
      limit: limit,
    );
    return rows.map((r) => PipEvent(
      id: r['id'] as String,
      type: r['type'] as String,
      payload: (jsonDecode(r['payload_json'] as String) as Map<String, dynamic>?) ?? {},
      timestamp: DateTime.parse(r['ts'] as String),
      deviceId: (r['device_id'] as String?) ?? 'unknown',
    )).toList();
  }

  Future<void> markEventsProcessed(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final id in eventIds) {
      batch.update('events', {'processed_at': now}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Retention: processed events go after 30 days, unprocessed ones after 90,
  /// so reflection never loses events it has not read yet.
  Future<void> pruneEvents({DateTime? now}) async {
    final db = await database;
    final t = now ?? DateTime.now();
    await db.delete(
      'events',
      where: '(processed_at IS NOT NULL AND ts < ?) OR ts < ?',
      whereArgs: [
        t.subtract(const Duration(days: 30)).toIso8601String(),
        t.subtract(const Duration(days: 90)).toIso8601String(),
      ],
    );
  }

  Future<void> upsertMemory(MemoryItem memory) async {
    final db = await database;
    await db.insert('memories', memory.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MemoryItem>> getAllMemories({bool includeDeleted = false}) async {
    final db = await database;
    final rows = await db.query(
      'memories',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'last_used_at DESC',
    );
    return rows.map((r) => MemoryItem.fromMap(r)).toList();
  }

  Future<void> deleteMemory(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update('memories', {'is_deleted': 1, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFact(ProfileFact fact) async {
    final db = await database;
    await db.insert('profile_facts', fact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProfileFact>> getAllFacts({bool includeDeleted = false}) async {
    final db = await database;
    final rows = await db.query(
      'profile_facts',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'confidence DESC',
    );
    return rows.map((r) => ProfileFact.fromMap(r)).toList();
  }

  Future<void> setFactConfidence(String key, double confidence) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'profile_facts',
      {'confidence': confidence, 'updated_at': now},
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<void> deleteFact(String key) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update('profile_facts', {'is_deleted': 1, 'updated_at': now}, where: 'key = ?', whereArgs: [key]);
  }

  Future<void> upsertRule(PipRule rule) async {
    final db = await database;
    await db.insert('rules', rule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PipRule>> getAllRules({bool includeDeleted = false}) async {
    final db = await database;
    final rows = await db.query(
      'rules',
      where: includeDeleted ? 'active = 1' : 'active = 1 AND is_deleted = 0',
    );
    return rows.map((r) => PipRule.fromMap(r)).toList();
  }

  Future<void> deleteRule(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update('rules', {'is_deleted': 1, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// "Forget Everything": tombstones all memories, facts and learned rules so
  /// other devices converge on the deletion during sync, and clears local
  /// events and meta. Content is blanked so nothing personal survives in the
  /// tombstone. [eraseOnThisDeviceOnly] hard-deletes instead, with no tombstones,
  /// so synced copies elsewhere are untouched (and may sync back).
  Future<void> forgetEverything({bool eraseOnThisDeviceOnly = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (eraseOnThisDeviceOnly) {
        await txn.delete('memories');
        await txn.delete('profile_facts');
        await txn.delete('rules', where: 'source = ?', whereArgs: ['learned']);
      } else {
        final now = DateTime.now().toIso8601String();
        await txn.update('memories', {'is_deleted': 1, 'updated_at': now, 'text': '', 'embedding': null});
        await txn.update('profile_facts', {'is_deleted': 1, 'updated_at': now, 'value': '', 'confidence': 0.0});
        await txn.update(
          'rules',
          {'is_deleted': 1, 'updated_at': now, 'instruction': ''},
          where: 'source = ?',
          whereArgs: ['learned'],
        );
      }
      await txn.delete('events');
      await txn.delete('meta');
    });
  }
}
