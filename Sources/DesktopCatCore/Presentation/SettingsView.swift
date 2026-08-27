import SwiftUI

public extension CatPersonality {
    var displayName: String {
        switch self {
        case .playfulKitten: "Playful Kitten"
        case .sleepyLoaf: "Sleepy Loaf"
        case .curiousExplorer: "Curious Explorer"
        case .dignifiedSenior: "Dignified Senior"
        }
    }
}

public extension AttentionLevel {
    var displayName: String {
        switch self {
        case .calm: "Calm"
        case .balanced: "Balanced"
        case .lively: "Lively"
        }
    }
}

public extension CatActivity {
    var displayName: String {
        switch self {
        case .lookingAround: "Looking Around"
        default: rawValue.capitalized
        }
    }
}

public struct SettingsView: View {
    @ObservedObject private var controller: MenuBarController
    @ObservedObject private var viewModel: CatViewModel

    public init(controller: MenuBarController) {
        self.controller = controller
        _viewModel = ObservedObject(wrappedValue: controller.viewModel)
    }

    public var body: some View {
        Form {
            Section("Companion") {
                HStack {
                    Button("Summon", systemImage: "sparkles", action: controller.summon)
                        .disabled(controller.isVisible)
                    Button("Hide", systemImage: "eye.slash", action: controller.hide)
                        .disabled(!controller.isVisible)
                    Toggle("Paused", isOn: pausedBinding)
                }

                Picker("Personality", selection: personalityBinding) {
                    ForEach(CatPersonality.allCases, id: \.self) { personality in
                        Text(personality.displayName).tag(personality)
                    }
                }
                Picker("Attention level", selection: attentionBinding) {
                    ForEach(AttentionLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                Picker("Window level", selection: windowLevelBinding) {
                    Text("Desktop").tag(PetWindowLevel.desktop)
                    Text("Floating").tag(PetWindowLevel.floating)
                }
                Toggle("Click through", isOn: clickThroughBinding)
                Toggle("Hide in fullscreen", isOn: hideInFullscreenBinding)
            }

            Section("Play") {
                HStack(spacing: 8) {
                    ForEach(CatToy.allCases) { toy in
                        Button {
                            controller.selectToy(toy)
                            controller.summon()
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: toy.systemImage)
                                Text(toy.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                                .frame(maxWidth: .infinity)
                        }
                        .help(toy.displayName)
                    }
                }
                CareMetersView(mood: viewModel.state.mood)
            }

            Section("Sound") {
                Toggle("Mute sounds", isOn: mutedBinding)
                LabeledContent("Volume") {
                    Slider(value: volumeBinding, in: 0...1)
                        .frame(maxWidth: 260)
                }
                .disabled(viewModel.state.isMuted)
            }

            Section("Appearance & Accessibility") {
                LabeledContent("Cat size") {
                    Slider(value: catScaleBinding, in: 0.65...1.3)
                        .frame(maxWidth: 260)
                }
                Toggle("Reduced motion", isOn: reducedMotionBinding)
                Toggle("High contrast", isOn: highContrastBinding)
            }

            Section("Keyboard Shortcuts") {
                ForEach(DesktopCatKeyboardAction.allCases, id: \.self) { action in
                    LabeledContent(action.title) {
                        Text("⇧⌘\(action.key)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 560)
    }

    private var pausedBinding: Binding<Bool> {
        Binding(get: { viewModel.state.isPaused }, set: { controller.setPaused($0) })
    }

    private var mutedBinding: Binding<Bool> {
        Binding(get: { viewModel.state.isMuted }, set: { controller.setMuted($0) })
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
        Binding(
            get: { viewModel.state.soundVolume },
            set: { newValue in controller.setSoundVolume(newValue) }
        )
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

@MainActor
struct CareMetersView: View {
    let mood: CatMood

    var body: some View {
        VStack(spacing: 5) {
            CareMeterRow(label: "Hunger", systemImage: "fork.knife", value: mood.hunger)
            CareMeterRow(label: "Affection", systemImage: "heart.fill", value: mood.affection)
            CareMeterRow(label: "Energy", systemImage: "bolt.fill", value: mood.energy)
            CareMeterRow(label: "Play", systemImage: "figure.play", value: mood.playfulness)
        }
    }
}

private struct CareMeterRow: View {
    let label: String
    let systemImage: String
    let value: Double

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage)
                .frame(width: 94, alignment: .leading)
            ProgressView(value: min(max(value, 0), 1))
            Text("\(Int(min(max(value, 0), 1) * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

@MainActor
struct CatContextMenuContent: View {
    @ObservedObject private var controller: MenuBarController
    @ObservedObject private var viewModel: CatViewModel

    init(controller: MenuBarController) {
        self.controller = controller
        _viewModel = ObservedObject(wrappedValue: controller.viewModel)
    }

    var body: some View {
        Button("Summon", systemImage: "sparkles", action: controller.summon)
        Button("Hide", systemImage: "eye.slash", action: controller.hide)
        Divider()
        Button(
            viewModel.state.isPaused ? "Resume" : "Pause",
            systemImage: viewModel.state.isPaused ? "play.fill" : "pause.fill",
            action: controller.togglePause
        )
        Button(
            viewModel.state.isMuted ? "Unmute" : "Mute",
            systemImage: viewModel.state.isMuted ? "speaker.wave.2" : "speaker.slash",
            action: controller.toggleMuted
        )
        Toggle("Click Through", isOn: clickThroughBinding)

        Menu("Window Level", systemImage: "macwindow.on.rectangle") {
            ForEach([PetWindowLevel.desktop, .floating], id: \.self) { level in
                Button(level == .desktop ? "Desktop" : "Floating") {
                    controller.setWindowLevel(level)
                }
            }
        }
        Menu("Play", systemImage: "tennisball.fill") {
            ForEach(CatToy.allCases) { toy in
                Button(toy.displayName, systemImage: toy.systemImage) {
                    controller.selectToy(toy)
                }
            }
        }
        Menu("Personality", systemImage: "cat.fill") {
            ForEach(CatPersonality.allCases, id: \.self) { personality in
                Button(personality.displayName) { controller.setPersonality(personality) }
            }
        }
        Menu("Care Meters", systemImage: "heart.text.square") {
            Text("Hunger \(percentage(viewModel.state.mood.hunger))")
            Text("Affection \(percentage(viewModel.state.mood.affection))")
            Text("Energy \(percentage(viewModel.state.mood.energy))")
            Text("Play \(percentage(viewModel.state.mood.playfulness))")
        }
        Menu("Attention", systemImage: "sparkle.magnifyingglass") {
            ForEach(AttentionLevel.allCases, id: \.self) { level in
                Button(level.displayName) { controller.setAttentionLevel(level) }
            }
        }
        Toggle("Hide in Fullscreen", isOn: hideInFullscreenBinding)
        Menu("Volume", systemImage: "speaker.wave.2") {
            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { volume in
                Button("\(Int(volume * 100))%") { controller.setSoundVolume(volume) }
            }
        }
        Menu("Cat Size", systemImage: "arrow.up.left.and.arrow.down.right") {
            Button("Small") { controller.setCatScale(0.75) }
            Button("Medium") { controller.setCatScale(1) }
            Button("Large") { controller.setCatScale(1.3) }
        }
        Toggle("Reduced Motion", isOn: reducedMotionBinding)
        Toggle("High Contrast", isOn: highContrastBinding)
        Divider()
        Button("Settings…", systemImage: "gearshape", action: controller.openSettings)
    }

    private var clickThroughBinding: Binding<Bool> {
        Binding(get: { viewModel.state.clickThrough }, set: { controller.setClickThrough($0) })
    }

    private var hideInFullscreenBinding: Binding<Bool> {
        Binding(get: { viewModel.state.hideInFullscreen }, set: { controller.setHideInFullscreen($0) })
    }

    private var reducedMotionBinding: Binding<Bool> {
        Binding(get: { viewModel.state.reducedMotion }, set: { controller.setReducedMotion($0) })
    }

    private var highContrastBinding: Binding<Bool> {
        Binding(get: { viewModel.state.highContrast }, set: { controller.setHighContrast($0) })
    }

    private func percentage(_ value: Double) -> String {
        "\(Int(min(max(value, 0), 1) * 100))%"
    }
}
