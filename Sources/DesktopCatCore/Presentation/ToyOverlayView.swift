import SwiftUI

public enum CatToy: String, CaseIterable, Identifiable, Sendable {
    case laser
    case yarn
    case feather
    case paperBall
    case treat

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .laser: "Laser"
        case .yarn: "Yarn"
        case .feather: "Feather"
        case .paperBall: "Paper Ball"
        case .treat: "Treat"
        }
    }

    public var systemImage: String {
        switch self {
        case .laser: "scope"
        case .yarn: "circle.grid.cross"
        case .feather: "leaf.fill"
        case .paperBall: "doc.fill"
        case .treat: "fish.fill"
        }
    }

    public var interaction: CatInteraction {
        switch self {
        case .laser: .laser
        case .yarn: .yarn
        case .feather: .feather
        case .paperBall: .paperBall
        case .treat: .treat
        }
    }
}

public struct ToyOverlayView: View {
    public let selectedToy: CatToy?
    public let reducedMotion: Bool
    public let onCompleted: () -> Void

    @State private var dragOffset: CGSize = .zero

    public init(
        selectedToy: CatToy?,
        reducedMotion: Bool,
        onCompleted: @escaping () -> Void
    ) {
        self.selectedToy = selectedToy
        self.reducedMotion = reducedMotion
        self.onCompleted = onCompleted
    }

    public var body: some View {
        ZStack {
            if let selectedToy {
                toyView(selectedToy)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .offset(
                        x: 34 + dragOffset.width,
                        y: 34 + dragOffset.height
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { dragOffset = $0.translation }
                            .onEnded { _ in
                                dragOffset = .zero
                                onCompleted()
                            }
                    )
                    .transition(reducedMotion ? .identity : .scale.combined(with: .opacity))
                    .accessibilityLabel(selectedToy.displayName)
                    .accessibilityHint("Interact to play with the cat")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reducedMotion ? nil : .spring(duration: 0.24), value: selectedToy)
    }

    @ViewBuilder
    private func toyView(_ toy: CatToy) -> some View {
        if toy == .laser {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.18))
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                    .shadow(color: .red, radius: 6)
            }
        } else {
            ZStack {
                Circle()
                    .fill(backgroundColor(for: toy).gradient)
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 2)
                Image(systemName: toy.systemImage)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.24), radius: 3, y: 2)
        }
    }

    private func backgroundColor(for toy: CatToy) -> Color {
        switch toy {
        case .laser: .red
        case .yarn: .purple
        case .feather: .teal
        case .paperBall: .gray
        case .treat: .orange
        }
    }
}
