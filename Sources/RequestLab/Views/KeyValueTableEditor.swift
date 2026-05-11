import SwiftUI

struct KeyValueTableEditor: View {
    let title: String
    let emptyTitle: String
    let emptyDescription: String
    var unresolvedNames: Set<String> = []
    @Binding var values: [String: String]
    @State private var rows: [KeyValueDraftRow] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Button {
                    addRow()
                } label: {
                    Label("Add row", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if rows.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "list.bullet.rectangle",
                    description: Text(emptyDescription)
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(spacing: 8) {
                    keyValueHeader

                    ForEach($rows) { $row in
                        keyValueRow($row)
                    }
                }
                .padding(10)
                .background(RequestLabTheme.elevatedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
                }
            }

            Spacer()
        }
        .onAppear {
            reloadRows(from: values)
        }
        .onChange(of: values) { _, newValue in
            if dictionary(from: rows) != newValue {
                reloadRows(from: newValue)
            }
        }
    }

    private var keyValueHeader: some View {
        HStack(spacing: 8) {
            Text("Key")
                .frame(minWidth: 120, idealWidth: 180, maxWidth: 240, alignment: .leading)
            Text("Value")
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
                .frame(width: 28)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private func keyValueRow(_ row: Binding<KeyValueDraftRow>) -> some View {
        HStack(spacing: 8) {
            TextField("Key", text: keyBinding(for: row))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 120, idealWidth: 180, maxWidth: 240)

            VariableTokenTextField("Value", text: valueBinding(for: row), unresolvedNames: unresolvedNames)

            Button(role: .destructive) {
                deleteRow(id: row.wrappedValue.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete row")
        }
    }

    private func keyBinding(for row: Binding<KeyValueDraftRow>) -> Binding<String> {
        Binding(
            get: { row.wrappedValue.key },
            set: { newValue in
                row.wrappedValue.key = newValue
                commitRows()
            }
        )
    }

    private func valueBinding(for row: Binding<KeyValueDraftRow>) -> Binding<String> {
        Binding(
            get: { row.wrappedValue.value },
            set: { newValue in
                row.wrappedValue.value = newValue
                commitRows()
            }
        )
    }

    private func addRow() {
        rows.append(KeyValueDraftRow(key: "", value: ""))
    }

    private func deleteRow(id: UUID) {
        rows.removeAll { $0.id == id }
        commitRows()
    }

    private func reloadRows(from values: [String: String]) {
        rows = values
            .sorted { $0.key < $1.key }
            .map { KeyValueDraftRow(key: $0.key, value: $0.value) }
    }

    private func commitRows() {
        values = dictionary(from: rows)
    }

    private func dictionary(from rows: [KeyValueDraftRow]) -> [String: String] {
        rows.reduce(into: [:]) { result, row in
            let key = row.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                return
            }

            result[key] = row.value
        }
    }
}

private struct KeyValueDraftRow: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}
