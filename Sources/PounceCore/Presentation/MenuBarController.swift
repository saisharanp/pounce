import AppKit
import Combine
import Foundation
import SwiftUI

public enum PounceKeyboardAction: String, CaseIterable, Sendable {
    case summonOrHide
    case pauseOrResume
    case muteOrUnmute

    public var title: String {
        switch self {
        case .summonOrHide: "Summon or Hide"
        case .pauseOrResume: "Pause or Resume"
        case .muteOrUnmute: "Mute or Unmute"
        }
    }

    public var key: String {
        switch self {
        case .summonOrHide: "C"
        case .pauseOrResume: "P"
        case .muteOrUnmute: "M"
        }
    }

    public var modifierDescription: String { "Command-Shift" }
}

@MainActor
public final class MenuBarController: ObservableObject {
    @Published public private(set) var isVisible: Bool
    @Published public private(set) var cleanupCandidates: [DesktopCleanupCandidate] = []
    @Published public var isCleanupPresented = false
    @Published public var isScreenTimePresented = false
    @Published public private(set) var cleanupError: String?
    @Published public private(set) var isScreenTimeActive = false

    public let viewModel: CatViewModel

    private let soundController: CatSoundController
    private let cleanupService: DesktopCleanupService
    private let clock: () -> Date
    private let reminderScheduler: ScreenTimeReminderScheduling
    private var screenTimeStartedAt: Date?
    private var onSetVisibility: (Bool) -> Void
    private var onSetClickThrough: (Bool) -> Void
    private var onSetWindowLevel: (PetWindowLevel) -> Void
    private var onSetHideInFullscreen: (Bool) -> Void
    private var onSetPaused: (Bool) -> Void
    private var onMoveWindow: (CGSize) -> Void
    private var onDragStateChanged: (Bool) -> Void
    private var onSetAttentionLevel: (AttentionLevel) -> Void
    private var onDirectReaction: () -> Void
    private var onOpenSettings: () -> Void

    public init(
        viewModel: CatViewModel,
        soundController: CatSoundController = CatSoundController(),
        isVisible: Bool = true,
        onSetVisibility: @escaping (Bool) -> Void = { _ in },
        onSetClickThrough: @escaping (Bool) -> Void = { _ in },
        onSetWindowLevel: @escaping (PetWindowLevel) -> Void = { _ in },
        onSetHideInFullscreen: @escaping (Bool) -> Void = { _ in },
        onSetPaused: @escaping (Bool) -> Void = { _ in },
        onMoveWindow: @escaping (CGSize) -> Void = { _ in },
        onDragStateChanged: @escaping (Bool) -> Void = { _ in },
        onSetAttentionLevel: @escaping (AttentionLevel) -> Void = { _ in },
        onDirectReaction: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        cleanupService: DesktopCleanupService = DesktopCleanupService(),
        clock: @escaping () -> Date = Date.init,
        reminderScheduler: ScreenTimeReminderScheduling = NoopScreenTimeReminderScheduler()
    ) {
        self.viewModel = viewModel
        self.soundController = soundController
        self.isVisible = isVisible
        self.onSetVisibility = onSetVisibility
        self.onSetClickThrough = onSetClickThrough
        self.onSetWindowLevel = onSetWindowLevel
        self.onSetHideInFullscreen = onSetHideInFullscreen
        self.onSetPaused = onSetPaused
        self.onMoveWindow = onMoveWindow
        self.onDragStateChanged = onDragStateChanged
        self.onSetAttentionLevel = onSetAttentionLevel
        self.onDirectReaction = onDirectReaction
        self.onOpenSettings = onOpenSettings
        self.cleanupService = cleanupService
        self.clock = clock
        self.reminderScheduler = reminderScheduler
    }

    public func summon() {
        setVisible(true)
    }

    public func hide() {
        setVisible(false)
    }

    public func toggleVisibility() {
        setVisible(!isVisible)
    }

    public func togglePause() {
        setPaused(!viewModel.state.isPaused)
    }

    public func setPaused(_ paused: Bool) {
        viewModel.setPaused(paused)
        onSetPaused(paused)
    }

    public func toggleMuted() {
        setMuted(!viewModel.state.isMuted)
    }

    public func setMuted(_ muted: Bool) {
        viewModel.updateState { $0.isMuted = muted }
        if muted {
            soundController.stop()
        }
    }

    public func setClickThrough(_ enabled: Bool) {
        viewModel.updateState { $0.clickThrough = enabled }
        onSetClickThrough(enabled)
    }

    public func setWindowLevel(_ level: PetWindowLevel) {
        viewModel.updateState { $0.windowLevel = level }
        onSetWindowLevel(level)
    }

    public func setPersonality(_ personality: CatPersonality) {
        viewModel.updateState { $0.personality = personality }
    }

    public func setAttentionLevel(_ level: AttentionLevel) {
        viewModel.updateState { $0.attentionLevel = level }
        onSetAttentionLevel(level)
    }

    public func setHideInFullscreen(_ enabled: Bool) {
        viewModel.updateState { $0.hideInFullscreen = enabled }
        onSetHideInFullscreen(enabled)
    }

    public func setSoundVolume(_ volume: Double) {
        viewModel.updateState { $0.soundVolume = PetState.clampedVolume(volume) }
    }

    public func setCatScale(_ scale: Double) {
        viewModel.updateState { $0.catScale = min(max(scale, 0.65), 1.3) }
    }

    public func setReducedMotion(_ enabled: Bool) {
        viewModel.updateState { $0.reducedMotion = enabled }
    }

    public func setHighContrast(_ enabled: Bool) {
        viewModel.updateState { $0.highContrast = enabled }
    }

    public func selectToy(_ toy: CatToy) {
        viewModel.selectToy(toy)
    }

    public func cancelSelectedToy() {
        viewModel.selectToy(nil)
    }

    public func completeSelectedToy() {
        guard let toy = viewModel.selectedToy,
              let reaction = viewModel.completeSelectedToy() else { return }
        playSound(for: toy.interaction, reaction: reaction)
        onDirectReaction()
    }

    public func handle(_ interaction: CatInteraction) {
        let reaction = viewModel.handle(interaction)
        playSound(for: interaction, reaction: reaction)
        onDirectReaction()
    }

    public func openSettings() {
        onOpenSettings()
    }

    public func openCleanup() {
        cleanupError = nil
        cleanupCandidates = []
        isCleanupPresented = true
    }

    public func scanDesktop() {
        switch cleanupService.preview() {
        case let .success(candidates):
            cleanupCandidates = candidates
            cleanupError = nil
        case let .failure(error):
            cleanupCandidates = []
            cleanupError = error.localizedDescription
        }
    }

    public func moveCleanupCandidatesToTrash(_ candidates: [DesktopCleanupCandidate]) {
        let results = cleanupService.moveToTrash(candidates)
        let errors = results.compactMap { result -> String? in
            if case let .failure(error) = result { return error.localizedDescription }
            return nil
        }
        cleanupError = errors.isEmpty ? nil : errors.joined(separator: "\n")
        cleanupCandidates.removeAll { candidate in
            results.contains { result in
                if case let .success(url) = result { return url == candidate.url }
                return false
            }
        }
    }

    public func toggleScreenTime() {
        if let startedAt = screenTimeStartedAt {
            let session = ScreenTimeSession(startedAt: startedAt, endedAt: clock())
            viewModel.updateState { $0.screenTimeSessions.append(session) }
            screenTimeStartedAt = nil
            isScreenTimeActive = false
            reminderScheduler.cancelBreakReminder()
        } else {
            screenTimeStartedAt = clock()
            isScreenTimeActive = true
            reminderScheduler.requestAuthorization()
            reminderScheduler.scheduleBreakReminder(
                after: TimeInterval(viewModel.state.breakIntervalMinutes * 60)
            )
        }
    }

    public func clearScreenTimeHistory() {
        viewModel.updateState { $0.screenTimeSessions.removeAll() }
    }

    public func setRoamingEnabled(_ enabled: Bool) {
        viewModel.updateState { $0.roamingEnabled = enabled }
    }

    public func moveWindow(by delta: CGSize) {
        onMoveWindow(delta)
    }

    public func setDragging(_ enabled: Bool) {
        onDragStateChanged(enabled)
    }

    public func setScreenTimeEnabled(_ enabled: Bool) {
        viewModel.updateState { $0.screenTimeEnabled = enabled }
        if !enabled, isScreenTimeActive { toggleScreenTime() }
    }

    public func connect(windowController: PounceWindowController) {
        onSetVisibility = { [weak windowController] in windowController?.setVisible($0) }
        onSetClickThrough = { [weak windowController] in windowController?.setClickThrough($0) }
        onSetWindowLevel = { [weak windowController] in windowController?.setWindowLevel($0) }
        onSetHideInFullscreen = { [weak windowController] in
            windowController?.setHideInFullscreen($0)
        }
        onMoveWindow = { [weak windowController] in windowController?.moveWindow(by: $0) }
        onDragStateChanged = { [weak windowController] in windowController?.setDraggingAnimation($0) }
    }

    private func setVisible(_ visible: Bool) {
        isVisible = visible
        onSetVisibility(visible)
    }

    private func playSound(for interaction: CatInteraction, reaction: CatReaction) {
        guard let sound = CatSoundController.sound(for: interaction, reaction: reaction) else {
            return
        }
        soundController.play(
            sound,
            isMuted: viewModel.state.isMuted,
            volume: viewModel.state.soundVolume
        )
    }
}

@MainActor
public struct MenuBarContent: View {
    @ObservedObject private var controller: MenuBarController
    @ObservedObject private var viewModel: CatViewModel

    public init(controller: MenuBarController) {
        self.controller = controller
        _viewModel = ObservedObject(wrappedValue: controller.viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Pounce", systemImage: "cat.fill")
                    .font(.headline)
                Spacer()
                Text(viewModel.state.isPaused ? "Paused" : viewModel.activity.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    controller.toggleVisibility()
                } label: {
                    Label(
                        controller.isVisible ? "Hide" : "Summon",
                        systemImage: controller.isVisible ? "eye.slash" : "sparkles"
                    )
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button {
                    controller.togglePause()
                } label: {
                    Label(
                        viewModel.state.isPaused ? "Resume" : "Pause",
                        systemImage: viewModel.state.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button {
                    controller.toggleMuted()
                } label: {
                    Label(
                        viewModel.state.isMuted ? "Unmute" : "Mute",
                        systemImage: viewModel.state.isMuted ? "speaker.wave.2" : "speaker.slash"
                    )
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
            .buttonStyle(.bordered)

            Divider()

            HStack(spacing: 8) {
                ForEach(CatToy.allCases) { toy in
                    Button {
                        controller.selectToy(toy)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: toy.systemImage)
                            Text(toy.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .help("Select \(toy.displayName.lowercased())")
                }
            }
            .buttonStyle(.bordered)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Personality")
                    Picker("Personality", selection: personalityBinding) {
                        ForEach(CatPersonality.allCases, id: \.self) { personality in
                            Text(personality.displayName).tag(personality)
                        }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Attention")
                    Picker("Attention", selection: attentionBinding) {
                        ForEach(AttentionLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Window level")
                    Picker("Window level", selection: windowLevelBinding) {
                        Text("Desktop").tag(PetWindowLevel.desktop)
                        Text("Floating").tag(PetWindowLevel.floating)
                    }
                    .labelsHidden()
                }
            }

            Toggle("Click Through", isOn: clickThroughBinding)
            Toggle("Hide in Fullscreen", isOn: hideInFullscreenBinding)

            VStack(alignment: .leading, spacing: 5) {
                Label("Volume", systemImage: "speaker.wave.2")
                Slider(value: volumeBinding, in: 0...1)
                    .disabled(viewModel.state.isMuted)
            }

            VStack(alignment: .leading, spacing: 5) {
                Label("Cat Size", systemImage: "arrow.up.left.and.arrow.down.right")
                Slider(value: catScaleBinding, in: 0.65...1.3)
            }

            HStack {
                Toggle("Reduced Motion", isOn: reducedMotionBinding)
                Toggle("High Contrast", isOn: highContrastBinding)
            }

            CareMetersView(mood: viewModel.state.mood)

            HStack {
                Button("Clean Up Desktop…", systemImage: "sparkles") { controller.openCleanup() }
                Button("Screen Time…", systemImage: "timer") { controller.isScreenTimePresented = true }
            }

            HStack {
                SettingsLink {
                    Label("Settings…", systemImage: "gearshape")
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 330)
        .background(.regularMaterial)
        .sheet(isPresented: $controller.isCleanupPresented) {
            DesktopCleanupView(controller: controller)
        }
        .sheet(isPresented: $controller.isScreenTimePresented) {
            ScreenTimeView(controller: controller)
        }
    }

    private var personalityBinding: Binding<CatPersonality> {
        Binding(get: { viewModel.state.personality }, set: { controller.setPersonality($0) })
    }

    private var attentionBinding: Binding<AttentionLevel> {
        Binding(get: { viewModel.state.attentionLevel }, set: { controller.setAttentionLevel($0) })
    }

    private var windowLevelBinding: Binding<PetWindowLevel> {
        Binding(get: { viewModel.state.windowLevel }, set: { controller.setWindowLevel($0) })
    }

    private var clickThroughBinding: Binding<Bool> {
        Binding(get: { viewModel.state.clickThrough }, set: { controller.setClickThrough($0) })
    }

    private var hideInFullscreenBinding: Binding<Bool> {
        Binding(get: { viewModel.state.hideInFullscreen }, set: { controller.setHideInFullscreen($0) })
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { viewModel.state.soundVolume }, set: { controller.setSoundVolume($0) })
    }

    private var catScaleBinding: Binding<Double> {
        Binding(get: { viewModel.state.catScale }, set: { controller.setCatScale($0) })
    }

    private var reducedMotionBinding: Binding<Bool> {
        Binding(get: { viewModel.state.reducedMotion }, set: { controller.setReducedMotion($0) })
    }

    private var highContrastBinding: Binding<Bool> {
        Binding(get: { viewModel.state.highContrast }, set: { controller.setHighContrast($0) })
    }
}
