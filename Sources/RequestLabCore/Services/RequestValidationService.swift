import Foundation

public struct RequestValidationService: Sendable {
    private let jsonFormatter: JSONFormattingService

    public init(jsonFormatter: JSONFormattingService = JSONFormattingService()) {
        self.jsonFormatter = jsonFormatter
    }

    public func validateForSend(_ request: APIRequest) throws {
        let trimmedURL = request.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            throw RequestLabError.invalidWorkspace("Request URL is required")
        }

        if request.kind == .graphQL {
            guard let payload = request.graphQL else {
                throw RequestLabError.invalidWorkspace("GraphQL request is missing query payload")
            }

            guard !payload.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RequestLabError.invalidWorkspace("GraphQL query is required")
            }

            _ = try jsonFormatter.prettyPrinted(payload.variables.isEmpty ? "{}" : payload.variables)
        }

        if case .json(let value) = request.body {
            _ = try jsonFormatter.prettyPrinted(value)
        }
    }
}
