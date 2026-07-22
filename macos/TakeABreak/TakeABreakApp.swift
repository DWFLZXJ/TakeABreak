import AppKit
import SwiftUI

@main
struct TakeABreakApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView()
                .environmentObject(model)
        } label: {
            Label {
                // When working/paused/breaking, show remaining time next to icon
                if model.state.phase != .idle {
                    Text(model.menuBarTitle)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            } icon: {
                Image(systemName: menuBarSymbol)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("偏好设置…") {
                    model.openPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appTermination) {
                Button("退出 Take a Break") {
                    model.quit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }

    private var menuBarSymbol: String {
        switch model.state.phase {
        case .idle:
            return "cup.and.saucer"
        case .working:
            return "timer"
        case .paused:
            return "pause.circle"
        case .breaking:
            return "leaf"
        }
    }
}
