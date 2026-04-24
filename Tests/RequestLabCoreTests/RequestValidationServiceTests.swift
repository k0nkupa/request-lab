import RequestLabCore
import Testing

@Suite("Request validation")
struct RequestValidationServiceTests {
    @Test("allows valid REST requests")
    func allowsValidRESTRequests() throws {
        let request = APIRequest(
            id: "req",
            name: "Request",
            method: .post,
            url: "https://api.example.test",
            body: .json(#"{"ok":true}"#)
        )

        try RequestValidationService().validateForSend(request)
    }

    @Test("rejects empty URLs")
    func rejectsEmptyURLs() {
        let request = APIRequest(id: "req", name: "Request", method: .get, url: "  ")

        #expect(throws: RequestLabError.invalidWorkspace("Request URL is required")) {
            try RequestValidationService().validateForSend(request)
        }
    }

    @Test("rejects invalid JSON bodies")
    func rejectsInvalidJSONBodies() {
        let request = APIRequest(
            id: "req",
            name: "Request",
            method: .post,
            url: "https://api.example.test",
            body: .json("{")
        )

        #expect(throws: RequestLabError.invalidWorkspace("JSON is invalid")) {
            try RequestValidationService().validateForSend(request)
        }
    }

    @Test("rejects GraphQL requests without query")
    func rejectsGraphQLRequestsWithoutQuery() {
        let request = APIRequest(
            id: "req",
            name: "GraphQL",
            kind: .graphQL,
            method: .post,
            url: "https://api.example.test/graphql",
            graphQL: APIGraphQLPayload(query: " ")
        )

        #expect(throws: RequestLabError.invalidWorkspace("GraphQL query is required")) {
            try RequestValidationService().validateForSend(request)
        }
    }
}
