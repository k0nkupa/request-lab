import Foundation
import Observation
import RequestLabCore

@MainActor
@Observable
final class AppStore {
    var workspace: APIWorkspace
    var workspaceURL: URL?
    var selectedRequestID: String?
    var selectedEnvironmentID: String?
    var isInspectorVisible = true
    var isSending = false
    var latestResponse: APIExecutionResult?
    var executionErrorMessage: String?
    var workspaceErrorMessage: String?

    @ObservationIgnored
    private let executionService: RequestExecutionService
    @ObservationIgnored
    private let workspaceFileStore: WorkspaceFileStore
    @ObservationIgnored
    private let keychainSecretStore: KeychainSecretStore

    init(
        workspace: APIWorkspace = .empty,
        workspaceURL: URL? = nil,
        executionService: RequestExecutionService = RequestExecutionService(),
        workspaceFileStore: WorkspaceFileStore = WorkspaceFileStore(),
        keychainSecretStore: KeychainSecretStore = KeychainSecretStore()
    ) {
        self.workspace = workspace
        self.workspaceURL = workspaceURL
        self.executionService = executionService
        self.workspaceFileStore = workspaceFileStore
        self.keychainSecretStore = keychainSecretStore
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

    var workspaceLocationTitle: String {
        workspaceURL?.lastPathComponent ?? "Unsaved workspace"
    }

    func openWorkspace(at url: URL) {
        do {
            workspace = try workspaceFileStore.load(from: url)
            workspaceURL = url
            selectedRequestID = workspace.collections.first?.requests.first?.id
            selectedEnvironmentID = workspace.environments.first?.id
            latestResponse = nil
            executionErrorMessage = nil
            workspaceErrorMessage = nil
        } catch {
            workspaceErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func saveWorkspace() {
        guard let workspaceURL else {
            workspaceErrorMessage = "Choose a workspace location before saving."
            return
        }

        saveWorkspace(to: workspaceURL)
    }

    func saveWorkspace(to url: URL) {
        do {
            try workspaceFileStore.save(workspace, to: url)
            workspaceURL = url
            workspaceErrorMessage = nil
        } catch {
            workspaceErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func updateSelectedRequest(_ mutate: (inout APIRequest) -> Void) {
        guard let selectedRequestID else {
            return
        }

        _ = workspace.updateRequest(id: selectedRequestID, mutate: mutate)
        latestResponse = nil
        executionErrorMessage = nil
    }

    func updateEnvironmentVariable(environmentID: String, variableID: String, value: String?) {
        guard let environmentIndex = workspace.environments.firstIndex(where: { $0.id == environmentID }),
              let variableIndex = workspace.environments[environmentIndex].variables.firstIndex(where: { $0.id == variableID })
        else {
            return
        }

        workspace.environments[environmentIndex].variables[variableIndex].value = value
        latestResponse = nil
        executionErrorMessage = nil
    }

    func readSecretValue(environmentID: String, variableID: String) -> String {
        (try? keychainSecretStore.readSecret(
            workspaceID: workspace.id,
            environmentID: environmentID,
            variableID: variableID
        )) ?? ""
    }

    func writeSecretValue(environmentID: String, variableID: String, value: String) {
        do {
            if value.isEmpty {
                try keychainSecretStore.deleteSecret(
                    workspaceID: workspace.id,
                    environmentID: environmentID,
                    variableID: variableID
                )
            } else {
                try keychainSecretStore.writeSecret(
                    value,
                    workspaceID: workspace.id,
                    environmentID: environmentID,
                    variableID: variableID
                )
            }
            workspaceErrorMessage = nil
            latestResponse = nil
            executionErrorMessage = nil
        } catch {
            workspaceErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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
            let result = try await executionService.execute(
                request,
                environment: selectedEnvironmentWithSecrets()
            )
            latestResponse = result
            appendHistoryEntry(from: result)
        } catch {
            latestResponse = nil
            executionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSending = false
    }

    private func selectedEnvironmentWithSecrets() -> APIEnvironment? {
        guard var environment = selectedEnvironment else {
            return nil
        }

        environment.variables = environment.variables.map { variable in
            guard variable.isSecret else {
                return variable
            }

            var resolvedVariable = variable
            resolvedVariable.value = try? keychainSecretStore.readSecret(
                workspaceID: workspace.id,
                environmentID: environment.id,
                variableID: variable.id
            )
            return resolvedVariable
        }

        return environment
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
