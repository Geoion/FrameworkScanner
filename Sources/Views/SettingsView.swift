import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker(
                    L("Appearance"),
                    selection: $appState.appearanceMode
                ) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(localizedModeName(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L("Appearance"))
            }

            Section {
                Picker(
                    L("Language"),
                    selection: $appState.appLanguage
                ) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            } header: {
                Text(L("Language"))
            }

            Section {
                HStack {
                    Text(L("Version"))
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("Author"))
                    Spacer()
                    Text("Geoion")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("Feedback"))
                    Spacer()
                    Button {
                        let subject = "FrameworkScanner Feedback"
                        let mailto = "mailto:eski.yin@gmail.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
                        if let url = URL(string: mailto) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("eski.yin@gmail.com", systemImage: "envelope")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }
            } header: {
                Text(L("About"))
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 450, height: 420)
    }

    private func localizedModeName(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return L("System")
        case .light: return L("Light")
        case .dark: return L("Dark")
        }
    }
}
