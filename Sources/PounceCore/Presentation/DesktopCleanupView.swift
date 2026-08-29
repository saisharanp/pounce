import SwiftUI

@MainActor
public struct DesktopCleanupView: View {
    @ObservedObject private var controller: MenuBarController
    @State private var selectedIDs: Set<String> = []

    public init(controller: MenuBarController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clean Up Desktop")
                .font(.title2.bold())
            Text("Pounce only suggests visible files directly on your Desktop. Nothing is deleted permanently; approved items move to the Trash.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let error = controller.cleanupError {
                Text(error).foregroundStyle(.red)
            }
            if controller.cleanupCandidates.isEmpty {
                ContentUnavailableView("No candidates", systemImage: "checkmark.circle", description: Text("Scan your Desktop to preview safe cleanup candidates."))
            } else {
                List(controller.cleanupCandidates) { candidate in
                    Toggle(isOn: selectionBinding(for: candidate)) {
                        VStack(alignment: .leading) {
                            Text(candidate.name)
                            Text("\(candidate.reason) · \(ByteCountFormatter.string(fromByteCount: candidate.byteCount, countStyle: .file))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            HStack {
                Button("Scan Desktop", action: controller.scanDesktop)
                Spacer()
                Button("Move Selected to Trash") {
                    controller.moveCleanupCandidatesToTrash(controller.cleanupCandidates.filter { selectedIDs.contains($0.id) })
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
                Button("Done") { controller.isCleanupPresented = false }
            }
        }
        .padding(20)
        .frame(width: 560, height: 460)
        .onAppear(perform: controller.scanDesktop)
    }

    private func selectionBinding(for candidate: DesktopCleanupCandidate) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(candidate.id) },
            set: { selected in
                if selected { selectedIDs.insert(candidate.id) } else { selectedIDs.remove(candidate.id) }
            }
        )
    }
}
