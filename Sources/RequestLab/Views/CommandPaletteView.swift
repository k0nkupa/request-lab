import SwiftUI

struct CommandPaletteCommand: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    init(
        id: String,
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }
}

struct CommandPaletteView: View {
    let commands: [CommandPaletteCommand]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredCommands: [CommandPaletteCommand] {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSearchText.isEmpty else {
            return commands
        }

        return commands.filter { command in
            command.title.localizedCaseInsensitiveContains(normalizedSearchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search commands", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)

            Divider()

            if filteredCommands.isEmpty {
                ContentUnavailableView.search
                    .frame(width: 420, height: 220)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(filteredCommands) { command in
                            Button {
                                command.action()
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: command.systemImage)
                                        .frame(width: 18)
                                        .symbolRenderingMode(.hierarchical)

                                    Text(command.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!command.isEnabled)
                        }
                    }
                }
                .frame(width: 420, height: 280)
            }
        }
        .padding(14)
        .onAppear {
            isSearchFocused = true
        }
    }
}
