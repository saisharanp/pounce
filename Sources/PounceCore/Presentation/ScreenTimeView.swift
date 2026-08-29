import SwiftUI

@MainActor
public struct ScreenTimeView: View {
    @ObservedObject private var controller: MenuBarController
    @ObservedObject private var viewModel: CatViewModel

    public init(controller: MenuBarController) {
        self.controller = controller
        _viewModel = ObservedObject(wrappedValue: controller.viewModel)
    }

    public var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let summary = ScreenTimeCalculator.summary(sessions: viewModel.state.screenTimeSessions, from: today, until: Date())
        VStack(alignment: .leading, spacing: 12) {
            Text("Pounce Screen Time").font(.title2.bold())
            Text("Tracks only Pounce sessions on this Mac. It does not read other apps, keystrokes, screenshots, or Apple’s private Screen Time database.")
                .font(.callout).foregroundStyle(.secondary)
            LabeledContent("Today", value: "\(Int(summary.totalSeconds / 60)) min")
            LabeledContent("Sessions", value: "\(summary.sessionCount)")
            Button(controller.isScreenTimeActive ? "Stop Session" : "Start Session", action: controller.toggleScreenTime)
            Button("Clear Local History", role: .destructive, action: controller.clearScreenTimeHistory)
        }
        .padding(20)
        .frame(width: 420)
    }
}
