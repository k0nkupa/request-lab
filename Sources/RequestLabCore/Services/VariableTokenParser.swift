import Foundation

public enum VariableTokenSegment: Equatable, Sendable {
    case text(String)
    case variable(rawValue: String, name: String)
}

public enum VariableTokenParser {
    public static func segments(in value: String) -> [VariableTokenSegment] {
        let pattern = #"\{\{\s*([A-Za-z0-9_.-]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(value)]
        }

        let range = NSRange(value.startIndex..., in: value)
        let matches = regex.matches(in: value, range: range)
        guard !matches.isEmpty else {
            return value.isEmpty ? [] : [.text(value)]
        }

        var segments: [VariableTokenSegment] = []
        var cursor = value.startIndex

        for match in matches {
            guard let tokenRange = Range(match.range(at: 0), in: value),
                  let nameRange = Range(match.range(at: 1), in: value)
            else {
                continue
            }

            if cursor < tokenRange.lowerBound {
                segments.append(.text(String(value[cursor..<tokenRange.lowerBound])))
            }

            segments.append(.variable(rawValue: String(value[tokenRange]), name: String(value[nameRange])))
            cursor = tokenRange.upperBound
        }

        if cursor < value.endIndex {
            segments.append(.text(String(value[cursor...])))
        }

        return segments
    }

    public static func containsToken(in value: String) -> Bool {
        segments(in: value).contains { segment in
            if case .variable = segment {
                return true
            }

            return false
        }
    }
}
