import SwiftUI

@main
struct FrameworkScannerApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var viewModel = ScannerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(viewModel)
                .preferredColorScheme(appState.effectiveColorScheme)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 650)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
