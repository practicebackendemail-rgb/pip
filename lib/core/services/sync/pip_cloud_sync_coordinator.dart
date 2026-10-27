import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/memory_models.dart';
import '../../domain/memory_repository.dart';
import '../../domain/sync_provider.dart';
import 'manual_encrypted_file_provider.dart';
import 'pip_cloud_crypto_service.dart';

/// Two-way sync coordinator managing user-owned encrypted backups with Last-Writer-Wins.
class PipCloudSyncCoordinator extends ChangeNotifier {
  static const String _deviceIdKey = 'pip_sync_device_id';
  static const String _lastSyncTsKey = 'pip_last_sync_timestamp';
  final MemoryRepository memoryRepository;
  final FlutterSecureStorage _secureStorage;

  ISyncProvider _activeProvider;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;
  String _deviceId = 'device_main';

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
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

    final lastSyncMillis = prefs.getInt(_lastSyncTsKey);
    if (lastSyncMillis != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
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
    notifyListeners();
  }

  /// Two-way sync: pulls remote changes, merges with LWW, and pushes local snapshot.
  Future<bool> syncNow({bool force = false}) async {
    if (_isSyncing) return false;
    final pass = await getSyncPassphrase();
    if (pass == null || pass.isEmpty) return false;

    // Cooldown check (1 hour) unless forced
    if (!force && _lastSyncTime != null) {
      final elapsed = DateTime.now().difference(_lastSyncTime!);
      if (elapsed.inHours < 1) {
        return false;
      }
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Pull and merge remote snapshots
      final remoteFiles = await _activeProvider.listFiles();
      for (final file in remoteFiles) {
        // Skip files created by this exact device
        if (file.name.contains('-$_deviceId.enc')) continue;

        try {
          final encrypted = await _activeProvider.pull(file.id);
          final decrypted = await PipCloudCryptoService.decryptPayload(encrypted, pass);
          final map = jsonDecode(decrypted) as Map<String, dynamic>;
          await mergeRemoteSnapshot(map);
        } catch (e) {
          debugPrint('Sync merge error for ${file.name}: $e');
        }
      }

      // 2. Export local snapshot v3 with all items including tombstones
      final facts = await memoryRepository.getAllFactsIncludingDeleted();
      final rules = await memoryRepository.getAllRulesIncludingDeleted();
      final memories = await memoryRepository.getAllMemoriesIncludingDeleted();

      final snapshot = {
        'version': 3,
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncTsKey, _lastSyncTime!.millisecondsSinceEpoch);

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Merges remote items using Last-Writer-Wins based on updatedAt timestamps and tombstones
  Future<void> mergeRemoteSnapshot(Map<String, dynamic> data) async {
    // 1. Merge facts with LWW
    final remoteFacts = data['facts'] as List?;
    if (remoteFacts != null) {
      for (final r in remoteFacts) {
        final f = ProfileFact.fromMap(r as Map<String, dynamic>);
        await memoryRepository.importFact(f);
      }
    }

    // 2. Merge rules with LWW
    final remoteRules = data['rules'] as List?;
    if (remoteRules != null) {
      for (final r in remoteRules) {
        final rule = PipRule.fromMap(r as Map<String, dynamic>);
        await memoryRepository.importRule(rule);
      }
    }

    // 3. Merge memories with LWW
    final remoteMemories = data['memories'] as List?;
    if (remoteMemories != null) {
      for (final m in remoteMemories) {
        final mem = MemoryItem.fromMap(m as Map<String, dynamic>);
        await memoryRepository.importMemory(mem);
      }
    }
  }
}
