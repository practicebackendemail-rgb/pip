# Pip Implementation Audit Report: Rigorous Status & Remediation Roadmap

*Comprehensive, verified technical audit of `personal_assistant` against the Pip Implementation Guide and the Pip Fix Plan.*

---

## 1. Executive Summary & Verdict Scorecard

While substantial architectural scaffolding and cryptographic primitives are in place, claims of "100% compliance" were premature. Several services are stubs, lack callers, or contain state mutation bugs.

| Step | Topic | Verdict | Current Reality & Required Remediation |
| :---: | :--- | :---: | :--- |
| **1** | **Email password** | **Done** | Passwords are in `FlutterSecureStorage`. One-time migration runs. `toJson()` excludes credentials. |
| **2** | **Reflection** | **Wired, with bugs** | Lifecycle triggers exist, but decay reads a stale snapshot that can overwrite newly learned facts. Rules duplicate on each run due to lack of deduplication in `addRule`. |
| **3** | **Memory search** | **Partly done** | Hybrid ranking fallback and cosine similarity are implemented, but vectors are not tagged by model type (`text-embedding-004` is assumed for all). Old memories without vectors are skipped. |
| **4** | **Event log** | **Moved to DB, few signals** | Events write to the encrypted SQLCipher database, but only the 7 original event types are emitted. Emotion state hooks (`onTaskCompleted`, `onOverdueAccumulation`) are not invoked. |
| **5** | **Tools** | **Real calling, simulated tools** | Native function calling and multi-turn loops work, but `send_email` does not transmit via SMTP (returns fake success), calendar uses an in-memory mock store, and reminders rely on in-app timers. Multi-turn loop drops the JSON reply schema, risking lost emotion fields. |
| **6** | **Cloud sync** | **Encryption done, sync non-functional** | PBKDF2 + AES-256-GCM envelope is robust, but `syncNow()` has no UI or background callers. Snapshots cause duplicate rules and revive deleted facts. Files are stored in app-private storage instead of user-accessible folders. |
| **7** | **Android overlay** | **Window exists, disconnected** | Service and permissions are declared in the manifest, but the main app does not stream mood or speech to `PipOverlayWidget`, and overlay taps are unhandled. |
| **8** | **Windows pet mode** | **Mostly done, minor gaps** | Frameless window, click-through, and `screen_retriever` position memory are implemented. Missing real `assets/icons/app_icon.ico` and startup launch wiring. |
| **9** | **Live voice** | **Stub** | Direct WebSocket connection to Gemini Live is not established; audio stream capture and playback pipelines are not operational. |
| **10** | **Tests & hygiene** | **Partial** | 12 tests pass, but coverage is shallow. API keys remain in plaintext in `SharedPreferences` within secondary services (`gemini_service.dart`, `llm_registry_service.dart`). |

---

## 2. Critical Bugs to Remediate First

### 1. `send_email` Does Not Transmit Mail
- **Problem:** `SendEmailTool.execute()` returns `{'status': 'dispatched'}` without ever invoking an SMTP client.
- **Fix:** Connect `enough_mail`'s `MailClient` or `SmtpClient` in `EmailService.sendEmail(...)` to perform real authentication and network transmission.

### 2. Calendar Tool Uses Mock In-Memory Store
- **Problem:** `LocalCalendarStore` hardcodes a mock "Daily Standup" rather than querying the platform calendar.
- **Fix:** Implement `device_calendar` in `CalendarTools` to request permissions, query real device event instances, and insert confirmed events.

### 3. Chat Multi-Turn Loop Edge Cases & Emotion Schema Loss
- **Problem:** If the LLM generates tool calls across all 5 turns, the loop terminates without emitting a final response, leaving the cubit in a permanent loading state. When `tools` are supplied, `jsonSchema` is omitted, causing `emotion`, `intensity`, and `animation` fields to drop.
- **Fix:** Guarantee a terminal plain-text synthesis step if turn 5 is reached. In multi-turn tool calling, include character bible emotion tags in the system prompt so the final output always parses mood.

### 4. Nightly Reflection Decay & Rule Duplication
- **Problem:** `_applyFactDecay` operates on the pre-reflection fact list, overwriting facts updated during the same run. `addRule` assigns a new random timestamp ID, causing identical instructions to duplicate on every reflection.
- **Fix:** Refresh the profile snapshot before decay. Add instruction-level deduplication to `addRule`.

### 5. Cloud Sync Inactivity & LWW Deletion Bug
- **Problem:** `syncNow()` is never invoked. Syncing performs raw appends, duplicating rules and restoring deleted facts. `ManualEncryptedFileProvider` writes to `getApplicationDocumentsDirectory()`, which is private on Android.
- **Fix:** Expose a manual "Sync Now" button and lifecycle hook. Use unique fact/rule keys with `updatedAt` timestamps for genuine Last-Writer-Wins, and tombstone deleted records.

### 6. Live Voice WebSocket Implementation
- **Problem:** `PipLiveVoiceService` is a connection stub without an active WebSocket or audio pipeline.
- **Fix:** Establish a real WebSocket connection to Gemini Live (`wss://generativelanguage.googleapis.com/...`), stream microphone PCM audio chunks, and wire received audio frames to `audioplayers`.

### 7. Android Overlay State Synchronization
- **Problem:** The main Flutter engine never shares mood, listening, or speech changes with `PipOverlayWidget` via `FlutterOverlayWindow.shareData`.
- **Fix:** Subscribe `PipStageCubit` state emissions to `PipOverlayManager.shareData(...)` and register a receiver for overlay tap events.

---

## 3. Secondary Deficits & Governance Issues

1. **Secret Persistence Hygiene:** `llm_registry_service.dart` and `gemini_service.dart` still duplicate API keys into plaintext `SharedPreferences`. All keys must be restricted to `FlutterSecureStorage`.
2. **Model Tagging on Vectors:** `MemoryItem.embeddingModel` defaults to `text-embedding-004`. When using Ollama or OpenAI, the actual embedding model name must be recorded, and cosine search must filter for matching models.
3. **Rich Event Signals:** Instrument user interaction points to log `task_created`, `task_completed`, `task_rescheduled`, `briefing_opened`, and `voice_interrupted`, and link `task_completed` to `PipEmotionState.onTaskCompleted()`.
4. **Reminders:** Replace `Future.delayed` timers in `ReminderTool` with system-level scheduled notifications using `flutter_local_notifications` zoned scheduling.
5. **Windows Pet Mode Polish:** Add `assets/icons/app_icon.ico` and hook `launch_at_startup` to user settings.
6. **File Length Budgets:** Refactor files exceeding 300 LOC (such as `PipStageCubit` at 403 LOC) into modular controller components.
