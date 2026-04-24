import Foundation
import Observation
import RequestLabCore

@Observable
final class AppStore {
    var workspace: APIWorkspace
    var selectedRequestID: String?
    var selectedEnvironmentID: String?
    var isInspectorVisible = true

    init(workspace: APIWorkspace = .empty) {
        self.workspace = workspace
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
                            auth: APIAuth(type: .bearer, tokenVariable: "apiToken"),
                            body: .none
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
