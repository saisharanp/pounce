# Desktop Cat for macOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, lightweight macOS desktop companion that presents a hand-drawn orange tabby with natural interactive and idle behaviour.

**Architecture:** A SwiftUI app owns the cat rendering, menu-bar UI, and settings. AppKit provides a transparent overlay window and macOS workspace integration; a pure-Swift domain layer chooses cat states and persists local state, allowing the essential behaviour to be tested without UI automation.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, UserDefaults, AVFoundation, macOS 14+.

**Spec:** `desktop-cat/docs/superpowers/specs/2026-08-25-desktop-cat-design.md`

## Global Constraints

- Target macOS 14 or newer; use SwiftUI for app UI and AppKit only at desktop-window/system integration boundaries.
- Keep all data on-device in `UserDefaults`; do not add accounts, analytics, network calls, cloud sync, or global activity logging.
- Render the cat from SwiftUI layers and transforms; do not bundle video assets or use continuous expensive effects.
- Direct user reactions take priority over idle behaviour; all random behaviour must use recent-history exclusion and cooldowns.
- Fullscreen uncertainty must hide the cat, and click-through must prevent the overlay from receiving ordinary mouse input.
- Reduced-motion and silent modes must work independently and persist across relaunches.
- Keep source files focused: one responsibility per type, with testable domain code outside SwiftUI views.

---

## Proposed file structure

```
desktop-cat/
  DesktopCat.xcodeproj/
  DesktopCat/
    DesktopCatApp.swift
    Domain/
      CatActivity.swift
      CatPersonality.swift
      CatMood.swift
      CatScheduler.swift
      CatInteraction.swift
      PetState.swift
    Persistence/
      PetStateStore.swift
    Desktop/
      DesktopCatWindowController.swift
      WorkspaceObserver.swift
    Presentation/
      CatViewModel.swift
      CatView.swift
      OrangeTabbyShape.swift
      ToyOverlayView.swift
      MenuBarController.swift
      SettingsView.swift
  DesktopCatTests/
    CatSchedulerTests.swift
    PetStateStoreTests.swift
    CatViewModelTests.swift
    DesktopCatWindowControllerTests.swift
```

## Task 1: Create the native macOS app target and domain vocabulary

**Files:**
- Create: `desktop-cat/DesktopCat.xcodeproj` and app target using the Xcode macOS App template
- Create: `desktop-cat/DesktopCat/DesktopCatApp.swift`
- Create: `desktop-cat/DesktopCat/Domain/CatActivity.swift`
- Create: `desktop-cat/DesktopCat/Domain/CatPersonality.swift`
- Create: `desktop-cat/DesktopCat/Domain/CatMood.swift`
- Create: `desktop-cat/DesktopCatTests/CatActivityTests.swift`

**Interfaces:**
- Produces: `CatActivity`, `CatPersonality`, and `CatMood` types consumed by every later domain and presentation task.

- [ ] **Step 1: Create an Xcode macOS App target named `DesktopCat`**

Set deployment target to macOS 14.0, interface to SwiftUI, language to Swift, and create the `DesktopCatTests` XCTest target. Place all files under `desktop-cat/`.

- [ ] **Step 2: Write the failing vocabulary test**

```swift
func testPlayfulPersonalityPrefersPlayOverSleep() {
    XCTAssertGreaterThan(
        CatPersonality.playfulKitten.weight(for: .pouncing),
        CatPersonality.playfulKitten.weight(for: .sleeping)
    )
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatActivityTests`

Expected: failure because `CatPersonality` is not defined.

- [ ] **Step 4: Add the domain vocabulary**

```swift
enum CatActivity: String, CaseIterable, Codable {
    case sitting, loafing, walking, sleeping, waking, stretching, grooming
    case kneading, lookingAround, pouncing, zooming, hiding, peeking, eating, sunbathing
}

enum CatPersonality: String, CaseIterable, Codable {
    case playfulKitten, sleepyLoaf, curiousExplorer, dignifiedSenior

    func weight(for activity: CatActivity) -> Int {
        switch (self, activity) {
        case (.playfulKitten, .pouncing), (.playfulKitten, .zooming): return 8
        case (.playfulKitten, .sleeping): return 2
        case (.sleepyLoaf, .sleeping), (.sleepyLoaf, .loafing): return 8
        case (.curiousExplorer, .walking), (.curiousExplorer, .lookingAround): return 8
        case (.dignifiedSenior, .sitting), (.dignifiedSenior, .sunbathing): return 7
        default: return 4
        }
    }
}

struct CatMood: Codable, Equatable {
    var hunger: Double = 0.25
    var affection: Double = 0.65
    var energy: Double = 0.65
    var playfulness: Double = 0.65
}
```

- [ ] **Step 5: Add the minimal app entry point and rerun tests**

```swift
@main
struct DesktopCatApp: App {
    var body: some Scene { Settings { EmptyView() } }
}
```

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatActivityTests`

Expected: PASS.

- [ ] **Step 6: Commit the working foundation**

```bash
git add desktop-cat/DesktopCat.xcodeproj desktop-cat/DesktopCat desktop-cat/DesktopCatTests/CatActivityTests.swift
git commit -m "feat: add desktop cat domain vocabulary"
```

## Task 2: Implement deterministic, non-repetitive idle scheduling

**Files:**
- Create: `desktop-cat/DesktopCat/Domain/CatScheduler.swift`
- Create: `desktop-cat/DesktopCatTests/CatSchedulerTests.swift`

**Interfaces:**
- Consumes: `CatActivity`, `CatPersonality`, `CatMood`.
- Produces: `CatScheduler.nextIdleActivity(now:personality:mood:recentActivities:) -> CatActivity` and `CatScheduler.isAllowed(_:now:recentActivities:) -> Bool`.

- [ ] **Step 1: Write failing scheduler tests**

```swift
func testSchedulerDoesNotRepeatRecentActivity() {
    let scheduler = CatScheduler(randomIndex: { _ in 0 })
    let next = scheduler.nextIdleActivity(
        now: Date(timeIntervalSince1970: 12 * 60 * 60),
        personality: .playfulKitten,
        mood: CatMood(),
        recentActivities: [.pouncing]
    )
    XCTAssertNotEqual(next, .pouncing)
}

func testLateNightBiasAllowsSleeping() {
    let scheduler = CatScheduler(randomIndex: { _ in 0 })
    XCTAssertTrue(scheduler.isAllowed(.sleeping, now: Date(timeIntervalSince1970: 2 * 60 * 60), recentActivities: []))
}
```

- [ ] **Step 2: Run the tests to verify failure**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatSchedulerTests`

Expected: failure because `CatScheduler` is not defined.

- [ ] **Step 3: Implement the scheduler with injected randomness**

```swift
struct CatScheduler {
    let randomIndex: (Int) -> Int

    func isAllowed(_ activity: CatActivity, now: Date, recentActivities: [CatActivity]) -> Bool {
        guard !recentActivities.suffix(2).contains(activity) else { return false }
        return true
    }

    func nextIdleActivity(now: Date, personality: CatPersonality, mood: CatMood, recentActivities: [CatActivity]) -> CatActivity {
        let allowed = CatActivity.allCases.filter { isAllowed($0, now: now, recentActivities: recentActivities) }
        let pool = allowed.flatMap { Array(repeating: $0, count: personality.weight(for: $0)) }
        return pool[randomIndex(pool.count)]
    }
}
```

Extend this implementation with explicit time-of-day and mood multipliers before selecting the pool; retain the injected `randomIndex` so tests remain deterministic.

- [ ] **Step 4: Run scheduler tests and the full suite**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS'`

Expected: PASS.

- [ ] **Step 5: Commit the scheduler**

```bash
git add desktop-cat/DesktopCat/Domain/CatScheduler.swift desktop-cat/DesktopCatTests/CatSchedulerTests.swift
git commit -m "feat: schedule varied cat idle activities"
```

## Task 3: Model user interactions and reaction priority

**Files:**
- Create: `desktop-cat/DesktopCat/Domain/CatInteraction.swift`
- Create: `desktop-cat/DesktopCatTests/CatInteractionTests.swift`

**Interfaces:**
- Consumes: `CatActivity` and `CatMood`.
- Produces: `CatInteraction`, `CatReaction`, and `CatReactionResolver.resolve(_:mood:) -> CatReaction`.

- [ ] **Step 1: Write failing reaction tests**

```swift
func testGentlePettingReturnsAffectionateReaction() {
    let reaction = CatReactionResolver.resolve(.gentlePet, mood: CatMood())
    XCTAssertEqual(reaction.activity, .kneading)
    XCTAssertEqual(reaction.expression, .slowBlink)
}

func testFastRepeatedInputReturnsMildAnnoyance() {
    let reaction = CatReactionResolver.resolve(.hurriedAttention, mood: CatMood())
    XCTAssertEqual(reaction.expression, .sideEye)
}
```

- [ ] **Step 2: Run the tests to verify failure**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatInteractionTests`

Expected: failure because reaction types are not defined.

- [ ] **Step 3: Implement explicit interaction mapping**

```swift
enum CatInteraction { case click, gentlePet, hurriedAttention, laser, yarn, feather, paperBall, treat }
enum CatExpression: String, Codable { case neutral, blink, slowBlink, purr, chirp, meow, sideEye, startled }
struct CatReaction: Equatable { let activity: CatActivity; let expression: CatExpression }

enum CatReactionResolver {
    static func resolve(_ input: CatInteraction, mood: CatMood) -> CatReaction {
        switch input {
        case .gentlePet: return .init(activity: .kneading, expression: .slowBlink)
        case .hurriedAttention: return .init(activity: .walking, expression: .sideEye)
        case .laser: return .init(activity: .pouncing, expression: .neutral)
        case .yarn, .paperBall: return .init(activity: .pouncing, expression: .chirp)
        case .feather: return .init(activity: .lookingAround, expression: .chirp)
        case .treat: return .init(activity: .eating, expression: .purr)
        case .click: return .init(activity: .sitting, expression: .blink)
        }
    }
}
```

- [ ] **Step 4: Verify mapping and priority behavior**

Add a test that a user reaction replaces an idle activity in `CatViewModel` (created in Task 6). Run the Task 3 test target now; add and run the view-model test in Task 6.

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatInteractionTests`

Expected: PASS.

- [ ] **Step 5: Commit reaction behavior**

```bash
git add desktop-cat/DesktopCat/Domain/CatInteraction.swift desktop-cat/DesktopCatTests/CatInteractionTests.swift
git commit -m "feat: add cat interaction reactions"
```

## Task 4: Persist preferences and gentle care state locally

**Files:**
- Create: `desktop-cat/DesktopCat/Domain/PetState.swift`
- Create: `desktop-cat/DesktopCat/Persistence/PetStateStore.swift`
- Create: `desktop-cat/DesktopCatTests/PetStateStoreTests.swift`

**Interfaces:**
- Consumes: `CatMood`, `CatPersonality`.
- Produces: `PetState` and `PetStateStore.load() -> PetState`, `PetStateStore.save(_:)`.

- [ ] **Step 1: Write the failing round-trip test**

```swift
func testStoreRoundTripsPreferences() {
    let defaults = UserDefaults(suiteName: #function)!
    let store = PetStateStore(defaults: defaults)
    let expected = PetState(personality: .curiousExplorer, isMuted: true, reducedMotion: true)
    store.save(expected)
    XCTAssertEqual(store.load(), expected)
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/PetStateStoreTests`

Expected: failure because `PetStateStore` is undefined.

- [ ] **Step 3: Implement a Codable state store with safe defaults**

```swift
struct PetState: Codable, Equatable {
    var personality: CatPersonality = .playfulKitten
    var mood: CatMood = .init()
    var isMuted = false
    var isPaused = false
    var clickThrough = false
    var reducedMotion = false
    var highContrast = false
    var catScale = 1.0
}

final class PetStateStore {
    private let defaults: UserDefaults
    private let key = "pet-state"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> PetState { guard let data = defaults.data(forKey: key), let state = try? JSONDecoder().decode(PetState.self, from: data) else { return .init() }; return state }
    func save(_ state: PetState) { defaults.set(try? JSONEncoder().encode(state), forKey: key) }
}
```

Store the window position as a separate `Codable` screen-relative point and clamp it in the window controller task.

- [ ] **Step 4: Run the persistence tests**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/PetStateStoreTests`

Expected: PASS.

- [ ] **Step 5: Commit persistence**

```bash
git add desktop-cat/DesktopCat/Domain/PetState.swift desktop-cat/DesktopCat/Persistence/PetStateStore.swift desktop-cat/DesktopCatTests/PetStateStoreTests.swift
git commit -m "feat: persist cat preferences locally"
```

## Task 5: Build the transparent desktop overlay and workspace protection

**Files:**
- Create: `desktop-cat/DesktopCat/Desktop/DesktopCatWindowController.swift`
- Create: `desktop-cat/DesktopCat/Desktop/WorkspaceObserver.swift`
- Create: `desktop-cat/DesktopCatTests/DesktopCatWindowControllerTests.swift`

**Interfaces:**
- Consumes: `PetState`.
- Produces: `DesktopCatWindowController.setClickThrough(_:)`, `setVisible(_:)`, `moveToVisibleFrame(_:)`, `WorkspaceObserver.isFullscreenAppActive`.

- [ ] **Step 1: Write failing geometry tests**

```swift
func testPositionIsClampedInsideVisibleFrame() {
    let frame = CGRect(x: 0, y: 0, width: 1000, height: 700)
    let result = DesktopCatWindowController.clampedOrigin(CGPoint(x: 1200, y: -50), windowSize: CGSize(width: 180, height: 180), visibleFrame: frame)
    XCTAssertEqual(result, CGPoint(x: 820, y: 0))
}
```

- [ ] **Step 2: Run geometry tests to verify failure**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/DesktopCatWindowControllerTests`

Expected: failure because `DesktopCatWindowController` is undefined.

- [ ] **Step 3: Implement the AppKit bridge**

```swift
final class DesktopCatWindowController: NSWindowController {
    func setClickThrough(_ enabled: Bool) { window?.ignoresMouseEvents = enabled }
    func setVisible(_ visible: Bool) { visible ? window?.orderFront(nil) : window?.orderOut(nil) }
    static func clampedOrigin(_ origin: CGPoint, windowSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - windowSize.width), y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - windowSize.height))
    }
}
```

Configure the `NSPanel`/`NSWindow` as borderless, transparent, non-opaque, shadowless, movable by background, and at the selected desktop or floating level. `WorkspaceObserver` subscribes to active-app notifications and reports fullscreen state; hidden is the safe result when it cannot determine state.

- [ ] **Step 4: Verify tests and manual window behavior**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS'`

Then launch the app and verify: transparent background, click-through toggles, moving between displays clamps safely, and fullscreen apps hide the cat.

- [ ] **Step 5: Commit desktop integration**

```bash
git add desktop-cat/DesktopCat/Desktop desktop-cat/DesktopCatTests/DesktopCatWindowControllerTests.swift
git commit -m "feat: add desktop cat overlay window"
```

## Task 6: Render the animated orange tabby and connect the view model

**Files:**
- Create: `desktop-cat/DesktopCat/Presentation/CatViewModel.swift`
- Create: `desktop-cat/DesktopCat/Presentation/OrangeTabbyShape.swift`
- Create: `desktop-cat/DesktopCat/Presentation/CatView.swift`
- Create: `desktop-cat/DesktopCatTests/CatViewModelTests.swift`

**Interfaces:**
- Consumes: `CatScheduler`, `CatReactionResolver`, `PetStateStore`.
- Produces: `CatViewModel.activity`, `expression`, `handle(_:)`, `scheduleIdleActivity(now:)`.

- [ ] **Step 1: Write failing view-model tests**

```swift
func testInteractionPreemptsIdleActivity() {
    let model = CatViewModel(store: PetStateStore(defaults: .init(suiteName: #function)!))
    model.scheduleIdleActivity(now: Date())
    model.handle(.gentlePet)
    XCTAssertEqual(model.activity, .kneading)
    XCTAssertEqual(model.expression, .slowBlink)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatViewModelTests`

Expected: failure because `CatViewModel` is undefined.

- [ ] **Step 3: Implement a main-actor view model and layered tabby**

```swift
@MainActor final class CatViewModel: ObservableObject {
    @Published private(set) var activity: CatActivity = .sitting
    @Published private(set) var expression: CatExpression = .neutral
    func handle(_ interaction: CatInteraction) {
        let reaction = CatReactionResolver.resolve(interaction, mood: state.mood)
        activity = reaction.activity; expression = reaction.expression
    }
}
```

Draw the tabby in `OrangeTabbyShape` from an orange body, darker curved stripe overlays, cream muzzle, eye pupils, ears, tail, and paws. In `CatView`, map activity/expression to short SwiftUI transforms: tail rotation, eye scale, body offset, paw rotation, and breathing scale. Do not use a perpetual `TimelineView`; run only bounded activity transitions and pause all motion when `reducedMotion` or `isPaused` is true.

- [ ] **Step 4: Add pointer and drag interpretation**

Translate tap, gentle drag velocity, and fast/repeated interactions into the matching `CatInteraction`. Keep app-level drag-to-reposition distinct from petting so intentional window moves always work.

- [ ] **Step 5: Run unit tests and manually inspect core animation**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS'`

Then launch and manually verify sitting, blinking, tail swishing, loafing, sleeping, stretching, grooming, gentle petting, and mild-annoyance poses.

- [ ] **Step 6: Commit cat presentation**

```bash
git add desktop-cat/DesktopCat/Presentation desktop-cat/DesktopCatTests/CatViewModelTests.swift
git commit -m "feat: render interactive orange tabby"
```

## Task 7: Add toys, menu-bar controls, settings, sound, and keyboard actions

**Files:**
- Create: `desktop-cat/DesktopCat/Presentation/ToyOverlayView.swift`
- Create: `desktop-cat/DesktopCat/Presentation/MenuBarController.swift`
- Create: `desktop-cat/DesktopCat/Presentation/SettingsView.swift`
- Modify: `desktop-cat/DesktopCat/DesktopCatApp.swift`

**Interfaces:**
- Consumes: `CatViewModel.handle(_:)`, `PetState`, `PetStateStore`, `DesktopCatWindowController`.
- Produces: menu actions for summon, hide, pause, mute, click-through, toy selection, and settings.

- [ ] **Step 1: Add a failing menu-action test to `CatViewModelTests.swift`**

```swift
func testTreatActionSelectsEatingReaction() {
    let model = CatViewModel(store: PetStateStore(defaults: .init(suiteName: #function)!))
    model.handle(.treat)
    XCTAssertEqual(model.activity, .eating)
}
```

- [ ] **Step 2: Run it to confirm the action path is covered**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatViewModelTests/testTreatActionSelectsEatingReaction`

Expected: PASS after Task 6; if it fails, correct the reaction mapping before adding UI controls.

- [ ] **Step 3: Add the visible control surfaces**

Use `MenuBarExtra` for Summon, Hide, Pause, Mute, Click Through, toys, personality selection, and Settings. Present a small context menu from `CatView`. In `ToyOverlayView`, display only the selected toy while active and route its completed gesture to `.laser`, `.yarn`, `.feather`, `.paperBall`, or `.treat`.

Use `AVAudioPlayer` for optional short bundled sounds; make playback a no-op whenever `isMuted` is true. `SettingsView` must bind to persisted values for sound, size, reduced motion, high contrast, fullscreen hiding, attention level, and keyboard shortcuts.

- [ ] **Step 4: Add and verify keyboard shortcuts**

Assign Command-Shift-C to summon/hide, Command-Shift-P to pause/resume, and Command-Shift-M to mute/unmute. Ensure all three actions are exposed in the menu so they remain discoverable.

- [ ] **Step 5: Run full tests and manual controls check**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS'`

Manually verify every menu and context-menu action, four toy responses, silent mode, preferences survival after relaunch, and keyboard shortcuts.

- [ ] **Step 6: Commit controls and accessibility**

```bash
git add desktop-cat/DesktopCat/DesktopCatApp.swift desktop-cat/DesktopCat/Presentation desktop-cat/DesktopCatTests/CatViewModelTests.swift
git commit -m "feat: add desktop cat controls and settings"
```

## Task 8: Integrate lifecycle, performance safeguards, and release validation

**Files:**
- Modify: `desktop-cat/DesktopCat/DesktopCatApp.swift`
- Modify: `desktop-cat/DesktopCat/Presentation/CatViewModel.swift`
- Modify: `desktop-cat/DesktopCat/Desktop/WorkspaceObserver.swift`
- Create: `desktop-cat/README.md`

**Interfaces:**
- Consumes: all prior components.
- Produces: an app that launches with restored preferences, suspends activity when hidden/paused/fullscreen, and documents launch and verification steps.

- [ ] **Step 1: Write failing lifecycle tests**

```swift
func testPausedModelDoesNotScheduleNewIdleActivity() {
    let model = CatViewModel(store: PetStateStore(defaults: .init(suiteName: #function)!))
    model.setPaused(true)
    model.scheduleIdleActivity(now: Date())
    XCTAssertEqual(model.activity, .sitting)
}
```

- [ ] **Step 2: Run lifecycle tests to verify failure**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS' -only-testing:DesktopCatTests/CatViewModelTests/testPausedModelDoesNotScheduleNewIdleActivity`

Expected: failure because `setPaused(_:)` is not implemented.

- [ ] **Step 3: Implement suspension and launch restoration**

Add `setPaused(_:)` and ensure the scheduler timer is invalidated while paused, hidden, or fullscreen. On launch, load `PetState`, recreate the overlay at a clamped position, apply click-through and accessibility state, and start idle scheduling only if visible and unpaused. Recheck state when application activation, screen-configuration, and workspace notifications arrive.

- [ ] **Step 4: Write concise project documentation**

`README.md` must state the macOS 14 requirement, how to open/run the Xcode project, the three keyboard shortcuts, how to use click-through, and how to run the test command.

- [ ] **Step 5: Run complete automated validation**

Run: `xcodebuild test -project DesktopCat.xcodeproj -scheme DesktopCat -destination 'platform=macOS'`

Expected: PASS with no skipped domain tests.

- [ ] **Step 6: Perform final manual acceptance check**

Verify each spec acceptance criterion: desktop placement, non-interference, click/pet/hurried reactions, four toys, randomized idle variety, time-of-day change, personality differences, care preferences, sound/silent mode, reduced motion, high contrast, keyboard actions, relaunch restoration, display change, and fullscreen hiding.

- [ ] **Step 7: Commit release-ready integration**

```bash
git add desktop-cat/DesktopCat desktop-cat/DesktopCatTests desktop-cat/README.md
git commit -m "feat: complete desktop cat lifecycle"
```

## Plan self-review

- **Spec coverage:** Tasks 1–2 cover vocabulary, personalities, time/mood-weighted non-repetitive idle behaviour. Task 3 covers reaction priority and toys. Task 4 covers local care/preferences. Task 5 covers overlay safety, display movement, click-through, and fullscreen hiding. Task 6 renders and animates the orange tabby. Task 7 covers menu bar, context menu, sound, accessibility, toys, and keyboard actions. Task 8 validates lifecycle, performance suspension, documentation, and all acceptance criteria.
- **Placeholder scan:** This plan contains no unfinished decisions; implementation choices, files, commands, test names, and expected outcomes are specified.
- **Type consistency:** `CatActivity`, `CatPersonality`, `CatMood`, `CatInteraction`, `CatReaction`, `PetState`, `PetStateStore`, and `CatViewModel` are introduced before later tasks consume them. `CatViewModel.handle(_:)` takes `CatInteraction` throughout.
