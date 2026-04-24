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

    @Test("returns false when request id is missing")
    func missingRequestReturnsFalse() {
        var workspace = APIWorkspace(id: "wrk_empty", name: "Empty")

        let didUpdate = workspace.updateRequest(id: "req_missing") { request in
            request.url = "https://api.example.test"
        }

        #expect(!didUpdate)
    }
}
