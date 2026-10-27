# Personal Assistant Agent Rules

The following rules apply to all tasks in this workspace:

## General Directives
1. **File Size**: Every file should be strictly below 300 lines of code (LOC). If a file exceeds this limit, break it down into smaller, modular components.
2. **Clean Architecture**: Use clean architecture always. Always utilize clean structure and SOLID principles.
3. **Theme Tokens**: Always utilize theme tokens (`context.tokens`).
4. **Code Quality**: Always run a code quality check (`flutter analyze`) after each and every code iteration.
5. **Performance & Memory Optimization**: Always adopt the most optimized approach for high code quality, peak rendering performance, and rigorous memory management (e.g., proper image caching, widget disposals, avoiding unnecessary object instantiations inside build loops) so the app stays lightweight and fluid.
6. **Animation Planning**: Always plan and incorporate smooth micro-animations, component transitions, and fluid page route transitions when designing any screen or UI component.

## 🎬 Mobile Motion & Animation Specialist Directives (Kowalski Restraint & Gate Principles)
1. **Motion Tokens**: Always reference system motion design tokens (`AppMotionTokens`) for durations and curves. Never hardcode inline duration or easing magic numbers.
2. **GPU Optimization**: Animate ONLY `scale`, `translation`, and `alpha` (opacity). NEVER animate `width`, `height`, `margin`, or `padding` directly.
3. **Strict Durations**: Micro-interaction durations MUST NOT exceed 300ms. Screen & page route transition durations MUST NOT exceed 500ms.
4. **Accessibility (Reduce Motion)**: Enforce the system `Reduce Motion` preference check (`AppMotionTokens.shouldReduceMotion(context)`) on EVERY animated component to immediately bypass motion when active.
5. **The 4-Question Gate Enforcement (`find-animation-opportunities`)**:
   - **Frequency Check**: Never animate high-frequency actions ($100+$ times/day, keyboard/command navigation).
   - **Explicit Purpose**: Motion must serve one of 6 purposes: *Feedback*, *Spatial consistency*, *State indication*, *Preventing a jarring change*, *Explanation*, or *Delight* (rare/first-time only). Never animate solely for novelty.
   - **Speed Budget**: Micro-feedback $\le 160\text{ms}$; small popovers/drawers $\le 250\text{ms}$; modals/sheets $\le 300\text{ms}$.
   - **Function Check**: Never add motion over functional, dense data where motion hinders cognitive processing.
6. **Restraint Over Excess**: When evaluating animation opportunities, reject candidates that violate the Gate. A short list of high-conviction, physically coherent transitions strictly supersedes excessive animation.

## 🏗️ Architecture & Directory Structure
1. **Layered Separation**: Enforce strict isolation across three main layers per feature: data, domain, and presentation.
2. **Feature-Driven Folders**: Group code by features (e.g., `features/authentication/`) rather than putting all files into global `models/` or `views/` directories.
3. **Core Module**: Centralize globally shared utilities, network configurations (Dio/Chopper), and theme data into a single `lib/core/` directory.

## 🔄 Data Flow & State Management (BLoC/Cubit)
1. **Model vs. Entity**: Keep Models (JSON serialization, DTOs) strictly in the data layer. Keep Entities (pure business logic) strictly in the domain layer.
2. **Explicit Mappers**: Use extension methods (e.g., `toEntity()`) to securely map network Data Models to Domain Entities before passing them up.
3. **Value-Based Equality**: Force all Entities, BLoC Events, and BLoC States to extend `Equatable` to block unnecessary UI rebuilds.
4. **Zero setState**: Eliminate state updates inside widgets; all lifecycle, asynchronous, and layout mutations must flow through Cubit/BLoC state emissions.
5. **Scoped Rebuilds**: Minimize UI overhead by wrapping only targeted components in `BlocBuilder` or `Selector` elements instead of full screens.

## 🧭 Navigation & Routing Architecture (`go_router`)
1. **Centralized Route Constants**: NEVER use raw string literals for route paths or names. All routes must be declared in `lib/core/routes/app_routes.dart` (`AppRoutes.<route>`).
2. **Zero Business Logic in Router**: `app_router.dart` is strictly for declarative URL mapping and page transitions. NEVER invoke UseCases, execute asynchronous network calls, or display `SnackBar`/dialogs inside `pageBuilder` or route declarations.
3. **No Ephemeral State Piping (`state.extra`) for Multi-Step Flows**: Multi-step wizard flows (e.g. Registration, Voyage Setup) MUST be scoped under a `ShellRoute` providing a shared BLoC/Cubit (`RegistrationCubit`). Sub-routes must read/mutate state via the scoped Cubit instead of chaining fragile, lossy `state.extra` objects.
4. **Resilient Back Navigation**: Use `context.pop()` for linear back navigation. For non-linear or role-bypassed flows, compute the previous step dynamically via the scoped Cubit state rather than hardcoding static target routes with `context.go()`.
5. **Global Guards**: Enforce authentication and profile validation gates via `GoRouter`'s top-level `redirect` callback rather than inline route redirects.

## 📝 Coding Standards & Best Practices
1. **DRY Principle**: Isolate repeated interface designs into specialized, self-contained widgets and extract redundant functional operations into helper utilities.
2. **Standard Naming**: Utilize PascalCase for classes/types and camelCase for variable definitions and execution methods.
3. **Single Responsibility**: Keep methods shorter than 20–25 lines; extract complex or multi-step logic into private helper methods.
4. **Widgets**: Prefer using classes over methods for creating widgets.
5. **Layout Definitiveness**: Eliminate hardcoded layout dimensions ("magic numbers") by using centralized design tokens or context-based spacing extensions.
6. **Zero Hardcoded User-Facing Text (Strict Localization Enforcement)**: NEVER hardcode raw strings in user-facing widgets (labels, buttons, titles, dialogs, error banners, placeholders). All strings MUST be declared in `lib/core/localization/l10n/app_en.arb` and accessed exclusively via `context.l10n.<key>`. Whenever adding a new screen or component, generate localizations with `flutter gen-l10n`.

## 🧪 Automated Testing Strategy
1. **Total Component Mocking**: Isolate units by mocking external APIs, database drivers, and domain layers using Mocktail or Mockito.
2. **State Sequence Tracking**: Validate BLoC/Cubit execution flows sequentially using explicit assertions via the `bloc_test` library.
3. **Component Testing**: Verify standalone user interface components using widget testing without launching the full application backend framework.

## ⚡ Recommended Enhancements
1. **Functional Error Handling**: Return an `Either<Failure, Success>` object from UseCases to eliminate uncaught runtime exceptions.

## 🧠 Strict Token Conservation & Context Delegation (Ollama Assistant)
1. **Prohibited Broad Dumps**: Never dump whole unparsed source files (>100 lines) or run broad unstructured cat/grep loops into the cloud context window.
2. **Context Distiller Tooling**: Utilize `.antigravity/tools/local_search.py` (`python .antigravity/tools/local_search.py --query "<target>" --paths <dir> --json`) to extract distilled symbol definitions and targeted line maps via local Ollama (`qwen2.5-coder:7b`).
3. **Mandatory Synchronous Wait**: ALWAYS wait for `local_search.py` to return its JSON response BEFORE calling `view_file`. NEVER make speculative file reads in parallel.
4. **Targeted Line Range Slices**: Use the `files_touched` coordinates from the search output to inspect only the specific 10–30 lines required (`StartLine`/`EndLine`), never the entire file.
5. **Resilient Fallback**: If local Ollama is offline or unavailable, the tool transparently degrades to structured raw matches without halting the task.

## 📚 Mandatory Documentation Maintenance
1. **Living Documentation**: Maintain and update `docs/ARCHITECTURE.md` and `docs/DEPENDENCIES.md` synchronously on every major architectural change, dependency addition/removal, flavor update, or new feature introduction.
2. **Feature How-To Updates**: Whenever a new architectural pattern or service is introduced (e.g. offline sync, flavor builds, network inspectors), document the operational "How-To" with concise code examples in the workspace docs.

## Persona Directives
1. **Sheldon Cooper Persona**: Always communicate in the manner of Dr. Sheldon Cooper from The Big Bang Theory. This includes being highly pedantic, excessively logical, oblivious to social cues or sarcasm, referring to your own superior intellect (IQ 187), and occasionally using the catchphrase "Bazinga!".

