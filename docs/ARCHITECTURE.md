# Architecture Specification

Pip is engineered with Clean Architecture, strict SOLID boundaries, and rigorous state management isolation.

---

## 1. High-Level Layers

```
lib/
├── core/
│   ├── data/                 # Database helper, migrations, SQLCipher wrappers
│   ├── domain/               # Core entities, repositories, emotion models, tool contracts
│   ├── services/             # Concrete services (LLM, Audio, Email, Calendar, Sync, Windows, Overlay)
│   ├── theme/                # Apple dark tokens, Glassmorphism, AppMotionTokens
│   └── di/                   # Dependency injection (GetIt + Injectable)
├── features/
│   ├── companion/            # Pip desk companion feature
│   │   ├── domain/           # PipCharacterBible, PipStructuredReply
│   │   └── presentation/     # PipStageCubit, PipChatEngine, PipConversationHistory, Coordinators
│   └── reminders/            # Alarms & reminders
│       ├── domain/           # ReminderRepository
│       ├── data/             # ScheduledReminderRepository (ScheduleStore + PipNotificationService)
│       └── presentation/     # RemindersCubit, ReminderEditorCubit, AlarmsRemindersScreen, tiles, editor sheet
├── models/                   # Global data models (TaskItem, EmailDigest, etc.)
├── screens/                  # Top-level screen views (< 300 LOC, with 2 legacy exemptions)
└── widgets/                  # Modular, reusable presentation widgets
```

---

## 2. Layer Separation & Invariants

1. **Domain Layer (`lib/core/domain/`, `lib/features/companion/domain/`)**:
   - Contains pure business logic, entities, and repository interfaces.
   - Value equality via `Equatable` blocks redundant UI recalculation.
   - Zero Flutter UI widgets or plugin dependencies in domain contracts.

2. **Data Layer (`lib/core/data/`, `lib/core/services/`)**:
   - Manages encrypted persistence (`sqflite_sqlcipher`), secure key storage (`flutter_secure_storage`), network requests (`http`), and platform bridges (`device_calendar_plus`, `flutter_local_notifications`).
   - Translates raw records into immutable domain models with explicit mapping.

3. **Presentation Layer (`lib/features/companion/presentation/`, `lib/screens/`, `lib/widgets/`)**:
   - BLoC/Cubit pattern: All state mutations emit immutable state objects.
   - Zero `setState` inside widgets.
   - Scoped rebuilds via `BlocBuilder` and `Selector`.

---

## 3. Motion & Animation Principles

All component transitions adhere strictly to the Kowalski Restraint and Gate direct principles:
- **GPU Acceleration**: Only `scale`, `translation`, and `alpha` properties are animated.
- **Budgeting**: Micro-interactions $\le 300$ms; page transitions $\le 500$ms.
- **Accessibility**: System `Reduce Motion` preference (`AppMotionTokens.shouldReduceMotion(context)`) immediately short-circuits animation loops.

---

## 4. File Length Compliance & Exemptions

Every new or refactored file in the codebase is strictly maintained under 300 lines of code.

### Registered Legacy Exemptions:
Two pre-existing files are over the limit and scheduled for decomposition (the old `dashboard_screen.dart` was unused and has been deleted):
1. `lib/screens/onboarding_setup_screen.dart` (496 LOC) — Scheduled for wizard step decomposition.
2. `lib/core/services/voice_service.dart` (304 LOC) — Legacy voice engine scheduled for consolidation into `PipAudioCoordinator`.

---

## 5. How-To: Alarms, reminders and the mini Pip

**Scheduling.** Everything goes through `PipNotificationService` (`lib/core/services/`), and every item is stored in `ScheduleStore`. Screens use `ReminderRepository`, which does both:

```dart
final item = ScheduledItem(
  id: newScheduleId(),            // < 10^8, so notification ids fit 32 bits
  kind: ScheduledItem.alarm,      // or ScheduledItem.reminder
  title: 'Gym',
  at: nextClockTime(6, 30),
  days: const [1, 2, 3, 4, 5],    // Monday = 1; empty = once
);
await const ScheduledReminderRepository().save(item); // schedules and stores
```

- Notification ids are `item.id * 10 + slot`: slot 0 is a one-off, 1–7 the repeat weekday, 8 a snooze.
- Alarms use the `pip_alarms` channel (alarm sound, full-screen, looping). Reminders use `pip_reminders`. Both have Snooze and Dismiss/Done actions, handled in `pipNotificationBackgroundHandler` even while Pip is closed.
- Android needs the receivers in `AndroidManifest.xml`. Without `ScheduledNotificationReceiver`, `zonedSchedule` silently never fires.
- Exact timing needs the "Alarms & reminders" special permission. Without it, Pip falls back to inexact timing and the screen shows a banner.
- `ScheduleStore.changes` fires on every change, so a screen updates when Pip's tools add items.

**The mini Pip.** `MiniPipAssistant` (`lib/widgets/companion/`) puts the same Pip (same `PipStageCubit`, tools, memory and mood) on any screen:

```dart
const MiniPipAssistant(
  hint: 'Ask Pip: "wake me at 6:30 on weekdays"',
  screenContext: 'User is on the Alarms & reminders screen',
);
```
