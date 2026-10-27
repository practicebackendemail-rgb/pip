# Architecture Overview

This project is structured adhering to Clean Architecture and SOLID principles.

## Structure

- `lib/core/` — Central shared utilities, themes, tokens, and services.
  - `theme/` — Apple dark theme, Glassmorphism styles, and `AppMotionTokens`.
  - `services/` — State and business providers (`GeminiAssistantService`, `TaskProvider`, `EmailService`, `VoiceService`, `PipSfxService`).
- `lib/models/` — Domain and data entity representations (`TaskItem`, `AssistantPersona`, `TaskPriority`).
- `lib/screens/` — Top-level screen views (kept strictly < 300 LOC).
- `lib/widgets/` — Isolated, modular UI presentation components (< 300 LOC).
  - `companion/` — Pip stage subcomponents (cards, docks, modals, comic speech bubbles).

## Motion Principles

All animations comply with Kowalski Restraint and Gate principles:
1. GPU-only: only `scale`, `translation`, and `alpha` are animated.
2. Max duration for micro-interactions: 300ms.
3. System `Reduce Motion` fallback is enforced via `AppMotionTokens.shouldReduceMotion(context)`.
