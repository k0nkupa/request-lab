import RequestLabCore
import SwiftUI

struct VariableTokenTextField: View {
    let title: String
    @Binding var text: String
    let unresolvedNames: Set<String>
    @FocusState private var isFocused: Bool

    init(_ title: String, text: Binding<String>, unresolvedNames: Set<String> = []) {
        self.title = title
        self.unresolvedNames = unresolvedNames
        _text = text
    }

    private var shouldShowTokens: Bool {
        !isFocused && VariableTokenParser.containsToken(in: text)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .opacity(shouldShowTokens ? 0.01 : 1)

            if shouldShowTokens {
                VariableTokenRunView(text: text, unresolvedNames: unresolvedNames)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 28)
                    .background(RequestLabTheme.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isFocused = true
                    }
            }
        }
        .frame(minHeight: 28)
    }
}

private struct VariableTokenRunView: View {
    let text: String
    let unresolvedNames: Set<String>

    private var segments: [VariableTokenSegment] {
        VariableTokenParser.segments(in: text)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let value):
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                    case .variable(_, let name):
                        let color = unresolvedNames.contains(name) ? RequestLabTheme.warning : RequestLabTheme.environment
                        Text(name)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(RequestLabTheme.softFill(color))
                            )
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(RequestLabTheme.softStroke(color), lineWidth: 1)
                            }
                            .help(unresolvedNames.contains(name) ? "Unresolved variable" : "Resolved variable")
                    }
                }
            }
            .padding(.horizontal, 7)
            .frame(minHeight: 28)
        }
    }
}
