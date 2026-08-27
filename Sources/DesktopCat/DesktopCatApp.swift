import AppKit
import DesktopCatCore
import SwiftUI

@main
@MainActor
struct DesktopCatApp: App {
    @StateObject private var menuController: MenuBarController
    private let windowController: DesktopCatWindowController

    init() {
        let store = PetStateStore()
        let viewModel = CatViewModel(store: store)
        let menuController = MenuBarController(
            viewModel: viewModel,
            onOpenSettings: {
                NSApplication.shared.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
            }
        )
        let windowController = DesktopCatWindowController(
            state: viewModel.state,
            viewModel: viewModel,
            menuController: menuController
        )

        _menuController = StateObject(wrappedValue: menuController)
        self.windowController = windowController
    }

    var body: some Scene {
        MenuBarExtra("Desktop Cat", systemImage: "cat.fill") {
            MenuBarContent(controller: menuController)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: menuController)
        }
    }
}
