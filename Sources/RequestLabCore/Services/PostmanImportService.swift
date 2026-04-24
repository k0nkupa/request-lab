import Foundation

public struct PostmanImportService: Sendable {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func importCollection(from data: Data) throws -> APICollection {
        let postmanCollection = try decoder.decode(PostmanCollection.self, from: data)
        let requests = postmanCollection.item.flatMap { item in
            importRequests(from: item, folderPath: [])
        }

        return APICollection(
            id: stableID(prefix: "col", name: postmanCollection.info.name),
            name: postmanCollection.info.name,
            requests: requests
        )
    }

    public func importEnvironment(from data: Data) throws -> APIEnvironment {
        let postmanEnvironment = try decoder.decode(PostmanEnvironment.self, from: data)
        let variables = postmanEnvironment.values
            .filter { $0.enabled != false }
            .map { value in
                APIVariable(
                    id: stableID(prefix: "var", name: value.key),
                    name: value.key,
                    value: value.type == "secret" ? nil : value.value,
                    isSecret: value.type == "secret"
                )
            }

        return APIEnvironment(
            id: stableID(prefix: "env", name: postmanEnvironment.name),
            name: postmanEnvironment.name,
            variables: variables
        )
    }

    private func importRequests(from item: PostmanItem, folderPath: [String]) -> [APIRequest] {
        let currentPath = folderPath + [item.name]

        if let children = item.item {
            return children.flatMap { importRequests(from: $0, folderPath: currentPath) }
        }

        guard let postmanRequest = item.request?.objectValue else {
            return []
        }

        let name = currentPath.joined(separator: " / ")
        let url = postmanRequest.url?.rawValue ?? ""
        let params = postmanRequest.url?.queryItems ?? [:]
        let headers = postmanRequest.headers
            .filter { $0.disabled != true }
            .reduce(into: [String: String]()) { values, header in
                guard let key = header.key, !key.isEmpty else {
                    return
                }

                values[key] = header.value ?? ""
            }

        return [
            APIRequest(
                id: stableID(prefix: "req", name: name),
                name: name,
                method: HTTPMethod(rawValue: postmanRequest.method ?? "GET") ?? .get,
                url: url,
                headers: headers,
                params: params,
                auth: importAuth(postmanRequest.auth),
                body: importBody(postmanRequest.body)
            )
        ]
    }

    private func importAuth(_ auth: PostmanAuth?) -> APIAuth? {
        guard let auth else {
            return nil
        }

        switch auth.type {
        case "bearer":
            return APIAuth(
                type: .bearer,
                tokenVariable: variableName(from: auth.value(for: "token"))
            )
        case "basic":
            return APIAuth(
                type: .basic,
                usernameVariable: variableName(from: auth.value(for: "username")),
                passwordVariable: variableName(from: auth.value(for: "password"))
            )
        case "apikey":
            return APIAuth(
                type: .apiKey,
                keyName: auth.value(for: "key"),
                keyValueVariable: variableName(from: auth.value(for: "value"))
            )
        default:
            return nil
        }
    }

    private func importBody(_ body: PostmanBody?) -> APIBody {
        guard let body else {
            return .none
        }

        switch body.mode {
        case "raw":
            let raw = body.raw ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("{") || trimmed.hasPrefix("[") ? .json(raw) : .raw(raw)
        case "urlencoded":
            return .form(keyValuePairs(from: body.urlencoded))
        case "formdata":
            return .form(keyValuePairs(from: body.formdata))
        default:
            return .none
        }
    }

    private func keyValuePairs(from parameters: [PostmanKeyValue]?) -> [String: String] {
        (parameters ?? [])
            .filter { $0.disabled != true }
            .reduce(into: [String: String]()) { values, parameter in
                guard let key = parameter.key, !key.isEmpty else {
                    return
                }

                values[key] = parameter.value ?? ""
            }
    }

    private func variableName(from value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{{"), trimmed.hasSuffix("}}") else {
            return trimmed.isEmpty ? nil : trimmed
        }

        return String(trimmed.dropFirst(2).dropLast(2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stableID(prefix: String, name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let slug = name
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { value, character in
                if character == "_", value.last == "_" {
                    return
                }
                value.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))

        return "\(prefix)_\(slug.isEmpty ? UUID().uuidString : slug)"
    }
}

private struct PostmanCollection: Decodable {
    var info: PostmanInfo
    var item: [PostmanItem]
}

private struct PostmanInfo: Decodable {
    var name: String
}

private struct PostmanItem: Decodable {
    var name: String
    var item: [PostmanItem]?
    var request: PostmanRequestValue?
}

private enum PostmanRequestValue: Decodable {
    case string(String)
    case object(PostmanRequest)

    var objectValue: PostmanRequest? {
        switch self {
        case .string(let url):
            PostmanRequest(method: "GET", header: [], url: .string(url), auth: nil, body: nil)
        case .object(let request):
            request
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .object(try container.decode(PostmanRequest.self))
        }
    }
}

private struct PostmanRequest: Decodable {
    var method: String?
    var header: [PostmanHeader]?
    var url: PostmanURL?
    var auth: PostmanAuth?
    var body: PostmanBody?

    var headers: [PostmanHeader] {
        header ?? []
    }
}

private enum PostmanURL: Decodable {
    case string(String)
    case object(PostmanURLObject)

    var rawValue: String {
        switch self {
        case .string(let value):
            value
        case .object(let value):
            value.raw ?? value.composedValue
        }
    }

    var queryItems: [String: String] {
        switch self {
        case .string:
            return [:]
        case .object(let value):
            return value.queryItems
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .object(try container.decode(PostmanURLObject.self))
        }
    }
}

private struct PostmanURLObject: Decodable {
    var raw: String?
    var protocolValue: String?
    var host: [StringOrInt]?
    var path: [StringOrInt]?
    var query: [PostmanKeyValue]?

    private enum CodingKeys: String, CodingKey {
        case raw
        case protocolValue = "protocol"
        case host
        case path
        case query
    }

    var composedValue: String {
        let scheme = protocolValue.map { "\($0)://" } ?? ""
        let hostValue = (host ?? []).map(\.stringValue).joined(separator: ".")
        let pathValue = (path ?? []).map(\.stringValue).joined(separator: "/")
        return pathValue.isEmpty ? "\(scheme)\(hostValue)" : "\(scheme)\(hostValue)/\(pathValue)"
    }

    var queryItems: [String: String] {
        (query ?? [])
            .filter { $0.disabled != true }
            .reduce(into: [String: String]()) { values, item in
                guard let key = item.key, !key.isEmpty else {
                    return
                }

                values[key] = item.value ?? ""
            }
    }
}

private struct PostmanHeader: Decodable {
    var key: String?
    var value: String?
    var disabled: Bool?
}

private struct PostmanAuth: Decodable {
    var type: String
    var bearer: [PostmanKeyValue]?
    var basic: [PostmanKeyValue]?
    var apikey: [PostmanKeyValue]?

    func value(for key: String) -> String? {
        let values: [PostmanKeyValue]?
        switch type {
        case "bearer":
            values = bearer
        case "basic":
            values = basic
        case "apikey":
            values = apikey
        default:
            values = nil
        }

        return values?.first { $0.key == key }?.value
    }
}

private struct PostmanBody: Decodable {
    var mode: String?
    var raw: String?
    var urlencoded: [PostmanKeyValue]?
    var formdata: [PostmanKeyValue]?
}

private struct PostmanKeyValue: Decodable {
    var key: String?
    var value: String?
    var type: String?
    var enabled: Bool?
    var disabled: Bool?
}

private struct PostmanEnvironment: Decodable {
    var name: String
    var values: [PostmanEnvironmentValue]
}

private struct PostmanEnvironmentValue: Decodable {
    var key: String
    var value: String?
    var type: String?
    var enabled: Bool?
}

private enum StringOrInt: Decodable {
    case string(String)
    case int(Int)

    var stringValue: String {
        switch self {
        case .string(let value):
            value
        case .int(let value):
            String(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .int(try container.decode(Int.self))
        }
    }
}
