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
        WindowGroup(L("Charts"), id: "charts") {
            if #available(macOS 14.0, *) {
                ChartsWindowView()
                    .id(appState.languageRefreshId)
                    .environmentObject(appState)
                    .environmentObject(viewModel)
            } else {
                Text(L("Charts require macOS 14 or later"))
                    .padding()
                    .frame(minWidth: 300, minHeight: 200)
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 640, height: 700)

        Settings {
            SettingsView()
                .id(appState.languageRefreshId)
                .environmentObject(appState)
                .environmentObject(viewModel)
        }
    }
}
