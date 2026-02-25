import SwiftUI

@main
struct FrameworkScannerApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var viewModel = ScannerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(appState.languageRefreshId)
                .environmentObject(appState)
                .environmentObject(viewModel)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 650)

        Settings {
            SettingsView()
                .id(appState.languageRefreshId)
                .environmentObject(appState)
        }
    }
}
