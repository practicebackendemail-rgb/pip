# Dependencies Specification

Comprehensive registry of all third-party dependencies, versions, and architectural responsibilities.

---

## 1. State Management & Architecture
- `flutter_bloc: ^9.1.1` — Predictable state management via Cubits and BLoCs.
- `equatable: ^3.0.0` — Value-based equality checking for models, events, and states.
- `get_it: ^9.3.0` & `injectable: ^3.0.0` — Compile-time safe service locator and dependency injection.
- `provider: ^6.1.5+1` — Reactive state provision for lightweight UI trees.

## 2. Storage & Cryptography
- `sqflite_sqlcipher: ^3.4.1` — 256-bit AES encrypted SQLite database storage.
- `flutter_secure_storage: ^11.2.0` — Hardware-backed Keychain / KeyStore key-value security.
- `cryptography: ^2.9.0` — PBKDF2 key derivation and AES-GCM-256 snapshot encryption.
- `shared_preferences: ^2.5.6` — Lightweight non-sensitive configuration storage.

## 3. Network & AI Providers
- `http: ^1.6.0` — High-efficiency REST client communicating via secure headers.
- `google_generative_ai: ^0.4.7` — Official Google Gemini SDK for chat completions and function calling.

## 4. Hardware, System Tools & Integrations
- `enough_mail: ^2.1.7` — Native IMAP and real SMTP email transmission client.
- `device_calendar_plus: ^0.8.1` — Platform calendar integration on Android/iOS.
- `flutter_local_notifications: ^22.3.3` & `timezone: ^0.11.2` & `flutter_timezone: ^5.1.1` — System zoned push notifications and reminders.
- `share_plus: ^13.3.1` — Cross-platform system share sheet.
- `file_picker: ^13.3.0` — Native file picker dialogs for encrypted snapshot imports.

## 5. Audio & Desktop Platform Presence
- `audioplayers: ^6.7.1` — Ben Burtt robotic audio cues and tactile SFX.
- `speech_to_text: ^7.4.0` & `flutter_tts: ^4.2.5` — Hardware microphone STT and speech synthesis fallback.
- `window_manager: ^0.5.2` & `screen_retriever: ^0.2.2` — Windows frameless, transparent pet mode and multi-monitor bounds.
- `tray_manager: ^0.5.3` & `hotkey_manager: ^0.2.3` — System tray menu and global hotkeys (`Ctrl+Shift+P`).
- `launch_at_startup: ^0.0.1` — Native OS startup launcher registration.
- `flutter_overlay_window: ^1.0.2` — Android system alert window floating desk pet.
- `home_widget: ^0.10.0` — Android/iOS desktop widget synchronization.

## 6. UI & Micro-interactions
- `flutter_animate: ^4.5.2` — Declarative motion matching Kowalski restraint tokens.
- `flutter_markdown: ^0.7.7+1` — Structured typography and code block rendering.
