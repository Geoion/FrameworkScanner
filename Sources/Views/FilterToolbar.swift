import SwiftUI

struct FilterToolbar: View {
    @EnvironmentObject private var viewModel: ScannerViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L("Search apps..."), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
                    .textContentType(.none)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 260)

            Spacer()

            Menu {
                Button(L("All Frameworks")) {
                    viewModel.selectedFrameworks.removeAll()
                }

                Divider()

                ForEach(FrameworkType.allCases) { fw in
                    Button {
                        if viewModel.selectedFrameworks.contains(fw) {
                            viewModel.selectedFrameworks.remove(fw)
                        } else {
                            viewModel.selectedFrameworks.insert(fw)
                        }
                    } label: {
                        HStack {
                            if viewModel.selectedFrameworks.contains(fw) {
                                Image(systemName: "checkmark")
                            }
                            Label(fw.displayName, systemImage: fw.symbolName)
                        }
                    }
                }
            } label: {
                Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 120)

            Menu {
                ForEach(SortOption.allCases) { option in
                    Button {
                        if viewModel.sortOption == option {
                            viewModel.sortDirection.toggle()
                        } else {
                            viewModel.sortOption = option
                            viewModel.sortDirection = .ascending
                        }
                    } label: {
                        HStack {
                            Text(localizedSortName(option))
                            if viewModel.sortOption == option {
                                Image(systemName: viewModel.sortDirection == .ascending
                                      ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Label(localizedSortName(viewModel.sortOption), systemImage: "arrow.up.arrow.down")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var filterLabel: String {
        if viewModel.selectedFrameworks.isEmpty {
            return L("All")
        }
        if viewModel.selectedFrameworks.count == 1 {
            return viewModel.selectedFrameworks.first!.displayName
        }
        return "\(viewModel.selectedFrameworks.count) " + L("selected")
    }

    private func localizedSortName(_ option: SortOption) -> String {
        switch option {
        case .name: return L("Name")
        case .size: return L("Size")
        case .date: return L("Date")
        case .framework: return L("Framework")
        }
    }
}
