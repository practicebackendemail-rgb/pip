# Pip Assistant - Strategic Roadmap & Backlog (TODO)

> *"An assistant confined to an application container is not an assistant; it is merely an interactive document."*  
> — *Dr. Sheldon Cooper, B.S., M.S., Ph.D.*

---

## 1. Zero-Friction Ambient Access (Beyond the Main App Window)
Users should not need to navigate into a foreground Flutter application to commune with Pip. Pip must exist ambrosially where the user actually operates.

- [ ] **Dynamic Android & Desktop Floating Overlay / Bubbles**
  - Transform Pip's floating overlay from a static avatar into an interactive, multi-state dynamic HUD.
  - Quick tap / hover expands into minimal voice wave + push-to-talk capsule.
  - Dynamic micro-gestures: drag, dock to screen edges, swipe-to-dismiss, and long-press for rapid action dials.
- [ ] **Interactive Home Screen Widgets (Android / iOS)**
  - Dynamic widget updates providing glanceable status (current Pip mood, proactive alert badges, pending reminders).
  - One-tap interactive microphone trigger invoking background voice loop or launching mini overlay directly without opening the full UI.
- [ ] **Desktop Ambient Mini-Bar / System Tray Presence**
  - Persistent floating desktop companion or system tray quick-launcher.
  - Global hotkey listener (e.g. `Ctrl+Space` or `Alt+P`) to summon Pip anywhere across the OS.

---

## 2. Notification Intelligence & Executive Briefing System
To act as a genuine executive personal assistant, Pip must ingest, triage, and filter the chaotic entropy of system notifications.

- [ ] **Notification Listener Service & Ingestion Engine**
  - Implement Android `NotificationListenerService` integration (with strict opt-in user permissions).
  - Intercept incoming alerts, extract application package, title, body, and priority metadata.
- [ ] **Contextual Notification Modes**
  - **Focus / Deep Work Mode**: Suppress all trivial notifications; admit only VIP contacts and critical alerts.
  - **Executive / Briefing Mode**: Aggregate and periodically deliver synthesized spoken/text summaries (e.g. *"You have 4 emails, but only Dr. Gablehauser's requires your immediate attention"*).
  - **Casual / Ambient Mode**: Normal proactive companion responses.
  - **DND / Silent Mode**: Complete sensory quiet.
- [ ] **Smart LLM-Powered Notification Prioritization & Summarizer**
  - Categorize alerts by urgency (Urgent & Important, Actionable, Informational, Noise/Spam).
  - On-demand or scheduled audio briefing ("Pip, what did I miss?").

---

## 3. Child Companion & Behavioral Insight Mode (Future Scope)
A specialized, safe, and timed interactive persona designed for child engagement and parental feedback.

- [ ] **Interactive Play & Learning Persona**
  - Child-friendly conversational tone, educational games, interactive storytelling, and vocabulary building.
  - Safety guardrails: strict content filtering, zero external links, and privacy-preserving local storage.
- [ ] **Child Behavioral Pattern Analysis & Parental Debrief**
  - Memory & sentiment logging: track curiosity trends, questions asked, emotional valence, and attention span.
  - Generate structured parental reports (e.g., *"Tommy showed strong interest in astronomy and dinosaurs today, but exhibited signs of frustration with math puzzles"*).
- [ ] **Automatic Screen-Time Cutoff & Graceful Sleep Cycle**
  - Configurable hard or soft session timer (e.g., 20 minutes).
  - Phased graceful shutdown sequence:
    1. Warning stage (*"Pip is getting sleepy in 3 minutes..."*).
    2. Gradual brightness / volume reduction.
    3. Sleep animation (*Pip curls up and goes to sleep*).
    4. Screen blackout / overlay termination to prevent tantrums and ensure healthy boundaries.

---

## 4. The Schedule & Habit Guardian (Predictive Chronobiology)
Proactive routine optimization and spatio-temporal buffer calculations to prevent schedule entropy.

- [ ] **Circadian & Routine Calibration**
  - Continuous behavioral pattern tracking (sleep/wake timing, screen activity versus idle duration).
  - Polite proactive interventions when routines deviate (e.g. night-time blue-light suppression, bedtime prompts).
- [ ] **Dynamic Spatio-Temporal Travel Buffers**
  - Cross-reference upcoming calendar engagements with real-time transit/traffic APIs and weather conditions.
  - Proactive departures alerts ("Depart in 8 minutes or transit delay probability exceeds 85%").

---

## 5. Autonomous Action Delegation (Tools & Function Calling)
Elevating Pip from an informational advisor to an agentic executor capable of cross-app fulfillment.

- [ ] **Conflict Resolution & Meeting Deconfliction**
  - Detect calendar scheduling overlaps.
  - Automatically formulate polite rescheduling correspondence and offer alternative mutual openings.
- [ ] **System Intent & Deep-Link Dispatcher**
  - Execute quick actions via Android Intents / Desktop URLs (e.g. pre-filling messages, quick navigation route launching).
  - Geofence-triggered actions (e.g. smart thermostat adjustments, home arrival triggers).

---

## 6. Episodic Memory with Graph-Based Association
Long-term semantic recall that persists beyond transient LLM context windows.

- [ ] **Entity & Relationship Knowledge Graph**
  - Map people, places, preferences, and dietary/health constraints into a structured local graph.
  - Associate contextual facts (e.g. "Leonard is lactose intolerant", "Passport is stored in the lower desk drawer").
- [ ] **Temporal Query Resolver**
  - Resolve queries bounded by subjective time ("Where did I say I kept my keys last Tuesday?").

---

## 7. Physiological & Emotional Biometrics (Equilibrium Engine)
Passive biometric monitoring to regulate sensory stimulation and prevent cognitive burnout.

- [ ] **Strain & Burnout Triage**
  - Deduce cognitive stress indicators via typing cadence, notification avalanche frequency, and vocal acoustic tension.
  - Automatically activate "Low-Stimulation Mode" (defer non-critical interruptions, soften Pip voice modulation).
- [ ] **Ergonomic & Hydration Nudges**
  - Sensor-driven micro-breaks when prolonged device immobility or slouching posture is inferred.

---

## 8. Ambient Financial, Privacy & Emergency Watchdog
Protecting personal boundaries, economic resources, and physical safety.

- [ ] **Subscription & Micro-Transaction Leakage Sentinel**
  - Parse payment notification metadata to catch silent recurring subscription price increases or forgotten free-trial expiration dates.
- [ ] **Duress, Fall & Emergency Protocol**
  - High-impact accelerometer spike or acoustic distress trigger to immediately initiate emergency contact routing.
- [ ] **Local-First Privacy Vault**
  - Ensure sensitive personal entities, financial totals, and private journal entries remain stored and queried strictly via on-device models without cloud leakage.

