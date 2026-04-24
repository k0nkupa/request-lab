import Foundation

public struct JSONFormattingService: Sendable {
    public init() {}

    public func prettyPrinted(_ value: String) throws -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmedValue.data(using: .utf8), !trimmedValue.isEmpty else {
            throw RequestLabError.invalidWorkspace("JSON is empty")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let output = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            return String(data: output, encoding: .utf8) ?? trimmedValue
        } catch {
            throw RequestLabError.invalidWorkspace("JSON is invalid")
        }
    }

    public func prettyPrintedIfJSON(_ value: String) -> String {
        (try? prettyPrinted(value)) ?? value
    }
}
