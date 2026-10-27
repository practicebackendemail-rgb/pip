# Pip Personal Assistant & Desk Companion

A privacy-first desk companion and proactive assistant designed with clean architecture, cryptographic integrity, and expressive persona dynamics.

---

## Architectural Principles & Highlights

1. **Security & Secrets Hygiene (Phase 1)**
   - API keys (Gemini, OpenAI, Anthropic, Groq) and credentials (SMTP/IMAP) are stored exclusively in hardware-backed `FlutterSecureStorage`.
   - Zero API keys are leaked into URLs (`x-goog-api-key` request headers are strictly utilized).
   - Plaintext `SharedPreferences` secrets migration executes transparently on app startup.

2. **Encrypted Persistence & Tombstoning (Phase 2 & Phase 6)**
   - Local database runs on encrypted SQLCipher (`sqflite_sqlcipher`).
   - Schema v2 introduces `is_deleted` tombstones and `updated_at` timestamps on facts, rules, and memories.
   - Vector search enforces model-specific similarity metrics (`MemoryRanker`), filtering out incompatible model dimensions and tombstoned items.

3. **Learning Loop & Emotion Hooks (Phase 3)**
   - Asynchronous nightly reflection parses raw database event log signals.
   - Profile fact decay is calculated without race conditions over newly ingested memories.
   - Pip's dynamic emotional model (`PipEmotionState`) directly reacts to task completion and overdue accumulation.

4. **Multi-Turn Chat Engine (Phase 4)**
   - Function calling tools are bounded by a strict 5-turn termination cap.
   - Guaranteed terminal synthesis step always resets loading states and parses character bible emotional schema.
   - Cubit layer is fully modularized (< 300 LOC) into `PipToolCoordinator` and `PipMemoryHelper`.

5. **Real Tool Integrations (Phase 5)**
   - Real authenticated SMTP email dispatch via `enough_mail`.
   - Real platform calendar integration via `device_calendar_plus`.
   - System-level persistent reminders via `flutter_local_notifications` and `timezone`.

6. **Two-Way Encrypted Sync (Phase 6)**
   - Snapshot v3 payload encryption using PBKDF2 (100,000 iterations capped against DoS iteration bombing) + AES-256-GCM.
   - Deterministic Last-Writer-Wins (LWW) conflict resolution honoring tombstoned records.
   - Export and import via system share sheet and file picker.

7. **Cross-Platform Presence (Phase 7 & Phase 8)**
   - **Android Floating Companion**: Always-on-top overlay with throttled state synchronization and voice-listening bridge.
   - **Windows Pet Mode**: Frameless, transparent ambient pet window with multi-display boundary validation, click-through, global hotkeys (`Ctrl+Shift+P`), and startup launch toggles.
   - **Live Voice Status**: Live Gemini WebSocket streaming is deferred and honestly documented as an unbuilt prototype (`PipLiveVoicePlaceholder.isImplemented == false`).

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.5`
- Dart SDK `^3.11.5`
- Android Studio / VS Code / Antigravity IDE

### Setup & Run
```bash
# Get dependencies
flutter pub get

# Run code generator
dart run build_runner build --delete-conflicting-outputs

# Execute code analyzer
dart analyze lib/ test/

# Run complete test suite
flutter test -j 1 test/
```

### Documentation Links
- [Detailed Architecture](docs/ARCHITECTURE.md)
- [Comprehensive Dependencies](docs/DEPENDENCIES.md)
- [Verification & Status Matrix](docs/STATUS.md)
