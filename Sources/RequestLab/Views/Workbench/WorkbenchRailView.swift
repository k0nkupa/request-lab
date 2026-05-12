import SwiftUI

struct WorkbenchRailView: View {
    @Binding var selectedSection: WorkbenchSection
    let openCommandPalette: () -> Void

    var body: some View {
        VStack(spacing: RequestLabSpacing.sm) {
            ForEach(WorkbenchSection.allCases) { section in
                railButton(for: section)
            }

            Spacer()
        }
        .padding(.vertical, RequestLabSpacing.md)
        .frame(maxHeight: .infinity)
        .workbenchSurface(.chrome, cornerRadius: 0)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(RequestLabTheme.editorBorder)
                .frame(width: 1)
        }
    }

    private func railButton(for section: WorkbenchSection) -> some View {
        let isSelected = section == selectedSection
        let helpText = section == .commands ? "Open command palette" : section.title
        let accessibilityHint = section == .commands ? "Open the command palette" : "Show \(section.title)"

        return Button {
            selectedSection = section
        } label: {
            Image(systemName: section.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 38, height: 34)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .workbenchSurface(
                    isSelected ? .interactive : .pane,
                    cornerRadius: 8,
                    tint: isSelected ? RequestLabTheme.selection : RequestLabTheme.editorBorder
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityHint(accessibilityHint)
        .help(helpText)
    }
}
