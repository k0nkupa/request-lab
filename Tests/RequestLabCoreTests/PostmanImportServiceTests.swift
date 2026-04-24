import Foundation
import RequestLabCore
import Testing

@Suite("Postman import")
struct PostmanImportServiceTests {
    @Test("imports Postman collection v2.1 requests")
    func importsCollectionRequests() throws {
        let data = try #require(
            """
            {
              "info": {
                "name": "Acme API",
                "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
              },
              "item": [
                {
                  "name": "Orders",
                  "item": [
                    {
                      "name": "Create order",
                      "request": {
                        "method": "POST",
                        "header": [
                          { "key": "Accept", "value": "application/json" },
                          { "key": "X-Skip", "value": "disabled", "disabled": true }
                        ],
                        "auth": {
                          "type": "bearer",
                          "bearer": [
                            { "key": "token", "value": "{{apiToken}}" }
                          ]
                        },
                        "url": {
                          "raw": "{{baseUrl}}/orders",
                          "query": [
                            { "key": "preview", "value": "true" }
                          ]
                        },
                        "body": {
                          "mode": "raw",
                          "raw": "{\\"brand\\":\\"TONY\\"}"
                        }
                      }
                    }
                  ]
                }
              ]
            }
            """.data(using: .utf8)
        )

        let collection = try PostmanImportService().importCollection(from: data)
        let request = try #require(collection.requests.first)

        #expect(collection.id == "col_acme_api")
        #expect(collection.name == "Acme API")
        #expect(request.id == "req_orders_create_order")
        #expect(request.name == "Orders / Create order")
        #expect(request.method == .post)
        #expect(request.url == "{{baseUrl}}/orders")
        #expect(request.params == ["preview": "true"])
        #expect(request.headers == ["Accept": "application/json"])
        #expect(request.auth == APIAuth(type: .bearer, tokenVariable: "apiToken"))
        #expect(request.body == .json(#"{"brand":"TONY"}"#))
    }

    @Test("imports Postman environment variables")
    func importsEnvironmentVariables() throws {
        let data = try #require(
            """
            {
              "name": "Local",
              "values": [
                { "key": "baseUrl", "value": "http://localhost:3000", "type": "default", "enabled": true },
                { "key": "apiToken", "value": "secret-token", "type": "secret", "enabled": true },
                { "key": "disabledValue", "value": "nope", "type": "default", "enabled": false }
              ]
            }
            """.data(using: .utf8)
        )

        let environment = try PostmanImportService().importEnvironment(from: data)

        #expect(environment.id == "env_local")
        #expect(environment.name == "Local")
        #expect(environment.variables.count == 2)
        #expect(
            environment.variables.contains(
                APIVariable(id: "var_baseurl", name: "baseUrl", value: "http://localhost:3000")
            )
        )
        #expect(
            environment.variables.contains(
                APIVariable(id: "var_apitoken", name: "apiToken", value: nil, isSecret: true)
            )
        )
    }

    @Test("imports form bodies and API key auth")
    func importsFormBodiesAndAPIKeyAuth() throws {
        let data = try #require(
            """
            {
              "info": { "name": "Forms" },
              "item": [
                {
                  "name": "Submit",
                  "request": {
                    "method": "POST",
                    "auth": {
                      "type": "apikey",
                      "apikey": [
                        { "key": "key", "value": "X-API-Key" },
                        { "key": "value", "value": "{{apiKey}}" }
                      ]
                    },
                    "url": "https://api.example.test/form",
                    "body": {
                      "mode": "urlencoded",
                      "urlencoded": [
                        { "key": "email", "value": "tony@example.test" },
                        { "key": "skip", "value": "disabled", "disabled": true }
                      ]
                    }
                  }
                }
              ]
            }
            """.data(using: .utf8)
        )

        let collection = try PostmanImportService().importCollection(from: data)
        let request = try #require(collection.requests.first)

        #expect(request.auth == APIAuth(type: .apiKey, keyName: "X-API-Key", keyValueVariable: "apiKey"))
        #expect(request.body == .form(["email": "tony@example.test"]))
    }
}
