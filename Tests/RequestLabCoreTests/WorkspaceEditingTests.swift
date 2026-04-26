import RequestLabCore
import Testing

@Suite("Workspace editing")
struct WorkspaceEditingTests {
    @Test("updates nested requests by id")
    func updatesNestedRequestsByID() {
        var workspace = APIWorkspace(
            id: "wrk_editing",
            name: "Editing",
            collections: [
                APICollection(
                    id: "col_orders",
                    name: "Orders",
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

        let didUpdate = workspace.updateRequest(id: "req_orders") { request in
            request.method = .post
            request.url = "https://api.example.test/orders/create"
        }

        #expect(didUpdate)
        #expect(workspace.collections.first?.requests.first?.method == .post)
        #expect(workspace.collections.first?.requests.first?.url == "https://api.example.test/orders/create")
    }

    @Test("adds and deletes collections")
    func addsAndDeletesCollections() {
        var workspace = APIWorkspace(id: "wrk", name: "Workspace")
        let collection = APICollection(id: "col_new", name: "New")

        workspace.addCollection(collection)

        #expect(workspace.collections == [collection])
        let didDelete = workspace.deleteCollection(id: "col_new")
        #expect(didDelete)
        #expect(workspace.collections.isEmpty)
    }

    @Test("renames collections by id")
    func renamesCollectionsByID() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col_orders", name: "Orders")]
        )

        let didRename = workspace.renameCollection(id: "col_orders", to: "\n  Customer Orders \t\n")

        #expect(didRename)
        #expect(workspace.collections.first?.name == "Customer Orders")
    }

    @Test("rename collection rejects empty names")
    func renameCollectionRejectsEmptyNames() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col_orders", name: "Orders")]
        )

        let didRename = workspace.renameCollection(id: "col_orders", to: "   ")

        #expect(!didRename)
        #expect(workspace.collections.first?.name == "Orders")
    }

    @Test("rename collection rejects duplicate save filenames")
    func renameCollectionRejectsDuplicateSaveFilenames() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [
                APICollection(id: "col_foo", name: "Foo Bar"),
                APICollection(id: "col_orders", name: "Orders"),
            ]
        )

        let didRename = workspace.renameCollection(id: "col_orders", to: "Foo/Bar")

        #expect(!didRename)
        #expect(workspace.collections.map(\.name) == ["Foo Bar", "Orders"])
    }

    @Test("sets and clears collection colors")
    func setsAndClearsCollectionColors() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col_orders", name: "Orders")]
        )

        let didSetColor = workspace.updateCollectionColor(id: "col_orders", color: .blue)
        #expect(didSetColor)
        #expect(workspace.collections.first?.color == .blue)

        let didClearColor = workspace.updateCollectionColor(id: "col_orders", color: nil)

        #expect(didClearColor)
        #expect(workspace.collections.first?.color == nil)
    }

    @Test("adds and deletes requests")
    func addsAndDeletesRequests() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col", name: "Collection")]
        )
        let request = APIRequest(
            id: "req_new",
            name: "New",
            method: .get,
            url: "https://api.example.test"
        )

        let didAdd = workspace.addRequest(request, toCollectionID: "col")
        #expect(didAdd)
        #expect(workspace.collectionID(containingRequestID: "req_new") == "col")
        let didDelete = workspace.deleteRequest(id: "req_new")
        #expect(didDelete)
        #expect(workspace.collections.first?.requests.isEmpty == true)
    }

    @Test("adds and deletes environments")
    func addsAndDeletesEnvironments() {
        var workspace = APIWorkspace(id: "wrk", name: "Workspace")
        let environment = APIEnvironment(id: "env_new", name: "New")

        workspace.addEnvironment(environment)

        #expect(workspace.environments == [environment])
        let didDelete = workspace.deleteEnvironment(id: "env_new")
        #expect(didDelete)
        #expect(workspace.environments.isEmpty)
    }

    @Test("adds and deletes collection environments")
    func addsAndDeletesCollectionEnvironments() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col", name: "Collection")]
        )
        let environment = APIEnvironment(id: "env_collection", name: "Collection Dev")

        let didAdd = workspace.addCollectionEnvironment(environment, toCollectionID: "col")
        #expect(didAdd)
        #expect(workspace.collections.first?.environments == [environment])

        let didDelete = workspace.deleteCollectionEnvironment(id: "env_collection", fromCollectionID: "col")
        #expect(didDelete)
        #expect(workspace.collections.first?.environments.isEmpty == true)
    }

    @Test("updates environments and variables across global and collection scopes")
    func updatesEnvironmentsAndVariablesAcrossScopes() throws {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [
                APICollection(
                    id: "col",
                    name: "Collection",
                    environments: [
                        APIEnvironment(
                            id: "env_collection",
                            name: "Collection Local",
                            variables: [
                                APIVariable(id: "var_base", name: "baseUrl", value: "http://localhost:3000")
                            ]
                        )
                    ]
                )
            ],
            environments: [
                APIEnvironment(id: "env_global", name: "Global Local")
            ]
        )

        let didRenameGlobal = workspace.updateEnvironment(id: "env_global") { environment in
            environment.name = "Global Dev"
        }
        #expect(didRenameGlobal)
        #expect(workspace.environments.first?.name == "Global Dev")

        let didAddVariable = workspace.addEnvironmentVariable(
            APIVariable(id: "var_token", name: "apiToken", value: nil, isSecret: true),
            toEnvironmentID: "env_collection"
        )
        #expect(didAddVariable)

        let didRenameVariable = workspace.updateEnvironmentVariable(
            environmentID: "env_collection",
            variableID: "var_base"
        ) { variable in
            variable.name = "BaseUrl"
            variable.value = "http://localhost:4000"
        }
        #expect(didRenameVariable)

        let collectionEnvironment = try #require(workspace.collections.first?.environments.first)
        #expect(collectionEnvironment.variables.map(\.name) == ["BaseUrl", "apiToken"])
        #expect(collectionEnvironment.variables.first?.value == "http://localhost:4000")

        let deletedVariable = workspace.deleteEnvironmentVariable(
            environmentID: "env_collection",
            variableID: "var_token"
        )
        #expect(deletedVariable?.name == "apiToken")
        #expect(workspace.collections.first?.environments.first?.variables.map(\.name) == ["BaseUrl"])
    }

    @Test("environment variable edits fail for missing ids")
    func environmentVariableEditsFailForMissingIDs() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            environments: [
                APIEnvironment(
                    id: "env_global",
                    name: "Global Local",
                    variables: [APIVariable(id: "var_base", name: "baseUrl")]
                )
            ]
        )

        let didAddMissingVariable = workspace.addEnvironmentVariable(APIVariable(name: "newKey"), toEnvironmentID: "env_missing")
        let didUpdateMissingVariable = workspace.updateEnvironmentVariable(environmentID: "env_global", variableID: "var_missing") { variable in
            variable.name = "BaseUrl"
        }
        let deletedMissingVariable = workspace.deleteEnvironmentVariable(environmentID: "env_global", variableID: "var_missing")

        #expect(!didAddMissingVariable)
        #expect(!didUpdateMissingVariable)
        #expect(deletedMissingVariable == nil)
    }

    @Test("returns false when request id is missing")
    func missingRequestReturnsFalse() {
        var workspace = APIWorkspace(id: "wrk_empty", name: "Empty")

        let didUpdate = workspace.updateRequest(id: "req_missing") { request in
            request.url = "https://api.example.test"
        }

        #expect(!didUpdate)
    }
}
