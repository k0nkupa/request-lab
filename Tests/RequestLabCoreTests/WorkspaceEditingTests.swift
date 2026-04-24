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

    @Test("returns false when request id is missing")
    func missingRequestReturnsFalse() {
        var workspace = APIWorkspace(id: "wrk_empty", name: "Empty")

        let didUpdate = workspace.updateRequest(id: "req_missing") { request in
            request.url = "https://api.example.test"
        }

        #expect(!didUpdate)
    }
}
