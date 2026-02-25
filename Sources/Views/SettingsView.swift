import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker(
                    NSLocalizedString("Appearance", comment: ""),
                    selection: $appState.appearanceMode
                ) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(localizedModeName(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(NSLocalizedString("Appearance", comment: ""))
            }

            Section {
                Picker(
                    NSLocalizedString("Language", comment: ""),
                    selection: $appState.appLanguage
                ) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(NSLocalizedString("Language", comment: ""))
            }

            Section {
                HStack {
                    Text(NSLocalizedString("Version", comment: ""))
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(NSLocalizedString("Author", comment: ""))
                    Spacer()
                    Text("Geoion")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(NSLocalizedString("Feedback", comment: ""))
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
                Text(NSLocalizedString("About", comment: ""))
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 450, height: 420)
    }

    private func localizedModeName(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return NSLocalizedString("System", comment: "")
        case .light: return NSLocalizedString("Light", comment: "")
        case .dark: return NSLocalizedString("Dark", comment: "")
        }
    }
}
