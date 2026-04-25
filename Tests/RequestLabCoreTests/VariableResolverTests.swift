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

    @Test("collection variables override global variables")
    func collectionVariablesOverrideGlobalVariables() throws {
        let globalEnvironment = APIEnvironment(
            id: "env_global",
            name: "Global",
            variables: [
                APIVariable(name: "baseUrl", value: "https://global.example.test"),
                APIVariable(name: "apiToken", value: "global-token", isSecret: true)
            ]
        )
        let collectionEnvironment = APIEnvironment(
            id: "env_collection",
            name: "Collection",
            variables: [
                APIVariable(name: "baseUrl", value: "https://collection.example.test"),
                APIVariable(name: "tenantId", value: "tenant-123")
            ]
        )

        let merged = try #require(APIEnvironment.merged(global: globalEnvironment, collection: collectionEnvironment))

        #expect(merged.variables.first { $0.name == "baseUrl" }?.value == "https://collection.example.test")
        #expect(merged.variables.first { $0.name == "apiToken" }?.value == "global-token")
        #expect(merged.variables.first { $0.name == "tenantId" }?.value == "tenant-123")
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

    @Test("shapes GraphQL request bodies")
    func shapesGraphQLRequestBodies() throws {
        let request = APIRequest(
            id: "req_graphql",
            name: "GraphQL orders",
            kind: .graphQL,
            method: .post,
            url: "{{baseUrl}}/graphql",
            graphQL: APIGraphQLPayload(
                query: "query Orders($limit: Int!) { orders(limit: $limit) { id } }",
                operationName: "Orders",
                variables: #"{"limit":{{limit}}}"#
            )
        )
        let environment = APIEnvironment(
            id: "env_local",
            name: "Local",
            variables: [
                APIVariable(name: "baseUrl", value: "https://api.example.test"),
                APIVariable(name: "limit", value: "25")
            ]
        )

        let resolved = try VariableResolver().resolve(request, environment: environment)
        let bodyData = try #require(resolved.bodyData)
        let body = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let graphQLVariables = try #require(body["variables"] as? [String: Any])

        #expect(resolved.url.absoluteString == "https://api.example.test/graphql")
        #expect(resolved.headers["Content-Type"] == "application/json")
        #expect(resolved.headers["Accept"] == "application/json")
        #expect(body["query"] as? String == "query Orders($limit: Int!) { orders(limit: $limit) { id } }")
        #expect(body["operationName"] as? String == "Orders")
        #expect(graphQLVariables["limit"] as? Int == 25)
    }

    @Test("throws when GraphQL variables are not JSON")
    func invalidGraphQLVariablesThrow() throws {
        let request = APIRequest(
            id: "req_graphql_invalid",
            name: "Invalid GraphQL",
            kind: .graphQL,
            method: .post,
            url: "https://api.example.test/graphql",
            graphQL: APIGraphQLPayload(
                query: "query Viewer { viewer { id } }",
                variables: "not json"
            )
        )

        do {
            _ = try VariableResolver().resolve(request, environment: nil)
            Issue.record("Expected GraphQL variable JSON validation failure")
        } catch RequestLabError.invalidWorkspace(let message) {
            #expect(message == "GraphQL variables must be valid JSON")
        } catch {
            Issue.record("Expected invalidWorkspace, got \(error)")
        }
    }
}
