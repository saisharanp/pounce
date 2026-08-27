import AppKit
import Darwin
import CoreGraphics
import DesktopCatCore
import Foundation
import SwiftUI

private struct CheckCase {
    let name: String
    let run: () throws -> Void
}

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private struct CatInspectionGrid: View {
    private let samples: [(CatActivity, CatExpression)] = [
        (.sitting, .blink), (.loafing, .purr), (.walking, .sideEye),
        (.sleeping, .slowBlink), (.waking, .startled), (.stretching, .neutral),
        (.grooming, .neutral), (.kneading, .slowBlink), (.lookingAround, .chirp),
        (.pouncing, .chirp), (.zooming, .startled), (.hiding, .neutral),
        (.peeking, .sideEye), (.eating, .purr), (.sunbathing, .meow)
    ]

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<5, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let index = row * 3 + column
                        let sample = samples[index]
                        VStack(spacing: 2) {
                            OrangeTabbyShape(
                                pose: CatPose(
                                    activity: sample.0,
                                    expression: sample.1,
                                    phase: sample.1 == .blink || sample.1 == .slowBlink
                                        ? true
                                        : index.isMultiple(of: 2),
                                    motionAllowed: true
                                ),
                                highContrast: index == 10
                            )
                            .frame(width: 120, height: 120)
                            Text("\(sample.0.rawValue) · \(sample.1.rawValue)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
    }
}

@MainActor
private func nativeSnapshot<Content: View>(
    of content: Content,
    size: CGSize
) -> NSImage? {
    let hostingView = NSHostingView(rootView: content)
    hostingView.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(
        contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()
    guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        return nil
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
    let image = NSImage(size: size)
    image.addRepresentation(bitmap)
    return image
}

private let checks = [
    CheckCase(name: "playfulPersonalityPrefersPlayOverSleep") {
        let playWeight = CatPersonality.playfulKitten.weight(for: .pouncing)
        let sleepWeight = CatPersonality.playfulKitten.weight(for: .sleeping)

        guard playWeight > sleepWeight else {
            throw CheckFailure(
                description: "expected pouncing weight (\(playWeight)) to exceed sleeping weight (\(sleepWeight))"
            )
        }
    },
    CheckCase(name: "schedulerDoesNotRepeatRecentActivity") {
        let scheduler = CatScheduler(randomIndex: { _ in 0 })
        let next = scheduler.nextIdleActivity(
            now: Date(timeIntervalSince1970: 12 * 60 * 60),
            personality: .playfulKitten,
            mood: CatMood(),
            recentActivities: [.pouncing]
        )

        guard next != .pouncing else {
            throw CheckFailure(description: "scheduler repeated recent activity: pouncing")
        }
    },
    CheckCase(name: "lateNightBiasAllowsSleeping") {
        let scheduler = CatScheduler(randomIndex: { _ in 0 })
        let isAllowed = scheduler.isAllowed(
            .sleeping,
            now: Date(timeIntervalSince1970: 2 * 60 * 60),
            recentActivities: []
        )

        guard isAllowed else {
            throw CheckFailure(description: "sleeping should be allowed late at night")
        }
    },
    CheckCase(name: "gentlePettingReturnsAffectionateReaction") {
        let reaction = CatReactionResolver.resolve(.gentlePet, mood: CatMood())

        guard reaction.activity == .kneading else {
            throw CheckFailure(description: "gentle petting should trigger kneading")
        }
        guard reaction.expression == .slowBlink else {
            throw CheckFailure(description: "gentle petting should trigger a slow blink")
        }
    },
    CheckCase(name: "fastRepeatedInputReturnsMildAnnoyance") {
        let reaction = CatReactionResolver.resolve(.hurriedAttention, mood: CatMood())

        guard reaction.expression == .sideEye else {
            throw CheckFailure(description: "hurried attention should trigger a side-eye")
        }
    },
    CheckCase(name: "laserProducesPouncingReaction") {
        let reaction = CatReactionResolver.resolve(.laser, mood: CatMood())

        guard reaction == CatReaction(activity: .pouncing, expression: .neutral) else {
            throw CheckFailure(description: "laser should trigger neutral pouncing")
        }
    },
    CheckCase(name: "yarnAndPaperBallProduceChirpingPounces") {
        let mood = CatMood()
        let yarnReaction = CatReactionResolver.resolve(.yarn, mood: mood)
        let paperBallReaction = CatReactionResolver.resolve(.paperBall, mood: mood)
        let expected = CatReaction(activity: .pouncing, expression: .chirp)

        guard yarnReaction == expected, paperBallReaction == expected else {
            throw CheckFailure(description: "yarn and paper ball should trigger chirping pounces")
        }
    },
    CheckCase(name: "featherProducesLookingAroundReaction") {
        let reaction = CatReactionResolver.resolve(.feather, mood: CatMood())

        guard reaction == CatReaction(activity: .lookingAround, expression: .chirp) else {
            throw CheckFailure(description: "feather should trigger a chirping look-around")
        }
    },
    CheckCase(name: "treatProducesEatingReaction") {
        let reaction = CatReactionResolver.resolve(.treat, mood: CatMood())

        guard reaction == CatReaction(activity: .eating, expression: .purr) else {
            throw CheckFailure(description: "treat should trigger purring eating")
        }
    },
    CheckCase(name: "clickProducesBlinkingSittingReaction") {
        let reaction = CatReactionResolver.resolve(.click, mood: CatMood())

        guard reaction == CatReaction(activity: .sitting, expression: .blink) else {
            throw CheckFailure(description: "click should trigger blinking sitting")
        }
    },
    CheckCase(name: "secondClickReachesMeowThroughViewModel") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))

        model.handle(.click)
        guard model.expression == .blink else {
            throw CheckFailure(description: "the first contextual click did not blink")
        }

        model.handle(.click)
        guard model.expression == .meow else {
            throw CheckFailure(description: "the second contextual click did not reach meow")
        }
    },
    CheckCase(name: "thirdClickReachesStartledThroughViewModel") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))

        model.handle(.click)
        model.handle(.click)
        model.handle(.click)

        guard model.activity == .lookingAround, model.expression == .startled else {
            throw CheckFailure(description: "the third contextual click did not reach a startled look-around")
        }
    },
    CheckCase(name: "repeatedIdenticalInteractionsAdvanceReactionNonce") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))
        let initialNonce = model.reactionNonce

        model.handle(.gentlePet)
        let firstNonce = model.reactionNonce
        model.handle(.gentlePet)
        let secondNonce = model.reactionNonce

        guard initialNonce < firstNonce, firstNonce < secondNonce else {
            throw CheckFailure(
                description: "identical direct reactions did not publish monotonically increasing animation nonces"
            )
        }
    },
    CheckCase(name: "interactionPreemptsIdleActivity") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            scheduler: CatScheduler(randomIndex: { _ in 0 })
        )

        model.scheduleIdleActivity(now: Date(timeIntervalSince1970: 12 * 60 * 60))
        model.handle(.gentlePet)

        guard model.activity == .kneading else {
            throw CheckFailure(description: "gentle petting did not preempt the idle activity with kneading")
        }
        guard model.expression == .slowBlink else {
            throw CheckFailure(description: "gentle petting did not synchronously select a slow blink")
        }
    },
    CheckCase(name: "pausedModelDoesNotScheduleNewIdleActivity") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            scheduler: CatScheduler(randomIndex: { _ in 0 })
        )

        model.setPaused(true)
        model.scheduleIdleActivity(now: Date(timeIntervalSince1970: 12 * 60 * 60))

        guard model.activity == .sitting, model.state.isPaused else {
            throw CheckFailure(description: "a paused model scheduled a new idle activity")
        }
    },
    CheckCase(name: "lifecycleEligibilitySuspendsIdleWorkWhenNotDisplayable") {
        guard AppCoordinator.shouldScheduleIdle(
            isVisible: true,
            isPaused: false,
            isFullscreenActive: false
        ) else {
            throw CheckFailure(description: "a visible, unpaused cat outside fullscreen was not eligible for idle work")
        }

        let suspendedStates = [
            (false, false, false),
            (true, true, false),
            (true, false, true)
        ]
        for (isVisible, isPaused, isFullscreenActive) in suspendedStates {
            guard !AppCoordinator.shouldScheduleIdle(
                isVisible: isVisible,
                isPaused: isPaused,
                isFullscreenActive: isFullscreenActive
            ) else {
                throw CheckFailure(description: "hidden, paused, or fullscreen state left idle work eligible")
            }
        }
    },
    CheckCase(name: "attentionLevelsUseApprovedIdleIntervals") {
        guard AppCoordinator.idleInterval(for: .calm) == 20...35,
              AppCoordinator.idleInterval(for: .balanced) == 10...20,
              AppCoordinator.idleInterval(for: .lively) == 5...12 else {
            throw CheckFailure(description: "attention levels did not use the approved idle intervals")
        }
    },
    CheckCase(name: "elapsedCareUpdateIsGentleAndNeverPunishes") {
        let updated = CatMood().applyingElapsedCare(seconds: 24 * 60 * 60)

        guard updated.hunger > 0.25,
              updated.hunger < 0.5,
              updated.affection >= 0.65,
              updated.energy >= 0.65,
              updated.playfulness >= 0.65 else {
            throw CheckFailure(description: "elapsed care update was not gentle and non-punitive")
        }
    },
    CheckCase(name: "launchRestorationAppliesPersistedElapsedCare") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let firstLaunch = Date(timeIntervalSince1970: 1_000_000)
        let relaunch = firstLaunch.addingTimeInterval(24 * 60 * 60)
        let original = PetState(
            mood: CatMood(hunger: 0.25, affection: 0.65, energy: 0.65, playfulness: 0.65),
            lastCareUpdate: firstLaunch.addingTimeInterval(-24 * 60 * 60)
        )
        store.save(original)

        let launchModel = CatViewModel(store: store)
        launchModel.restoreElapsedCare(now: firstLaunch)
        let afterLaunch = store.load()

        guard afterLaunch.lastCareUpdate == firstLaunch,
              afterLaunch.mood.hunger > original.mood.hunger else {
            throw CheckFailure(description: "launch restoration did not apply persisted elapsed care")
        }

        let relaunchModel = CatViewModel(store: store)
        relaunchModel.restoreElapsedCare(now: relaunch)
        let afterRelaunch = store.load()

        guard afterRelaunch.lastCareUpdate == relaunch,
              afterRelaunch.mood.hunger > afterLaunch.mood.hunger else {
            throw CheckFailure(description: "relaunch did not apply care since the persisted launch timestamp")
        }
    },
    CheckCase(name: "selectedToyIsTransientAndCompletesEveryInteraction") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let model = CatViewModel(store: store)
        let expectedReactions: [(CatToy, CatActivity, CatExpression)] = [
            (.laser, .pouncing, .neutral),
            (.yarn, .pouncing, .chirp),
            (.feather, .lookingAround, .chirp),
            (.paperBall, .pouncing, .chirp),
            (.treat, .eating, .purr)
        ]

        for (toy, expectedActivity, expectedExpression) in expectedReactions {
            model.selectToy(toy)
            guard model.selectedToy == toy else {
                throw CheckFailure(description: "\(toy) did not become the transient selected toy")
            }
            model.completeSelectedToy()
            guard model.selectedToy == nil,
                  model.activity == expectedActivity,
                  model.expression == expectedExpression else {
                throw CheckFailure(description: "\(toy) did not complete with its approved reaction")
            }
        }

        guard store.load() == PetState() else {
            throw CheckFailure(description: "transient toy selection leaked into persisted pet state")
        }
    },
    CheckCase(name: "treatActionSelectsEatingReaction") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))

        model.handle(.treat)

        guard model.activity == .eating else {
            throw CheckFailure(description: "the treat action did not select the eating reaction")
        }
    },
    CheckCase(name: "proceduralSoundsHonorMuteAndClampedVolume") {
        guard CatSoundController.playbackPlan(
            for: .purr,
            isMuted: true,
            volume: 0.8
        ) == nil else {
            throw CheckFailure(description: "muted sound created a playback plan")
        }

        guard let plan = CatSoundController.playbackPlan(
            for: .play,
            isMuted: false,
            volume: 3
        ) else {
            throw CheckFailure(description: "enabled sound did not create a playback plan")
        }
        guard plan.volume == 1,
              plan.data.count > 44,
              String(data: plan.data.prefix(4), encoding: .ascii) == "RIFF",
              String(data: plan.data.dropFirst(8).prefix(4), encoding: .ascii) == "WAVE" else {
            throw CheckFailure(description: "procedural playback was not a clamped local WAV tone")
        }

        let distinctTones = Set(CatSoundKind.allCases.map {
            CatSoundController.toneData(for: $0)
        })
        guard distinctTones.count == CatSoundKind.allCases.count else {
            throw CheckFailure(description: "one or more approved cat responses shared the same tone")
        }
    },
    CheckCase(name: "interactionsRouteEveryApprovedSoundResponse") {
        let mappings: [(CatInteraction, CatReaction, CatSoundKind)] = [
            (.gentlePet, CatReaction(activity: .kneading, expression: .slowBlink), .purr),
            (.click, CatReaction(activity: .sitting, expression: .meow), .meow),
            (.feather, CatReaction(activity: .lookingAround, expression: .chirp), .chirp),
            (.laser, CatReaction(activity: .pouncing, expression: .neutral), .play),
            (.treat, CatReaction(activity: .eating, expression: .purr), .eat)
        ]

        for (interaction, reaction, expected) in mappings {
            guard CatSoundController.sound(for: interaction, reaction: reaction) == expected else {
                throw CheckFailure(description: "\(expected.rawValue) did not map from its approved response")
            }
        }
    },
    CheckCase(name: "menuControllerRoutesActionsAndPersistsSettings") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let model = CatViewModel(store: store)
        var visibilityChanges: [Bool] = []
        var clickThroughChanges: [Bool] = []
        var levelChanges: [PetWindowLevel] = []
        let controls = MenuBarController(
            viewModel: model,
            onSetVisibility: { visibilityChanges.append($0) },
            onSetClickThrough: { clickThroughChanges.append($0) },
            onSetWindowLevel: { levelChanges.append($0) }
        )

        controls.hide()
        controls.summon()
        controls.togglePause()
        controls.toggleMuted()
        controls.setClickThrough(true)
        controls.setWindowLevel(.floating)
        controls.setPersonality(.curiousExplorer)
        controls.setAttentionLevel(.lively)
        controls.setHideInFullscreen(false)
        controls.setSoundVolume(-0.5)
        controls.selectToy(.treat)
        controls.completeSelectedToy()

        guard visibilityChanges == [false, true],
              clickThroughChanges == [true],
              levelChanges == [.floating] else {
            throw CheckFailure(description: "menu actions did not reach their explicit window callbacks")
        }
        guard model.state.isPaused,
              model.state.isMuted,
              model.state.clickThrough,
              model.state.windowLevel == .floating,
              model.state.personality == .curiousExplorer,
              model.state.attentionLevel == .lively,
              !model.state.hideInFullscreen,
              model.state.soundVolume == 0 else {
            throw CheckFailure(description: "menu controls did not update the complete persisted state")
        }
        guard model.activity == .eating, model.selectedToy == nil else {
            throw CheckFailure(description: "the treat control did not complete through the model API")
        }
        guard store.load() == model.state else {
            throw CheckFailure(description: "menu-driven settings did not survive persistence")
        }
    },
    CheckCase(name: "keyboardActionsAreCompleteAndDiscoverable") {
        let shortcuts = DesktopCatKeyboardAction.allCases.map {
            ($0.title, $0.key, $0.modifierDescription)
        }
        let expected = [
            ("Summon or Hide", "C", "Command-Shift"),
            ("Pause or Resume", "P", "Command-Shift"),
            ("Mute or Unmute", "M", "Command-Shift")
        ]

        guard shortcuts.count == expected.count else {
            throw CheckFailure(description: "the discoverable shortcut list was incomplete")
        }
        for (actual, expectedShortcut) in zip(shortcuts, expected) {
            guard actual.0 == expectedShortcut.0,
                  actual.1 == expectedShortcut.1,
                  actual.2 == expectedShortcut.2 else {
                throw CheckFailure(description: "keyboard action \(actual.0) had the wrong discoverable shortcut")
            }
        }
    },
    CheckCase(name: "toyOverlayRendersEveryApprovedControl") {
        guard CatToy.allCases.map(\.displayName) == [
            "Laser", "Yarn", "Feather", "Paper Ball", "Treat"
        ] else {
            throw CheckFailure(description: "the toy overlay did not expose all five approved labels")
        }

        for toy in CatToy.allCases {
            let renderer = ImageRenderer(
                content: ToyOverlayView(
                    selectedToy: toy,
                    reducedMotion: true,
                    onCompleted: {}
                )
                .frame(width: 180, height: 180)
            )
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let representation = image.tiffRepresentation,
                  representation.count > 500 else {
                throw CheckFailure(description: "\(toy.displayName) did not render a visible native overlay")
            }
        }
    },
    CheckCase(name: "catViewRendersTransientToyOverlay") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))
        let controller = MenuBarController(viewModel: model)
        let plainRenderer = ImageRenderer(
            content: CatView(viewModel: model, controller: controller)
                .frame(width: 180, height: 180)
        )
        plainRenderer.scale = 2
        guard let plain = plainRenderer.nsImage?.tiffRepresentation else {
            throw CheckFailure(description: "the base cat view did not render")
        }

        model.selectToy(.treat)
        let toyRenderer = ImageRenderer(
            content: CatView(viewModel: model, controller: controller)
                .frame(width: 180, height: 180)
        )
        toyRenderer.scale = 2
        guard let withToy = toyRenderer.nsImage?.tiffRepresentation,
              withToy != plain else {
            throw CheckFailure(description: "the selected treat was not composed over the cat view")
        }
    },
    CheckCase(name: "menuAndSettingsSurfacesRenderNatively") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let controls = MenuBarController(
            viewModel: CatViewModel(store: PetStateStore(defaults: defaults))
        )
        guard let settingsImage = nativeSnapshot(
            of: SettingsView(controller: controls),
            size: CGSize(width: 480, height: 780)
        ),
            let settings = settingsImage.tiffRepresentation,
            settings.count > 2_000,
            let menuImage = nativeSnapshot(
                of: MenuBarContent(controller: controls),
                size: CGSize(width: 330, height: 780)
            ),
            let menu = menuImage.tiffRepresentation,
            menu.count > 2_000 else {
            throw CheckFailure(description: "menu-bar or settings controls did not render visibly")
        }

        if let snapshotPath = ProcessInfo.processInfo.environment["DESKTOP_CAT_CONTROLS_SNAPSHOT_PATH"] {
            let image = NSImage(size: CGSize(width: 846, height: 816))
            image.lockFocus()
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: image.size).fill()
            menuImage.draw(at: CGPoint(x: 18, y: 18), from: .zero, operation: .copy, fraction: 1)
            settingsImage.draw(at: CGPoint(x: 348, y: 18), from: .zero, operation: .copy, fraction: 1)
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CheckFailure(description: "the control inspection image could not be encoded")
            }
            try png.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
            print("SNAPSHOT \(snapshotPath)")
        }
    },
    CheckCase(name: "viewModelRetainsTwoRecentIdleActivities") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            scheduler: CatScheduler(randomIndex: { _ in 0 })
        )
        let noon = Date(timeIntervalSince1970: 12 * 60 * 60)

        model.scheduleIdleActivity(now: noon)
        model.scheduleIdleActivity(now: noon)
        model.scheduleIdleActivity(now: noon)

        guard model.recentIdleActivities == [.loafing, .walking] else {
            throw CheckFailure(
                description: "expected only the latest two idle activities, got \(model.recentIdleActivities)"
            )
        }
    },
    CheckCase(name: "viewModelPersistsStateChanges") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let model = CatViewModel(store: store)

        model.updateState {
            $0.reducedMotion = true
            $0.highContrast = true
            $0.catScale = 1.3
        }

        let restored = store.load()
        guard restored == model.state else {
            throw CheckFailure(description: "the model's state change was not persisted")
        }
        guard restored.reducedMotion, restored.highContrast, restored.catScale == 1.3 else {
            throw CheckFailure(description: "the persisted accessibility and scale values were incomplete")
        }
    },
    CheckCase(name: "viewModelUsesInjectedInitialRenderingState") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let expected = PetState(reducedMotion: true, highContrast: true, catScale: 1.25)
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            initialState: expected
        )

        guard model.state == expected else {
            throw CheckFailure(description: "the panel's initial accessibility and scale state was not adopted")
        }
    },
    CheckCase(name: "primaryActivitiesUseDistinctCatPoses") {
        let poses = CatActivity.allCases.map {
            CatPose(activity: $0, expression: .neutral, phase: false, motionAllowed: false)
        }

        guard Set(poses).count == CatActivity.allCases.count else {
            throw CheckFailure(description: "one or more primary activities collapsed to the same generic pose")
        }
    },
    CheckCase(name: "expressionsUseDistinctFacePoses") {
        let expressions: [CatExpression] = [
            .neutral, .blink, .slowBlink, .purr, .chirp, .meow, .sideEye, .startled
        ]
        let poses = expressions.map {
            CatPose(activity: .sitting, expression: $0, phase: false, motionAllowed: false)
        }

        guard Set(poses).count == expressions.count else {
            throw CheckFailure(description: "one or more expressions collapsed to the same face pose")
        }
    },
    CheckCase(name: "disabledMotionUsesStablePose") {
        let activeStart = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: false,
            motionAllowed: true
        )
        let activeEnd = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: true,
            motionAllowed: true
        )
        let staticStart = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: false,
            motionAllowed: false
        )
        let staticEnd = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: true,
            motionAllowed: false
        )

        guard activeStart != activeEnd else {
            throw CheckFailure(description: "normal motion did not produce a bounded phase change")
        }
        guard staticStart == staticEnd else {
            throw CheckFailure(description: "reduced-motion or paused rendering still changed by phase")
        }
    },
    CheckCase(name: "normalBlinkClosesThenEndsOpen") {
        let start = CatPose(
            activity: .sitting,
            expression: .blink,
            phase: false,
            motionAllowed: true
        )
        let closed = CatPose(
            activity: .sitting,
            expression: .blink,
            phase: true,
            motionAllowed: true
        )
        let end = CatPose(
            activity: .sitting,
            expression: .blink,
            phase: false,
            motionAllowed: true
        )

        guard start.eyeScaleY == 1, closed.eyeScaleY < 0.2, end.eyeScaleY == 1 else {
            throw CheckFailure(description: "normal blink did not resolve open, closed, then open eye poses")
        }
    },
    CheckCase(name: "normalSlowBlinkClosesThenEndsOpen") {
        let start = CatPose(
            activity: .kneading,
            expression: .slowBlink,
            phase: false,
            motionAllowed: true
        )
        let closed = CatPose(
            activity: .kneading,
            expression: .slowBlink,
            phase: true,
            motionAllowed: true
        )
        let end = CatPose(
            activity: .kneading,
            expression: .slowBlink,
            phase: false,
            motionAllowed: true
        )

        guard start.eyeScaleY == 1, closed.eyeScaleY < 0.4, end.eyeScaleY == 1 else {
            throw CheckFailure(description: "normal slow blink did not resolve open, closed, then open eye poses")
        }
    },
    CheckCase(name: "slowBlinkUsesSlowerBoundedAnimationTiming") {
        let blink = CatAnimationTiming(expression: .blink)
        let slowBlink = CatAnimationTiming(expression: .slowBlink)

        guard slowBlink.closingMilliseconds > blink.closingMilliseconds,
              slowBlink.openingMilliseconds > blink.openingMilliseconds,
              slowBlink.totalMilliseconds > blink.totalMilliseconds,
              slowBlink.totalMilliseconds <= 2_000 else {
            throw CheckFailure(description: "slow-blink timing was not slower than blink while remaining bounded")
        }
    },
    CheckCase(name: "animatedCatPosesStayInsideVisualBounds") {
        let expressions: [CatExpression] = [
            .neutral, .blink, .slowBlink, .purr, .chirp, .meow, .sideEye, .startled
        ]

        for activity in CatActivity.allCases {
            for expression in expressions {
                for phase in [false, true] {
                    let pose = CatPose(
                        activity: activity,
                        expression: expression,
                        phase: phase,
                        motionAllowed: true
                    )
                    guard abs(pose.bodyX) <= 12,
                          pose.bodyY >= -4, pose.bodyY <= 15,
                          pose.bodyScaleX >= 0.75, pose.bodyScaleX <= 1.2,
                          pose.bodyScaleY >= 0.75, pose.bodyScaleY <= 1.1,
                          abs(pose.bodyRotation) <= 12,
                          abs(pose.headRotation) <= 45,
                          abs(pose.tailRotation) <= 35,
                          pose.opacity >= 0.3, pose.opacity <= 1 else {
                        throw CheckFailure(
                            description: "\(activity.rawValue)/\(expression.rawValue) exceeded the cat's visual bounds"
                        )
                    }
                }
            }
        }
    },
    CheckCase(name: "tapOnCatMapsToClick") {
        let interaction = CatGestureInterpreter.interaction(
            translation: CGSize(width: 1, height: 1),
            duration: 0.15,
            recentContactCount: 1
        )

        guard case .click = interaction else {
            throw CheckFailure(description: "a stationary contact did not map to a click")
        }
    },
    CheckCase(name: "slowDragOnCatMapsToGentlePet") {
        let interaction = CatGestureInterpreter.interaction(
            translation: CGSize(width: 40, height: 5),
            duration: 1.2,
            recentContactCount: 1
        )

        guard case .gentlePet = interaction else {
            throw CheckFailure(description: "a deliberate slow drag did not map to gentle petting")
        }
    },
    CheckCase(name: "fastDragOnCatMapsToHurriedAttention") {
        let interaction = CatGestureInterpreter.interaction(
            translation: CGSize(width: 80, height: 0),
            duration: 0.1,
            recentContactCount: 1
        )

        guard case .hurriedAttention = interaction else {
            throw CheckFailure(description: "a fast drag did not map to mild hurried-attention feedback")
        }
    },
    CheckCase(name: "repeatedCatContactMapsToHurriedAttention") {
        let interaction = CatGestureInterpreter.interaction(
            translation: .zero,
            duration: 0.2,
            recentContactCount: 3
        )

        guard case .hurriedAttention = interaction else {
            throw CheckFailure(description: "repeated contact did not map to mild hurried-attention feedback")
        }
    },
    CheckCase(name: "orangeTabbyRendersVisibleNativeLayers") {
        let pose = CatPose(
            activity: .sitting,
            expression: .slowBlink,
            phase: false,
            motionAllowed: false
        )
        let renderer = ImageRenderer(
            content: OrangeTabbyShape(pose: pose, highContrast: false)
                .frame(width: 160, height: 160)
        )
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let representation = image.tiffRepresentation,
              representation.count > 1_000 else {
            throw CheckFailure(description: "the layered orange tabby did not produce a visible rendered image")
        }

        if let snapshotPath = ProcessInfo.processInfo.environment["DESKTOP_CAT_SNAPSHOT_PATH"] {
            let inspectionRenderer = ImageRenderer(content: CatInspectionGrid())
            inspectionRenderer.scale = 2
            guard let inspectionImage = inspectionRenderer.nsImage,
                  let tiff = inspectionImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CheckFailure(description: "the pose inspection grid could not be encoded")
            }
            try png.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
            print("SNAPSHOT \(snapshotPath)")
        }
    },
    CheckCase(name: "catHitAreaLeavesTransparentPanelCornersDraggable") {
        let bounds = CGRect(x: 0, y: 0, width: 160, height: 160)

        guard CatHitArea.contains(CGPoint(x: 80, y: 88), in: bounds) else {
            throw CheckFailure(description: "the illustrated cat center was not interactive")
        }
        guard !CatHitArea.contains(CGPoint(x: 5, y: 5), in: bounds),
              !CatHitArea.contains(CGPoint(x: 155, y: 155), in: bounds) else {
            throw CheckFailure(description: "transparent panel corners intercepted cat gestures")
        }
    },
    CheckCase(name: "storeRoundTripsPreferences") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let expected = PetState(
            personality: .curiousExplorer,
            isMuted: true,
            reducedMotion: true
        )

        store.save(expected)

        guard store.load() == expected else {
            throw CheckFailure(description: "saved state did not round-trip through UserDefaults")
        }
    },
    CheckCase(name: "storeRoundTripsCompletePetState") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let expected = PetState(
            personality: .dignifiedSenior,
            mood: CatMood(hunger: 0.8, affection: 0.4, energy: 0.2, playfulness: 0.9),
            isMuted: true,
            isPaused: true,
            clickThrough: true,
            reducedMotion: true,
            highContrast: true,
            catScale: 1.35,
            windowOrigin: ScreenRelativePoint(x: 0.82, y: 0.18),
            windowLevel: .floating
        )

        store.save(expected)

        guard store.load() == expected else {
            throw CheckFailure(description: "care, accessibility, scale, or placement state did not round-trip")
        }
    },
    CheckCase(name: "taskSevenPreferencesRoundTripAndClampVolume") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let expected = PetState(
            soundVolume: 1.4,
            hideInFullscreen: false,
            attentionLevel: .lively
        )

        store.save(expected)
        let restored = store.load()

        guard restored.soundVolume == 1 else {
            throw CheckFailure(description: "sound volume was not clamped to the persisted 0...1 range")
        }
        guard !restored.hideInFullscreen, restored.attentionLevel == .lively else {
            throw CheckFailure(description: "fullscreen or attention preferences did not round-trip")
        }
    },
    CheckCase(name: "legacyStateUsesSafeTaskSevenDefaults") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        defaults.set(
            Data(#"{"personality":"sleepyLoaf","soundVolume":-3,"attentionLevel":"unknown"}"#.utf8),
            forKey: "pet-state"
        )
        let restored = PetStateStore(defaults: defaults).load()

        guard restored.personality == .sleepyLoaf else {
            throw CheckFailure(description: "an invalid new preference discarded valid legacy state")
        }
        guard restored.soundVolume == 0,
              restored.hideInFullscreen,
              restored.attentionLevel == .balanced else {
            throw CheckFailure(description: "legacy state did not receive safe task-seven preference defaults")
        }
    },
    CheckCase(name: "absentStoredDataReturnsSafeDefaults") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)

        guard store.load() == PetState() else {
            throw CheckFailure(description: "absent stored data did not return PetState defaults")
        }
    },
    CheckCase(name: "corruptStoredDataReturnsSafeDefaults") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        defaults.set(Data([0x00, 0xFF, 0x7F]), forKey: "pet-state")
        let store = PetStateStore(defaults: defaults)

        guard store.load() == PetState() else {
            throw CheckFailure(description: "corrupt stored data did not return PetState defaults")
        }
    },
    CheckCase(name: "partialStoredDataUsesSafeDefaults") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        defaults.set(Data(#"{"personality":"sleepyLoaf"}"#.utf8), forKey: "pet-state")
        let store = PetStateStore(defaults: defaults)
        var expected = PetState()
        expected.personality = .sleepyLoaf

        guard store.load() == expected else {
            throw CheckFailure(description: "missing fields in stored data did not use safe defaults")
        }
    },
    CheckCase(name: "encodingFailurePreservesLastValidState") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let valid = PetState(personality: .sleepyLoaf, catScale: 0.9)
        var invalid = valid
        invalid.mood.energy = .nan

        store.save(valid)
        store.save(invalid)

        guard store.load() == valid else {
            throw CheckFailure(description: "an encoding failure overwrote the last valid state")
        }
    },
    CheckCase(name: "positionIsClampedInsideVisibleFrame") {
        let frame = CGRect(x: 0, y: 0, width: 1_000, height: 700)
        let result = DesktopCatWindowController.clampedOrigin(
            CGPoint(x: 1_200, y: -50),
            windowSize: CGSize(width: 180, height: 180),
            visibleFrame: frame
        )

        guard result == CGPoint(x: 820, y: 0) else {
            throw CheckFailure(description: "expected out-of-bounds position to clamp to (820, 0), got \(result)")
        }
    },
    CheckCase(name: "oversizedWindowIsAnchoredToVisibleFrameOrigin") {
        let frame = CGRect(x: 40, y: 30, width: 100, height: 80)
        let result = DesktopCatWindowController.clampedOrigin(
            CGPoint(x: 70, y: 50),
            windowSize: CGSize(width: 180, height: 180),
            visibleFrame: frame
        )

        guard result == CGPoint(x: 40, y: 30) else {
            throw CheckFailure(description: "expected oversized window to anchor at visible-frame origin, got \(result)")
        }
    },
    CheckCase(name: "fullscreenHidingPreferenceControlsVisibilityPolicy") {
        guard !DesktopCatWindowController.shouldShow(
            requestedVisibility: true,
            isFullscreenActive: true,
            hideInFullscreen: true
        ) else {
            throw CheckFailure(description: "fullscreen hiding did not suppress a requested cat window")
        }
        guard DesktopCatWindowController.shouldShow(
            requestedVisibility: true,
            isFullscreenActive: true,
            hideInFullscreen: false
        ) else {
            throw CheckFailure(description: "disabling fullscreen hiding did not reveal the requested cat window")
        }
        guard !DesktopCatWindowController.shouldShow(
            requestedVisibility: false,
            isFullscreenActive: false,
            hideInFullscreen: false
        ) else {
            throw CheckFailure(description: "fullscreen preference overrode an explicit hide action")
        }
    },
    CheckCase(name: "fullscreenClassificationRecognizesScreenCoveringWindow") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [WorkspaceWindow(frame: screen, isOnScreen: true, layer: 0)],
            screenFrames: [screen]
        )

        guard isFullscreen else {
            throw CheckFailure(description: "expected a visible layer-zero screen-covering window to be fullscreen")
        }
    },
    CheckCase(name: "fullscreenClassificationAllowsSmallFrameTolerance") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let nearlyEqualWindow = CGRect(x: 0.5, y: -0.5, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [WorkspaceWindow(frame: nearlyEqualWindow, isOnScreen: true, layer: 0)],
            screenFrames: [screen]
        )

        guard isFullscreen else {
            throw CheckFailure(description: "expected a window within frame tolerance to be fullscreen")
        }
    },
    CheckCase(name: "fullscreenClassificationRejectsSpanningWindow") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let spanningWindow = CGRect(x: -100, y: -100, width: 3_200, height: 1_200)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [WorkspaceWindow(frame: spanningWindow, isOnScreen: true, layer: 0)],
            screenFrames: [screen]
        )

        guard !isFullscreen else {
            throw CheckFailure(description: "expected a spanning window not to be classified as fullscreen")
        }
    },
    CheckCase(name: "fullscreenClassificationIgnoresNonCoveringOrNonContentWindows") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [
                WorkspaceWindow(frame: CGRect(x: 0, y: 0, width: 1_000, height: 700), isOnScreen: true, layer: 0),
                WorkspaceWindow(frame: screen, isOnScreen: false, layer: 0),
                WorkspaceWindow(frame: screen, isOnScreen: true, layer: 3)
            ],
            screenFrames: [screen]
        )

        guard !isFullscreen else {
            throw CheckFailure(description: "expected non-covering and non-content windows not to be fullscreen")
        }
    },
    CheckCase(name: "fullscreenClassificationHidesWhenDataIsUnavailable") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: nil,
            screenFrames: [screen]
        )

        guard isFullscreen else {
            throw CheckFailure(description: "expected unavailable fullscreen data to hide the cat")
        }
    },
    CheckCase(name: "workspaceObserverRefreshesWhenFullscreenAppHides") {
        let notificationCenter = NotificationCenter()
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        var windowData: [WorkspaceWindow]? = [
            WorkspaceWindow(frame: screen, isOnScreen: true, layer: 0)
        ]
        let observer = WorkspaceObserver(
            windowDataProvider: { windowData },
            screenFrameProvider: { [screen] },
            notificationCenter: notificationCenter
        )

        guard observer.isFullscreenAppActive else {
            throw CheckFailure(description: "the fullscreen fixture did not initialize conservatively")
        }

        windowData = []
        notificationCenter.post(name: NSWorkspace.didHideApplicationNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        guard !observer.isFullscreenAppActive else {
            throw CheckFailure(description: "hiding the fullscreen application did not refresh workspace state")
        }
    }
]

@MainActor
private func selectedChecks(arguments: [String]) throws -> [CheckCase] {
    guard !arguments.isEmpty else { return checks }
    guard arguments.count == 2, arguments[0] == "--filter" else {
        throw CheckFailure(description: "usage: DesktopCatChecks [--filter <substring>]")
    }

    let filter = arguments[1]
    let selected = checks.filter { $0.name.contains(filter) }
    guard !selected.isEmpty else {
        throw CheckFailure(description: "no checks matched filter: \(filter)")
    }
    return selected
}

@MainActor
private func runChecks(arguments: [String]) -> Int32 {
    do {
        let selected = try selectedChecks(arguments: arguments)
        var failureCount = 0

        for check in selected {
            do {
                try check.run()
                print("PASS \(check.name)")
            } catch {
                failureCount += 1
                print("FAIL \(check.name): \(error)")
            }
        }

        print("SUMMARY \(selected.count - failureCount) passed, \(failureCount) failed")
        return failureCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE
    } catch {
        print("FAIL harness: \(error)")
        print("SUMMARY 0 passed, 1 failed")
        return EXIT_FAILURE
    }
}

exit(runChecks(arguments: Array(CommandLine.arguments.dropFirst())))
