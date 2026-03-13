import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ScannerViewModel

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
                Toggle(L("Recursive Scan"), isOn: $viewModel.recursiveScanEnabled)

                Picker(L("Max Depth"), selection: $viewModel.maxScanDepth) {
                    Text("2").tag(2)
                    Text("3").tag(3)
                    Text("4").tag(4)
                    Text("5").tag(5)
                }
                .disabled(!viewModel.recursiveScanEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Excluded Folders"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.excludedDirectoryPaths.isEmpty {
                        Text(L("No excluded folders"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.excludedDirectoryPaths, id: \.self) { path in
                            HStack(spacing: 8) {
                                Text(path)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(L("Remove")) {
                                    viewModel.removeExcludedDirectory(path)
                                }
                                .buttonStyle(.borderless)
                                .font(.caption2)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 8) {
                    Button(L("Add Excluded Folder...")) {
                        viewModel.addExcludedDirectory()
                    }
                    Button(L("Clear Exclusions")) {
                        viewModel.clearExcludedDirectories()
                    }
                    .disabled(viewModel.excludedDirectoryPaths.isEmpty)
                    Spacer()
                    Button(L("Reset Scope Defaults")) {
                        viewModel.resetScanScopeToDefaults()
                    }
                    .disabled(
                        !viewModel.recursiveScanEnabled &&
                        viewModel.maxScanDepth == 2 &&
                        viewModel.excludedDirectoryPaths.isEmpty
                    )
                }
            } header: {
                Text(L("Scope"))
            }

            Section {
                let status = viewModel.securityDataStatus

                HStack {
                    Text(L("Rules Version"))
                    Spacer()
                    Text(status.version)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("Last Reviewed"))
                    Spacer()
                    Text(status.lastReviewedAt)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("Data Age"))
                    Spacer()
                    Text("\(status.daysSinceReview) \(L("days"))")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("Reminder Threshold"))
                    Spacer()
                    Text("\(status.reminderThresholdDays) \(L("days"))")
                        .foregroundStyle(.secondary)
                }

                if let reminder = viewModel.securityReleaseReminderMessage {
                    Text(reminder)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text(L("Security Intelligence"))
            }

            Section {
                HStack {
                    Text(L("Version"))
                    Spacer()
                    Text(appState.currentAppVersion)
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
                Text(L("Updates are handled in the App Store."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L("About"))
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(false)
        .frame(width: 500, height: 560)
    }

    private func localizedModeName(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return L("System")
        case .light: return L("Light")
        case .dark: return L("Dark")
        }
    }
}
