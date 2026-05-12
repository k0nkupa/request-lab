import RequestLabCore
import Testing

@Suite("cURL export")
struct CurlExportServiceTests {
    @Test("exports method URL headers auth and JSON body")
    func exportsRequestAsCurl() throws {
        let request = APIRequest(
            id: "req_orders",
            name: "Create order",
            method: .post,
            url: "{{baseUrl}}/orders",
            headers: ["Accept": "application/json"],
            params: ["preview": "true"],
            auth: APIAuth(type: .bearer, tokenVariable: "apiToken"),
            body: .json(#"{"brand":"TONY"}"#)
        )

        let command = try CurlExportService().export(request: request)

        #expect(
            command == """
            curl \\
              -X \\
              POST \\
              '{{baseUrl}}/orders?preview=true' \\
              -H \\
              'Accept: application/json' \\
              -H \\
              'Authorization: Bearer {{apiToken}}' \\
              -H \\
              'Content-Type: application/json' \\
              --data \\
              '{"brand":"TONY"}'
            """
        )
    }

    @Test("exports basic auth and form body")
    func exportsBasicAuthAndFormBody() throws {
        let request = APIRequest(
            id: "req_login",
            name: "Login",
            method: .post,
            url: "https://api.example.test/login",
            auth: APIAuth(type: .basic, usernameVariable: "username", passwordVariable: "password"),
            body: .form(["email": "tony@example.test", "scope": "orders"])
        )

        let command = try CurlExportService().export(request: request)

        #expect(command.contains("--user"))
        #expect(command.contains("'{{username}}:{{password}}'"))
        #expect(command.contains("'Content-Type: application/x-www-form-urlencoded'"))
        #expect(command.contains("'email=tony@example.test&scope=orders'"))
    }
}
