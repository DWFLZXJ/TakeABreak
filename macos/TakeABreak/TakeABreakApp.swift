import SwiftUI

@main
struct TakeABreakApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView()
                .environmentObject(model)
        } label: {
            // Text label updates as model publishes (mm:ss while running)
            Text(model.menuBarTitle)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(model)
        }
    }
}
