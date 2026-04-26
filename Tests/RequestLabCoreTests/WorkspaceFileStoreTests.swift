import Foundation
import RequestLabCore
import Testing

@Suite("Workspace models")
struct WorkspaceFileStoreTests {
    @Test("workspace model exposes collections, environments, and history")
    func workspaceModelShape() throws {
        let workspace = APIWorkspace.sample

        #expect(workspace.collections.first?.requests.first?.auth?.tokenVariable == "apiToken")
        #expect(workspace.environments.first?.variables.count == 2)
        #expect(workspace.history.first?.statusCode == 200)
    }

    @Test("workspace folder saves and loads as YAML")
    func workspaceRoundTrip() throws {
        let tempURL = URL(filePath: NSTemporaryDirectory())
            .appending(path: UUID().uuidString)
            .appendingPathExtension("workspace")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        let workspace = APIWorkspace.sample

        try store.save(workspace, to: tempURL)
        let loaded = try store.load(from: tempURL)

        #expect(loaded == workspace)
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "workspace.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "collections/orders.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "environments/local.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: ".client/history.yaml").path))
    }

    @Test("collection environments save and load inline with collections")
    func collectionEnvironmentsRoundTrip() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        let workspace = APIWorkspace(
            id: "wrk_collection_env",
            name: "Collection Environment Workspace",
            collections: [
                APICollection(
                    id: "col_orders",
                    name: "Orders",
                    environments: [
                        APIEnvironment(
                            id: "env_orders_dev",
                            name: "Orders Dev",
                            variables: [
                                APIVariable(name: "baseUrl", value: "https://orders.example.test")
                            ]
                        )
                    ],
                    requests: [
                        APIRequest(
                            id: "req_orders",
                            name: "Orders",
                            method: .get,
                            url: "{{baseUrl}}/orders"
                        )
                    ]
                )
            ]
        )

        try store.save(workspace, to: tempURL)
        let loaded = try store.load(from: tempURL)
        let collectionYAML = try String(
            contentsOf: tempURL.appending(path: "collections/orders.yaml"),
            encoding: .utf8
        )

        #expect(loaded == workspace)
        #expect(collectionYAML.contains("env_orders_dev"))
    }

    @Test("collection colors save and load inline with collections")
    func collectionColorsRoundTrip() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        let workspace = APIWorkspace(
            id: "wrk_collection_color",
            name: "Collection Color Workspace",
            collections: [
                APICollection(
                    id: "col_orders",
                    name: "Orders",
                    color: .purple,
                    requests: [
                        APIRequest(
                            id: "req_orders",
                            name: "Orders",
                            method: .get,
                            url: "https://api.example.test/orders"
                        )
                    ]
                )
            ]
        )

        try store.save(workspace, to: tempURL)
        let loaded = try store.load(from: tempURL)
        let collectionYAML = try String(
            contentsOf: tempURL.appending(path: "collections/orders.yaml"),
            encoding: .utf8
        )

        #expect(loaded == workspace)
        #expect(collectionYAML.contains("color: purple"))
    }

    @Test("legacy collection YAML decodes without environments")
    func legacyCollectionYAMLDecodesWithoutEnvironments() throws {
        let data = try #require(
            #"{"id":"col_legacy","name":"Legacy","requests":[]}"#
                .data(using: .utf8)
        )

        let collection = try JSONDecoder().decode(APICollection.self, from: data)

        #expect(collection.id == "col_legacy")
        #expect(collection.color == nil)
        #expect(collection.environments.isEmpty)
    }

    @Test("secret environment values are redacted from shared YAML")
    func secretEnvironmentValuesAreRedactedFromSharedYAML() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        let workspace = APIWorkspace(
            id: "wrk_secret",
            name: "Secret Workspace",
            environments: [
                APIEnvironment(
                    id: "env_local",
                    name: "Local",
                    variables: [
                        APIVariable(name: "apiToken", value: "secret-token", isSecret: true),
                        APIVariable(name: "baseUrl", value: "http://localhost:3000", isSecret: false)
                    ]
                )
            ]
        )

        try store.save(workspace, to: tempURL)
        let environmentYAML = try String(
            contentsOf: tempURL.appending(path: "environments/local.yaml"),
            encoding: .utf8
        )
        let loaded = try store.load(from: tempURL)
        let loadedSecret = loaded.environments.first?.variables.first { $0.name == "apiToken" }
        let loadedBaseURL = loaded.environments.first?.variables.first { $0.name == "baseUrl" }

        #expect(!environmentYAML.contains("secret-token"))
        #expect(loadedSecret?.value == nil)
        #expect(loadedSecret?.isSecret == true)
        #expect(loadedBaseURL?.value == "http://localhost:3000")
    }

    @Test("sample workspace fixture loads")
    func sampleWorkspaceFixtureLoads() throws {
        let fixtureURL = URL(filePath: FileManager.default.currentDirectoryPath)
            .appending(path: "Fixtures/SampleWorkspace.workspace")

        let workspace = try WorkspaceFileStore().load(from: fixtureURL)

        #expect(workspace.id == "wrk_sample")
        #expect(workspace.collections.first?.requests.first?.url == "{{baseUrl}}/orders")
        #expect(workspace.collections.first?.requests.last?.kind == .graphQL)
        #expect(workspace.environments.first?.variables.contains { $0.name == "apiToken" && $0.isSecret } == true)
        #expect(workspace == .sample)
    }

    @Test("repeated saves remove stale collection and environment YAML")
    func repeatedSavesRemoveStaleCollectionAndEnvironmentFiles() throws {
        let tempURL = URL(filePath: NSTemporaryDirectory())
            .appending(path: UUID().uuidString)
            .appendingPathExtension("workspace")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        try store.save(.sample, to: tempURL)
        let clientCacheURL = tempURL.appending(path: ".client/cache.yaml")
        try "cached: true\n".write(to: clientCacheURL, atomically: true, encoding: .utf8)

        let updatedWorkspace = APIWorkspace(
            id: "wrk_sample",
            name: "Sample Workspace",
            collections: [],
            environments: [],
            history: []
        )

        try store.save(updatedWorkspace, to: tempURL)
        let loaded = try store.load(from: tempURL)

        #expect(loaded == updatedWorkspace)
        #expect(!FileManager.default.fileExists(atPath: tempURL.appending(path: "collections/orders.yaml").path))
        #expect(!FileManager.default.fileExists(atPath: tempURL.appending(path: "environments/local.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: ".client/history.yaml").path))
        #expect(FileManager.default.fileExists(atPath: clientCacheURL.path))
        #expect(try String(contentsOf: clientCacheURL, encoding: .utf8) == "cached: true\n")
    }

    @Test("save preserves existing workspace when validation fails")
    func savePreservesExistingWorkspaceWhenValidationFails() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        let originalWorkspace = APIWorkspace.sample
        let invalidWorkspace = APIWorkspace(
            id: "wrk_duplicate_collections",
            name: "Duplicate Collections",
            collections: [
                APICollection(id: "col_orders_upper", name: "Orders"),
                APICollection(id: "col_orders_lower", name: "orders")
            ]
        )

        try store.save(originalWorkspace, to: tempURL)

        #expect(throws: RequestLabError.invalidWorkspace("Duplicate collection filename: orders.yaml")) {
            try store.save(invalidWorkspace, to: tempURL)
        }

        let loaded = try store.load(from: tempURL)

        #expect(loaded == originalWorkspace)
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "workspace.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "collections/orders.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "environments/local.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: ".client/history.yaml").path))
    }

    @Test("save rejects duplicate collection and environment filenames")
    func saveRejectsDuplicateCollectionAndEnvironmentFileNames() throws {
        let store = WorkspaceFileStore(fileManager: .default)
        let duplicateCollectionsURL = temporaryWorkspaceURL()
        let duplicateEnvironmentsURL = temporaryWorkspaceURL()
        defer {
            try? FileManager.default.removeItem(at: duplicateCollectionsURL)
            try? FileManager.default.removeItem(at: duplicateEnvironmentsURL)
        }
        let duplicateCollectionsWorkspace = APIWorkspace(
            id: "wrk_duplicate_collections",
            name: "Duplicate Collections",
            collections: [
                APICollection(id: "col_orders_upper", name: "Orders"),
                APICollection(id: "col_orders_lower", name: "orders")
            ]
        )
        let duplicateEnvironmentsWorkspace = APIWorkspace(
            id: "wrk_duplicate_environments",
            name: "Duplicate Environments",
            environments: [
                APIEnvironment(id: "env_foo_slash", name: "Foo/Bar"),
                APIEnvironment(id: "env_foo_space", name: "Foo Bar")
            ]
        )

        #expect(throws: RequestLabError.invalidWorkspace("Duplicate collection filename: orders.yaml")) {
            try store.save(duplicateCollectionsWorkspace, to: duplicateCollectionsURL)
        }
        #expect(throws: RequestLabError.invalidWorkspace("Duplicate environment filename: foo-bar.yaml")) {
            try store.save(duplicateEnvironmentsWorkspace, to: duplicateEnvironmentsURL)
        }
    }

    @Test("save and load preserve collection and environment order")
    func saveAndLoadPreserveCollectionAndEnvironmentOrder() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        let workspace = APIWorkspace(
            id: "wrk_ordered",
            name: "Ordered Workspace",
            collections: [
                APICollection(id: "col_zebra", name: "Zebra"),
                APICollection(id: "col_alpha", name: "Alpha")
            ],
            environments: [
                APIEnvironment(id: "env_zebra", name: "Zebra"),
                APIEnvironment(id: "env_alpha", name: "Alpha")
            ]
        )

        try store.save(workspace, to: tempURL)
        let loaded = try store.load(from: tempURL)

        #expect(loaded.collections.map(\.id) == ["col_zebra", "col_alpha"])
        #expect(loaded.environments.map(\.id) == ["env_zebra", "env_alpha"])
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "collections/.order.yaml").path))
        #expect(FileManager.default.fileExists(atPath: tempURL.appending(path: "environments/.order.yaml").path))
    }

    @Test(".order.yaml rejects unlisted YAML files")
    func orderFileRejectsUnlistedYAMLFiles() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        try store.save(.sample, to: tempURL)
        try """
        id: col_draft
        name: Draft
        requests: []

        """.write(to: tempURL.appending(path: "collections/draft.yaml"), atomically: true, encoding: .utf8)

        do {
            _ = try store.load(from: tempURL)
            Issue.record("Expected invalidWorkspace for unlisted YAML file")
        } catch RequestLabError.invalidWorkspace(let message) {
            #expect(message.contains("unlisted YAML files: draft.yaml"))
        } catch {
            Issue.record("Expected invalidWorkspace, got \(error)")
        }
    }

    @Test(".order.yaml rejects missing listed YAML files")
    func orderFileRejectsMissingListedYAMLFiles() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        try store.save(.sample, to: tempURL)
        try """
        - orders.yaml
        - missing.yaml

        """.write(to: tempURL.appending(path: "collections/.order.yaml"), atomically: true, encoding: .utf8)

        do {
            _ = try store.load(from: tempURL)
            Issue.record("Expected invalidWorkspace for missing listed YAML file")
        } catch RequestLabError.invalidWorkspace(let message) {
            #expect(message.contains("listed missing YAML files: missing.yaml"))
        } catch {
            Issue.record("Expected invalidWorkspace, got \(error)")
        }
    }

    @Test("variable identity remains stable across rename")
    func variableIdentityIsStored() {
        var variable = APIVariable(name: "apiToken", value: nil, isSecret: true)

        #expect(variable.id == "var_apiToken")

        variable.name = "renamedApiToken"

        #expect(variable.id == "var_apiToken")
    }

    @Test("variable decoding keeps compatibility when id is absent")
    func variableDecodingDefaultsMissingID() throws {
        let data = try #require(#"{"name":"baseUrl","value":"http://localhost:3000","isSecret":false}"#.data(using: .utf8))
        let variable = try JSONDecoder().decode(APIVariable.self, from: data)

        #expect(variable.id == "var_baseUrl")
    }

    @Test("body none uses explicit type shape")
    func bodyNoneCodableShape() throws {
        let data = try JSONEncoder().encode(APIBody.none)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["type"] as? String == "none")
        #expect(object["value"] == nil)
        #expect(object["fields"] == nil)
        #expect(try JSONDecoder().decode(APIBody.self, from: data) == .none)
    }

    @Test("body raw round trips")
    func bodyRawRoundTrips() throws {
        let data = try JSONEncoder().encode(APIBody.raw("hello"))

        #expect(try JSONDecoder().decode(APIBody.self, from: data) == .raw("hello"))
    }

    @Test("body form round trips with fields")
    func bodyFormRoundTripsWithFields() throws {
        let data = try JSONEncoder().encode(APIBody.form(["a": "b"]))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let fields = try #require(object["fields"] as? [String: String])

        #expect(object["type"] as? String == "form")
        #expect(fields == ["a": "b"])
        #expect(try JSONDecoder().decode(APIBody.self, from: data) == .form(["a": "b"]))
    }

    @Test("body unknown type fails decoding")
    func bodyUnknownTypeFailsDecoding() throws {
        let data = try #require(#"{"type":"binary"}"#.data(using: .utf8))
        var didThrow = false

        do {
            _ = try JSONDecoder().decode(APIBody.self, from: data)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }

    @Test("request decoding defaults missing kind to REST")
    func requestDecodingDefaultsMissingKindToREST() throws {
        let data = try #require(
            #"{"id":"req_legacy","name":"Legacy","method":"GET","url":"https://api.example.test","headers":{},"params":{},"body":{"type":"none"}}"#
                .data(using: .utf8)
        )

        let request = try JSONDecoder().decode(APIRequest.self, from: data)

        #expect(request.kind == .rest)
        #expect(request.graphQL == nil)
    }

    @Test("GraphQL payload round trips")
    func graphQLPayloadRoundTrips() throws {
        let request = APIRequest(
            id: "req_graphql",
            name: "GraphQL orders",
            kind: .graphQL,
            method: .post,
            url: "https://api.example.test/graphql",
            graphQL: APIGraphQLPayload(
                query: "query Orders { orders { id } }",
                operationName: "Orders",
                variables: #"{"limit":50}"#
            )
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(APIRequest.self, from: data)

        #expect(decoded == request)
    }

    private func temporaryWorkspaceURL() -> URL {
        URL(filePath: NSTemporaryDirectory())
            .appending(path: UUID().uuidString)
            .appendingPathExtension("workspace")
    }
}

extension APIWorkspace {
    static var sample: APIWorkspace {
        APIWorkspace(
            id: "wrk_sample",
            name: "Sample Workspace",
            collections: [
                APICollection(
                    id: "col_orders",
                    name: "Orders",
                    requests: [
                        APIRequest(
                            id: "req_orders_list",
                            name: "List orders",
                            method: .get,
                            url: "{{baseUrl}}/orders",
                            headers: ["Accept": "application/json"],
                            params: ["limit": "50"],
                            auth: APIAuth(type: .bearer, tokenVariable: "apiToken"),
                            body: .none
                        ),
                        APIRequest(
                            id: "req_orders_graphql",
                            name: "GraphQL orders",
                            kind: .graphQL,
                            method: .post,
                            url: "{{baseUrl}}/graphql",
                            graphQL: APIGraphQLPayload(
                                query: """
                                query Orders($limit: Int!) {
                                  orders(limit: $limit) {
                                    id
                                    status
                                  }
                                }
                                """,
                                operationName: "Orders",
                                variables: #"{"limit": 50}"#
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
                        APIVariable(id: "var_baseUrl", name: "baseUrl", value: "http://localhost:3000", isSecret: false),
                        APIVariable(id: "var_apiToken", name: "apiToken", value: nil, isSecret: true)
                    ]
                )
            ],
            history: [
                APIHistoryEntry(
                    id: "hist_orders_list",
                    requestId: "req_orders_list",
                    method: .get,
                    url: "http://localhost:3000/orders",
                    statusCode: 200,
                    durationMilliseconds: 42
                )
            ]
        )
    }
}
