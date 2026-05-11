import SwiftUI

struct WorkbenchTopBar<EnvironmentControl: View, Actions: View>: View {
    let workspaceTitle: String
    let isSending: Bool
    let canSend: Bool
    let isInspectorVisible: Bool
    let send: () -> Void
    let toggleInspector: () -> Void
    let environmentControl: () -> EnvironmentControl
    let actions: () -> Actions

    var body: some View {
        HStack(spacing: RequestLabSpacing.md) {
            Label("RequestLab", systemImage: "point.3.connected.trianglepath.dotted")
                .font(RequestLabTextStyle.chromeTitle)
                .symbolRenderingMode(.hierarchical)

            Text(workspaceTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()
                .frame(height: 20)

            environmentControl()
                .font(.caption.weight(.semibold))
                .foregroundStyle(RequestLabTheme.environment)
                .lineLimit(1)
                .padding(.horizontal, RequestLabSpacing.sm)
                .padding(.vertical, 5)
                .workbenchSurface(.interactive, cornerRadius: 8, tint: RequestLabTheme.environment)

            Spacer(minLength: RequestLabSpacing.md)

            actions()

            Button {
                send()
            } label: {
                Label(isSending ? "Sending" : "Send", systemImage: isSending ? "hourglass" : "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(RequestLabTheme.primaryAction)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Send request")

            Button {
                toggleInspector()
            } label: {
                Image(systemName: isInspectorVisible ? "sidebar.trailing" : "sidebar.right")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help(isInspectorVisible ? "Hide inspector" : "Show inspector")
            .accessibilityLabel(isInspectorVisible ? "Hide inspector" : "Show inspector")
        }
        .padding(.horizontal, RequestLabSpacing.md)
        .padding(.vertical, RequestLabSpacing.sm)
        .workbenchSurface(.chrome, cornerRadius: 0)
    }
}
