import Foundation
import RequestLabCore
import Testing

@Suite("Variable resolver")
struct VariableResolverTests {
    @Test("resolves URL, query params, headers, auth, and JSON body")
    func resolvesRequestParts() throws {
        let request = APIRequest(
            id: "req_orders",
            name: "Orders",
            method: .post,
            url: "{{baseUrl}}/orders",
            headers: ["X-Trace": "{{traceId}}"],
            params: ["limit": "{{limit}}"],
            auth: APIAuth(type: .bearer, tokenVariable: "apiToken"),
            body: .json(#"{"brand":"{{brand}}"}"#)
        )
        let environment = APIEnvironment(
            id: "env_local",
            name: "Local",
            variables: [
                APIVariable(name: "baseUrl", value: "https://api.example.test"),
                APIVariable(name: "traceId", value: "trace-123"),
                APIVariable(name: "limit", value: "50"),
                APIVariable(name: "apiToken", value: "token-abc", isSecret: true),
                APIVariable(name: "brand", value: "TONY")
            ]
        )

        let resolved = try VariableResolver().resolve(request, environment: environment)

        #expect(resolved.url.absoluteString == "https://api.example.test/orders?limit=50")
        #expect(resolved.headers["X-Trace"] == "trace-123")
        #expect(resolved.headers["Authorization"] == "Bearer token-abc")
        #expect(resolved.headers["Content-Type"] == "application/json")
        #expect(String(data: try #require(resolved.bodyData), encoding: .utf8) == #"{"brand":"TONY"}"#)
    }

    @Test("throws when a variable cannot be resolved")
    func unresolvedVariableThrows() throws {
        let request = APIRequest(
            id: "req_missing",
            name: "Missing",
            method: .get,
            url: "{{baseUrl}}/orders/{{orderId}}"
        )
        let environment = APIEnvironment(
            id: "env_local",
            name: "Local",
            variables: [
                APIVariable(name: "baseUrl", value: "https://api.example.test")
            ]
        )

        do {
            _ = try VariableResolver().resolve(request, environment: environment)
            Issue.record("Expected unresolved variable failure")
        } catch RequestLabError.invalidWorkspace(let message) {
            #expect(message == "Unresolved variable: orderId")
        } catch {
            Issue.record("Expected invalidWorkspace, got \(error)")
        }
    }

    @Test("resolves basic auth and form body")
    func resolvesBasicAuthAndFormBody() throws {
        let request = APIRequest(
            id: "req_login",
            name: "Login",
            method: .post,
            url: "https://api.example.test/login",
            auth: APIAuth(
                type: .basic,
                usernameVariable: "username",
                passwordVariable: "password"
            ),
            body: .form(["email": "{{email}}", "scope": "orders"])
        )
        let environment = APIEnvironment(
            id: "env_local",
            name: "Local",
            variables: [
                APIVariable(name: "username", value: "tony"),
                APIVariable(name: "password", value: "secret"),
                APIVariable(name: "email", value: "tony@example.test")
            ]
        )

        let resolved = try VariableResolver().resolve(request, environment: environment)

        #expect(resolved.headers["Authorization"] == "Basic dG9ueTpzZWNyZXQ=")
        #expect(resolved.headers["Content-Type"] == "application/x-www-form-urlencoded")
        #expect(String(data: try #require(resolved.bodyData), encoding: .utf8) == "email=tony@example.test&scope=orders")
    }
}
