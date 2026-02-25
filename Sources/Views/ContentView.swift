import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ScannerViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.needsPermission {
                PermissionRequestView()
            } else if viewModel.isScanning {
                ScanningView()
            } else if viewModel.allApps.isEmpty {
                EmptyStateView()
            } else {
                FilterToolbar()
                StatsBarView()
                Divider()
                TableHeaderView()
                Divider()
                AppListView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.rescan()
                } label: {
                    Label(
                        NSLocalizedString("Scan", comment: ""),
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(viewModel.isScanning)
            }
        }
        .onAppear {
            viewModel.checkPermissionAndScan()
        }
        .alert(
            NSLocalizedString("Permission Required", comment: ""),
            isPresented: $viewModel.permissionError
        ) {
            Button(NSLocalizedString("Grant Access", comment: "")) {
                viewModel.requestPermission()
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString(
                "FrameworkScanner needs access to the Applications folder to scan installed apps. Please grant access to continue.",
                comment: ""
            ))
        }
    }
}

// MARK: - Permission Request View

struct PermissionRequestView: View {
    @EnvironmentObject private var viewModel: ScannerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(NSLocalizedString("Access Required", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString(
                "FrameworkScanner needs access to the Applications folder to scan and identify frameworks used by your installed apps.",
                comment: ""
            ))
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 400)

            Button {
                viewModel.requestPermission()
            } label: {
                Label(
                    NSLocalizedString("Grant Access", comment: ""),
                    systemImage: "folder"
                )
                .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Scanning View

struct ScanningView: View {
    @EnvironmentObject private var viewModel: ScannerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if let icon = viewModel.scanCurrentIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .id(viewModel.scanProgress)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.scanProgress)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }

            if viewModel.scanTotal > 0 {
                VStack(spacing: 8) {
                    ProgressView(
                        value: Double(viewModel.scanCurrent),
                        total: Double(viewModel.scanTotal)
                    )
                    .progressViewStyle(.linear)
                    .frame(width: 300)

                    Text("\(viewModel.scanCurrent) / \(viewModel.scanTotal)")
                        .font(.title3)
                        .monospacedDigit()
                        .fontWeight(.medium)

                    Text(viewModel.scanProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 300)
                }
            } else {
                ProgressView()
                Text(NSLocalizedString("Preparing scan...", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @EnvironmentObject private var viewModel: ScannerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "app.dashed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("No Applications Found", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)
            Text(NSLocalizedString(
                "Try scanning again or grant access to a different directory.",
                comment: ""
            ))
            .foregroundStyle(.secondary)
            Button(NSLocalizedString("Scan Again", comment: "")) {
                viewModel.rescan()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Table Header

struct TableHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            PlainHeaderLabel(
                title: NSLocalizedString("Application", comment: ""),
                alignment: .leading
            )

            Spacer()

            TippedHeaderLabel(
                title: NSLocalizedString("Framework", comment: ""),
                tooltip: NSLocalizedString("The development framework detected inside the app bundle (e.g. Electron, SwiftUI, Qt). Electron apps also show Chromium and Node.js versions.", comment: ""),
                alignment: .trailing,
                width: 140
            )

            PlainHeaderLabel(
                title: NSLocalizedString("Size / Date", comment: ""),
                alignment: .trailing,
                width: 90
            )

            TippedHeaderLabel(
                title: NSLocalizedString("Arch", comment: ""),
                tooltip: NSLocalizedString("CPU architecture: Apple Silicon (arm64), Intel (x86_64), or Universal (both).", comment: ""),
                alignment: .center,
                width: 90
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

struct PlainHeaderLabel: View {
    let title: String
    var alignment: Alignment = .leading
    var width: CGFloat? = nil

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
    }
}

struct TippedHeaderLabel: View {
    let title: String
    let tooltip: String
    var alignment: Alignment = .leading
    var width: CGFloat? = nil

    @State private var showTip = false
    @State private var hoverTimer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Image(systemName: "questionmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .onTapGesture { showTip.toggle() }
                .onHover { hovering in
                    if hovering {
                        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            Task { @MainActor in showTip = true }
                        }
                    } else {
                        hoverTimer?.invalidate()
                        hoverTimer = nil
                    }
                }
                .popover(isPresented: $showTip, arrowEdge: .bottom) {
                    Text(tooltip)
                        .font(.caption)
                        .padding(10)
                        .frame(maxWidth: 260)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
        .frame(width: width, alignment: alignment)
    }
}

// MARK: - App List View

struct AppListView: View {
    @EnvironmentObject private var viewModel: ScannerViewModel

    var body: some View {
        List(viewModel.filteredApps) { app in
            AppRowView(app: app)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        }
        .listStyle(.inset)
    }
}
