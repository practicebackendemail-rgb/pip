# Implementation Status & Verification Matrix

*Factual status of features, verified by automated unit tests, compiler checks, and static analysis.*
*Date: 2026-10-27*

---

| Area | Feature | Status | Evidence | Date |
| :--- | :--- | :--- | :--- | :--- |
| **Secrets & Security** | Plaintext API keys eliminated from SharedPreferences | Working | `secrets_migration_test.dart` asserts removal of all provider keys | 2026-10-27 |
| **Secrets & Security** | API keys removed from request URLs (header auth) | Working | Verified in `gemini_service.dart` (`x-goog-api-key`) and tests | 2026-10-27 |
| **Secrets & Security** | SharedPreferences to SecureStorage automatic migration | Working | Unit tests pass; keys migrated before first call | 2026-10-27 |
| **Data Layer** | SQLCipher schema v2 with tombstones (`is_deleted = 1`) | Working | `database_helper.dart` v2 migration; unit tests pass | 2026-10-27 |
| **Data Layer** | `MemoryRanker` 75/25 similarity & importance weighting | Working | `memory_ranking_test.dart` passes with 6 unit tests | 2026-10-27 |
| **Data Layer** | Model-specific vector filtering (prevent dimension collision) | Working | `MemoryRanker.rankMemories` filters by model ID | 2026-10-27 |
| **Learning Loop** | Reflection reads unprocessed database events | Working | `NightlyReflectionService` queries `event_log` table | 2026-10-27 |
| **Learning Loop** | Rule deduplication in `addRule` | Working | Case/whitespace-insensitive deduplication in `learning_loop_test.dart` | 2026-10-27 |
| **Learning Loop** | Decay race condition avoidance | Working | Snapshot refreshed prior to decay in `learning_loop_test.dart` | 2026-10-27 |
| **Signals & Emotion** | Task completion boosts valence and energy | Working | `learning_loop_test.dart` verifies state boost | 2026-10-27 |
| **Signals & Emotion** | Overdue task accumulation lowers valence | Working | `learning_loop_test.dart` verifies penalty trigger | 2026-10-27 |
| **Chat Engine** | `PipStageCubit` split under 300 LOC (288 LOC) | Working | `pip_tool_coordinator.dart` & `pip_memory_helper.dart` extracted | 2026-10-27 |
| **Chat Engine** | 5-turn tool calling termination cap | Working | `chat_engine_test.dart` verifies loop terminates at turn 5 | 2026-10-27 |
| **Chat Engine** | Terminal plain-text structured JSON schema call | Working | `chat_engine_test.dart` verifies emotion schema preserved | 2026-10-27 |
| **Chat Engine** | Function role mapped from `'tool'` to `'function'` | Working | Explicit mapping implemented in `PipToolCoordinator` | 2026-10-27 |
| **Real Tools** | Real authenticated SMTP email transmission | Working | `enough_mail` integrated; `real_tools_test.dart` passes | 2026-10-27 |
| **Real Tools** | Real device calendar integration | Working | `device_calendar_plus` integrated; `real_tools_test.dart` passes | 2026-10-27 |
| **Real Tools** | System-level persistent zoned reminders | Working | `flutter_local_notifications` + `timezone` in `real_tools_test.dart` | 2026-10-27 |
| **Two-Way Sync** | Snapshot v3 with tombstones and LWW conflict resolution | Working | `two_way_sync_test.dart` merges simulated devices | 2026-10-27 |
| **Two-Way Sync** | PBKDF2 iteration capping against DoS bombing | Working | `two_way_sync_test.dart` rejects hazardous payload | 2026-10-27 |
| **Two-Way Sync** | System share sheet export & file picker import | Working | Integrated in `ManualEncryptedFileProvider` | 2026-10-27 |
| **Two-Way Sync** | Manual "Sync Now" UI button & resume trigger | Working | Added in `WhatPipKnowsScreen` with 1-hour cooldown | 2026-10-27 |
| **Platform Presence**| Android floating companion state sync | Working | `PipOverlayBridge` throttles cubit sync to 250ms | 2026-10-27 |
| **Platform Presence**| Android overlay tap triggers voice listening | Working | `platform_presence_test.dart` verifies message handling | 2026-10-27 |
| **Platform Presence**| Windows frameless pet mode, click-through, bounds | Working | `screen_retriever` multi-monitor validation active | 2026-10-27 |
| **Platform Presence**| Windows tray icon (`app_icon.ico`) & startup launcher | Working | Multi-res icon registered; `platform_presence_test.dart` passes | 2026-10-27 |
| **Live Voice** | Bidirectional Gemini Live WebSocket audio streaming | Not Built | Explicitly deferred per Phase 8 Option B; `PipLiveVoicePlaceholder` | 2026-10-27 |
| **File Compliance** | Modified/new files strictly < 300 LOC | Working | All Phase 0–8 files under limit; 3 legacy screens documented | 2026-10-27 |
