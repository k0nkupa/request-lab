import Foundation
import Observation
import RequestLabCore

@MainActor
@Observable
final class AppStore {
    var workspace: APIWorkspace
    var selectedRequestID: String?
    var selectedEnvironmentID: String?
    var isInspectorVisible = true
    var isSending = false
    var latestResponse: APIExecutionResult?
    var executionErrorMessage: String?

    @ObservationIgnored
    private let executionService: RequestExecutionService

    init(
        workspace: APIWorkspace = .empty,
        executionService: RequestExecutionService = RequestExecutionService()
    ) {
        self.workspace = workspace
        self.executionService = executionService
        self.selectedRequestID = workspace.collections.first?.requests.first?.id
        self.selectedEnvironmentID = workspace.environments.first?.id
    }

    var selectedRequest: APIRequest? {
        workspace.collections
            .flatMap(\.requests)
            .first { $0.id == selectedRequestID }
    }

    var selectedEnvironment: APIEnvironment? {
        workspace.environments.first { $0.id == selectedEnvironmentID }
    }

    func sendSelectedRequest() async {
        guard let request = selectedRequest else {
            executionErrorMessage = "Select a request before sending."
            latestResponse = nil
            return
        }

        isSending = true
        executionErrorMessage = nil

        do {
            let result = try await executionService.execute(request, environment: selectedEnvironment)
            latestResponse = result
            appendHistoryEntry(from: result)
        } catch {
            latestResponse = nil
            executionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSending = false
    }

    private func appendHistoryEntry(from result: APIExecutionResult) {
        workspace.history.insert(
            APIHistoryEntry(
                id: "hist_\(UUID().uuidString)",
                requestId: result.requestId,
                method: result.method,
                url: result.url,
                statusCode: result.statusCode,
                durationMilliseconds: result.durationMilliseconds
            ),
            at: 0
        )
    }
}

extension APIWorkspace {
    static var empty: APIWorkspace {
        APIWorkspace(
            id: "wrk_default",
            name: "RequestLab",
            collections: [
                APICollection(
                    id: "col_starter",
                    name: "Starter Collection",
                    requests: [
                        APIRequest(
                            id: "req_starter_get",
                            name: "Get started",
                            method: .get,
                            url: "{{baseUrl}}/health",
                            headers: ["Accept": "application/json"],
                            params: [:],
                            auth: nil,
                            body: .none
                        ),
                        APIRequest(
                            id: "req_starter_graphql",
                            name: "GraphQL viewer",
                            kind: .graphQL,
                            method: .post,
                            url: "{{baseUrl}}/graphql",
                            headers: [:],
                            params: [:],
                            auth: nil,
                            body: .none,
                            graphQL: APIGraphQLPayload(
                                query: """
                                query Viewer {
                                  viewer {
                                    id
                                  }
                                }
                                """,
                                operationName: "Viewer",
                                variables: "{}"
                            )
                        )
                    ]
                )
            ],
            environments: [
                APIEnvironment(
                    id: "env_local",
                    name: "Local",
                    variables: [
                        APIVariable(
                            id: "var_baseUrl",
                            name: "baseUrl",
                            value: "http://localhost:3000",
                            isSecret: false
                        ),
                        APIVariable(
                            id: "var_apiToken",
                            name: "apiToken",
                            value: nil,
                            isSecret: true
                        )
                    ]
                )
            ],
            history: []
        )
    }
}
