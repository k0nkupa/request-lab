import Foundation

public struct ResolvedAPIRequest: Equatable, Sendable {
    public var request: APIRequest
    public var url: URL
    public var headers: [String: String]
    public var bodyData: Data?

    public init(request: APIRequest, url: URL, headers: [String: String], bodyData: Data? = nil) {
        self.request = request
        self.url = url
        self.headers = headers
        self.bodyData = bodyData
    }
}

public struct VariableResolver: Sendable {
    public init() {}

    public func resolve(_ request: APIRequest, environment: APIEnvironment?) throws -> ResolvedAPIRequest {
        let variables = variableMap(from: environment)
        let resolvedURLString = try resolveVariables(in: request.url, variables: variables)
        let url = try makeURL(from: resolvedURLString, params: request.params, variables: variables)
        var headers = try resolveHeaders(request.headers, variables: variables)

        try applyAuth(request.auth, to: &headers, variables: variables)
        let bodyData = try makeBodyData(for: request, headers: &headers, variables: variables)

        return ResolvedAPIRequest(request: request, url: url, headers: headers, bodyData: bodyData)
    }

    public func resolveVariables(in value: String, environment: APIEnvironment?) throws -> String {
        try resolveVariables(in: value, variables: variableMap(from: environment))
    }

    private func variableMap(from environment: APIEnvironment?) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: (environment?.variables ?? []).compactMap { variable in
                guard let value = variable.value, !value.isEmpty else {
                    return nil
                }

                return (variable.name, value)
            }
        )
    }

    private func resolveHeaders(_ headers: [String: String], variables: [String: String]) throws -> [String: String] {
        try Dictionary(
            uniqueKeysWithValues: headers.map { key, value in
                (try resolveVariables(in: key, variables: variables), try resolveVariables(in: value, variables: variables))
            }
        )
    }

    private func makeURL(from value: String, params: [String: String], variables: [String: String]) throws -> URL {
        guard var components = URLComponents(string: value),
              components.scheme != nil,
              components.host != nil
        else {
            throw RequestLabError.invalidWorkspace("Invalid request URL: \(value)")
        }

        let resolvedParams = try params.map { key, value in
            URLQueryItem(
                name: try resolveVariables(in: key, variables: variables),
                value: try resolveVariables(in: value, variables: variables)
            )
        }

        if !resolvedParams.isEmpty {
            components.queryItems = (components.queryItems ?? []) + resolvedParams.sorted { $0.name < $1.name }
        }

        guard let url = components.url else {
            throw RequestLabError.invalidWorkspace("Invalid request URL: \(value)")
        }

        return url
    }

    private func applyAuth(
        _ auth: APIAuth?,
        to headers: inout [String: String],
        variables: [String: String]
    ) throws {
        guard let auth, auth.type != .none else {
            return
        }

        switch auth.type {
        case .none:
            return
        case .bearer:
            let token = try variable(named: auth.tokenVariable, variables: variables, label: "bearer token")
            headers["Authorization"] = "Bearer \(token)"
        case .basic:
            let username = try variable(named: auth.usernameVariable, variables: variables, label: "basic username")
            let password = try variable(named: auth.passwordVariable, variables: variables, label: "basic password")
            let token = Data("\(username):\(password)".utf8).base64EncodedString()
            headers["Authorization"] = "Basic \(token)"
        case .apiKey:
            guard let keyName = auth.keyName, !keyName.isEmpty else {
                throw RequestLabError.invalidWorkspace("Missing API key header name")
            }

            headers[keyName] = try variable(named: auth.keyValueVariable, variables: variables, label: "API key")
        }
    }

    private func makeBodyData(
        for request: APIRequest,
        headers: inout [String: String],
        variables: [String: String]
    ) throws -> Data? {
        if request.kind == .graphQL {
            return try makeGraphQLBodyData(from: request.graphQL, headers: &headers, variables: variables)
        }

        switch request.body {
        case .none:
            return nil
        case .raw(let value):
            return try resolveVariables(in: value, variables: variables).data(using: .utf8)
        case .json(let value):
            headers["Content-Type", default: "application/json"] = "application/json"
            return try resolveVariables(in: value, variables: variables).data(using: .utf8)
        case .form(let fields):
            headers["Content-Type", default: "application/x-www-form-urlencoded"] = "application/x-www-form-urlencoded"
            var components = URLComponents()
            components.queryItems = try fields
                .map { key, value in
                    URLQueryItem(
                        name: try resolveVariables(in: key, variables: variables),
                        value: try resolveVariables(in: value, variables: variables)
                    )
                }
                .sorted { $0.name < $1.name }

            return (components.percentEncodedQuery ?? "").data(using: .utf8)
        }
    }

    private func makeGraphQLBodyData(
        from payload: APIGraphQLPayload?,
        headers: inout [String: String],
        variables: [String: String]
    ) throws -> Data {
        guard let payload else {
            throw RequestLabError.invalidWorkspace("GraphQL request is missing query payload")
        }

        let query = try resolveVariables(in: payload.query, variables: variables)
        let operationName = try payload.operationName.map { try resolveVariables(in: $0, variables: variables) }
        let variablesObject = try graphQLVariablesObject(from: payload.variables, variables: variables)
        var body: [String: Any] = ["query": query, "variables": variablesObject]

        if let operationName, !operationName.isEmpty {
            body["operationName"] = operationName
        }

        headers["Content-Type", default: "application/json"] = "application/json"
        headers["Accept", default: "application/json"] = "application/json"

        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    private func graphQLVariablesObject(from rawValue: String, variables: [String: String]) throws -> Any {
        let resolvedValue = try resolveVariables(in: rawValue, variables: variables)
        let trimmedValue = resolvedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else {
            return [String: Any]()
        }

        guard let data = trimmedValue.data(using: .utf8) else {
            throw RequestLabError.invalidWorkspace("GraphQL variables must be UTF-8 JSON")
        }

        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw RequestLabError.invalidWorkspace("GraphQL variables must be valid JSON")
        }
    }

    private func variable(named name: String?, variables: [String: String], label: String) throws -> String {
        guard let name, let value = variables[name] else {
            throw RequestLabError.invalidWorkspace("Unresolved \(label) variable: \(name ?? "missing")")
        }

        return value
    }

    private func resolveVariables(in value: String, variables: [String: String]) throws -> String {
        var output = ""

        for segment in VariableTokenParser.segments(in: value) {
            switch segment {
            case .text(let text):
                output += text
            case .variable(_, let name):
                guard let replacement = variables[name] else {
                    throw RequestLabError.invalidWorkspace("Unresolved variable: \(name)")
                }

                output += replacement
            }
        }

        return output
    }
}
