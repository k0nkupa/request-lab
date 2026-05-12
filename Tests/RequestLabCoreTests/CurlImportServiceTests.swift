import Foundation
import RequestLabCore
import Testing

@Suite("cURL import")
struct CurlImportServiceTests {
    @Test("imports POST JSON cURL command")
    func importsPostJSONCommand() throws {
        let command = """
        curl -X POST \\
          -H 'Accept: application/json' \\
          -H 'Content-Type: application/json' \\
          --data '{"brand":"TONY"}' \\
          https://api.example.test/orders
        """

        let request = try CurlImportService().importRequest(from: command)

        #expect(request.name == "POST /orders")
        #expect(request.method == .post)
        #expect(request.url == "https://api.example.test/orders")
        #expect(request.headers == ["Accept": "application/json", "Content-Type": "application/json"])
        #expect(request.body == .json(#"{"brand":"TONY"}"#))
    }

    @Test("imports short data flag as POST")
    func importsShortDataFlagAsPost() throws {
        let request = try CurlImportService().importRequest(
            from: #"curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'email=tony%40example.test&scope=orders' https://api.example.test/login"#
        )

        #expect(request.method == .post)
        #expect(request.body == .form(["email": "tony@example.test", "scope": "orders"]))
    }

    @Test("rejects non curl commands")
    func rejectsNonCurlCommands() {
        #expect(throws: RequestLabError.invalidWorkspace("cURL command must start with curl")) {
            _ = try CurlImportService().importRequest(from: "wget https://api.example.test")
        }
    }

    @Test("imported cURL request saves and loads in workspace")
    func importedCurlRequestSavesAndLoads() throws {
        let request = try CurlImportService().importRequest(
            from: #"curl -X POST -H 'Content-Type: application/json' --data '{"ok":true}' https://api.example.test/orders"#
        )
        let workspace = APIWorkspace(
            id: "wrk_curl",
            name: "cURL Workspace",
            collections: [
                APICollection(id: "col_curl", name: "cURL", requests: [request])
            ]
        )
        let workspaceURL = URL(filePath: NSTemporaryDirectory())
            .appending(path: UUID().uuidString)
            .appendingPathExtension("workspace")
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        try store.save(workspace, to: workspaceURL)
        let loaded = try store.load(from: workspaceURL)

        #expect(loaded.collections.first?.requests.first == request)
    }
}
