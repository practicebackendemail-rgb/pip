import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_repository.dart';
import 'package:personal_assistant/core/services/sync/pip_cloud_crypto_service.dart';
import 'package:personal_assistant/core/services/sync/pip_cloud_sync_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMemoryRepository implements MemoryRepository {
  final Map<String, ProfileFact> facts = {};
  final Map<String, PipRule> rules = {};
  final Map<String, MemoryItem> memories = {};

  @override
  Future<void> importFact(ProfileFact fact) async {
    final existing = facts[fact.key];
    if (existing == null || fact.updatedAt.isAfter(existing.updatedAt)) {
      facts[fact.key] = fact;
    }
  }

  @override
  Future<void> importRule(PipRule rule) async {
    final existing = rules[rule.id];
    if (existing == null || rule.updatedAt.isAfter(existing.updatedAt)) {
      rules[rule.id] = rule;
    }
  }

  @override
  Future<void> importMemory(MemoryItem memory) async {
    final existing = memories[memory.id];
    if (existing == null || memory.updatedAt.isAfter(existing.updatedAt)) {
      memories[memory.id] = memory;
    }
  }

  @override
  Future<List<ProfileFact>> getAllFactsIncludingDeleted() async => facts.values.toList();

  @override
  Future<List<PipRule>> getAllRulesIncludingDeleted() async => rules.values.toList();

  @override
  Future<List<MemoryItem>> getAllMemoriesIncludingDeleted() async => memories.values.toList();

  @override
  Future<List<ProfileFact>> getProfile() async =>
      facts.values.where((f) => !f.isDeleted).toList();

  @override
  Future<List<PipRule>> getActiveRules() async =>
      rules.values.where((r) => !r.isDeleted).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Phase 6: Two-Way Sync & Last-Writer-Wins Tests', () {
    test('Crypto hardening rejects hazardous iteration bombing attacks', () async {
      const hazardousEnvelope =
          '{"envelope_version": 2, "iterations": 10000000, "salt": "AAAA", "nonce": "AAAA", "cipher": "AAAA", "mac": "AAAA"}';

      expect(
        () async => await PipCloudCryptoService.decryptPayload(hazardousEnvelope, 'mypass'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Export backup refuses without a passphrase and reports why', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final coordinator = PipCloudSyncCoordinator(memoryRepository: FakeMemoryRepository());
      expect(coordinator.supportsBackupFiles, isTrue);
      expect(await coordinator.exportBackup(), isFalse);
      expect(coordinator.lastError, contains('passphrase'));
    });

    test('Two simulated devices merge with Last-Writer-Wins and honor tombstones', () async {
      final repo = FakeMemoryRepository();
      final coordinator = PipCloudSyncCoordinator(memoryRepository: repo);

      final t1 = DateTime.now().subtract(const Duration(hours: 2));
      final t2 = DateTime.now().subtract(const Duration(hours: 1));

      // Device A initializes local facts and rules
      repo.facts['user_occupation'] = ProfileFact(
        key: 'user_occupation',
        value: 'Theoretical Physicist',
        confidence: 0.9,
        evidenceCount: 10,
        updatedAt: t1,
        lastReinforcedAt: t1,
        isDeleted: false,
      );

      repo.rules['rule_1'] = PipRule(
        id: 'rule_1',
        instruction: 'Never sit in Sheldon spot',
        scope: 'global',
        source: 'user',
        active: true,
        updatedAt: t1,
        isDeleted: false,
      );

      // Simulate remote Device B sending a snapshot where fact was updated at t2
      // and rule was deleted (tombstoned) at t2
      final remoteSnapshotFromDeviceB = {
        'version': 3,
        'device_id': 'dev_B',
        'facts': [
          {
            'key': 'user_occupation',
            'value': 'Senior Theoretical Physicist',
            'confidence': 0.95,
            'evidence_count': 12,
            'updated_at': t2.toIso8601String(),
            'last_reinforced_at': t2.toIso8601String(),
            'is_deleted': 0,
          }
        ],
        'rules': [
          {
            'id': 'rule_1',
            'instruction': 'Never sit in Sheldon spot',
            'scope': 'global',
            'source': 'user',
            'active': 1,
            'updated_at': t2.toIso8601String(),
            'is_deleted': 1,
          }
        ],
        'memories': [],
      };

      await coordinator.mergeRemoteSnapshot(remoteSnapshotFromDeviceB);

      // Verify LWW: fact updated to newer value, rule tombstone applied
      expect(repo.facts['user_occupation']!.value, equals('Senior Theoretical Physicist'));
      expect(repo.rules['rule_1']!.isDeleted, isTrue);

      // Now verify that a stale update (t1) cannot overwrite a newer tombstone or value
      final staleSnapshot = {
        'version': 3,
        'device_id': 'dev_C',
        'rules': [
          {
            'id': 'rule_1',
            'instruction': 'Never sit in Sheldon spot',
            'scope': 'global',
            'source': 'user',
            'active': 1,
            'updated_at': t1.toIso8601String(),
            'is_deleted': 0, // Stale undelete attempt
          }
        ],
      };

      await coordinator.mergeRemoteSnapshot(staleSnapshot);
      expect(repo.rules['rule_1']!.isDeleted, isTrue);

      // Active rules read must filter out the tombstone
      final active = await repo.getActiveRules();
      expect(active.any((r) => r.id == 'rule_1'), isFalse);
    });
  });
}
