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
                    .fixedSize(horizontal: false, vertical: true)
                StatsBarView()
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                TableHeaderView()
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                AppListView()
                    .frame(maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.rescan()
                } label: {
                    Label(L("Scan"), systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.exportAsCSV()
                    } label: {
                        Label(L("Export as CSV"), systemImage: "tablecells")
                    }
                    Button {
                        viewModel.exportAsJSON()
                    } label: {
                        Label(L("Export as JSON"), systemImage: "curlybraces")
                    }
                } label: {
                    Label(L("Export"), systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.filteredApps.isEmpty)
            }
        }
        .onAppear {
            viewModel.checkPermissionAndScan()
        }
        .alert(
            L("Permission Required"),
            isPresented: $viewModel.permissionError
        ) {
            Button(L("Grant Access")) {
                viewModel.requestPermission()
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("FrameworkScanner needs access to the Applications folder to scan installed apps. Please grant access to continue."))
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

            Text(L("Access Required"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(L("FrameworkScanner needs access to the Applications folder to scan and identify frameworks used by your installed apps."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            Button {
                viewModel.requestPermission()
            } label: {
                Label(L("Grant Access"), systemImage: "folder")
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
                VStack(spacing: 6) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    Text(viewModel.scanProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 200)
                }
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
                }
            } else {
                ProgressView()
                Text(L("Preparing scan..."))
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
            Text(L("No Applications Found"))
                .font(.title2)
                .fontWeight(.semibold)
            Text(L("Try scanning again or grant access to a different directory."))
                .foregroundStyle(.secondary)
            Button(L("Scan Again")) {
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
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            PlainHeaderLabel(
                title: L("Application"),
                alignment: .leading
            )

            Spacer()

            TippedHeaderLabel(
                title: L("Framework"),
                tooltip: L("The development framework detected inside the app bundle (e.g. Electron, SwiftUI, Qt). Electron apps also show Chromium and Node.js versions."),
                alignment: .trailing,
                width: 140
            )

            PlainHeaderLabel(
                title: L("Size / Date"),
                alignment: .trailing,
                width: 90
            )

            TippedHeaderLabel(
                title: L("Arch"),
                tooltip: L("CPU architecture: Apple Silicon (arm64), Intel (x86_64), or Universal (both)."),
                alignment: .center,
                width: 90
            )

            Color.clear.frame(width: 20)
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredApps) { app in
                    AppRowView(app: app)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    Divider().padding(.leading, 12)
                }
            }
        }
    }
}
