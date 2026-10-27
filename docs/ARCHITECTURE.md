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
│   └── companion/            # Pip desk companion feature
│       ├── domain/           # PipCharacterBible, PipStructuredReply
│       └── presentation/     # PipStageCubit, PipStageState, Coordinators, Widgets
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
The following three pre-existing legacy UI screens/services are scheduled for decomposition in a future milestone:
1. `lib/screens/dashboard_screen.dart` (548 LOC) — Scheduled for extraction into sub-widgets.
2. `lib/screens/onboarding_setup_screen.dart` (496 LOC) — Scheduled for wizard step decomposition.
3. `lib/core/services/voice_service.dart` (304 LOC) — Legacy voice engine scheduled for consolidation into `PipAudioCoordinator`.
