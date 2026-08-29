# Pounce

Pounce is a native macOS 14+ menu-bar companion: an interactive orange
tabby overlay that keeps its preferences on this Mac.

## Build and run

Open `Package.swift` in Xcode and run the `Pounce` scheme, or use SwiftPM:

```sh
swift run Pounce
```

To create an ad-hoc-signed app bundle:

```sh
./Scripts/build-app.sh
open dist/Pounce.app
```

## Controls

- Command-Shift-C — Summon or Hide
- Command-Shift-P — Pause or Resume
- Command-Shift-M — Mute or Unmute

Use the menu-bar cat icon for toys, personality, sound, appearance, and window
preferences. Click Through makes the cat ignore pointer input; recover it by
opening the menu-bar icon and turning **Click Through** off.

Pounce is available across Spaces, can be dragged directly by clicking and
dragging the cat, and reacts to clicks, double-clicks, scrolling, secondary
clicks, and repeated contact. It roams within the visible frame when idle and
pauses movement while hidden, paused, reduced-motion, or another app is truly
fullscreen. Roaming and dragging use continuous walking motion, while every
interaction drives a bounded pose/expression animation; Reduced Motion keeps
the state changes without animated movement.

## Desktop cleanup and screen time

**Clean Up Desktop…** previews visible files directly on the Desktop. Pounce
never permanently deletes files: only explicitly selected items are moved to
the macOS Trash after confirmation. Hidden files, folders, symlinks, bundles,
mounted-volume content, and paths outside Desktop are excluded.

The Screen Time panel tracks only Pounce sessions locally on this Mac. It can
run focus sessions and schedule break reminders, but it does not read Apple’s
private system Screen Time database or inspect other apps, keystrokes, screen
contents, screenshots, or network activity. Notifications are requested only
when a break reminder is first scheduled.

## Checks

The project intentionally uses a dependency-free checks executable, not XCTest
or Swift Testing:

```sh
swift run PounceChecks
swift run PounceChecks --filter pausedModelDoesNotScheduleNewIdleActivity
```

## Privacy and limitations

All preferences stay in local `UserDefaults`. Pounce has no network,
analytics, accounts, cloud sync, microphone access, Accessibility permission,
or global input capture. It conservatively hides during fullscreen uncertainty
and pauses idle work when hidden, paused, or fullscreen. Fullscreen detection,
audio playback, multi-display placement, and the menu-bar panel depend on the
current macOS desktop session and are best verified on a local Mac.
