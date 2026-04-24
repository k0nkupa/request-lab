import Foundation
import Security

public struct KeychainSecretStore: Sendable {
    private let servicePrefix: String

    public init(servicePrefix: String = "RequestLab") {
        self.servicePrefix = servicePrefix
    }

    public func secretKey(workspaceID: String, environmentID: String, variableID: String) -> String {
        "\(workspaceID):\(environmentID):\(variableID)"
    }

    public func readSecret(workspaceID: String, environmentID: String, variableID: String) throws -> String? {
        let key = secretKey(workspaceID: workspaceID, environmentID: environmentID, variableID: variableID)
        var query = baseQuery(account: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw RequestLabError.keychainFailed("Read failed with status \(status)")
        }
    }

    public func writeSecret(
        _ value: String,
        workspaceID: String,
        environmentID: String,
        variableID: String
    ) throws {
        let key = secretKey(workspaceID: workspaceID, environmentID: environmentID, variableID: variableID)
        let data = Data(value.utf8)
        let query = baseQuery(account: key)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw RequestLabError.keychainFailed("Create failed with status \(addStatus)")
            }
        default:
            throw RequestLabError.keychainFailed("Update failed with status \(status)")
        }
    }

    public func deleteSecret(workspaceID: String, environmentID: String, variableID: String) throws {
        let key = secretKey(workspaceID: workspaceID, environmentID: environmentID, variableID: variableID)
        let status = SecItemDelete(baseQuery(account: key) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RequestLabError.keychainFailed("Delete failed with status \(status)")
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: account
        ]
    }
}
