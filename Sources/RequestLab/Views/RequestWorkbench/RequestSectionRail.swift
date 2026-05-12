import SwiftUI

enum RequestWorkbenchSection: String, CaseIterable, Identifiable {
    case params
    case headers
    case auth
    case body
    case graphQL

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .params:
            "Params"
        case .headers:
            "Headers"
        case .auth:
            "Auth"
        case .body:
            "Body"
        case .graphQL:
            "GraphQL"
        }
    }

    var systemImage: String {
        switch self {
        case .params:
            "line.3.horizontal.decrease.circle"
        case .headers:
            "list.bullet.rectangle"
        case .auth:
            "lock"
        case .body:
            "doc.plaintext"
        case .graphQL:
            "curlybraces"
        }
    }
}

struct RequestSectionRail: View {
    @Binding var selectedSection: RequestWorkbenchSection
    let isGraphQLRequest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Request")
                .font(RequestLabTextStyle.sectionLabel)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            sectionButton(.params)
            sectionButton(.headers)
            sectionButton(.auth)
            sectionButton(.body)
            sectionButton(.graphQL)

            Spacer()
        }
        .padding(10)
        .frame(width: 138)
        .workbenchSurface(.pane, cornerRadius: 0)
    }

    private func sectionButton(_ section: RequestWorkbenchSection) -> some View {
        let isDisabled = section == .graphQL && !isGraphQLRequest

        return Button {
            selectedSection = section
        } label: {
            RequestSectionRailButtonLabel(
                section: section,
                isSelected: selectedSection == section
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(section.title)
        .help(accessibilityHelp(for: section))
    }

    private func accessibilityHelp(for section: RequestWorkbenchSection) -> String {
        if section == .graphQL && !isGraphQLRequest {
            return "Switch the request type to GraphQL to edit GraphQL fields."
        }

        return "Show the \(section.title) request section."
    }
}

private struct RequestSectionRailButtonLabel: View {
    let section: RequestWorkbenchSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .frame(width: 16)
                .symbolRenderingMode(.hierarchical)

            Text(section.title)
                .lineLimit(1)
        }
        .font(.callout.weight(isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? .primary : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(RequestLabTheme.softFill(RequestLabTheme.selection))
            }
        }
    }
}
