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
        let bodyData = try makeBodyData(from: request.body, headers: &headers, variables: variables)

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
        from body: APIBody,
        headers: inout [String: String],
        variables: [String: String]
    ) throws -> Data? {
        switch body {
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

    private func variable(named name: String?, variables: [String: String], label: String) throws -> String {
        guard let name, let value = variables[name] else {
            throw RequestLabError.invalidWorkspace("Unresolved \(label) variable: \(name ?? "missing")")
        }

        return value
    }

    private func resolveVariables(in value: String, variables: [String: String]) throws -> String {
        var output = value
        let pattern = #"\{\{\s*([A-Za-z0-9_.-]+)\s*\}\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed()

        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: value),
                  let tokenRange = Range(match.range(at: 0), in: value)
            else {
                continue
            }

            let name = String(value[nameRange])
            guard let replacement = variables[name] else {
                throw RequestLabError.invalidWorkspace("Unresolved variable: \(name)")
            }

            output.replaceSubrange(tokenRange, with: replacement)
        }

        return output
    }
}
