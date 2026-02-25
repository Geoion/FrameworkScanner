import SwiftUI

struct FilterToolbar: View {
    @EnvironmentObject private var viewModel: ScannerViewModel

    var body: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    NSLocalizedString("Search apps...", comment: ""),
                    text: $viewModel.searchText
                )
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

            // 框架筛选
            Menu {
                Button(NSLocalizedString("All Frameworks", comment: "")) {
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
                Label(
                    filterLabel,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 120)

            // 排序
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
                Label(
                    localizedSortName(viewModel.sortOption),
                    systemImage: "arrow.up.arrow.down"
                )
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
            return NSLocalizedString("All", comment: "")
        }
        if viewModel.selectedFrameworks.count == 1 {
            return viewModel.selectedFrameworks.first!.displayName
        }
        return "\(viewModel.selectedFrameworks.count) " + NSLocalizedString("selected", comment: "")
    }

    private func localizedSortName(_ option: SortOption) -> String {
        switch option {
        case .name: return NSLocalizedString("Name", comment: "")
        case .size: return NSLocalizedString("Size", comment: "")
        case .date: return NSLocalizedString("Date", comment: "")
        case .framework: return NSLocalizedString("Framework", comment: "")
        }
    }
}
