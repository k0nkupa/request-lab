import Foundation

public struct APIExecutionResult: Equatable, Sendable {
    public var requestId: String
    public var method: HTTPMethod
    public var url: String
    public var statusCode: Int
    public var durationMilliseconds: Int
    public var headers: [String: String]
    public var body: String

    public init(
        requestId: String,
        method: HTTPMethod,
        url: String,
        statusCode: Int,
        durationMilliseconds: Int,
        headers: [String: String],
        body: String
    ) {
        self.requestId = requestId
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.durationMilliseconds = durationMilliseconds
        self.headers = headers
        self.body = body
    }
}

public struct RequestExecutionService: Sendable {
    private let session: URLSession
    private let resolver: VariableResolver

    public init(
        session: URLSession = .shared,
        resolver: VariableResolver = VariableResolver()
    ) {
        self.session = session
        self.resolver = resolver
    }

    public func execute(_ request: APIRequest, environment: APIEnvironment?) async throws -> APIExecutionResult {
        let resolved = try resolver.resolve(request, environment: environment)
        var urlRequest = URLRequest(url: resolved.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = resolved.bodyData

        for (key, value) in resolved.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let startedAt = Date()
        let (data, response) = try await session.data(for: urlRequest)
        let duration = max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RequestLabError.invalidWorkspace("Request did not return an HTTP response")
        }

        return APIExecutionResult(
            requestId: request.id,
            method: request.method,
            url: resolved.url.absoluteString,
            statusCode: httpResponse.statusCode,
            durationMilliseconds: duration,
            headers: responseHeaders(from: httpResponse),
            body: String(data: data, encoding: .utf8) ?? ""
        )
    }

    private func responseHeaders(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { headers, item in
            guard let key = item.key as? String else {
                return
            }

            headers[key] = String(describing: item.value)
        }
    }
}
