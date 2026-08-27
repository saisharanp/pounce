import AppKit
import Combine
import Foundation
import SwiftUI

public enum DesktopCatKeyboardAction: String, CaseIterable, Sendable {
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

    public let viewModel: CatViewModel

    private let soundController: CatSoundController
    private var onSetVisibility: (Bool) -> Void
    private var onSetClickThrough: (Bool) -> Void
    private var onSetWindowLevel: (PetWindowLevel) -> Void
    private var onSetHideInFullscreen: (Bool) -> Void
    private var onSetPaused: (Bool) -> Void
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
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.soundController = soundController
        self.isVisible = isVisible
        self.onSetVisibility = onSetVisibility
        self.onSetClickThrough = onSetClickThrough
        self.onSetWindowLevel = onSetWindowLevel
        self.onSetHideInFullscreen = onSetHideInFullscreen
        self.onSetPaused = onSetPaused
        self.onOpenSettings = onOpenSettings
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
    }

    public func handle(_ interaction: CatInteraction) {
        let reaction = viewModel.handle(interaction)
        playSound(for: interaction, reaction: reaction)
    }

    public func openSettings() {
        onOpenSettings()
    }

    public func connect(windowController: DesktopCatWindowController) {
        onSetVisibility = { [weak windowController] in windowController?.setVisible($0) }
        onSetClickThrough = { [weak windowController] in windowController?.setClickThrough($0) }
        onSetWindowLevel = { [weak windowController] in windowController?.setWindowLevel($0) }
        onSetHideInFullscreen = { [weak windowController] in
            windowController?.setHideInFullscreen($0)
        }
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
                Label("Desktop Cat", systemImage: "cat.fill")
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
