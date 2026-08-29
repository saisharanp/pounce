# Pounce Interaction and Productivity Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add always-enabled drag, all-Space visibility, richer interactions, autonomous motion, safe Desktop cleanup, and local screen-time tools to Pounce.

**Architecture:** Keep domain decisions in `PounceCore` and AppKit concerns in the window/controller layer. Inject clocks, randomness, filesystem, workspace, and notifications so each feature has dependency-free checks.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-08-29-pounce-interaction-productivity-design.md`

## Global Constraints

- No private APIs or external dependencies.
- Cleanup is preview-first, confirmation-gated, Trash-only, and Desktop-scoped.
- Screen-time is local Pounce session tracking, not system Screen Time database access.
- Fullscreen uncertainty hides Pounce; reduced motion disables roaming animation.
- Preserve backward-compatible `PetState` decoding and existing controls.

### Task 1: Extend interaction and persisted state

**Files:**
- Modify: `Sources/PounceCore/Domain/CatInteraction.swift`
- Modify: `Sources/PounceCore/Domain/PetState.swift`
- Modify: `Sources/PounceCore/Presentation/CatViewModel.swift`
- Test: `Sources/PounceChecks/main.swift`

- [ ] Add `.doubleClick`, `.scrollUp`, `.scrollDown`, and `.secondaryClick` interactions with reactions and sound mappings.
- [ ] Add persisted settings for roaming and screen-time preferences plus Codable defaults.
- [ ] Add interaction-count and debounce helpers to the view model without changing existing click semantics.
- [ ] Add checks for every new resolver branch and backward decoding.
- [ ] Run the focused checks and commit.

### Task 2: Implement drag and pointer event routing

**Files:**
- Modify: `Sources/PounceCore/Desktop/PounceWindowController.swift`
- Modify: `Sources/PounceCore/Presentation/CatView.swift`
- Test: `Sources/PounceChecks/main.swift`

- [ ] Add a hosting view event state machine with a 4-point drag threshold, click/double-click timing, scroll direction, and secondary-click routing.
- [ ] Make drag enabled independent of Click Through; preserve Click Through as an explicit whole-window input policy.
- [ ] Persist clamped origin during and after drag, including display transitions.
- [ ] Add deterministic gesture interpretation checks.
- [ ] Run build and focused checks, then commit.

### Task 3: Join Spaces and add bounded autonomous motion

**Files:**
- Create: `Sources/PounceCore/Desktop/PounceMotionCoordinator.swift`
- Modify: `Sources/PounceCore/Desktop/PounceWindowController.swift`
- Modify: `Sources/PounceCore/Lifecycle/AppCoordinator.swift`
- Test: `Sources/PounceChecks/main.swift`

- [ ] Add a timer-driven, injectable motion coordinator that selects bounded destinations within the active visible frame.
- [ ] Pause and cancel motion whenever hidden, paused, fullscreen, or reduced motion is enabled.
- [ ] Refresh bounds on display and workspace changes; retain `.canJoinAllSpaces` and nonactivating behavior.
- [ ] Add checks for bounds, pause conditions, and deterministic destinations.
- [ ] Run build and focused checks, then commit.

### Task 4: Add safe Desktop cleanup service

**Files:**
- Create: `Sources/PounceCore/Desktop/DesktopCleanupService.swift`
- Modify: `Sources/PounceCore/Presentation/MenuBarController.swift`
- Create: `Sources/PounceCore/Presentation/DesktopCleanupView.swift`
- Test: `Sources/PounceChecks/main.swift`

- [ ] Define candidate metadata, exclusion rules, preview generation, and injected Trash operation.
- [ ] Restrict enumeration to the user Desktop and exclude hidden files, symlinks, bundles, volumes, and unsafe paths.
- [ ] Add a confirmation UI with selectable candidates, dry-run preview, cancellation, per-file errors, and Trash-only execution.
- [ ] Add filesystem abstraction checks for filtering and failure handling.
- [ ] Run build and focused checks, then commit.

### Task 5: Add local screen-time companion

**Files:**
- Create: `Sources/PounceCore/Domain/ScreenTime.swift`
- Create: `Sources/PounceCore/Presentation/ScreenTimeView.swift`
- Modify: `Sources/PounceCore/Persistence/PetStateStore.swift`
- Modify: `Sources/PounceCore/Presentation/MenuBarController.swift`
- Test: `Sources/PounceChecks/main.swift`

- [ ] Implement injectable session clock, focus/break intervals, local summaries, and history clearing.
- [ ] Add notification scheduling abstraction with no keystroke or screen-content capture.
- [ ] Persist history safely and expose explicit privacy copy and settings.
- [ ] Add checks for session rollover, pause/resume, summaries, reminders, and clearing.
- [ ] Run build and focused checks, then commit.

### Task 6: Integrate UI, documentation, and verification

**Files:**
- Modify: `Sources/Pounce/PounceApp.swift`
- Modify: `Sources/PounceCore/Presentation/SettingsView.swift`
- Modify: `Sources/PounceCore/Presentation/MenuBarController.swift`
- Modify: `README.md`

- [ ] Wire cleanup and screen-time views into menu-bar controls and Settings.
- [ ] Document controls, permissions, local-only privacy behavior, and system Screen Time limitation.
- [ ] Run `swift build`, `swift run PounceChecks`, `./Scripts/build-app.sh`, inspect the final diff, and verify `Pounce.app` metadata.
- [ ] Commit and report any environment-only test limitation separately.
