# Pip Fix Plan: Detailed Instructions

*Step-by-step instructions to close the gaps between the personal\_assistant codebase and the Pip Implementation Guide*

Based on a read-only review of `lib/` and `docs/` in personal\_assistant.zip. The code was not compiled or run, so anything marked **Verify** needs checking on your machine.

## How to use this plan

Work top to bottom. Steps 1 to 4 fix security and make the learning loop real, and they are small. Steps 5 to 9 add capability and take longer. Each step lists the files involved, numbered instructions, and a definition of done.

| Step | Topic | Size | Why now |
| --- | --- | --- | --- |
| 1 | Move the email password to secure storage | Small | Plain-text credential |
| 2 | Make the nightly reflection actually run | Small | Learning loop is dead |
| 3 | Make memory search semantic | Medium | Retrieval is not relevant today |
| 4 | Move the event log into the encrypted DB and log richer signals | Medium | Unencrypted, thin data |
| 5 | Native tool calling and broader tools | Large | Breadth |
| 6 | Real cloud sync | Large | User-owned backup |
| 7 | Android always-visible overlay | Medium | Presence |
| 8 | Windows pet mode polish | Medium | Presence |
| 9 | Live voice | Large | Natural conversation |
| 10 | Tests, docs and housekeeping | Ongoing | Keeps it honest |

## Step 1: Move the email password to secure storage

**Problem:** `email_service.dart` stores `mail_server`, `mail_user` and `mail_pass` in SharedPreferences, which is unencrypted.

**Files:** `lib/core/services/email_service.dart`, `lib/screens/settings_persona_screen.dart`, `lib/screens/onboarding_setup_screen.dart`.

**Instructions**

1. In `email_service.dart`, create one `FlutterSecureStorage` instance and use it for the password only. Keep server and username in SharedPreferences if you like, since they are not secrets, or move all three for simplicity.
2. Replace every `prefs.setString('mail_pass', ...)` with a secure-storage write under a clear key such as `pip_mail_password`. Replace every read the same way.
3. Add a one-time migration that runs at startup: if SharedPreferences still contains `mail_pass`, copy it to secure storage, then delete the preference key. Run it before the email service first reads credentials.
4. Add a `clearCredentials()` method that wipes the secure entry and the preferences, and call it from the existing disconnect or forget-everything flow.
5. Never include the password in logs, debug prints, `toJson()` output, or the event log. Check `toJson()` in the config class: it currently serializes a `password` field, so make sure that JSON is never persisted or sent anywhere.
6. Prefer app passwords or OAuth where the mail provider supports them, and say so on the setup screen.

**Done when:** a search of the project for `mail_pass` finds only the migration code, and inspecting the app's SharedPreferences file shows no password.

## Step 2: Make the nightly reflection run

**Problem:** `NightlyReflectionService.runReflectionIfNeeded()` is defined and registered in dependency injection, but nothing calls it.

**Files:** `lib/core/services/nightly_reflection_service.dart`, `lib/main.dart`, `lib/features/companion/presentation/cubit/pip_stage_cubit.dart`.

**Instructions**

1. Decide the trigger. On mobile you cannot rely on background timing, so trigger on app start and on app resume (use `WidgetsBindingObserver.didChangeAppLifecycleState`). On Windows the same trigger works, plus an optional timer.
2. Add a once-per-day guard. Store `last_reflection_at` (in the encrypted database or secure preferences) and skip if less than 20 hours have passed. This replaces the current check of at least 5 events anywhere in history.
3. Fix the event window. The service uses `events.take(30)`, which takes from the start of the list. **Verify** how `EventLogService` orders events: if it appends, you are reflecting on the oldest 30. Instead select events since `last_reflection_at`, newest-last, capped at a sensible size (for example 200), and summarize if there are more.
4. Use the strong-model role. Ask `LlmRegistryService` for a model configured for reflection if you have roles, otherwise the active provider.
5. Validate the model output. Parse the JSON with the same fenced-block tolerant parser used in `PipStructuredReply`, check that `new_facts`, `new_rules` and `new_memories` are lists, and clamp confidence to the 0.1 to 1.0 range. On a parse failure, retry once with the error message appended, then give up and keep `last_reflection_at` unchanged.
6. Apply results safely. Upsert facts so repeated evidence raises confidence gradually (for example add 0.1 per confirmation up to 0.95). Insert rules with source `learned` so the What Pip Knows screen can show them as suggestions. Record memories through the embedding path from Step 3.
7. Mark processed events (add a `processed_at` column in Step 4) so they are not analyzed twice, and delete or compress raw events older than your retention window (for example 30 days) into a short summary row.
8. Add decay: during each run, lower the confidence of facts that were not reinforced in the last 30 days, and remove facts that fall below 0.2.
9. Show progress in the UI. The service already extends `ChangeNotifier`, so surface a small status in What Pip Knows (last reflection time).

**Done when:** after a day of use, the Facts and Rules tabs gain entries without any manual action, and running reflection twice in a row does nothing the second time.

## Step 3: Make memory search semantic

**Problem:** `embed()` is never called, memories are saved without embeddings, and the chat cubit calls `searchMemories(const [], limit: 3)`. With an empty query vector the repository returns the first stored memories regardless of relevance.

**Files:** `lib/core/domain/llm_provider.dart`, `lib/core/services/llm_registry_service.dart`, the four adapters, `lib/core/domain/memory_repository.dart`, `lib/core/domain/encrypted_memory_db.dart`, `pip_stage_cubit.dart`.

**Instructions**

1. Add a separate embedding provider setting. Chat and embeddings are different models, and the Anthropic adapter returns an empty list for `embed()`. In `LlmRegistryService` add `getEmbeddingProvider()` and a settings entry so the user can choose Gemini, an OpenAI-compatible endpoint, or a local model.
2. Add `embedding_model` to the embeddings or memories table. Bump the database version and write an `onUpgrade` migration. Without this you cannot tell which vectors are comparable after the user switches models.
3. On every memory write (`recordMemory`, reflection output, `memory_candidates` from replies), call the embedding provider and store the vector with the model name. If the provider is unavailable, store the memory without a vector and queue it.
4. Add a backfill job that finds memories with a missing or outdated vector and embeds them in small batches. Run it at startup after the first reflection check.
5. In `pip_stage_cubit.dart`, embed the user message before building the prompt and pass the vector to `searchMemories`. Skip embedding for very short inputs (greetings) and cache the last query vector.
6. Keep a fallback for providers without embeddings: rank by importance, recency, and simple keyword overlap instead of returning the first rows. Replace the current empty-vector branch with this logic.
7. Check the Gemini embedding model name used in `gemini_llm_adapter.dart` (currently `text-embedding-004`). **Verify** it is still served and update it if Google has replaced it.
8. If the memory count passes a few thousand, move the cosine loop into an isolate with `compute`. Only consider a vector index package if profiling shows a problem.
9. Set a minimum similarity threshold so irrelevant memories are not injected just to fill the top 3.

**Done when:** asking about something mentioned weeks ago brings that memory into the prompt, and switching embedding provider triggers a re-embed instead of silently comparing incompatible vectors.

## Step 4: Move the event log into the encrypted DB and log richer signals

**Problem:** `EventLogService` keeps events in SharedPreferences under `pip_events_log_v1` as an unbounded list, outside the encrypted database. Only seven event types are logged today: `user_query`, `tool_invoked`, `tool_success`, `tool_confirmed_and_executed`, `tool_action_cancelled`, `pip_awakened`, `pip_slept`.

**Files:** `lib/core/domain/event_log.dart`, `memory_repository.dart`, `encrypted_memory_db.dart`, and the screens and cubits listed below.

**Instructions**

1. Add an `events` table to the encrypted database: id, type, payload JSON, timestamp, device id, processed\_at.
2. Make `EventLogService` write through the repository (`logEvent` already exists) and keep only a small in-memory cache of recent events for the UI.
3. Write a one-time migration: read `pip_events_log_v1`, insert each event, then delete the preferences key.
4. Add retention: a periodic prune that summarizes and deletes events older than your window (Step 2 covers the summary).
5. Log the signals the learning loop needs. Add these where the user action happens:
   - `task_created`, `task_completed`, `task_snoozed`, `task_rescheduled`, `task_deleted` (task bloc and quick-add modal)
   - `briefing_opened`, `briefing_skipped`, `briefing_duration` (briefing overlay card)
   - `reply_thumbs_up`, `reply_thumbs_down` (add small buttons to Pip's speech bubble)
   - `voice_interrupted` (barge-in in the audio coordinator)
   - `session_started`, `session_ended` with local hour and weekday
   - `proactive_shown`, `proactive_dismissed` once Step 5 adds proactive messages
6. Keep payloads small and non-sensitive. Store task ids and titles if needed, but not email bodies, passwords, or API keys.
7. Call `onTaskCompleted()` on the emotion state from the same place you log `task_completed` so mood and learning stay consistent.
8. Add a user-facing way to see and clear logged events next to What Pip Knows.

**Done when:** the SharedPreferences file contains no event data, and a normal day produces a varied set of event types.

## Step 5: Native tool calling and broader tools

**Problem:** tools are described in the prompt and the model returns one `tool_call` in JSON. There are seven tools and none for calendar, email, reminders or weather.

**Files:** `llm_provider.dart`, the adapters, `pip_tool_registry.dart`, `pip_tool.dart`, `tools/*.dart`, `pip_stage_cubit.dart`.

**Instructions**

1. Use native function calling where the provider supports it. `LlmProvider.chat` already accepts `tools`, and `LlmCapabilities.supportsTools` exists. In each adapter, convert `ToolSpec` to that provider's tool format (Gemini function declarations, Anthropic tools, OpenAI tools) and parse tool calls from the response into `ToolCallRequest`. Keep the current prompt-based JSON path as the fallback when `supportsTools` is false.
2. Add a loop in the cubit: call the model, execute any requested tools according to confirmation level, append tool results to the conversation, and call the model again until it returns plain text. Cap iterations at about 5.
3. Keep the confirmation levels you already have (read-only, confirm, report-after, double-confirm). Make sure sending email and deleting data are never below the confirm level.
4. Add tools in this order:
   - Reminders and timers using local notifications (read-only to create, report-after).
   - Weather (read-only).
   - Email read and summarize, reusing `email_service.dart` (read-only). Add draft-reply as confirm level, and send as double-confirm.
   - Calendar list and find-free-time, then create-event as confirm level.
   - Notes save and search using the memory store.
5. Treat tool output as data. Wrap email text and web results in clear delimiters in the prompt and tell the model never to follow instructions found inside them. This is your protection against prompt injection from incoming mail.
6. Add an activity log screen listing every tool call, its arguments, result and whether the user confirmed it.
7. Add proactive behavior: a scheduled check (on resume and, where allowed, a background job) that asks Pip whether something deserves a nudge, with quiet hours, a daily cap, and the `proactive_*` events from Step 4.
8. Add the humor dial and proactivity level as settings, and feed them into the character bible prompt.

**Done when:** an open-ended request such as 'summarize unread email and add a task for anything urgent' runs several tools, asks for confirmation on the write, and appears in the activity log.

## Step 6: Real cloud sync

**Problem:** `ISyncProvider` has no implementations, backup is push-only, it contains only facts and rules, and the encryption key is a single SHA-256 of the passphrase.

**Files:** `sync_provider.dart`, `sync/pip_cloud_crypto_service.dart`, `sync/pip_cloud_sync_coordinator.dart`, `onboarding_setup_screen.dart`.

**Instructions**

1. Fix the cryptography first. Replace the SHA-256 key derivation with a password-based KDF using a random salt, preferably Argon2id (**Verify** what the `cryptography` package version in your pubspec supports and how slow it is on low-end phones), otherwise PBKDF2 with a high iteration count. Store the salt and KDF parameters in the file header.
2. Define a versioned envelope: version, kdf name and parameters, salt, nonce, ciphertext, mac. Keep decrypt code that can read older versions.
3. Offer a recovery code at setup (a random key shown once for printing) and warn that a forgotten passphrase cannot be recovered.
4. Implement providers in this order:
   - `ManualEncryptedFileProvider`: export and import through the system share sheet or file picker. This works on every platform and needs no OAuth.
   - `GoogleDriveAppDataProvider`: use the `drive.appdata` scope, which is non-sensitive. On mobile use Google sign-in with the Drive API client. On Windows the sign-in plugin may not support desktop, so **Verify** and, if needed, use a loopback OAuth flow with `googleapis_auth`. You will need your own OAuth client IDs, and on Android a registered signing certificate fingerprint.
   - `WebDavProvider`: for Nextcloud and similar services.
5. Expand what is synced: facts, rules, memories (with `embedding_model`), summaries, and optionally the event log. Do not sync API keys or email credentials unless the user opts in, and then only inside the encrypted payload.
6. Make sync two-way. Each device writes its own files (`events-<deviceId>-<date>.enc`, `snapshot-<deviceId>.enc`) and never edits another device's files. On launch or resume, list remote files, download new ones, decrypt, and merge: union events and memories by id, last-writer-wins for facts and rules by timestamp.
7. Keep the passphrase handling honest. Storing the passphrase in secure storage is acceptable on a personal device, but consider storing only the derived key.
8. Add a sync status line and a manual Sync now action. Run reflection on only one device, or record its output as an event others merge.
9. Test with two emulators: edit on both offline, sync both, and confirm nothing is lost and deleted facts do not return.

**Done when:** a second device restores the full profile from the user's own cloud, and an attacker with the cloud files but not the passphrase learns nothing readable.

## Step 7: Android always-visible overlay

**Problem:** the manifest has only `RECORD_AUDIO`, `INTERNET`, `BLUETOOTH` and a widget receiver. There is no overlay, foreground service or notification permission.

**Instructions**

1. Add `flutter_overlay_window` (the original package, because the 'plus' variant renders a native text view and cannot draw your Flutter Pip). Check its current README for manifest details.
2. Add permissions: `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, and `POST_NOTIFICATIONS` for Android 13 and later.
3. Declare the overlay service with `foregroundServiceType` set to `specialUse` and the required subtype property, as the package documents.
4. Create an overlay entry point (`overlayMain`) that renders only the compact Pip (eyes and head, optional speech bubble) and receives state from the main app through the package's data sharing.
5. Ask for the overlay permission with a short in-character explanation, and open the system settings screen where the user grants it.
6. Start the overlay only while the app is visible. On recent Android versions an app with overlay permission can start a foreground service from the background only if it already has a visible overlay, and boot-time starts are restricted, so do not plan on auto-start at boot. Give the user one-tap ways to bring Pip back: your existing home screen widget, a quick-settings tile, and a notification action.
7. Keep voice push-to-talk. Tapping the overlay Pip starts listening. Always-on microphone use needs its own foreground service type and a stronger Play Console justification.
8. In Play Console, complete the foreground service declaration for the type you use and describe the user impact if the service is interrupted. All service types are reviewed, so write a clear explanation.
9. Add a help screen about battery optimization, because some phone makers stop background services aggressively. **Verify** by testing on at least two or three brands.

**Done when:** Pip stays on screen over other apps, can be dismissed and restored in one tap, and a Play Console declaration is ready.

## Step 8: Windows pet mode polish

**Problem:** `enterAmbientPetMode()` sets a frameless, transparent, always-on-top window but lacks click-through, tray, hotkey, startup launch, dragging and position memory.

**Files:** `lib/core/services/pip_desktop_window_manager.dart`, `windows/runner/flutter_window.cpp`.

**Instructions**

1. Hide Pip from the taskbar in pet mode with `setSkipTaskbar(true)` and restore it when leaving pet mode.
2. Add click-through. Call `setIgnoreMouseEvents(true, forward: true)` so clicks pass to windows behind, and toggle it off while the pointer is over Pip's body or bubble (use a mouse-region hover handler in Dart). Test that the toggle does not flicker.
3. Add dragging with `startDragging` on pointer down over Pip, and save the position when the drag ends. Use `screen_retriever` (already in pubspec) to store which monitor the window was on and restore it, falling back to the primary monitor if that monitor is gone.
4. Add a system tray icon with Open, Pet mode on or off, Do not disturb, and Quit, using `tray_manager`.
5. Add a global hotkey to show, hide or focus Pip, using `hotkey_manager`.
6. Add launch at startup with `launch_at_startup`, off by default and controlled by a setting.
7. Handle display scaling by sizing the window from the device pixel ratio so Pip is not tiny on high-DPI screens.
8. Test transparency on Windows 11. If you see a black or opaque rectangle, the fix is native: adjust window creation in `flutter_window.cpp` and extend the frame into the client area, as the audit notes suggested. Do this only if the Dart-side options fail.
9. **Verify the database on Windows.** The project uses `sqflite_sqlcipher`, which to my knowledge targets mobile platforms. Confirm it opens on Windows. If it does not, keep the `MemoryRepository` interface and swap the data layer for an FFI SQLite build with SQLCipher on desktop. Do this before investing further in Windows features.
10. Auto-hide or shrink Pip when a full-screen app is running, and add a Do not disturb toggle.

**Done when:** Pip floats on the desktop without blocking clicks, remembers where it was, and starts from the tray or a hotkey.

## Step 9: Live voice

**Instructions**

1. Decide the route. With Gemini there are two: a Firebase-based package that works through a Firebase project and proxy, which does not fit user-supplied keys with no developer backend, or a direct WebSocket connection with the user's key. The direct route is the better match to your design, but check the maturity of the packages before committing.
2. Pick an audio capture library and test it for dropped frames on a mid-range Android phone. The audit raised the choice between `record` and `flutter_sound`, and benchmarking on your target devices is the only way to settle it.
3. Stream microphone audio in the format the live API requires (**Verify** current sample rates and encodings in the provider's documentation), play back returned audio with low latency, and use voice activity detection or the server's own turn detection.
4. Implement barge-in: stop playback immediately when the user starts speaking. Your `PipAudioCoordinator` already has barge-in behavior for the STT and TTS path, so reuse its states.
5. Handle session limits. Audio sessions are time-limited without compression, so reconnect and resume context before the limit.
6. Keep the current STT, LLM and TTS pipeline as the fallback for providers without live audio, and choose the path from `LlmCapabilities`.
7. Map the reply's `voice_style` and `emotion` to speech settings and keep the character animation in sync.

**Done when:** the user can interrupt Pip mid-sentence and the spoken tone matches the emotion shown.

## Step 10: Tests, documentation and housekeeping

**Tests** (the `test/` folder is empty)

1. Unit tests for `PipStructuredReply.parseRaw` (plain JSON, fenced JSON, JSON with extra text, garbage).
2. Unit tests for `PipEmotionState` (task completed, overdue, time drift, mood mapping).
3. Unit tests for the memory repository (cosine ranking, threshold, fallback ranking, forget everything).
4. A crypto round trip test (encrypt, decrypt, wrong passphrase fails, tampering fails).
5. Reflection tests with canned model output, including malformed JSON.
6. Tool tests that confirm each tool's confirmation level and that write tools cannot run without confirmation.
7. Adapter tests against recorded HTTP responses for each provider.

**Security hygiene**

- The Gemini adapters put the API key in the request URL (`?key=...`). Move it to the `x-goog-api-key` header so it does not end up in logs or proxies.
- Confirm no secret appears in `debugPrint` output, event payloads, or sync files.
- Move every remaining secret from SharedPreferences to secure storage.

**Cleanup**

- Remove or isolate unused dependencies (for example `google_generative_ai` and `provider` if nothing uses them) and finish the move to one state-management approach.
- Rewrite `README.md`, `docs/ARCHITECTURE.md` and `docs/DEPENDENCIES.md`, which still describe an earlier version.
- Replace `docs/AUDIT_PIP_IMPLEMENTATION_GUIDE.md`. Its summary table marks phases 0 to 8 as compliant while its own section 3 says phases 5 to 8 are not built, and its claims about analyzer results and `setState` use are unverified. Use a status table that matches reality, and run `flutter analyze` yourself.
- Add CI that runs analysis and tests on every push.

## Final checklist

| Check | Done |
| --- | --- |
| No secrets in SharedPreferences |  |
| Reflection runs daily and is idempotent |  |
| Memories are embedded on write and searched by relevance |  |
| Events live in the encrypted DB with varied signal types |  |
| Native tool calling with a capped loop and activity log |  |
| Email, calendar, reminder and weather tools behind confirmation levels |  |
| Two-way encrypted sync with a salted KDF and one real provider |  |
| Android overlay with a Play declaration ready |  |
| Windows click-through, tray, hotkey, position memory |  |
| Windows database support verified |  |
| Live voice with barge-in and fallback |  |
| Tests in CI, accurate docs |  |
