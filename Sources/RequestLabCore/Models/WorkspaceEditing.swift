import Foundation

public extension APIWorkspace {
    mutating func addCollection(_ collection: APICollection) {
        collections.append(collection)
    }

    mutating func deleteCollection(id collectionID: String) -> Bool {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }

        collections.remove(at: collectionIndex)
        return true
    }

    mutating func updateCollection(id collectionID: String, mutate: (inout APICollection) -> Void) -> Bool {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }

        mutate(&collections[collectionIndex])
        return true
    }

    mutating func renameCollection(id collectionID: String, to name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }

        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }

        let proposedFileName = WorkspaceFileNaming.yamlFileName(for: trimmedName)
        let hasFileNameCollision = collections.enumerated().contains { index, collection in
            index != collectionIndex && WorkspaceFileNaming.yamlFileName(for: collection.name) == proposedFileName
        }
        guard !hasFileNameCollision else {
            return false
        }

        collections[collectionIndex].name = trimmedName
        return true
    }

    mutating func updateCollectionColor(id collectionID: String, color: APICollectionColor?) -> Bool {
        updateCollection(id: collectionID) { collection in
            collection.color = color
        }
    }

    mutating func addRequest(_ request: APIRequest, toCollectionID collectionID: String) -> Bool {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }

        collections[collectionIndex].requests.append(request)
        return true
    }

    mutating func updateRequest(id requestID: String, mutate: (inout APIRequest) -> Void) -> Bool {
        for collectionIndex in collections.indices {
            guard let requestIndex = collections[collectionIndex].requests.firstIndex(where: { $0.id == requestID }) else {
                continue
            }

            mutate(&collections[collectionIndex].requests[requestIndex])
            return true
        }

        return false
    }

    mutating func deleteRequest(id requestID: String) -> Bool {
        for collectionIndex in collections.indices {
            guard let requestIndex = collections[collectionIndex].requests.firstIndex(where: { $0.id == requestID }) else {
                continue
            }

            collections[collectionIndex].requests.remove(at: requestIndex)
            return true
        }

        return false
    }

    func collectionID(containingRequestID requestID: String) -> String? {
        collections.first { collection in
            collection.requests.contains { $0.id == requestID }
        }?.id
    }

    func collection(containingRequestID requestID: String?) -> APICollection? {
        guard let requestID else {
            return nil
        }

        return collections.first { collection in
            collection.requests.contains { $0.id == requestID }
        }
    }

    mutating func addCollectionEnvironment(_ environment: APIEnvironment, toCollectionID collectionID: String) -> Bool {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }

        collections[collectionIndex].environments.append(environment)
        return true
    }

    mutating func deleteCollectionEnvironment(id environmentID: String, fromCollectionID collectionID: String) -> Bool {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }),
              let environmentIndex = collections[collectionIndex].environments.firstIndex(where: { $0.id == environmentID })
        else {
            return false
        }

        collections[collectionIndex].environments.remove(at: environmentIndex)
        return true
    }

    mutating func updateEnvironment(id environmentID: String, mutate: (inout APIEnvironment) -> Void) -> Bool {
        if let environmentIndex = environments.firstIndex(where: { $0.id == environmentID }) {
            mutate(&environments[environmentIndex])
            return true
        }

        for collectionIndex in collections.indices {
            guard let environmentIndex = collections[collectionIndex].environments.firstIndex(where: { $0.id == environmentID }) else {
                continue
            }

            mutate(&collections[collectionIndex].environments[environmentIndex])
            return true
        }

        return false
    }

    mutating func addEnvironmentVariable(_ variable: APIVariable, toEnvironmentID environmentID: String) -> Bool {
        updateEnvironment(id: environmentID) { environment in
            environment.variables.append(variable)
        }
    }

    mutating func updateEnvironmentVariable(
        environmentID: String,
        variableID: String,
        mutate: (inout APIVariable) -> Void
    ) -> Bool {
        if let environmentIndex = environments.firstIndex(where: { $0.id == environmentID }),
           let variableIndex = environments[environmentIndex].variables.firstIndex(where: { $0.id == variableID })
        {
            mutate(&environments[environmentIndex].variables[variableIndex])
            return true
        }

        for collectionIndex in collections.indices {
            guard let environmentIndex = collections[collectionIndex].environments.firstIndex(where: { $0.id == environmentID }),
                  let variableIndex = collections[collectionIndex].environments[environmentIndex].variables.firstIndex(where: { $0.id == variableID })
            else {
                continue
            }

            mutate(&collections[collectionIndex].environments[environmentIndex].variables[variableIndex])
            return true
        }

        return false
    }

    mutating func deleteEnvironmentVariable(environmentID: String, variableID: String) -> APIVariable? {
        if let environmentIndex = environments.firstIndex(where: { $0.id == environmentID }),
           let variableIndex = environments[environmentIndex].variables.firstIndex(where: { $0.id == variableID })
        {
            return environments[environmentIndex].variables.remove(at: variableIndex)
        }

        for collectionIndex in collections.indices {
            guard let environmentIndex = collections[collectionIndex].environments.firstIndex(where: { $0.id == environmentID }),
                  let variableIndex = collections[collectionIndex].environments[environmentIndex].variables.firstIndex(where: { $0.id == variableID })
            else {
                continue
            }

            return collections[collectionIndex].environments[environmentIndex].variables.remove(at: variableIndex)
        }

        return nil
    }

    mutating func addEnvironment(_ environment: APIEnvironment) {
        environments.append(environment)
    }

    mutating func deleteEnvironment(id environmentID: String) -> Bool {
        guard let environmentIndex = environments.firstIndex(where: { $0.id == environmentID }) else {
            return false
        }

        environments.remove(at: environmentIndex)
        return true
    }
}
