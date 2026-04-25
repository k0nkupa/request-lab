import RequestLabCore
import SwiftUI

enum RequestLabTheme {
    static let tint = Color(nsColor: .controlAccentColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor)
    static let editorBorder = Color(nsColor: .separatorColor).opacity(0.7)

    static let selection = Color.blue
    static let primaryAction = Color.blue
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.cyan
    static let graphQL = Color.purple
    static let environment = Color.indigo
    static let collection = Color.teal

    static func softFill(_ color: Color) -> Color {
        color.opacity(0.12)
    }

    static func softStroke(_ color: Color) -> Color {
        color.opacity(0.35)
    }

    static func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get, .head:
            success
        case .post:
            primaryAction
        case .put, .patch:
            warning
        case .delete:
            error
        case .options:
            info
        }
    }

    static func responseColor(statusCode: Int) -> Color {
        switch statusCode {
        case 200..<300:
            success
        case 300..<400:
            info
        case 400..<500:
            warning
        default:
            error
        }
    }
}

struct RequestLabSurface: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RequestLabTheme.softFill(tint))
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(RequestLabTheme.softStroke(tint), lineWidth: 1)
            }
    }
}

extension View {
    func requestLabSurface(
        tint: Color = RequestLabTheme.selection,
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(RequestLabSurface(tint: tint, cornerRadius: cornerRadius))
    }
}
