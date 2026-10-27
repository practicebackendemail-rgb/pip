import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'encrypted_memory_db.dart';

/// Single logged event for Pip's reflection engine and emotional drift.
class PipEvent {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final String deviceId;

  PipEvent({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? timestamp,
    this.deviceId = 'unknown',
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'ts': timestamp.toIso8601String(),
        'device_id': deviceId,
      };

  factory PipEvent.fromJson(Map<String, dynamic> json) => PipEvent(
        id: json['id'] as String,
        type: json['type'] as String,
        payload: (json['payload'] as Map<String, dynamic>?) ?? {},
        timestamp: DateTime.parse(json['ts'] as String),
        deviceId: (json['device_id'] as String?) ?? 'unknown',
      );
}

/// Event log service writing through SQLCipher encrypted database with in-memory caching.
class EventLogService extends ChangeNotifier {
  static const String _legacyKey = 'pip_events_log_v1';
  final EncryptedMemoryDatabase _db = EncryptedMemoryDatabase.instance;
  final List<PipEvent> _recentCache = [];

  List<PipEvent> get events => List.unmodifiable(_recentCache);

  EventLogService() {
    _initAndMigrate();
  }

  Future<void> _initAndMigrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // One-time migration from SharedPreferences to SQLCipher encrypted DB
      if (prefs.containsKey(_legacyKey)) {
        final raw = prefs.getStringList(_legacyKey) ?? [];
        for (final item in raw) {
          try {
            final parsed = PipEvent.fromJson(jsonDecode(item));
            await _db.logEvent(parsed);
          } catch (_) {}
        }
        await prefs.remove(_legacyKey);
        debugPrint('Migrated ${raw.length} legacy events to encrypted DB.');
      }

      // Populate recent memory cache (latest 100 events)
      final stored = await _db.getEvents(limit: 100);
      _recentCache.clear();
      _recentCache.addAll(stored);
      notifyListeners();

      // Enforce 30-day retention prune
      final threshold = DateTime.now().subtract(const Duration(days: 30));
      await _db.pruneEventsOlderThan(threshold);
    } catch (e) {
      debugPrint('EventLogService init error: $e');
    }
  }

  Future<void> log(String type, [Map<String, dynamic>? payload]) async {
    final event = PipEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_recentCache.length}',
      type: type,
      payload: payload ?? {},
    );

    _recentCache.add(event);
    if (_recentCache.length > 100) {
      _recentCache.removeAt(0);
    }
    notifyListeners();

    try {
      await _db.logEvent(event);
    } catch (e) {
      debugPrint('EventLogService save error: $e');
    }
  }

  List<PipEvent> getEventsSince(DateTime since) {
    return _recentCache.where((e) => e.timestamp.isAfter(since)).toList();
  }
}
