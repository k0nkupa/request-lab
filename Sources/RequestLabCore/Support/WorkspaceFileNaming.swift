import Foundation

enum WorkspaceFileNaming {
    static func baseFileName(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = name.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let candidate = String(scalars)
            .split(separator: "-")
            .joined(separator: "-")

        return candidate.isEmpty ? "item" : candidate
    }

    static func yamlFileName(for name: String) -> String {
        "\(baseFileName(for: name)).yaml"
    }
}
