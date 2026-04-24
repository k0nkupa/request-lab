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
    @ObservationIgnored
    private let postmanImportService: PostmanImportService

    init(
        workspace: APIWorkspace = .empty,
        workspaceURL: URL? = nil,
        executionService: RequestExecutionService = RequestExecutionService(),
        workspaceFileStore: WorkspaceFileStore = WorkspaceFileStore(),
        keychainSecretStore: KeychainSecretStore = KeychainSecretStore(),
        postmanImportService: PostmanImportService = PostmanImportService()
    ) {
        self.workspace = workspace
        self.workspaceURL = workspaceURL
        self.executionService = executionService
        self.workspaceFileStore = workspaceFileStore
        self.keychainSecretStore = keychainSecretStore
        self.postmanImportService = postmanImportService
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

    func importPostmanCollection(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let collection = try postmanImportService.importCollection(from: data)
            workspace.collections.append(collection)
            selectedRequestID = collection.requests.first?.id
            workspaceErrorMessage = nil
            latestResponse = nil
            executionErrorMessage = nil
        } catch {
            workspaceErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func importPostmanEnvironment(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let environment = try postmanImportService.importEnvironment(from: data)
            workspace.environments.append(environment)
            selectedEnvironmentID = environment.id
            workspaceErrorMessage = nil
            latestResponse = nil
            executionErrorMessage = nil
        } catch {
            workspaceErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func createCollection() {
        let collection = APICollection(
            id: "col_\(UUID().uuidString)",
            name: nextName(base: "New Collection", existingNames: workspace.collections.map(\.name))
        )

        workspace.addCollection(collection)
        clearExecutionState()
    }

    func deleteCollection(id collectionID: String) {
        let deletedRequestIDs = workspace.collections
            .first { $0.id == collectionID }?
            .requests
            .map(\.id) ?? []

        guard workspace.deleteCollection(id: collectionID) else {
            return
        }

        if let selectedRequestID, deletedRequestIDs.contains(selectedRequestID) {
            self.selectedRequestID = workspace.collections.first?.requests.first?.id
        }

        clearExecutionState()
    }

    func createRequest(kind: APIRequestKind = .rest) {
        if workspace.collections.isEmpty {
            createCollection()
        }

        guard let collectionID = workspace.collectionID(containingRequestID: selectedRequestID ?? "")
            ?? workspace.collections.first?.id
        else {
            return
        }

        let request = defaultRequest(kind: kind)
        guard workspace.addRequest(request, toCollectionID: collectionID) else {
            return
        }

        selectedRequestID = request.id
        clearExecutionState()
    }

    func createRequest(kind: APIRequestKind = .rest, in collectionID: String) {
        let request = defaultRequest(kind: kind)
        guard workspace.addRequest(request, toCollectionID: collectionID) else {
            return
        }

        selectedRequestID = request.id
        clearExecutionState()
    }

    func deleteSelectedRequest() {
        guard let selectedRequestID,
              workspace.deleteRequest(id: selectedRequestID)
        else {
            return
        }

        self.selectedRequestID = workspace.collections.first?.requests.first?.id
        clearExecutionState()
    }

    func deleteRequest(id requestID: String) {
        guard workspace.deleteRequest(id: requestID) else {
            return
        }

        if selectedRequestID == requestID {
            selectedRequestID = workspace.collections.first?.requests.first?.id
        }

        clearExecutionState()
    }

    func createEnvironment() {
        let environment = APIEnvironment(
            id: "env_\(UUID().uuidString)",
            name: nextName(base: "New Environment", existingNames: workspace.environments.map(\.name)),
            variables: [
                APIVariable(name: "baseUrl", value: "http://localhost:3000")
            ]
        )

        workspace.addEnvironment(environment)
        selectedEnvironmentID = environment.id
        clearExecutionState()
    }

    func deleteEnvironment(id environmentID: String) {
        guard workspace.deleteEnvironment(id: environmentID) else {
            return
        }

        if selectedEnvironmentID == environmentID {
            selectedEnvironmentID = workspace.environments.first?.id
        }

        clearExecutionState()
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
        clearExecutionState()
    }

    func updateEnvironmentVariable(environmentID: String, variableID: String, value: String?) {
        guard let environmentIndex = workspace.environments.firstIndex(where: { $0.id == environmentID }),
              let variableIndex = workspace.environments[environmentIndex].variables.firstIndex(where: { $0.id == variableID })
        else {
            return
        }

        workspace.environments[environmentIndex].variables[variableIndex].value = value
        clearExecutionState()
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
            clearExecutionState()
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

    private func clearExecutionState() {
        latestResponse = nil
        executionErrorMessage = nil
    }

    private func defaultRequest(kind: APIRequestKind) -> APIRequest {
        let name = nextName(
            base: kind == .graphQL ? "New GraphQL Request" : "New Request",
            existingNames: workspace.collections.flatMap(\.requests).map(\.name)
        )

        if kind == .graphQL {
            return APIRequest(
                id: "req_\(UUID().uuidString)",
                name: name,
                kind: .graphQL,
                method: .post,
                url: "{{baseUrl}}/graphql",
                graphQL: APIGraphQLPayload(
                    query: "query NewQuery {\n  viewer {\n    id\n  }\n}",
                    operationName: "NewQuery",
                    variables: "{}"
                )
            )
        }

        return APIRequest(
            id: "req_\(UUID().uuidString)",
            name: name,
            method: .get,
            url: "{{baseUrl}}"
        )
    }

    private func nextName(base: String, existingNames: [String]) -> String {
        guard existingNames.contains(base) else {
            return base
        }

        var index = 2
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }

        return "\(base) \(index)"
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
