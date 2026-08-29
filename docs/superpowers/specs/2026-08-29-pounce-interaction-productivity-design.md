# Pounce Interaction and Productivity Features

## Goal

Extend Pounce into an always-available, naturally moving companion with richer pointer reactions, a safe Desktop cleanup assistant, and a local screen-time companion while retaining the existing SwiftUI/AppKit architecture and macOS 14+ support.

## Design

The domain layer gains explicit pointer interactions, autonomous-motion state, and local screen-time records. Time, randomness, file-system access, workspace state, and notification scheduling are injected so `PounceChecks` remains deterministic. Existing `PetStateStore` decoding stays backward compatible by supplying defaults for new fields.

`PounceWindowController` remains the single owner of the non-activating panel. Its hosting view recognizes click, double-click, scroll, secondary click, and drag gestures; drag uses a movement threshold and persists clamped screen-relative placement. The panel joins all Spaces but remains hidden when `WorkspaceObserver` classifies another app as fullscreen. A motion coordinator schedules bounded moves only while the panel is displayable and the pet is not paused.

Desktop cleanup is a preview-first service over the Desktop directory. It returns metadata-only candidates, excludes unsafe entries, and moves only explicitly selected files to the user Trash through an injected operation. No permanent deletion or network access is allowed. Screen-time tracks only Pounce session intervals locally, exposes focus/break reminders, and makes no claim to read Apple’s private system Screen Time database.

## Safety and compatibility

- macOS 14+; no private APIs or external dependencies.
- Existing state keys and controls continue to decode and work.
- Cleanup never permanently deletes and never leaves the Desktop without confirmation.
- Fullscreen uncertainty hides Pounce; reduced motion disables animated roaming.
- Existing menu-bar controls, hotkeys, sound, toys, and settings remain functional.
