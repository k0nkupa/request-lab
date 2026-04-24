import Foundation
import RequestLabCore
import Testing

@Suite("Keychain secret store", .serialized)
struct KeychainSecretStoreTests {
    @Test("writes reads updates and deletes secrets")
    func writesReadsUpdatesAndDeletesSecrets() throws {
        let store = KeychainSecretStore(servicePrefix: "RequestLabTests.\(UUID().uuidString)")
        let workspaceID = "wrk_keychain"
        let environmentID = "env_local"
        let variableID = "var_apiToken"

        try store.deleteSecret(
            workspaceID: workspaceID,
            environmentID: environmentID,
            variableID: variableID
        )

        try store.writeSecret(
            "first-token",
            workspaceID: workspaceID,
            environmentID: environmentID,
            variableID: variableID
        )
        #expect(
            try store.readSecret(
                workspaceID: workspaceID,
                environmentID: environmentID,
                variableID: variableID
            ) == "first-token"
        )

        try store.writeSecret(
            "updated-token",
            workspaceID: workspaceID,
            environmentID: environmentID,
            variableID: variableID
        )
        #expect(
            try store.readSecret(
                workspaceID: workspaceID,
                environmentID: environmentID,
                variableID: variableID
            ) == "updated-token"
        )

        try store.deleteSecret(
            workspaceID: workspaceID,
            environmentID: environmentID,
            variableID: variableID
        )
        #expect(
            try store.readSecret(
                workspaceID: workspaceID,
                environmentID: environmentID,
                variableID: variableID
            ) == nil
        )
    }

    @Test("builds stable account keys")
    func buildsStableAccountKeys() {
        let store = KeychainSecretStore(servicePrefix: "RequestLabTests")

        #expect(
            store.secretKey(
                workspaceID: "wrk",
                environmentID: "env",
                variableID: "var"
            ) == "wrk:env:var"
        )
    }
}
