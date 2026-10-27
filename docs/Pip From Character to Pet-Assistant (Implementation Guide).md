# Pip: From Character to Pet-Assistant

*Implementation guide for a local-first, bring-your-own-model Flutter assistant*

## 1. Purpose and scope

Pip is a Flutter app with an animated character, speech-to-text (STT) input, a Gemini model behind it, structured custom responses, task management, progress tracking, and task and email briefings. It works, but it feels like a feature set rather than a companion.

This guide describes how to turn Pip into a pet-assistant: a character with emotion, humor and charm that learns its owner over time, acts on their behalf across devices, and does all of it without a server owned by the developer.

**The three gaps this guide closes**

1. **Personality:** Pip lacks emotion, coolness, humor and charm.
2. **Learning:** Pip does not understand the owner's patterns, likes and dislikes, and does not adapt like a pet would.
3. **Breadth:** Pip is limited to briefings, tasks and progress tracking, and does not yet do what its owner intends in general.

**Design constraints agreed so far**

- No developer-owned server and no user data on the developer's infrastructure.
- Each user stores their own data in their own cloud account (Drive, OneDrive, iCloud, or similar).
- Each user supplies their own API key, and can use any model provider, not only Gemini.
- Targets: Android, iOS and Windows, using Flutter.

**How to use this document:** work through the phases in order. Each phase lists goals, tasks, deliverables and acceptance criteria. Package names and provider API details change, so check current documentation before relying on any specific one.

## 2. Guiding principles

1. **Local-first.** The device is the source of truth. Cloud storage is a user-owned backup and sync channel.
2. **Separate the layers.** Emotion state, memory, tools and the language model are different concerns. Do not pack them into one prompt.
3. **Model-agnostic.** Pip depends on capabilities (tool calling, structured output, embeddings), not on a vendor.
4. **Transparent learning.** The user can see, edit and delete everything Pip has learned.
5. **Earned autonomy.** Reading is automatic. Sending, deleting and spending need confirmation until the user grants more trust.
6. **Pet before tool.** Pip should start interactions, react to neglect, celebrate wins, and feel different on a bad day than a good one.

## 3. Target architecture

```
Presentation   Character animation, chat/voice UI, settings, 'What Pip knows' screen
    |
Application    Cubits/use-cases: Converse, Reflect, Brief, RunTool, Sync
    |
Domain         Interfaces: LlmProvider, MemoryRepository, SyncProvider, Tool,
               PlatformServices; entities: PipState, Memory, ProfileFact, Rule, Event
    |
Data/Platform  Drift DB, provider adapters, cloud adapters, OS integrations
```

**Core runtime loop for every user turn**

1. Capture input (typed or STT text).
2. Load Pip's emotion state, the user profile, active rules, and the top relevant memories.
3. Build the prompt: persona + state + profile + rules + memories + tool list + user message.
4. Call the chosen model. If it requests tools, run them (with confirmation rules) and loop.
5. Parse the structured reply: `text`, `emotion`, `intensity`, `animation`, `voice_style`.
6. Animate, speak, log events, and update Pip's state.

## 4. Phase 0: Foundations

**Goal:** create the seams that later phases plug into, without changing behavior.

**Tasks**

- Define domain interfaces: `LlmProvider`, `MemoryRepository`, `SyncProvider`, `Tool`, and small platform interfaces (`NotifyService`, `CalendarService`, `EmailService`).
- Wrap the existing Gemini call behind `LlmProvider` so nothing else calls Gemini directly.
- Add an `EventLog` service. Every meaningful action writes an event (task completed, briefing opened, reply thumbs-up).
- Add a feature flag system so new behavior can be switched on gradually.

**Deliverables:** interfaces compiled, Gemini adapter in place, events being written to a simple store.

**Acceptance:** the app behaves exactly as before, but every model call goes through `LlmProvider` and every user action emits an event.

## 5. Phase 1: Local storage

**Goal:** a durable, queryable, encrypted store for everything Pip learns.

**Technology**

- **Drift (SQLite)** as the main database. Use SQLCipher for encryption at rest, through sqlcipher\_flutter\_libs. Do not add sqlite3\_flutter\_libs or drift\_flutter next to it: their bundled SQLite clashes with SQLCipher and has caused startup crashes on desktop. Call the sqlite3 open override on every isolate that touches the database, check PRAGMA cipher\_version right after opening (the key pragma fails silently on plain SQLite, leaving the file unencrypted), and create the encrypted database as a new file, because an existing plain file cannot be encrypted in place.
- **flutter\_secure\_storage** for API keys, OAuth tokens, and the encryption key.
- **Hive or shared\_preferences** only for small fast values such as UI settings.
- Embeddings stored as BLOB columns next to each memory.

**Initial tables**

| Table | Key columns | Purpose |
| --- | --- | --- |
| `events` | id, type, payload\_json, ts, device\_id | Append-only raw log |
| `memories` | id, text, embedding, embedding\_model, importance, created\_at, last\_used\_at | Episodic memory |
| `profile_facts` | key, value, confidence, evidence\_count, updated\_at | Learned traits |
| `rules` | id, scope, instruction, source, active | Explicit and learned rules |
| `pip_state` | mood, energy, bond, boredom, last\_interaction | Emotional state |
| `tasks` | existing task tables | Keep your current ones |

**Tasks**

- Write Drift tables and DAOs and a migration strategy from day one.
- Implement `MemoryRepository` with `logEvent`, `searchMemories`, `getProfile`, `upsertFact`, `addRule`, `applyReflection`.
- Implement encrypted export and import of the whole store to a single file (a backup the user can keep anywhere).

**Acceptance:** data survives app restarts and upgrades, the database file is unreadable without the key, and export then import on a fresh install restores everything.

## 6. Phase 2: Multi-model provider layer

**Goal:** let the user choose any model with their own key, and keep Pip's quality stable across them.

### 6.1 The interface

```dart
abstract class LlmProvider {
  String get id;
  LlmCapabilities get capabilities; // tools, jsonSchema, streaming, vision, maxContext
  Future<LlmResponse> chat(List<Message> messages, {List<ToolSpec>? tools, JsonSchema? schema});
  Stream<LlmChunk> chatStream(List<Message> messages, {List<ToolSpec>? tools});
  Future<List<List<double>>> embed(List<String> texts); // optional
}
```

### 6.2 Adapters (three cover almost everything)

1. **OpenAI-compatible** (`/v1/chat/completions`): OpenAI, OpenRouter, Groq, Together, Mistral, DeepSeek, Ollama, LM Studio. The user supplies base URL, key and model name.
2. **Gemini native.**
3. **Anthropic native** (Messages API).

Implement them with plain `dio` or `http` so you control request formats. Existing Dart clients cover all three (openai\_dart, anthropic\_sdk\_dart, googleai\_dart, plus ollama\_dart for local models, and the LangChain.dart family on top), but they are pre-1.0, so use them only behind your own LlmProvider interface.

### 6.3 Handling differences

- **Tool calling:** convert your internal `ToolSpec` to each provider format and convert tool calls back.
- **Structured output:** if the model supports schemas, use them. Otherwise ask for JSON, validate, and retry once with the validation error appended. Pip's emotion and animation fields depend on this.
- **Capability fallback:** if a model has no tool calling, run a reduced mode (fixed intents) instead of failing.
- **Prompt tuning:** keep a small per-provider prompt adjustment file. Models read the same persona differently.

### 6.4 Embeddings are separate

Chat models often cannot embed. Let the user pick an embedding provider independently (Gemini, OpenAI, or a local model through Ollama). Store the embedding model name with every vector. When the user changes embedding model, re-embed old memories in the background, because vectors from different models are not comparable.

### 6.5 Settings screen

- One entry per provider with key (secure storage), base URL and model.
- **Roles:** main chat model, fast model for quick replies, strong model for nightly reflection, optional fallback.
- A test-connection button with clear errors (bad key, no quota, model not found).
- Daily token and approximate cost display.

**Acceptance:** the same conversation script runs on Gemini, an OpenAI-compatible endpoint, and Anthropic, with valid structured replies on each. Switching provider needs no code change.

## 7. Phase 3: Personality and emotion

**Goal:** make Pip charming, funny and emotionally consistent.

### 7.1 Emotion engine (in app code, not in the prompt)

Hold a small state and update it from events:

- **Mood** (valence), **energy**, **bond** (grows slowly with positive interaction), **boredom**, **curiosity**.
- Events push values (task completed raises mood, ignored for hours raises boredom, late-night use lowers energy, overdue pile lowers mood).
- Values drift back toward a baseline over time so Pip is never stuck in one mood.
- Pass the current state into every model call as a short block.

### 7.2 Structured reply contract

```json
{
  "text": "string",
  "emotion": "happy|excited|sleepy|unsure|proud|sulky|mischievous|calm",
  "intensity": 0.0,
  "animation": "wave|bounce|tilt|droop|none",
  "voice_style": "normal|whisper|cheer|deadpan",
  "memory_candidates": ["optional short notes worth remembering"]
}
```

The emotion field drives Pip's eyes, arms, LED and voice. The same sentence can now come out sleepy, proud or sarcastic.

### 7.3 Character bible

Write a one-page persona prompt covering:

- Voice and tone (for example, dry robot humor, warm, never mean).
- Quirks and running jokes, favorite and least favorite things.
- Hard rules: at most one joke per reply, shorter replies when the user is busy, never joke about serious topics, never guilt-trip about work.
- How mood changes behavior (low energy means shorter and slower, high bond means more teasing and callbacks).

### 7.4 Humor dial

Track how the user reacts to jokes (laughs, thumbs, replies that skip the joke). Raise or lower a humor level setting automatically and let the user override it.

### 7.5 Proactive behavior

A pet starts interactions. Add scheduled and event-based moments: greeting on first open of the day, celebrating streaks, gently sulking after long neglect, commenting on a heavy calendar, a small reaction to weather or time of day. Cap frequency so Pip never becomes annoying, and respect quiet hours.

**Acceptance:** over a week of testing, replies differ with mood state, jokes appear sparingly, the user can set humor and proactivity levels, and no more than the configured number of proactive messages appear per day.

## 8. Phase 4: Learning the user

**Goal:** Pip understands routines, preferences and dislikes, and adapts.

### 8.1 Signals to log (events)

Tasks completed, snoozed, rescheduled or ignored; briefings opened or skipped; time of day of each interaction; replies the user interrupts or cuts short; thumbs up or down; emails the user always ignores or always answers first; explicit statements ('I hate long briefings').

### 8.2 Nightly reflection job

Once a day (or when the app opens after a gap), run a reflection with the strong model:

1. Input: the day's events, current profile facts, current rules, and recent memories.
2. Output (JSON): new or updated `profile_facts` with confidence, new `memories`, suggested `rules`, and a short summary.
3. Apply the output through `applyReflection`, compress old events into summaries, and delete the raw originals past a retention window.

Facts need repeated evidence before reaching high confidence. Confidence decays if not reinforced, so outdated habits fade.

### 8.3 Episodic memory and retrieval

- Store notable moments as `memories` with an embedding and an importance score.
- Before each reply, embed the user message, fetch the top few similar memories (brute-force cosine similarity in an isolate is fine for a few thousand items; if you outgrow that, ObjectBox 4.0 offers an on-device vector index for Flutter, at the cost of a second database or moving everything to ObjectBox), and add them to the prompt.
- Prune low-importance, rarely used memories.
- Callbacks such as 'this is the third Monday you have pushed this task' are what make the character feel like it knows the user.

### 8.4 Explicit feedback and rules

Turn direct instructions into scoped rules ('never remind me about X', 'keep briefings under 30 seconds'). Show which rule changed behavior when it matters.

### 8.5 Transparency screen

A 'What Pip knows about me' screen listing profile facts, memories and rules with confidence, source and delete or edit controls. Add a 'forget everything' action. This builds trust and corrects wrong guesses.

**Acceptance:** after two weeks of use, briefings adapt in length and timing, Pip references specific past events correctly, the user can inspect and delete any learned item, and deleted items never reappear.

## 9. Phase 5: Tools and broader capabilities

**Goal:** move from fixed features to an assistant that can act on intent.

### 9.1 Tool registry with function calling

Replace per-feature response formats with a registry of tools the model can call. Each tool declares name, description, JSON parameter schema, whether it is read-only or write, and a confirmation policy.

**Suggested starter tools**

| Area | Tools |
| --- | --- |
| Tasks | create, update, complete, list, reschedule |
| Calendar | list events, find free time, create event |
| Email | search, summarize thread, draft reply, send (confirm) |
| Time | set reminder, timer, focus session |
| Notes | save note, search notes |
| Info | web search, weather |
| Pip itself | update\_profile\_fact, add\_rule, set\_mood\_note |

Tool calling formats differ by provider, so the adapters from Phase 2 translate between your `ToolSpec` and each provider. Email is the riskiest tool to ship publicly: Gmail read access is a restricted scope, so plan it as personal or small-group use first (see section 13).

### 9.2 Autonomy ladder

- **Level 0:** read-only tools run automatically.
- **Level 1:** write tools need a one-tap confirmation showing exactly what will happen.
- **Level 2:** for specific, low-risk actions the user has approved before, Pip acts and reports afterward.
- Sending email, deleting data and anything involving money always stay at Level 1 unless the user explicitly changes it.
- Keep an **activity log** screen with every action Pip took and a way to undo where possible.

### 9.3 Background triggers

Use scheduled and event triggers: meeting starting soon, important email arrived, a habit time approaching, a task overdue. Each trigger runs a small check, then lets Pip decide whether to speak up, using the emotion and quiet-hour rules.

### 9.4 Teachable routines

Let the user define routines in natural language ('when I say shipping day, check open tickets, summarize the unread emails from the team, and block two hours'). Store them as structured routines the planner can run.

**Acceptance:** the user can give an open-ended request, Pip chooses and chains tools, asks for confirmation on writes, and every action appears in the activity log.

## 10. Phase 6: Platform integration

**Goal:** use each OS properly behind the shared interfaces from Phase 0. Pip's tools only see the interfaces, so the same brain runs everywhere.

### 10.1 Cross-platform capabilities

| Capability | Approach |
| --- | --- |
| Calendar and email | Prefer cloud APIs (Gmail, Google Calendar, Microsoft Graph) with OAuth PKCE, which behave the same everywhere (Gmail read access is restricted, so personal or small-group use first; see section 13) |
| Notifications | `flutter_local_notifications` (and a Windows-compatible option) |
| Voice | `speech_to_text` now, Live voice later (Phase 8) |
| Secrets | `flutter_secure_storage` (Keystore, Keychain, Windows credential store) |

### 10.2 Android

- WorkManager for the nightly reflection and periodic checks; a foreground service only if always-on listening is truly needed.
- Home screen widget (for example with `home_widget`) showing Pip's face and the next task.
- Quick-settings tile and app shortcuts.
- Notification listener (explicit permission) so Pip can summarize messages from other apps.
- Optional floating overlay Pip, which requires a special permission.
- Accessibility-service control of other apps is powerful but banned on Google Play when it lets an app autonomously plan and execute actions (policy effective January 2026), and a general voice assistant does not qualify as an accessibility tool, so keep it out of Play builds and treat it as sideload-only.

### 10.3 iOS

- No continuous background work. Use BGTaskScheduler (timing not guaranteed), local notifications, and run reflection when the app opens, treating background runs as a bonus: iOS does not guarantee when processing tasks run, and they often run only overnight.
- Siri and Shortcuts via App Intents is the best system-level entry point. Plugins such as flutter\_app\_intents (iOS 16 and later) help, but the intents themselves are written in Swift in the iOS target.
- WidgetKit and Live Activities need a small Swift extension next to Flutter.
- No overlay and no reading other apps' notifications, so design Pip as an in-app and widget character.

### 10.4 Windows

- Frameless, transparent, always-on-top Pip window (for example with `window_manager`), plus a system tray icon and a global hotkey to wake Pip. Expect some native C++ work for a truly transparent floating pet window: existing Flutter desktop pets use layered windows on Windows.
- Launch at login.
- Win32 or WinRT access through FFI for active window title and idle time, so Pip can notice long stretches in one app and suggest breaks.
- Microsoft Graph for Outlook and Teams.

### 10.5 Permission design

Ask for each permission at the moment it is needed, explained in Pip's own voice. Never request everything at install.

**Acceptance:** every capability works on the platforms where it is possible, degrades gracefully where it is not, and no permission is requested before it is needed.

## 11. Phase 7: User-owned cloud sync

**Goal:** backup and multi-device sync with no developer server.

### 11.1 Storage options

| Option | Platforms | Notes |
| --- | --- | --- |
| Google Drive appDataFolder | All | Hidden app-only folder, non-sensitive scope (no security assessment), best default |
| OneDrive app folder (Graph) | All | Natural fit for Windows users |
| iCloud (CloudKit or iCloud Drive) | Apple only | Great for Apple users |
| Dropbox app folder, WebDAV, Nextcloud | All | Optional extras |
| Manual encrypted export | All | Always available fallback |

Implement a `SyncProvider` interface (`push`, `pull`, `list`) and one adapter per service.

### 11.2 Sync design without a server

- Drift on each device remains the source of truth.
- Each device writes only its own files: append-only event logs (`events-<deviceId>-<date>.enc`) and periodic snapshots of profile facts, rules and memories. Devices never edit the same file, so there are no write conflicts.
- On launch or resume, a device downloads new files from other devices and merges: events are unioned, profile facts use last-writer-wins by timestamp, memories merge by id.
- Reflection runs on one designated device, or any device records its result as an event others merge.

### 11.3 Encryption

- Encrypt on the device with AES-GCM before upload (for example with the `cryptography` package).
- Derive the key from a user passphrase with Argon2 and keep the derived key in secure storage.
- Warn clearly that a forgotten passphrase cannot be recovered, and offer a printable recovery code at setup.
- API keys stay in secure storage and do not sync by default. If synced, include them only inside the encrypted snapshot as an opt-in.

### 11.4 Limits to accept

No silent push to wake the app, no central account recovery, and sync happens when a device is open or woken rather than instantly.

**Acceptance:** a second device restores the full profile and memory from the user's own cloud, nothing readable is stored in the cloud, and merging two devices never loses data.

## 12. Phase 8: Better voice

**Goal:** a more natural, interruptible voice experience.

- Today: STT, then text to the model, then TTS. This works but adds latency and loses tone.
- Option: use a provider's live or realtime audio API where available (for example Gemini Live). It offers lower latency, interruption, and expressive voice. For Gemini there are two routes: the firebase\_ai package, which works through a Firebase project and proxy and therefore does not fit a user-supplied key with no developer backend, or the experimental gemini\_live package, which has no Firebase dependency but may change. Without session compression, Gemini audio sessions are capped at roughly 15 minutes, so build in reconnection.
- Keep the text pipeline as the universal fallback for providers without live audio.
- Map `voice_style` from the reply contract to speech rate, pitch and style.
- Add barge-in (stop speaking when the user talks) and a push-to-talk mode for noisy places.

**Acceptance:** the user can interrupt Pip mid-sentence, and spoken tone matches the emotion field.

## 13. Privacy, security and safety

- **What leaves the device:** prompts sent to the user's chosen model provider (including retrieved memories and profile details), encrypted sync files in the user's own cloud, and calls to Gmail, Calendar or Graph with the user's own login. State this plainly in the app.
- **Provider data policies differ.** Some tiers may use prompts for product improvement. Check each provider's current terms and tell users which tier or setting is safer. For Gemini specifically, free-tier prompts are used to improve Google products while paid-tier prompts are not, and users in the EEA, UK and Switzerland get the paid terms, so tell users to use a paid key for private content. A local model (for example through Ollama) is the most private option.
- **Email and calendar scopes:** Gmail scopes are restricted and public apps need Google's verification, plus an annual third-party security assessment (CASA, quoted at roughly $500 to $4,500). Google ties the assessment to access through a third-party server, which favors this serverless design, but at least one local-only app reported being required to complete it anyway, so confirm early. Unverified apps are limited to 100 users, so personal use or a small test group is the realistic first target.
- **Prompt injection:** emails and web pages can contain instructions. Treat tool outputs as data, never as commands, and keep confirmation on writes.
- **Secrets hygiene:** no keys in logs, analytics or crash reports.
- **Wellbeing:** Pip is a companion, not a replacement for people. Avoid guilt-tripping, dependency-building behavior, and anything that discourages the user from seeking human help.

## 14. Testing and evaluation

- **Scripted conversations:** a fixed set (greeting, busy morning, ignored for days, joke that lands, joke that flops, risky request) run against every supported provider after each prompt change.
- **Schema tests:** validate the reply contract and tool calls on every provider, including retry behavior.
- **Memory tests:** inject synthetic event histories and check that the reflection produces sensible facts and that deletion truly removes them.
- **Sync tests:** simulate two devices editing offline, then merging.
- **Safety tests:** confirmation always required for writes, prompt-injection samples in emails, quiet hours respected.
- **Human check:** a short weekly review of real replies for tone, humor and annoyance.

## 15. Roadmap summary

| Order | Phase | Main output | Depends on |
| --- | --- | --- | --- |
| 0 | Foundations | Interfaces, event log, flags | none |
| 1 | Local storage | Encrypted Drift store, export and import | 0 |
| 2 | Provider layer | Adapters, settings, roles, embeddings | 0 |
| 3 | Personality | Emotion engine, reply contract, persona, proactivity | 1, 2 |
| 4 | Learning | Reflection, memory retrieval, rules, transparency screen | 1, 2, 3 |
| 5 | Tools | Function calling, autonomy ladder, triggers, routines | 2, 4 |
| 6 | Platforms | Widgets, background jobs, desktop mode, Siri and Shortcuts | 5 |
| 7 | Cloud sync | User-owned encrypted sync | 1, 4 |
| 8 | Voice | Live voice, barge-in, expressive speech | 2, 3 |

Phases 3 and 4 give the biggest change in how Pip feels, so a sensible first milestone is Phases 0 to 4 on a single platform.

## 16. Open decisions

1. Which cloud providers to support first (Drive is the safest default).
2. Whether to ship a local embedding option on day one.
3. How much autonomy to allow by default, and which actions are never automatic.
4. Whether Pip stays a mobile-first character or also becomes an always-on desktop pet on Windows.
5. How and when to ask users to set a sync passphrase without hurting onboarding.
6. Public release plan, since restricted Gmail scopes add a verification step.
