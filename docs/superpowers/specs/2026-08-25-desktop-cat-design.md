# Desktop Cat for macOS — Design

## Goal

Create a native macOS desktop companion: a charming, hand-drawn orange tabby that behaves like a gentle, believable cat without interrupting the user's work.

## Scope

The first release includes a transparent desktop cat, contextual reactions, random idle behaviour, simple toys, a menu-bar control surface, local preference storage, basic care meters, sound controls, and accessibility settings. It does not include cloud sync, accounts, analytics, networking, a game economy, or global activity logging.

## Technical approach

The project is a native SwiftUI macOS app with a small AppKit integration layer.

- **AppKit window controller:** creates and manages a transparent, borderless cat window. It supports desktop-level and always-on-top placement, click-through mode, display-boundary handling, and hiding during fullscreen apps.
- **SwiftUI presentation:** draws the orange tabby from layered, reusable vector-like parts—body, tabby markings, eyes, ears, paws, and tail—rather than video assets. Smooth transforms and short transitions create the animation.
- **Animation engine:** selects and coordinates activity states, applying priorities so user responses always interrupt idle activity safely.
- **Menu-bar and settings UI:** exposes quick actions and a minimal settings surface without requiring the cat itself to be visible.
- **Local pet store:** persists settings and light-weight pet state with macOS preferences.

## Cat state model

The engine represents the cat as a mutually exclusive primary activity plus expression and movement modifiers.

Primary activities include: idle sitting, loafing, walking, sleeping, waking, stretching, grooming, kneading, looking around, playing, pouncing, zooming, hiding, peeking, eating, and sunbathing.

Modifiers include: blink, slow blink, ear twitch, tail swish, purr, chirp, meow, side-eye, and mildly startled. Activities define entry, looping, exit, and cooldown timing. Direct interaction overrides idle activities; when complete, the cat transitions to an appropriate calm pose.

The scheduler uses weighted random choices, recent-history exclusion, time-of-day bias, personality bias, and energy level to prevent repetitive patterns. Reduced-motion mode selects stationary alternatives and gentle opacity/pose changes.

## Interaction model

| Input | Response |
| --- | --- |
| Click on cat | Contextual blink, chirp, roll, cursor look, or playful startle |
| Slow affectionate drag | Lean-in, purr, knead, slow blink, tail swish |
| Fast/repeated interaction | Brief mild annoyance: ear tilt, side-eye, tail flick, small retreat |
| Nearby active pointer | Occasional investigation or pursuit while the cat is active |
| Laser dot | Track, stalk, and pounce |
| Yarn/paper ball | Bat, chase, or inspect |
| Feather wand | Watch and swat |
| Treat | Approach, eat, settle contentedly |
| Right click/menu bar | Summon, hide, pause, mute, toggle click-through, choose toy/personality, open settings |

Pointer behaviour deliberately avoids system-wide event capture or activity recording. It only responds to pointer information available through the companion surface and explicit toy controls.

## Personalities and care

The selectable personalities are playful kitten, sleepy loaf, curious explorer, and dignified senior. They tune state-selection weights rather than create divergent feature sets.

Optional, low-pressure meters track hunger, affection, energy, and playfulness. They decay slowly, never punish the user, and merely influence possible idle activities and reaction likelihood.

## Settings and accessibility

Settings include window level, click-through, fullscreen hiding, attention level, selected personality, sound volume/silent mode, cat size, reduced motion, high contrast, and keyboard shortcuts for summon, hide, and pause.

All data is local. On launch, the app restores the cat's position and state safely. If a saved display no longer exists, the cat returns to a visible point on the primary display. If audio is unavailable, the app quietly runs without sound.

## Reliability and performance

The app uses a single timed scheduler and stops active timers/animations when paused, hidden, or in reduced-power idle circumstances. Drawing is limited to the cat window and animations avoid continuous heavy effects. Fullscreen detection uncertainty resolves in favour of hiding the cat, so work remains unobstructed.

## Validation

Automated tests cover state selection, cooldown/history logic, interaction-priority rules, preference persistence, and display-boundary correction. Manual verification covers window layering, click-through behaviour, fullscreen hiding, sounds and silent mode, accessibility preferences, and resource use during idle behaviour.

## Acceptance criteria

1. The orange tabby can sit unobtrusively on the desktop and can be hidden, summoned, paused, moved, or made click-through.
2. Click, petting, hurried interaction, and each toy produce appropriate, non-repetitive reactions.
3. The cat demonstrates the agreed range of idle and time-of-day behaviour without blocking ordinary work.
4. Personality, care, audio, accessibility, and placement preferences survive relaunch.
5. The app works gracefully across display changes and fullscreen applications.
