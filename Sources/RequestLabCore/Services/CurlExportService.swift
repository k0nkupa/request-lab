import Foundation

public struct CurlExportService: Sendable {
    public init() {}

    public func export(request: APIRequest) throws -> String {
        let url = urlWithParams(request.url, params: request.params)
        var headers = request.headers
        var arguments = ["curl", "-X", request.method.rawValue, shellQuote(url)]

        applyAuth(request.auth, headers: &headers, arguments: &arguments)
        let body = requestBody(request.body, headers: &headers)

        for (key, value) in headers.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            arguments.append("-H")
            arguments.append(shellQuote("\(key): \(value)"))
        }

        if let body {
            arguments.append("--data")
            arguments.append(shellQuote(body))
        }

        return multilineCommand(arguments)
    }

    private func urlWithParams(_ url: String, params: [String: String]) -> String {
        guard !params.isEmpty else {
            return url
        }

        var components = URLComponents()
        components.queryItems = params
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let query = components.percentEncodedQuery, !query.isEmpty else {
            return url
        }

        return "\(url)\(url.contains("?") ? "&" : "?")\(query)"
    }

    private func applyAuth(_ auth: APIAuth?, headers: inout [String: String], arguments: inout [String]) {
        guard let auth, auth.type != .none else {
            return
        }

        switch auth.type {
        case .none:
            return
        case .bearer:
            guard let tokenVariable = auth.tokenVariable, !tokenVariable.isEmpty else {
                return
            }

            headers["Authorization", default: "Bearer {{\(tokenVariable)}}"] = "Bearer {{\(tokenVariable)}}"
        case .basic:
            guard let usernameVariable = auth.usernameVariable, !usernameVariable.isEmpty,
                  let passwordVariable = auth.passwordVariable, !passwordVariable.isEmpty
            else {
                return
            }

            arguments.append("--user")
            arguments.append(shellQuote("{{\(usernameVariable)}}:{{\(passwordVariable)}}"))
        case .apiKey:
            guard let keyName = auth.keyName, !keyName.isEmpty,
                  let keyValueVariable = auth.keyValueVariable, !keyValueVariable.isEmpty
            else {
                return
            }

            headers[keyName, default: "{{\(keyValueVariable)}}"] = "{{\(keyValueVariable)}}"
        }
    }

    private func requestBody(_ body: APIBody, headers: inout [String: String]) -> String? {
        switch body {
        case .none:
            return nil
        case .raw(let value):
            return value
        case .json(let value):
            headers["Content-Type", default: "application/json"] = "application/json"
            return value
        case .form(let fields):
            headers["Content-Type", default: "application/x-www-form-urlencoded"] = "application/x-www-form-urlencoded"
            var components = URLComponents()
            components.queryItems = fields
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
            return components.percentEncodedQuery ?? ""
        }
    }

    private func multilineCommand(_ arguments: [String]) -> String {
        guard let first = arguments.first else {
            return ""
        }

        return ([first] + arguments.dropFirst().map { "  \($0)" })
            .joined(separator: " \\\n")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
