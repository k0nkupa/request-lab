# macOS API Client Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working native macOS foundation for RequestLab: SwiftPM app scaffold, three-pane SwiftUI shell, typed workspace model, YAML persistence, sample workspace, tests, and local run button.

**Architecture:** Use a SwiftPM SwiftUI GUI app with a small `RequestLabApp` target and a separate `RequestLabCore` library target for models and persistence. Keep UI, model, storage, fixtures, tests, and run tooling in separate files so the next plans can add request execution, GraphQL, Keychain, and Postman import without ripping up the foundation.

**Tech Stack:** Swift 6 toolchain, SwiftUI, Swift Testing, Foundation, Yams 6.2.1 for YAML, Swift Package Manager, project-local `.app` staging script.

---

## Scope

This plan implements the Phase 1 foundation only.

Included:

- SwiftPM package for a macOS 14+ SwiftUI app.
- App shell with native three-pane layout.
- RequestLab domain models.
- YAML load/save for workspace folders.
- Sample workspace fixture.
- Unit tests for model round-trip behavior.
- `script/build_and_run.sh`.
- `.codex/environments/environment.toml`.
- README with development commands.

Deferred to later plans:

- Real HTTP execution.
- GraphQL editor and request shaping.
- Keychain secret storage.
- Postman import.
- Response viewer.
- Rich AppKit-backed editors.
- Release packaging.

## File Structure

- Create: `Package.swift`  
  Defines `RequestLab`, `RequestLabCore`, and `RequestLabCoreTests`.
- Create: `Sources/RequestLab/App/RequestLabApp.swift`  
  SwiftUI app entrypoint and activation delegate.
- Create: `Sources/RequestLab/Views/ContentView.swift`  
  Root three-pane `NavigationSplitView`.
- Create: `Sources/RequestLab/Views/SidebarView.swift`  
  Workspace, collection, environment, and history navigation list.
- Create: `Sources/RequestLab/Views/RequestEditorView.swift`  
  Static request composer and foundation response panel.
- Create: `Sources/RequestLab/Views/InspectorView.swift`  
  Optional right-side inspector content.
- Create: `Sources/RequestLab/Stores/AppStore.swift`  
  App-level observable state that loads a sample workspace.
- Create: `Sources/RequestLabCore/Models/WorkspaceModels.swift`  
  Workspace, collection, request, environment, and history models.
- Create: `Sources/RequestLabCore/Stores/WorkspaceFileStore.swift`  
  YAML folder load/save service.
- Create: `Sources/RequestLabCore/Support/RequestLabError.swift`  
  Small typed error surface for persistence failures.
- Create: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`  
  Round-trip and fixture tests.
- Create: `Fixtures/SampleWorkspace.workspace/workspace.yaml`  
  Sample workspace metadata.
- Create: `Fixtures/SampleWorkspace.workspace/collections/orders.yaml`  
  Sample REST request collection.
- Create: `Fixtures/SampleWorkspace.workspace/environments/local.yaml`  
  Sample environment.
- Create: `Fixtures/SampleWorkspace.workspace/.client/history.yaml`  
  Sample local-only history.
- Create: `script/build_and_run.sh`  
  Kill, build, bundle, launch, verify, and log script.
- Create: `.codex/environments/environment.toml`  
  Codex app Run action.
- Create: `README.md`  
  Local development commands and scope note.
- Modify: `.gitignore`  
  Add `.swiftpm/` and `dist/`.

## Task 1: SwiftPM Package

**Files:**
- Create: `Package.swift`

- [ ] **Step 1: Create the package manifest**

Write `Package.swift`:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RequestLab",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RequestLab", targets: ["RequestLab"]),
        .library(name: "RequestLabCore", targets: ["RequestLabCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1")
    ],
    targets: [
        .executableTarget(
            name: "RequestLab",
            dependencies: ["RequestLabCore"],
            path: "Sources/RequestLab"
        ),
        .target(
            name: "RequestLabCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/RequestLabCore"
        ),
        .testTarget(
            name: "RequestLabCoreTests",
            dependencies: ["RequestLabCore"],
            path: "Tests/RequestLabCoreTests"
        )
    ]
)
```

- [ ] **Step 2: Resolve dependencies**

Run:

```bash
rtk swift package resolve
```

Expected: command exits with status `0` and creates `Package.resolved`.

- [ ] **Step 3: Commit package manifest**

```bash
rtk git add Package.swift Package.resolved
rtk git commit -m "chore: add SwiftPM package"
```

## Task 2: Core Workspace Models

**Files:**
- Create: `Sources/RequestLabCore/Models/WorkspaceModels.swift`
- Create: `Sources/RequestLabCore/Support/RequestLabError.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`

- [ ] **Step 1: Write failing model initialization test**

Create `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`:

```swift
import Foundation
import RequestLabCore
import Testing

@Suite("Workspace models")
struct WorkspaceFileStoreTests {
    @Test("workspace model exposes collections, environments, and history")
    func workspaceModelShape() throws {
        let workspace = APIWorkspace(
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
                        )
                    ]
                )
            ],
            environments: [
                APIEnvironment(
                    id: "env_local",
                    name: "Local",
                    variables: [
                        APIVariable(name: "baseUrl", value: "http://localhost:3000", isSecret: false),
                        APIVariable(name: "apiToken", value: nil, isSecret: true)
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

        #expect(workspace.collections.first?.requests.first?.auth?.tokenVariable == "apiToken")
        #expect(workspace.environments.first?.variables.count == 2)
        #expect(workspace.history.first?.statusCode == 200)
    }
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
rtk swift test --filter WorkspaceFileStoreTests/workspaceModelShape
```

Expected: FAIL because `APIWorkspace`, `APICollection`, and related model types do not exist.

- [ ] **Step 3: Add model types**

Create `Sources/RequestLabCore/Models/WorkspaceModels.swift`:

```swift
import Foundation

public struct APIWorkspace: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var collections: [APICollection]
    public var environments: [APIEnvironment]
    public var history: [APIHistoryEntry]

    public init(
        id: String,
        name: String,
        collections: [APICollection] = [],
        environments: [APIEnvironment] = [],
        history: [APIHistoryEntry] = []
    ) {
        self.id = id
        self.name = name
        self.collections = collections
        self.environments = environments
        self.history = history
    }
}

public struct APICollection: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var requests: [APIRequest]

    public init(id: String, name: String, requests: [APIRequest] = []) {
        self.id = id
        self.name = name
        self.requests = requests
    }
}

public struct APIRequest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var method: HTTPMethod
    public var url: String
    public var headers: [String: String]
    public var params: [String: String]
    public var auth: APIAuth?
    public var body: APIBody

    public init(
        id: String,
        name: String,
        method: HTTPMethod,
        url: String,
        headers: [String: String] = [:],
        params: [String: String] = [:],
        auth: APIAuth? = nil,
        body: APIBody = .none
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.url = url
        self.headers = headers
        self.params = params
        self.auth = auth
        self.body = body
    }
}

public enum HTTPMethod: String, Codable, CaseIterable, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

public struct APIAuth: Codable, Equatable, Sendable {
    public var type: APIAuthType
    public var tokenVariable: String?
    public var usernameVariable: String?
    public var passwordVariable: String?
    public var keyName: String?
    public var keyValueVariable: String?

    public init(
        type: APIAuthType,
        tokenVariable: String? = nil,
        usernameVariable: String? = nil,
        passwordVariable: String? = nil,
        keyName: String? = nil,
        keyValueVariable: String? = nil
    ) {
        self.type = type
        self.tokenVariable = tokenVariable
        self.usernameVariable = usernameVariable
        self.passwordVariable = passwordVariable
        self.keyName = keyName
        self.keyValueVariable = keyValueVariable
    }
}

public enum APIAuthType: String, Codable, Equatable, Sendable {
    case none
    case bearer
    case basic
    case apiKey
}

public enum APIBody: Codable, Equatable, Sendable {
    case none
    case raw(String)
    case json(String)
    case form([String: String])

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case fields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "none":
            self = .none
        case "raw":
            self = .raw(try container.decode(String.self, forKey: .value))
        case "json":
            self = .json(try container.decode(String.self, forKey: .value))
        case "form":
            self = .form(try container.decode([String: String].self, forKey: .fields))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported body type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .none:
            try container.encode("none", forKey: .type)
        case .raw(let value):
            try container.encode("raw", forKey: .type)
            try container.encode(value, forKey: .value)
        case .json(let value):
            try container.encode("json", forKey: .type)
            try container.encode(value, forKey: .value)
        case .form(let fields):
            try container.encode("form", forKey: .type)
            try container.encode(fields, forKey: .fields)
        }
    }
}

public struct APIEnvironment: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var variables: [APIVariable]

    public init(id: String, name: String, variables: [APIVariable] = []) {
        self.id = id
        self.name = name
        self.variables = variables
    }
}

public struct APIVariable: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var value: String?
    public var isSecret: Bool

    public init(name: String, value: String? = nil, isSecret: Bool = false) {
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }
}

public struct APIHistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var requestId: String
    public var method: HTTPMethod
    public var url: String
    public var statusCode: Int?
    public var durationMilliseconds: Int?

    public init(
        id: String,
        requestId: String,
        method: HTTPMethod,
        url: String,
        statusCode: Int? = nil,
        durationMilliseconds: Int? = nil
    ) {
        self.id = id
        self.requestId = requestId
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.durationMilliseconds = durationMilliseconds
    }
}
```

- [ ] **Step 4: Add typed error surface**

Create `Sources/RequestLabCore/Support/RequestLabError.swift`:

```swift
import Foundation

public enum RequestLabError: Error, Equatable, LocalizedError, Sendable {
    case missingWorkspaceFile(URL)
    case missingDirectory(URL)
    case invalidWorkspace(String)
    case yamlDecodeFailed(String)
    case yamlEncodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingWorkspaceFile(let url):
            "Missing workspace file: \(url.path)"
        case .missingDirectory(let url):
            "Missing directory: \(url.path)"
        case .invalidWorkspace(let message):
            "Invalid workspace: \(message)"
        case .yamlDecodeFailed(let message):
            "Failed to decode YAML: \(message)"
        case .yamlEncodeFailed(let message):
            "Failed to encode YAML: \(message)"
        }
    }
}
```

- [ ] **Step 5: Run model test**

Run:

```bash
rtk swift test --filter WorkspaceFileStoreTests/workspaceModelShape
```

Expected: PASS.

- [ ] **Step 6: Commit models**

```bash
rtk git add Sources/RequestLabCore Tests/RequestLabCoreTests
rtk git commit -m "feat: add workspace domain models"
```

## Task 3: YAML Workspace File Store

**Files:**
- Modify: `Sources/RequestLabCore/Stores/WorkspaceFileStore.swift`
- Modify: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`

- [ ] **Step 1: Add failing YAML round-trip test**

Replace `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift` with:

```swift
import Foundation
import RequestLabCore
import Testing

@Suite("Workspace file store")
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
                        )
                    ]
                )
            ],
            environments: [
                APIEnvironment(
                    id: "env_local",
                    name: "Local",
                    variables: [
                        APIVariable(name: "baseUrl", value: "http://localhost:3000", isSecret: false),
                        APIVariable(name: "apiToken", value: nil, isSecret: true)
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
```

- [ ] **Step 2: Run failing store test**

Run:

```bash
rtk swift test --filter WorkspaceFileStoreTests/workspaceRoundTrip
```

Expected: FAIL because `WorkspaceFileStore` does not exist.

- [ ] **Step 3: Add YAML store implementation**

Create `Sources/RequestLabCore/Stores/WorkspaceFileStore.swift`:

```swift
import Foundation
import Yams

public final class WorkspaceFileStore: Sendable {
    private let fileManager: FileManager
    private let encoder: YAMLEncoder
    private let decoder: YAMLDecoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = YAMLEncoder()
        self.decoder = YAMLDecoder()
    }

    public func load(from workspaceURL: URL) throws -> APIWorkspace {
        let workspaceFile = workspaceURL.appending(path: "workspace.yaml")
        guard fileManager.fileExists(atPath: workspaceFile.path) else {
            throw RequestLabError.missingWorkspaceFile(workspaceFile)
        }

        let metadata: WorkspaceMetadata = try decode(WorkspaceMetadata.self, from: workspaceFile)
        let collections = try loadCollections(from: workspaceURL)
        let environments = try loadEnvironments(from: workspaceURL)
        let history = try loadHistory(from: workspaceURL)

        return APIWorkspace(
            id: metadata.id,
            name: metadata.name,
            collections: collections,
            environments: environments,
            history: history
        )
    }

    public func save(_ workspace: APIWorkspace, to workspaceURL: URL) throws {
        try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: workspaceURL.appending(path: "collections"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: workspaceURL.appending(path: "environments"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: workspaceURL.appending(path: ".client"), withIntermediateDirectories: true)

        let metadata = WorkspaceMetadata(id: workspace.id, name: workspace.name)
        try encode(metadata, to: workspaceURL.appending(path: "workspace.yaml"))

        for collection in workspace.collections {
            try encode(collection, to: workspaceURL.appending(path: "collections/\(fileName(for: collection.name)).yaml"))
        }

        for environment in workspace.environments {
            try encode(environment, to: workspaceURL.appending(path: "environments/\(fileName(for: environment.name)).yaml"))
        }

        try encode(workspace.history, to: workspaceURL.appending(path: ".client/history.yaml"))
    }

    private func loadCollections(from workspaceURL: URL) throws -> [APICollection] {
        let directory = workspaceURL.appending(path: "collections")
        return try loadYAMLFiles(in: directory, as: APICollection.self)
    }

    private func loadEnvironments(from workspaceURL: URL) throws -> [APIEnvironment] {
        let directory = workspaceURL.appending(path: "environments")
        return try loadYAMLFiles(in: directory, as: APIEnvironment.self)
    }

    private func loadHistory(from workspaceURL: URL) throws -> [APIHistoryEntry] {
        let historyFile = workspaceURL.appending(path: ".client/history.yaml")
        guard fileManager.fileExists(atPath: historyFile.path) else {
            return []
        }

        return try decode([APIHistoryEntry].self, from: historyFile)
    }

    private func loadYAMLFiles<T: Decodable>(in directory: URL, as type: T.Type) throws -> [T] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "yaml" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try files.map { try decode(T.self, from: $0) }
    }

    private func decode<T: Decodable>(_ type: T.Type, from fileURL: URL) throws -> T {
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return try decoder.decode(T.self, from: text)
        } catch let error as RequestLabError {
            throw error
        } catch {
            throw RequestLabError.yamlDecodeFailed("\(fileURL.path): \(error.localizedDescription)")
        }
    }

    private func encode<T: Encodable>(_ value: T, to fileURL: URL) throws {
        do {
            let text = try encoder.encode(value)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RequestLabError.yamlEncodeFailed("\(fileURL.path): \(error.localizedDescription)")
        }
    }

    private func fileName(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = name.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let candidate = String(scalars)
            .split(separator: "-")
            .joined(separator: "-")

        return candidate.isEmpty ? "item" : candidate
    }
}

private struct WorkspaceMetadata: Codable, Equatable, Sendable {
    var id: String
    var name: String
}
```

- [ ] **Step 4: Run YAML store tests**

Run:

```bash
rtk swift test --filter WorkspaceFileStoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit file store**

```bash
rtk git add Sources/RequestLabCore/Stores Tests/RequestLabCoreTests
rtk git commit -m "feat: add YAML workspace store"
```

## Task 4: Sample Workspace Fixture

**Files:**
- Create: `Fixtures/SampleWorkspace.workspace/workspace.yaml`
- Create: `Fixtures/SampleWorkspace.workspace/collections/orders.yaml`
- Create: `Fixtures/SampleWorkspace.workspace/environments/local.yaml`
- Create: `Fixtures/SampleWorkspace.workspace/.client/history.yaml`
- Modify: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`

- [ ] **Step 1: Create fixture files**

Create `Fixtures/SampleWorkspace.workspace/workspace.yaml`:

```yaml
id: wrk_sample
name: Sample Workspace
```

Create `Fixtures/SampleWorkspace.workspace/collections/orders.yaml`:

```yaml
id: col_orders
name: Orders
requests:
- id: req_orders_list
  name: List orders
  method: GET
  url: "{{baseUrl}}/orders"
  headers:
    Accept: application/json
  params:
    limit: "50"
  auth:
    type: bearer
    tokenVariable: apiToken
  body:
    type: none
```

Create `Fixtures/SampleWorkspace.workspace/environments/local.yaml`:

```yaml
id: env_local
name: Local
variables:
- name: baseUrl
  value: http://localhost:3000
  isSecret: false
- name: apiToken
  isSecret: true
```

Create `Fixtures/SampleWorkspace.workspace/.client/history.yaml`:

```yaml
- id: hist_orders_list
  requestId: req_orders_list
  method: GET
  url: http://localhost:3000/orders
  statusCode: 200
  durationMilliseconds: 42
```

- [ ] **Step 2: Add failing fixture test**

Add this test inside `WorkspaceFileStoreTests`:

```swift
@Test("sample workspace fixture loads")
func sampleWorkspaceFixtureLoads() throws {
    let fixtureURL = URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "Fixtures/SampleWorkspace.workspace")

    let workspace = try WorkspaceFileStore().load(from: fixtureURL)

    #expect(workspace.id == "wrk_sample")
    #expect(workspace.collections.first?.requests.first?.url == "{{baseUrl}}/orders")
    #expect(workspace.environments.first?.variables.contains { $0.name == "apiToken" && $0.isSecret })
}
```

- [ ] **Step 3: Run fixture test**

Run:

```bash
rtk swift test --filter WorkspaceFileStoreTests/sampleWorkspaceFixtureLoads
```

Expected: PASS.

- [ ] **Step 4: Run all core tests**

Run:

```bash
rtk swift test
```

Expected: PASS.

- [ ] **Step 5: Commit fixture**

```bash
rtk git add Fixtures Tests Sources/RequestLabCore/Models/WorkspaceModels.swift
rtk git commit -m "test: add sample workspace fixture"
```

## Task 5: App Store And Three-Pane SwiftUI Shell

**Files:**
- Create: `Sources/RequestLab/App/RequestLabApp.swift`
- Create: `Sources/RequestLab/Stores/AppStore.swift`
- Create: `Sources/RequestLab/Views/ContentView.swift`
- Create: `Sources/RequestLab/Views/SidebarView.swift`
- Create: `Sources/RequestLab/Views/RequestEditorView.swift`
- Create: `Sources/RequestLab/Views/InspectorView.swift`

- [ ] **Step 1: Create app store**

Create `Sources/RequestLab/Stores/AppStore.swift`:

```swift
import Foundation
import Observation
import RequestLabCore

@Observable
final class AppStore {
    var workspace: APIWorkspace
    var selectedRequestID: APIRequest.ID?
    var selectedEnvironmentID: APIEnvironment.ID?
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
            id: "wrk_empty",
            name: "Untitled Workspace",
            collections: [
                APICollection(
                    id: "col_starter",
                    name: "Starter",
                    requests: [
                        APIRequest(
                            id: "req_welcome",
                            name: "Welcome request",
                            method: .get,
                            url: "https://api.example.com/health",
                            headers: ["Accept": "application/json"],
                            params: [:],
                            auth: nil,
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
                        APIVariable(name: "baseUrl", value: "http://localhost:3000", isSecret: false)
                    ]
                )
            ],
            history: []
        )
    }
}
```

- [ ] **Step 2: Create app entrypoint**

Create `Sources/RequestLab/App/RequestLabApp.swift`:

```swift
import AppKit
import SwiftUI

@main
struct RequestLabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup("RequestLab") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandMenu("Request") {
                Button("Send Request") {}
                    .keyboardShortcut(.return, modifiers: [.command])
                Button("Save Request") {}
                    .keyboardShortcut("s", modifiers: [.command])
            }

            CommandMenu("View") {
                Button(store.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                    store.isInspectorVisible.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }

        Settings {
            Form {
                Text("RequestLab Settings")
                Text("Preferences are empty in the foundation slice.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 420)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 3: Create root content view**

Create `Sources/RequestLab/Views/ContentView.swift`:

```swift
import RequestLabCore
import SwiftUI

struct ContentView: View {
    @Bindable var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } content: {
            RequestEditorView(request: store.selectedRequest)
        } detail: {
            if store.isInspectorVisible {
                InspectorView(environment: store.selectedEnvironment, request: store.selectedRequest)
            } else {
                Text("Inspector hidden")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.workspace.name)
        .toolbar {
            ToolbarItemGroup {
                Button("Send", systemImage: "paperplane.fill") {}
                    .keyboardShortcut(.return, modifiers: [.command])
                Button("Save", systemImage: "tray.and.arrow.down") {}
                    .keyboardShortcut("s", modifiers: [.command])
            }

            ToolbarItem {
                Picker("Environment", selection: $store.selectedEnvironmentID) {
                    ForEach(store.workspace.environments) { environment in
                        Text(environment.name).tag(Optional(environment.id))
                    }
                }
                .frame(width: 160)
            }

            ToolbarItem {
                Button(store.isInspectorVisible ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right") {
                    store.isInspectorVisible.toggle()
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create sidebar view**

Create `Sources/RequestLab/Views/SidebarView.swift`:

```swift
import RequestLabCore
import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore

    var body: some View {
        List(selection: $store.selectedRequestID) {
            Section("Collections") {
                ForEach(store.workspace.collections) { collection in
                    DisclosureGroup {
                        ForEach(collection.requests) { request in
                            Label(request.name, systemImage: "bolt.horizontal")
                                .tag(Optional(request.id))
                        }
                    } label: {
                        Label(collection.name, systemImage: "folder")
                    }
                }
            }

            Section("Environments") {
                ForEach(store.workspace.environments) { environment in
                    Label(environment.name, systemImage: "slider.horizontal.3")
                }
            }

            Section("History") {
                ForEach(store.workspace.history) { item in
                    Label("\(item.method.rawValue) \(item.url)", systemImage: "clock")
                        .lineLimit(1)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    }
}
```

- [ ] **Step 5: Create request editor view**

Create `Sources/RequestLab/Views/RequestEditorView.swift`:

```swift
import RequestLabCore
import SwiftUI

struct RequestEditorView: View {
    let request: APIRequest?

    var body: some View {
        VStack(spacing: 0) {
            if let request {
                requestBar(for: request)
                Divider()
                requestTabs(for: request)
                Divider()
                responsePlaceholder
            } else {
                ContentUnavailableView("No Request Selected", systemImage: "tray")
            }
        }
        .navigationSplitViewColumnWidth(min: 520, ideal: 760)
    }

    private func requestBar(for request: APIRequest) -> some View {
        HStack(spacing: 8) {
            Text(request.method.rawValue)
                .font(.headline)
                .frame(width: 72)
            Text(request.url)
                .font(.body.monospaced())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Send", systemImage: "paperplane.fill") {}
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func requestTabs(for request: APIRequest) -> some View {
        TabView {
            keyValueList("Params", values: request.params)
                .tabItem { Text("Params") }
            keyValueList("Headers", values: request.headers)
                .tabItem { Text("Headers") }
            Text(request.auth?.type.rawValue ?? "No auth")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .tabItem { Text("Auth") }
            Text("Body editor is not part of the foundation slice.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Text("Body") }
        }
        .frame(minHeight: 260)
    }

    private var responsePlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response")
                .font(.headline)
            Text("Request execution is not part of the foundation slice.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
    }

    private func keyValueList(_ title: String, values: [String: String]) -> some View {
        List {
            if values.isEmpty {
                Text("No \(title.lowercased())")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(values.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.body.monospaced())
                        Spacer()
                        Text(value)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 6: Create inspector view**

Create `Sources/RequestLab/Views/InspectorView.swift`:

```swift
import RequestLabCore
import SwiftUI

struct InspectorView: View {
    let environment: APIEnvironment?
    let request: APIRequest?

    var body: some View {
        List {
            Section("Request") {
                if let request {
                    LabeledContent("Name", value: request.name)
                    LabeledContent("Method", value: request.method.rawValue)
                    LabeledContent("Auth", value: request.auth?.type.rawValue ?? "None")
                } else {
                    Text("No request selected")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Environment") {
                if let environment {
                    LabeledContent("Name", value: environment.name)
                    ForEach(environment.variables) { variable in
                        LabeledContent(variable.name, value: variable.isSecret ? "Keychain secret" : (variable.value ?? "Empty"))
                    }
                } else {
                    Text("No environment selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
    }
}
```

- [ ] **Step 7: Build the app**

Run:

```bash
rtk swift build
```

Expected: PASS.

- [ ] **Step 8: Commit app shell**

```bash
rtk git add Sources/RequestLab
rtk git commit -m "feat: add native macOS app shell"
```

## Task 6: Build And Run Tooling

**Files:**
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`
- Modify: `.gitignore`

- [ ] **Step 1: Add run script**

Create `script/build_and_run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="RequestLab"
BUNDLE_ID="dev.requestlab.app"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

rtk swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
rtk chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 2: Make script executable**

Run:

```bash
rtk chmod +x script/build_and_run.sh
```

Expected: `test -x script/build_and_run.sh` exits with status `0`.

- [ ] **Step 3: Add Codex Run action**

Create `.codex/environments/environment.toml`:

```toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "RequestLab"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 4: Update ignore rules**

Append these lines to `.gitignore`:

```gitignore
.swiftpm/
dist/
```

- [ ] **Step 5: Verify app launch path**

Run:

```bash
rtk ./script/build_and_run.sh --verify
```

Expected: command exits with status `0` and `RequestLab` is running as a macOS app bundle.

- [ ] **Step 6: Commit tooling**

```bash
rtk git add .codex .gitignore script
rtk git commit -m "chore: add macOS run tooling"
```

## Task 7: README And Foundation Verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Add README**

Create `README.md`:

```markdown
# RequestLab

RequestLab is a lightweight, open-source macOS API client. It is designed as a native SwiftUI alternative to Postman for REST and GraphQL workflows.

## Current Scope

This repository currently contains the Phase 1 foundation:

- Native SwiftUI macOS app shell.
- Three-pane workspace, request, and inspector layout.
- Typed workspace models.
- YAML workspace load/save.
- Sample workspace fixture.
- Swift tests for model and persistence behavior.
- Local build/run script for Codex and terminal workflows.

Request execution, GraphQL editing, Keychain secrets, and Postman import are planned follow-up slices.

## Requirements

- macOS 14 Sonoma or later.
- Xcode command line tools with Swift 6 support.

## Development

Resolve dependencies:

```bash
rtk swift package resolve
```

Run tests:

```bash
rtk swift test
```

Build:

```bash
rtk swift build
```

Build and launch the macOS app:

```bash
rtk ./script/build_and_run.sh
```

Verify the app process launches:

```bash
rtk ./script/build_and_run.sh --verify
```

## Workspace Format

Workspace folders use YAML files:

```text
SampleWorkspace.workspace/
  workspace.yaml
  collections/
  environments/
  .client/
```

Files under `.client/` are local-only and should not be treated as shareable API definitions.
```

- [ ] **Step 2: Run full verification**

Run:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
```

Expected: all commands exit with status `0`.

- [ ] **Step 3: Inspect git status**

Run:

```bash
rtk git status --short
```

Expected: only `README.md` is uncommitted.

- [ ] **Step 4: Commit README**

```bash
rtk git add README.md
rtk git commit -m "docs: add RequestLab foundation README"
```

## Task 8: Final Foundation Audit

**Files:**
- Inspect: `Package.swift`
- Inspect: `Sources/RequestLab`
- Inspect: `Sources/RequestLabCore`
- Inspect: `Tests/RequestLabCoreTests`
- Inspect: `script/build_and_run.sh`
- Inspect: `.codex/environments/environment.toml`
- Inspect: `README.md`

- [ ] **Step 1: Run final commands**

Run:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
rtk git status --short
```

Expected:

```text
rtk swift test: exit 0
rtk swift build: exit 0
build_and_run --verify: exit 0
rtk git status --short: no output
```

- [ ] **Step 2: Confirm foundation coverage**

Check:

```bash
rtk proxy find Sources Tests Fixtures script .codex -maxdepth 4 -type f
```

Expected files include:

```text
.codex/environments/environment.toml
Fixtures/SampleWorkspace.workspace/.client/history.yaml
Fixtures/SampleWorkspace.workspace/collections/orders.yaml
Fixtures/SampleWorkspace.workspace/environments/local.yaml
Fixtures/SampleWorkspace.workspace/workspace.yaml
Sources/RequestLab/App/RequestLabApp.swift
Sources/RequestLab/Stores/AppStore.swift
Sources/RequestLab/Views/ContentView.swift
Sources/RequestLab/Views/InspectorView.swift
Sources/RequestLab/Views/RequestEditorView.swift
Sources/RequestLab/Views/SidebarView.swift
Sources/RequestLabCore/Models/WorkspaceModels.swift
Sources/RequestLabCore/Stores/WorkspaceFileStore.swift
Sources/RequestLabCore/Support/RequestLabError.swift
Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift
script/build_and_run.sh
```

- [ ] **Step 3: Report next slice**

Report this exact next-slice recommendation in the handoff:

```text
Next implementation slice: request execution and variable resolution.
```

## Plan Self-Review

Spec coverage:

- Native macOS SwiftUI foundation: covered by Tasks 1, 5, and 6.
- Three-pane layout: covered by Task 5.
- YAML workspace files: covered by Tasks 3 and 4.
- Git-friendly local workspace foundation: covered by model and fixture files in Tasks 2-4.
- Tests: covered by Tasks 2-4 and final verification in Task 8.
- Build/run tooling: covered by Task 6.

Intentional gaps for later plans:

- HTTP execution and response viewer.
- GraphQL-specific composer.
- Keychain storage.
- Postman importer.
- Import/export UI.

Incomplete-content scan:

- No incomplete markers or unnamed file paths are used.
- `RequestLab` is the concrete working app name for this plan.

Type consistency:

- Model names are consistent across tests, store, and UI: `APIWorkspace`, `APICollection`, `APIRequest`, `APIEnvironment`, `APIVariable`, `APIHistoryEntry`.
- Store API is consistently `WorkspaceFileStore.load(from:)` and `WorkspaceFileStore.save(_:to:)`.
