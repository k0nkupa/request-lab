import SwiftUI

struct WorkspaceNavigatorView: View {
    @Bindable var store: AppStore
    @Binding var selectedSection: WorkbenchSection
    let confirmDeleteRequest: (String) -> Void
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Group {
                switch selectedSection {
                case .requests, .commands:
                    RequestsNavigatorView(
                        store: store,
                        searchText: searchText,
                        confirmDeleteRequest: confirmDeleteRequest
                    )
                case .environments:
                    EnvironmentsNavigatorView(store: store, searchText: searchText)
                case .history:
                    HistoryNavigatorView(store: store, searchText: searchText)
                }
            }
        }
        .workbenchSurface(.pane, cornerRadius: 0)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RequestLabSpacing.sm) {
            Label(selectedSection.title, systemImage: selectedSection.systemImage)
                .font(.headline)
                .labelStyle(.titleAndIcon)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(RequestLabTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
            }
        }
        .padding(.horizontal, RequestLabSpacing.md)
        .padding(.vertical, RequestLabSpacing.md)
    }
}
