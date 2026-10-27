# Pip Implementation Status

Checked against `Remediation_Plan_v2` on 2026-10-27, by reading the code and running the commands below.

**Status values**
- **Working**: implemented, with an automated test that exercises the behavior.
- **Partial**: some of the plan's steps are done; the gap is named.
- **Not built**: absent on purpose, or not started.
- **Unverified**: the code exists, but the behavior depends on a real API, phone or PC and has not been tried there.

Unit tests use fakes, so a passing test proves the logic, not the integration.

**Evidence (2026-10-27)**
- `dart analyze lib/ test/`: 3 infos (`withOpacity` deprecations in `glass_container.dart`), 0 warnings, 0 errors.
- `flutter test -j 1 test/`: 63 passed.
- Debug builds: see the build section at the end.

## Secrets

| Feature | Status | Evidence |
|---|---|---|
| No API keys in SharedPreferences; one-time migration to secure storage | Working | `secrets_migration_test.dart` |
| Keys sent in headers, not URLs | Working | No `key=` in any URL under `lib/` |
| Upgrading from an old build on a real device | Unverified | Not tried on a device |

## Data layer

| Feature | Status | Evidence |
|---|---|---|
| Schema v3: tombstones, `processed_at`, `meta`, `events(ts)` index | Working | `memory_schema_test.dart` upgrades a real v1 SQLite database |
| Migration errors are logged and abort the open | Working | `memory_schema_test.dart` |
| Embedding tags carry the provider (`gemini:`, `openai:`, `ollama:`); `none` when there is no vector | Working | `memory_schema_test.dart` |
| Vectors compared only within the same model and the same length | Working | `memory_ranking_test.dart`, `tool_messages_and_ranker_test.dart` |
| Keyword matches fill short vector results | Working | `tool_messages_and_ranker_test.dart` |
| `recordMemory` and `addRule` skip duplicates | Working | `normalizeMemoryText` test; `learning_loop_test.dart` |
| Forget Everything: tombstones that sync, content blanked, events cleared | Partial | Code only. SQLCipher cannot run in unit tests, so there is no test. |
| Retention: processed events kept 30 days, unprocessed 90 | Partial | Code only, no test |
| SQLCipher database on Windows | Unverified | `sqflite_sqlcipher` may not ship a Windows implementation. No clear error message is shown if it fails. |

## Learning loop

| Feature | Status | Evidence |
|---|---|---|
| Reflection reads unprocessed events from the database and stores its run time in `meta` | Working | `learning_loop_test.dart` |
| Learned rules capped at 20 | Partial | Code only, no test |
| Signals logged: task created, completed, uncompleted and deleted; briefing opened and closed; thumbs up/down; session start and end | Working | `learning_and_chat_engine_test.dart` covers the task events. Others are wired at their call sites. |
| `voice_interrupted` signal | Not built | `PipAudioCoordinator.interruptPlayback` is never called, so voice barge-in does not exist yet |
| Emotion: task completed, overdue count grows, time drift (on resume and every 15 minutes) | Working | `learning_and_chat_engine_test.dart` |
| Embedding backfill at startup and when the embedding provider changes | Working | `learning_and_chat_engine_test.dart` |
| Gemini `text-embedding-004` model still served by Google | Unverified | It may be retired. If it is, embedding fails and search falls back to keywords. |

## Chat engine

| Feature | Status | Evidence |
|---|---|---|
| `PipChatEngine`: at most 5 tool rounds, 45-second timeout, spinner always reset | Working | `chat_engine_test.dart` |
| Tool calls and results sent the way each provider expects (OpenAI, Anthropic, Gemini with `thoughtSignature`); text fallback for Groq | Working (logic) / Unverified (live) | `tool_messages_and_ranker_test.dart`. Not tried against the real APIs. |
| Plain-text reply with tools on gets one structured pass, so emotion is kept | Working | `learning_and_chat_engine_test.dart` |
| Last 8 turns sent with each request (not saved) | Working | `learning_and_chat_engine_test.dart` |
| After a confirmed tool runs, Pip speaks a summary of the real result | Working | `learning_and_chat_engine_test.dart` |
| Event log keeps tool names and argument keys only, never values or results | Working | `pip_tool_coordinator.dart` |
| Old Gemini-only chat path | Removed | The unused dashboard and chat screens were deleted. Settings still uses `GeminiAssistantService` for the Gemini key and model only. |

## Tools

| Feature | Status | Evidence |
|---|---|---|
| Email sends over SMTP; reports success only when the server accepts the message | Working (logic) / Unverified (live) | `real_tools_test.dart` with a fake service |
| Calendar via `device_calendar_plus` (Android and iOS); error on Windows | Working (logic) / Unverified (device) | `real_tools_test.dart` |
| Reminders scheduled with `zonedSchedule` (inexact); in-app timer on Windows | Working (logic) / Unverified (device) | Not yet checked that a reminder fires after the app is closed |

## Sync

| Feature | Status | Evidence |
|---|---|---|
| Snapshot v3 with tombstones; newest edit wins; two simulated devices converge | Working | `two_way_sync_test.dart` |
| PBKDF2 iteration cap | Working | `two_way_sync_test.dart` |
| Sync now, Export Backup (share sheet with the encrypted file) and Import Backup (file picker), in Settings and What Pip Knows | Partial | Export without a passphrase is tested. The share and pick flows are unverified on a device. |
| Recovery code | Not built | It was removed because nothing used it. A forgotten passphrase cannot be recovered. |

## Platform

| Feature | Status | Evidence |
|---|---|---|
| Android overlay mirrors the app's state, throttled to 250 ms; tapping it starts listening | Working (logic) / Unverified (device) | `platform_presence_test.dart`. The bridge is started in `main.dart`. |
| Overlay shown only while the app is visible; restore paths | Not built | Plan step 7.1.3 |
| Windows tray icon and launch at startup (with a Settings switch) | Unverified | Not tried on a PC |
| Windows click-through on hover | Unverified | Plan step 7.2.3 |

## Live voice

| Feature | Status | Evidence |
|---|---|---|
| Gemini Live streaming | Not built | Deferred (Option B). `PipLiveVoicePlaceholder` is labeled as not built. |

## File size

Every file except these two is under about 300 lines; both are exemptions until they are split:
- `onboarding_setup_screen.dart`: 496 lines
- `voice_service.dart`: 304 lines

## Builds

Neither platform builds on the development machine right now, and in both cases the cause is the toolchain, not Dart code:

| Platform | Result (2026-10-27) | Cause and fix |
|---|---|---|
| Android `flutter build apk --debug` | Failed | Gradle stops with `java.io.IOException: Unable to establish loopback connection`, inside and outside the sandbox. This is a JDK/Gradle networking problem on this machine (firewall, antivirus or JDK version). Re-run after fixing it. |
| Windows `flutter build windows --debug` | Failed | `flutter_secure_storage_windows` and `flutter_local_notifications_windows` cannot find `atlbase.h`/`atlstr.h`. Install the "C++ ATL for latest build tools" component in the Visual Studio Installer. |

The Dart code compiles: analyze reports 0 errors and the test suite compiles and passes.
