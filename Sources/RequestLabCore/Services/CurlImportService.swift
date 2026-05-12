import Foundation

public struct CurlImportService: Sendable {
    public init() {}

    public func importRequest(from command: String) throws -> APIRequest {
        let tokens = try tokenize(command)
        guard tokens.first == "curl" else {
            throw RequestLabError.invalidWorkspace("cURL command must start with curl")
        }

        var method: HTTPMethod?
        var headers: [String: String] = [:]
        var body: String?
        var url: String?
        var index = 1

        while index < tokens.count {
            let token = tokens[index]

            switch token {
            case "-X", "--request":
                method = HTTPMethod(rawValue: try value(after: token, in: tokens, index: &index).uppercased())
            case let value where value.hasPrefix("-X") && value.count > 2:
                method = HTTPMethod(rawValue: String(value.dropFirst(2)).uppercased())
            case let value where value.hasPrefix("--request="):
                method = HTTPMethod(rawValue: String(value.dropFirst("--request=".count)).uppercased())
            case "-H", "--header":
                parseHeader(try value(after: token, in: tokens, index: &index), into: &headers)
            case let value where value.hasPrefix("--header="):
                parseHeader(String(value.dropFirst("--header=".count)), into: &headers)
            case "-d", "--data", "--data-raw", "--data-binary":
                body = try value(after: token, in: tokens, index: &index)
                if method == nil {
                    method = .post
                }
            case let value where value.hasPrefix("--data="):
                body = String(value.dropFirst("--data=".count))
                if method == nil {
                    method = .post
                }
            case "--url":
                url = try value(after: token, in: tokens, index: &index)
            case let value where value.hasPrefix("--url="):
                url = String(value.dropFirst("--url=".count))
            case let value where value.hasPrefix("-"):
                break
            default:
                url = token
            }

            index += 1
        }

        guard let url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RequestLabError.invalidWorkspace("cURL command is missing a URL")
        }

        return APIRequest(
            id: "req_\(UUID().uuidString)",
            name: requestName(method: method ?? .get, url: url),
            method: method ?? .get,
            url: url,
            headers: headers,
            body: requestBody(from: body, headers: headers)
        )
    }

    private func value(after option: String, in tokens: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard tokens.indices.contains(valueIndex) else {
            throw RequestLabError.invalidWorkspace("Missing value for \(option)")
        }

        index = valueIndex
        return tokens[valueIndex]
    }

    private func parseHeader(_ value: String, into headers: inout [String: String]) {
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let key = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return
        }

        headers[key] = parts.dropFirst().first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func requestBody(from body: String?, headers: [String: String]) -> APIBody {
        guard let body else {
            return .none
        }

        let contentType = headers.first { key, _ in
            key.caseInsensitiveCompare("Content-Type") == .orderedSame
        }?.value
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        if contentType?.localizedCaseInsensitiveContains("application/x-www-form-urlencoded") == true {
            return .form(formFields(from: body))
        }

        if contentType?.localizedCaseInsensitiveContains("application/json") == true
            || trimmedBody.hasPrefix("{")
            || trimmedBody.hasPrefix("[")
        {
            return .json(body)
        }

        return .raw(body)
    }

    private func formFields(from body: String) -> [String: String] {
        var fields: [String: String] = [:]
        var components = URLComponents()
        components.percentEncodedQuery = body

        for item in components.queryItems ?? [] {
            fields[item.name] = item.value ?? ""
        }

        return fields
    }

    private func requestName(method: HTTPMethod, url: String) -> String {
        guard let components = URLComponents(string: url) else {
            return "\(method.rawValue) cURL Request"
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? "\(method.rawValue) \(components.host ?? "cURL Request")" : "\(method.rawValue) /\(path)"
    }

    private func tokenize(_ command: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var isEscaping = false

        for character in command {
            if isEscaping {
                if character != "\n" {
                    current.append(character)
                }
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "'" || character == "\"" {
                quote = character
                continue
            }

            if character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(character)
        }

        if quote != nil {
            throw RequestLabError.invalidWorkspace("cURL command has an unterminated quote")
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
