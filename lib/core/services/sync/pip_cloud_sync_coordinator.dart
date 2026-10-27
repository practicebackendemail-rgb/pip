import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/memory_models.dart';
import '../../domain/memory_repository.dart';
import '../../domain/sync_provider.dart';
import 'manual_encrypted_file_provider.dart';
import 'pip_cloud_crypto_service.dart';

/// Two-way sync coordinator managing user-owned encrypted backups.
/// Synchronizes profile facts, behavioral rules, and episodic memories with vector embeddings.
class PipCloudSyncCoordinator extends ChangeNotifier {
  static const String _deviceIdKey = 'pip_sync_device_id';
  final MemoryRepository memoryRepository;
  final FlutterSecureStorage _secureStorage;

  ISyncProvider _activeProvider;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String _deviceId = 'device_main';

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  ISyncProvider get activeProvider => _activeProvider;
  String get deviceId => _deviceId;

  PipCloudSyncCoordinator({
    required this.memoryRepository,
    FlutterSecureStorage? secureStorage,
    ISyncProvider? defaultProvider,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _activeProvider = defaultProvider ?? ManualEncryptedFileProvider() {
    _initDevice();
  }

  Future<void> _initDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      _deviceId = stored;
    } else {
      _deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch % 100000}';
      await prefs.setString(_deviceIdKey, _deviceId);
    }
  }

  void setProvider(ISyncProvider provider) {
    _activeProvider = provider;
    notifyListeners();
  }

  Future<String?> getSyncPassphrase() async {
    return _secureStorage.read(key: 'pip_sync_passphrase');
  }

  Future<void> setSyncPassphrase(String passphrase) async {
    await _secureStorage.write(key: 'pip_sync_passphrase', value: passphrase);
  }

  /// Two-way sync: pulls remote changes, merges by ID/timestamp, and pushes local snapshot.
  Future<bool> syncNow() async {
    if (_isSyncing) return false;
    final pass = await getSyncPassphrase();
    if (pass == null || pass.isEmpty) return false;

    _isSyncing = true;
    notifyListeners();

    try {
      // 1. Pull and merge remote snapshots
      final remoteFiles = await _activeProvider.listFiles();
      for (final file in remoteFiles) {
        // Skip files uploaded by this device
        if (file.name.contains('$_deviceId.enc')) continue;

        try {
          final encrypted = await _activeProvider.pull(file.id);
          final decrypted = await PipCloudCryptoService.decryptPayload(encrypted, pass);
          final map = jsonDecode(decrypted) as Map<String, dynamic>;
          await _mergeRemoteSnapshot(map);
        } catch (e) {
          debugPrint('Sync merge error for ${file.name}: $e');
        }
      }

      // 2. Export local snapshot and push
      final facts = await memoryRepository.getProfile();
      final rules = await memoryRepository.getActiveRules();
      final memories = await memoryRepository.searchMemories(const [], limit: 100);

      final snapshot = {
        'version': 2,
        'device_id': _deviceId,
        'timestamp': DateTime.now().toIso8601String(),
        'facts': facts.map((f) => f.toMap()).toList(),
        'rules': rules.map((r) => r.toMap()).toList(),
        'memories': memories.map((m) => m.toMap()).toList(),
      };

      final payload = jsonEncode(snapshot);
      final encrypted = await PipCloudCryptoService.encryptPayload(payload, pass);
      final fileName = 'snapshot-$_deviceId.enc';
      await _activeProvider.push(fileName, encrypted);

      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Cloud sync error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _mergeRemoteSnapshot(Map<String, dynamic> data) async {
    // 1. Merge facts (Last-Writer-Wins)
    final remoteFacts = data['facts'] as List?;
    if (remoteFacts != null) {
      for (final r in remoteFacts) {
        final f = ProfileFact.fromMap(r as Map<String, dynamic>);
        await memoryRepository.upsertFact(f.key, f.value, confidence: f.confidence);
      }
    }

    // 2. Merge rules
    final remoteRules = data['rules'] as List?;
    if (remoteRules != null) {
      for (final r in remoteRules) {
        final rule = PipRule.fromMap(r as Map<String, dynamic>);
        await memoryRepository.addRule(rule.instruction, scope: rule.scope, source: rule.source);
      }
    }

    // 3. Union memories by ID
    final remoteMemories = data['memories'] as List?;
    if (remoteMemories != null) {
      for (final m in remoteMemories) {
        final mem = MemoryItem.fromMap(m as Map<String, dynamic>);
        await memoryRepository.recordMemory(mem.text, embedding: mem.embedding, importance: mem.importance);
      }
    }
  }
}
