import Foundation
import Observation
import RequestLabCore

@MainActor
@Observable
final class AppStore {
    var workspace: APIWorkspace
    var workspaceURL: URL?
    var selectedRequestID: String?
    var selectedCenterPane: CenterPaneSelection?
    var selectedGlobalEnvironmentID: String?
    var selectedCollectionEnvironmentIDByCollectionID: [String: String] = [:]
    var collectionsWithNoEnvironmentSelection: Set<String> = []
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
    @ObservationIgnored
    private let requestValidationService: RequestValidationService

    init(
        workspace: APIWorkspace = .empty,
        workspaceURL: URL? = nil,
        executionService: RequestExecutionService = RequestExecutionService(),
        workspaceFileStore: WorkspaceFileStore = WorkspaceFileStore(),
        keychainSecretStore: KeychainSecretStore = KeychainSecretStore(),
        postmanImportService: PostmanImportService = PostmanImportService(),
        requestValidationService: RequestValidationService = RequestValidationService()
    ) {
        self.workspace = workspace
        self.workspaceURL = workspaceURL
        self.executionService = executionService
        self.workspaceFileStore = workspaceFileStore
        self.keychainSecretStore = keychainSecretStore
        self.postmanImportService = postmanImportService
        self.requestValidationService = requestValidationService
        self.selectedRequestID = workspace.collections.first?.requests.first?.id
        self.selectedCenterPane = selectedRequestID.map(CenterPaneSelection.request)
        self.selectedGlobalEnvironmentID = workspace.environments.first?.id
    }

    var selectedRequest: APIRequest? {
        workspace.collections
            .flatMap(\.requests)
            .first { $0.id == selectedRequestID }
    }

    var selectedCollection: APICollection? {
        workspace.collection(containingRequestID: selectedRequestID)
    }

    var selectedGlobalEnvironment: APIEnvironment? {
        workspace.environments.first { $0.id == selectedGlobalEnvironmentID }
    }

    var selectedCollectionEnvironment: APIEnvironment? {
        guard let collection = selectedCollection,
              !collectionsWithNoEnvironmentSelection.contains(collection.id)
        else {
            return nil
        }

        if let selectedEnvironmentID = selectedCollectionEnvironmentIDByCollectionID[collection.id],
           let environment = collection.environments.first(where: { $0.id == selectedEnvironmentID })
        {
            return environment
        }

        return collection.environments.first
    }

    var editorTitle: String {
        guard let request = selectedRequest else {
            return selectedCollection?.name ?? workspace.name
        }

        guard let collection = selectedCollection else {
            return request.name
        }

        return "\(collection.name) - \(request.name)"
    }

    var environmentPairTitle: String {
        let names: [String] = [selectedGlobalEnvironment?.name, selectedCollectionEnvironment?.name]
            .compactMap { name -> String? in
                guard let name, !name.isEmpty else {
                    return nil
                }

                return name
            }

        return names.isEmpty ? "No environment" : names.joined(separator: " + ")
    }

    var selectedEnvironmentForEditing: APIEnvironment? {
        switch selectedCenterPane {
        case .globalEnvironment(let environmentID):
            workspace.environments.first { $0.id == environmentID }
        case .collectionEnvironment(_, let environmentID):
            workspace.collections
                .flatMap(\.environments)
                .first { $0.id == environmentID }
        case .request, .none:
            nil
        }
    }

    var selectedEnvironmentEditorTitle: String {
        switch selectedCenterPane {
        case .globalEnvironment:
            "Global Environment"
        case .collectionEnvironment:
            "Collection Environment"
        case .request, .none:
            "Environment"
        }
    }

    var workspaceLocationTitle: String {
        workspaceURL?.lastPathComponent ?? "Unsaved workspace"
    }

    func openWorkspace(at url: URL) {
        do {
            workspace = try workspaceFileStore.load(from: url)
            workspaceURL = url
            selectedRequestID = workspace.collections.first?.requests.first?.id
            selectedCenterPane = selectedRequestID.map(CenterPaneSelection.request)
            selectedGlobalEnvironmentID = workspace.environments.first?.id
            selectedCollectionEnvironmentIDByCollectionID = [:]
            collectionsWithNoEnvironmentSelection = []
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
            selectedCenterPane = selectedRequestID.map(CenterPaneSelection.request)
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
            selectedGlobalEnvironmentID = environment.id
            selectedCenterPane = .globalEnvironment(environment.id)
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
            selectedCenterPane = self.selectedRequestID.map(CenterPaneSelection.request)
        } else if case .collectionEnvironment(let selectedCollectionID, _) = selectedCenterPane,
                  selectedCollectionID == collectionID
        {
            selectedCenterPane = (workspace.collections.first?.requests.first?.id).map(CenterPaneSelection.request)
        }
        selectedCollectionEnvironmentIDByCollectionID.removeValue(forKey: collectionID)
        collectionsWithNoEnvironmentSelection.remove(collectionID)

        clearExecutionState()
    }

    func renameCollection(id collectionID: String, to name: String) {
        guard workspace.renameCollection(id: collectionID, to: name) else {
            return
        }

        clearExecutionState()
    }

    func updateCollectionColor(id collectionID: String, color: APICollectionColor?) {
        guard workspace.updateCollectionColor(id: collectionID, color: color) else {
            return
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
        selectedCenterPane = .request(request.id)
        clearExecutionState()
    }

    func createRequest(kind: APIRequestKind = .rest, in collectionID: String) {
        let request = defaultRequest(kind: kind)
        guard workspace.addRequest(request, toCollectionID: collectionID) else {
            return
        }

        selectedRequestID = request.id
        selectedCenterPane = .request(request.id)
        clearExecutionState()
    }

    func deleteSelectedRequest() {
        guard let selectedRequestID,
              workspace.deleteRequest(id: selectedRequestID)
        else {
            return
        }

        self.selectedRequestID = workspace.collections.first?.requests.first?.id
        selectedCenterPane = self.selectedRequestID.map(CenterPaneSelection.request)
        clearExecutionState()
    }

    func deleteRequest(id requestID: String) {
        guard workspace.deleteRequest(id: requestID) else {
            return
        }

        if selectedRequestID == requestID {
            selectedRequestID = workspace.collections.first?.requests.first?.id
            selectedCenterPane = selectedRequestID.map(CenterPaneSelection.request)
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
        selectedGlobalEnvironmentID = environment.id
        selectedCenterPane = .globalEnvironment(environment.id)
        clearExecutionState()
    }

    func createCollectionEnvironment(in collectionID: String) {
        let existingNames = workspace.collections
            .first { $0.id == collectionID }?
            .environments
            .map(\.name) ?? []
        let environment = APIEnvironment(
            id: "env_\(UUID().uuidString)",
            name: nextName(base: "New Environment", existingNames: existingNames),
            variables: [
                APIVariable(name: "baseUrl", value: "http://localhost:3000")
            ]
        )

        guard workspace.addCollectionEnvironment(environment, toCollectionID: collectionID) else {
            return
        }

        selectedCollectionEnvironmentIDByCollectionID[collectionID] = environment.id
        collectionsWithNoEnvironmentSelection.remove(collectionID)
        selectedCenterPane = .collectionEnvironment(collectionID: collectionID, environmentID: environment.id)
        clearExecutionState()
    }

    func deleteEnvironment(id environmentID: String) {
        guard workspace.deleteEnvironment(id: environmentID) else {
            return
        }

        if selectedGlobalEnvironmentID == environmentID {
            selectedGlobalEnvironmentID = workspace.environments.first?.id
        }

        if case .globalEnvironment(let selectedEnvironmentID) = selectedCenterPane,
           selectedEnvironmentID == environmentID
        {
            selectedCenterPane = selectedRequestID.map(CenterPaneSelection.request)
        }

        clearExecutionState()
    }

    func deleteCollectionEnvironment(id environmentID: String, fromCollectionID collectionID: String) {
        guard workspace.deleteCollectionEnvironment(id: environmentID, fromCollectionID: collectionID) else {
            return
        }

        if selectedCollectionEnvironmentIDByCollectionID[collectionID] == environmentID {
            selectedCollectionEnvironmentIDByCollectionID.removeValue(forKey: collectionID)
        }

        if case .collectionEnvironment(let selectedCollectionID, let selectedEnvironmentID) = selectedCenterPane,
           selectedCollectionID == collectionID,
           selectedEnvironmentID == environmentID
        {
            selectedCenterPane = selectedRequestID.map(CenterPaneSelection.request)
        }

        clearExecutionState()
    }

    func selectCenterPane(_ selection: CenterPaneSelection?) {
        guard let selection else {
            selectedCenterPane = nil
            return
        }

        switch selection {
        case .request(let requestID):
            selectedRequestID = requestID
            selectedCenterPane = selection
            clearExecutionState()
        case .globalEnvironment(let environmentID):
            selectedCenterPane = selection
            selectGlobalEnvironment(id: environmentID)
        case .collectionEnvironment(let collectionID, let environmentID):
            selectedCenterPane = selection
            selectCollectionEnvironment(id: environmentID, for: collectionID)
        }
    }

    func selectGlobalEnvironment(id environmentID: String?) {
        selectedGlobalEnvironmentID = environmentID
        clearExecutionState()
    }

    func selectCollectionEnvironment(id environmentID: String?, for collectionID: String) {
        if let environmentID {
            selectedCollectionEnvironmentIDByCollectionID[collectionID] = environmentID
            collectionsWithNoEnvironmentSelection.remove(collectionID)
        } else {
            selectedCollectionEnvironmentIDByCollectionID.removeValue(forKey: collectionID)
            collectionsWithNoEnvironmentSelection.insert(collectionID)
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

    func updateEnvironmentName(environmentID: String, name: String) {
        guard workspace.updateEnvironment(id: environmentID, mutate: { environment in
            environment.name = name
        }) else {
            return
        }

        clearExecutionState()
    }

    func addEnvironmentVariable(environmentID: String) {
        let existingNames = environment(id: environmentID)?.variables.map(\.name) ?? []
        let variable = APIVariable(
            id: "var_\(UUID().uuidString)",
            name: nextName(base: "newKey", existingNames: existingNames),
            value: "",
            isSecret: false
        )

        guard workspace.addEnvironmentVariable(variable, toEnvironmentID: environmentID) else {
            return
        }

        clearExecutionState()
    }

    func updateEnvironmentVariableName(environmentID: String, variableID: String, name: String) {
        guard workspace.updateEnvironmentVariable(environmentID: environmentID, variableID: variableID, mutate: { variable in
            variable.name = name
        }) else {
            return
        }

        clearExecutionState()
    }

    func updateEnvironmentVariable(environmentID: String, variableID: String, value: String?) {
        guard workspace.updateEnvironmentVariable(environmentID: environmentID, variableID: variableID, mutate: { variable in
            variable.value = value
        }) else {
            return
        }

        clearExecutionState()
    }

    func deleteEnvironmentVariable(environmentID: String, variableID: String) {
        let deletedVariable = workspace.deleteEnvironmentVariable(environmentID: environmentID, variableID: variableID)
        guard let deletedVariable else {
            return
        }

        if deletedVariable.isSecret {
            try? keychainSecretStore.deleteSecret(
                workspaceID: workspace.id,
                environmentID: environmentID,
                variableID: variableID
            )
        }

        clearExecutionState()
    }

    func environmentName(environmentID: String) -> String {
        environment(id: environmentID)?.name ?? ""
    }

    func variableName(environmentID: String, variableID: String) -> String {
        environment(id: environmentID)?
            .variables
            .first { $0.id == variableID }?
            .name ?? ""
    }

    func variableValue(environmentID: String, variableID: String) -> String {
        environment(id: environmentID)?
            .variables
            .first { $0.id == variableID }?
            .value ?? ""
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
            try requestValidationService.validateForSend(request)
            let result = try await executionService.execute(
                request,
                environment: effectiveEnvironmentWithSecrets()
            )
            latestResponse = result
            appendHistoryEntry(from: result)
        } catch {
            latestResponse = nil
            executionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSending = false
    }

    private func effectiveEnvironmentWithSecrets() -> APIEnvironment? {
        let globalEnvironment = environmentWithSecrets(selectedGlobalEnvironment)
        let collectionEnvironment = environmentWithSecrets(selectedCollectionEnvironment)

        return APIEnvironment.merged(global: globalEnvironment, collection: collectionEnvironment)
    }

    private func environmentWithSecrets(_ environment: APIEnvironment?) -> APIEnvironment? {
        guard var resolvedEnvironment = environment else {
            return nil
        }

        resolvedEnvironment.variables = resolvedEnvironment.variables.map { variable in
            guard variable.isSecret else {
                return variable
            }

            var resolvedVariable = variable
            resolvedVariable.value = try? keychainSecretStore.readSecret(
                workspaceID: workspace.id,
                environmentID: resolvedEnvironment.id,
                variableID: variable.id
            )
            return resolvedVariable
        }

        return resolvedEnvironment
    }

    private func environment(id environmentID: String) -> APIEnvironment? {
        if let globalEnvironment = workspace.environments.first(where: { $0.id == environmentID }) {
            return globalEnvironment
        }

        return workspace.collections
            .flatMap(\.environments)
            .first { $0.id == environmentID }
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

enum CenterPaneSelection: Hashable {
    case request(String)
    case globalEnvironment(String)
    case collectionEnvironment(collectionID: String, environmentID: String)
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
                    environments: [
                        APIEnvironment(
                            id: "env_starter_local",
                            name: "Starter Local",
                            variables: [
                                APIVariable(
                                    id: "var_starter_baseUrl",
                                    name: "baseUrl",
                                    value: "http://localhost:3000",
                                    isSecret: false
                                )
                            ]
                        )
                    ],
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
