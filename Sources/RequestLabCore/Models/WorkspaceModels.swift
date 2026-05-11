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

public enum APICollectionColor: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case blue
    case green
    case red
    case purple
    case orange
    case cyan
    case indigo
    case pink
    case gray

    public var id: String { rawValue }
}

public struct APICollection: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var color: APICollectionColor?
    public var environments: [APIEnvironment]
    public var requests: [APIRequest]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case environments
        case requests
    }

    public init(
        id: String,
        name: String,
        color: APICollectionColor? = nil,
        environments: [APIEnvironment] = [],
        requests: [APIRequest] = []
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.environments = environments
        self.requests = requests
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
            .flatMap(APICollectionColor.init(rawValue:))
        self.environments = try container.decodeIfPresent([APIEnvironment].self, forKey: .environments) ?? []
        self.requests = try container.decodeIfPresent([APIRequest].self, forKey: .requests) ?? []
    }
}

public struct APIRequest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kind: APIRequestKind
    public var method: HTTPMethod
    public var url: String
    public var headers: [String: String]
    public var params: [String: String]
    public var auth: APIAuth?
    public var body: APIBody
    public var graphQL: APIGraphQLPayload?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case method
        case url
        case headers
        case params
        case auth
        case body
        case graphQL
    }

    public init(
        id: String,
        name: String,
        kind: APIRequestKind = .rest,
        method: HTTPMethod,
        url: String,
        headers: [String: String] = [:],
        params: [String: String] = [:],
        auth: APIAuth? = nil,
        body: APIBody = .none,
        graphQL: APIGraphQLPayload? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.method = method
        self.url = url
        self.headers = headers
        self.params = params
        self.auth = auth
        self.body = body
        self.graphQL = graphQL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decodeIfPresent(APIRequestKind.self, forKey: .kind) ?? .rest
        self.method = try container.decode(HTTPMethod.self, forKey: .method)
        self.url = try container.decode(String.self, forKey: .url)
        self.headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        self.params = try container.decodeIfPresent([String: String].self, forKey: .params) ?? [:]
        self.auth = try container.decodeIfPresent(APIAuth.self, forKey: .auth)
        self.body = try container.decodeIfPresent(APIBody.self, forKey: .body) ?? .none
        self.graphQL = try container.decodeIfPresent(APIGraphQLPayload.self, forKey: .graphQL)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(method, forKey: .method)
        try container.encode(url, forKey: .url)
        try container.encode(headers, forKey: .headers)
        try container.encode(params, forKey: .params)
        try container.encodeIfPresent(auth, forKey: .auth)
        try container.encode(body, forKey: .body)
        try container.encodeIfPresent(graphQL, forKey: .graphQL)
    }
}

public enum APIRequestKind: String, Codable, CaseIterable, Equatable, Sendable {
    case rest
    case graphQL = "graphql"
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

public enum APIAuthType: String, Codable, CaseIterable, Equatable, Sendable {
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

public struct APIGraphQLPayload: Codable, Equatable, Sendable {
    public var query: String
    public var operationName: String?
    public var variables: String

    public init(query: String, operationName: String? = nil, variables: String = "{}") {
        self.query = query
        self.operationName = operationName
        self.variables = variables
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

    public static func merged(global: APIEnvironment?, collection: APIEnvironment?) -> APIEnvironment? {
        guard global != nil || collection != nil else {
            return nil
        }

        var variables: [APIVariable] = []
        var indexesByName: [String: Int] = [:]

        for variable in global?.variables ?? [] {
            indexesByName[variable.name] = variables.count
            variables.append(variable)
        }

        for variable in collection?.variables ?? [] {
            if let index = indexesByName[variable.name] {
                variables[index] = variable
            } else {
                indexesByName[variable.name] = variables.count
                variables.append(variable)
            }
        }

        let id = [global?.id, collection?.id]
            .compactMap(\.self)
            .joined(separator: "+")
        let name = [global?.name, collection?.name]
            .compactMap(\.self)
            .joined(separator: " + ")

        return APIEnvironment(id: id, name: name, variables: variables)
    }
}

public struct APIVariable: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var value: String?
    public var isSecret: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case value
        case isSecret
    }

    public init(id: String? = nil, name: String, value: String? = nil, isSecret: Bool = false) {
        self.id = id ?? "var_\(name)"
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "var_\(name)"
        self.name = name
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
        self.isSecret = try container.decode(Bool.self, forKey: .isSecret)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encode(isSecret, forKey: .isSecret)
    }
}

public struct APIHistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var requestId: String
    public var createdAt: Date
    public var requestName: String?
    public var method: HTTPMethod
    public var url: String
    public var statusCode: Int?
    public var durationMilliseconds: Int?
    public var responseSizeBytes: Int?
    public var contentType: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case requestId
        case createdAt
        case requestName
        case method
        case url
        case statusCode
        case durationMilliseconds
        case responseSizeBytes
        case contentType
    }

    public init(
        id: String,
        requestId: String,
        createdAt: Date = Date(),
        requestName: String? = nil,
        method: HTTPMethod,
        url: String,
        statusCode: Int? = nil,
        durationMilliseconds: Int? = nil,
        responseSizeBytes: Int? = nil,
        contentType: String? = nil
    ) {
        self.id = id
        self.requestId = requestId
        self.createdAt = createdAt
        self.requestName = requestName
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.durationMilliseconds = durationMilliseconds
        self.responseSizeBytes = responseSizeBytes
        self.contentType = contentType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.requestId = try container.decode(String.self, forKey: .requestId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        self.requestName = try container.decodeIfPresent(String.self, forKey: .requestName)
        self.method = try container.decode(HTTPMethod.self, forKey: .method)
        self.url = try container.decode(String.self, forKey: .url)
        self.statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        self.durationMilliseconds = try container.decodeIfPresent(Int.self, forKey: .durationMilliseconds)
        self.responseSizeBytes = try container.decodeIfPresent(Int.self, forKey: .responseSizeBytes)
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(requestId, forKey: .requestId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(requestName, forKey: .requestName)
        try container.encode(method, forKey: .method)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(statusCode, forKey: .statusCode)
        try container.encodeIfPresent(durationMilliseconds, forKey: .durationMilliseconds)
        try container.encodeIfPresent(responseSizeBytes, forKey: .responseSizeBytes)
        try container.encodeIfPresent(contentType, forKey: .contentType)
    }
}
