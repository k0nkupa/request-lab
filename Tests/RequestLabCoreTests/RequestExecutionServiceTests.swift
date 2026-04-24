import Foundation
import RequestLabCore
import Testing

@Suite("Request execution", .serialized)
struct RequestExecutionServiceTests {
    @Test("executes a resolved request")
    func executesResolvedRequest() async throws {
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.example.test/orders?limit=50")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-abc")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(String(data: bodyData(from: request), encoding: .utf8) == #"{"brand":"TONY"}"#)

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 201,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            return (response, #"{"ok":true}"#.data(using: .utf8) ?? Data())
        }
        defer { MockURLProtocol.handler = nil }

        let service = RequestExecutionService(session: URLSession.mocked)
        let request = APIRequest(
            id: "req_orders",
            name: "Create order",
            method: .post,
            url: "{{baseUrl}}/orders",
            params: ["limit": "50"],
            auth: APIAuth(type: .bearer, tokenVariable: "apiToken"),
            body: .json(#"{"brand":"{{brand}}"}"#)
        )
        let environment = APIEnvironment(
            id: "env_local",
            name: "Local",
            variables: [
                APIVariable(name: "baseUrl", value: "https://api.example.test"),
                APIVariable(name: "apiToken", value: "token-abc", isSecret: true),
                APIVariable(name: "brand", value: "TONY")
            ]
        )

        let result = try await service.execute(request, environment: environment)

        #expect(result.requestId == "req_orders")
        #expect(result.statusCode == 201)
        #expect(result.url == "https://api.example.test/orders?limit=50")
        #expect(result.headers["Content-Type"] == "application/json")
        #expect(result.body == #"{"ok":true}"#)
    }

    @Test("returns non-2xx responses instead of throwing")
    func nonSuccessResponseIsStillAResult() async throws {
        MockURLProtocol.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 404,
                    httpVersion: "HTTP/1.1",
                    headerFields: [:]
                )
            )

            return (response, #"{"error":"missing"}"#.data(using: .utf8) ?? Data())
        }
        defer { MockURLProtocol.handler = nil }

        let service = RequestExecutionService(session: URLSession.mocked)
        let request = APIRequest(
            id: "req_missing",
            name: "Missing",
            method: .get,
            url: "https://api.example.test/missing"
        )

        let result = try await service.execute(request, environment: nil)

        #expect(result.statusCode == 404)
        #expect(result.body == #"{"error":"missing"}"#)
    }

    @Test("executes a GraphQL request")
    func executesGraphQLRequest() async throws {
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.example.test/graphql")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")

            let body = try #require(try JSONSerialization.jsonObject(with: bodyData(from: request)) as? [String: Any])
            let graphQLVariables = try #require(body["variables"] as? [String: Any])

            #expect(body["query"] as? String == "query Viewer { viewer { id } }")
            #expect(body["operationName"] as? String == "Viewer")
            #expect(graphQLVariables["preview"] as? Bool == true)

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            return (response, #"{"data":{"viewer":{"id":"1"}}}"#.data(using: .utf8) ?? Data())
        }
        defer { MockURLProtocol.handler = nil }

        let service = RequestExecutionService(session: URLSession.mocked)
        let request = APIRequest(
            id: "req_graphql",
            name: "Viewer",
            kind: .graphQL,
            method: .post,
            url: "{{baseUrl}}/graphql",
            graphQL: APIGraphQLPayload(
                query: "query Viewer { viewer { id } }",
                operationName: "Viewer",
                variables: #"{"preview":true}"#
            )
        )
        let environment = APIEnvironment(
            id: "env_local",
            name: "Local",
            variables: [
                APIVariable(name: "baseUrl", value: "https://api.example.test")
            ]
        )

        let result = try await service.execute(request, environment: environment)

        #expect(result.statusCode == 200)
        #expect(result.body == #"{"data":{"viewer":{"id":"1"}}}"#)
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static var mocked: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func bodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return Data()
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)

    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 {
            break
        }

        data.append(buffer, count: count)
    }

    return data
}
