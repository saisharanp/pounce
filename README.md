# Desktop Cat

Desktop Cat is a native macOS 14+ menu-bar companion: an interactive orange
tabby overlay that keeps its preferences on this Mac.

## Build and run

Open `Package.swift` in Xcode and run the `DesktopCat` scheme, or use SwiftPM:

```sh
swift run DesktopCat
```

To create an ad-hoc-signed app bundle:

```sh
./Scripts/build-app.sh
open dist/DesktopCat.app
```

## Controls

- Command-Shift-C — Summon or Hide
- Command-Shift-P — Pause or Resume
- Command-Shift-M — Mute or Unmute

Use the menu-bar cat icon for toys, personality, sound, appearance, and window
preferences. Click Through makes the cat ignore pointer input; recover it by
opening the menu-bar icon and turning **Click Through** off.

## Checks

The project intentionally uses a dependency-free checks executable, not XCTest
or Swift Testing:

```sh
swift run DesktopCatChecks
swift run DesktopCatChecks --filter pausedModelDoesNotScheduleNewIdleActivity
```

## Privacy and limitations

All preferences stay in local `UserDefaults`. Desktop Cat has no network,
analytics, accounts, cloud sync, microphone access, Accessibility permission,
or global input capture. It conservatively hides during fullscreen uncertainty
and pauses idle work when hidden, paused, or fullscreen. Fullscreen detection,
audio playback, multi-display placement, and the menu-bar panel depend on the
current macOS desktop session and are best verified on a local Mac.
