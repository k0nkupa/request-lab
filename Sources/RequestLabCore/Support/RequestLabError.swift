import Foundation

public enum RequestLabError: Error, Equatable, LocalizedError, Sendable {
    case missingWorkspaceFile(URL)
    case missingDirectory(URL)
    case invalidWorkspace(String)
    case yamlDecodeFailed(String)
    case yamlEncodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingWorkspaceFile(let url):
            "Missing workspace file: \(url.path)"
        case .missingDirectory(let url):
            "Missing directory: \(url.path)"
        case .invalidWorkspace(let message):
            "Invalid workspace: \(message)"
        case .yamlDecodeFailed(let message):
            "Failed to decode YAML: \(message)"
        case .yamlEncodeFailed(let message):
            "Failed to encode YAML: \(message)"
        }
    }
}
