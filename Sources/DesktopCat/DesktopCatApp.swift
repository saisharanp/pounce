import AppKit
import DesktopCatCore
import SwiftUI

@main
@MainActor
struct DesktopCatApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        _coordinator = StateObject(wrappedValue: AppCoordinator())
    }

    var body: some Scene {
        MenuBarExtra("Desktop Cat", systemImage: "cat.fill") {
            MenuBarContent(controller: coordinator.menuController)
                .onAppear { coordinator.start() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: coordinator.menuController)
                .onAppear { coordinator.start() }
        }
    }
}
