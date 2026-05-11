import SwiftUI

enum RequestLabSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum WorkbenchSurfaceKind {
    case chrome
    case pane
    case elevated
    case interactive
}

struct WorkbenchSurfaceModifier: ViewModifier {
    let kind: WorkbenchSurfaceKind
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            switch kind {
            case .interactive:
                content
                    .glassEffect(.regular.tint(glassTint).interactive(), in: .rect(cornerRadius: cornerRadius))
            case .chrome, .pane, .elevated:
                content
                    .glassEffect(.regular.tint(glassTint), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(surfaceFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(surfaceStroke, lineWidth: 1)
                }
        }
    }

    private var glassTint: Color {
        switch kind {
        case .chrome:
            RequestLabTheme.tint.opacity(0.08)
        case .pane:
            RequestLabTheme.background.opacity(0.18)
        case .elevated:
            RequestLabTheme.elevatedSurface.opacity(0.22)
        case .interactive:
            tint.opacity(0.18)
        }
    }

    private var surfaceFill: Color {
        switch kind {
        case .chrome:
            RequestLabTheme.surface.opacity(0.72)
        case .pane:
            RequestLabTheme.background.opacity(0.62)
        case .elevated:
            RequestLabTheme.elevatedSurface.opacity(0.82)
        case .interactive:
            RequestLabTheme.softFill(tint)
        }
    }

    private var surfaceStroke: Color {
        switch kind {
        case .interactive:
            RequestLabTheme.softStroke(tint)
        case .chrome, .pane, .elevated:
            RequestLabTheme.editorBorder
        }
    }
}

extension View {
    func workbenchSurface(
        _ kind: WorkbenchSurfaceKind,
        cornerRadius: CGFloat = 12,
        tint: Color = RequestLabTheme.selection
    ) -> some View {
        modifier(WorkbenchSurfaceModifier(kind: kind, cornerRadius: cornerRadius, tint: tint))
    }
}

enum RequestLabTextStyle {
    static let chromeTitle = Font.callout.weight(.semibold)
    static let paneTitle = Font.headline.weight(.semibold)
    static let sectionLabel = Font.caption.weight(.semibold)
    static let rowLabel = Font.callout
    static let code = Font.system(.body, design: .monospaced)
    static let codeSmall = Font.system(.caption, design: .monospaced)
}
