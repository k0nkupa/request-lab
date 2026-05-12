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

    mutating func renameRequest(id requestID: String, to name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }

        return updateRequest(id: requestID) { request in
            request.name = trimmedName
        }
    }

    mutating func duplicateRequest(id requestID: String, newID: String, name: String) -> APIRequest? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              collectionID(containingRequestID: newID) == nil
        else {
            return nil
        }

        for collectionIndex in collections.indices {
            guard let requestIndex = collections[collectionIndex].requests.firstIndex(where: { $0.id == requestID }) else {
                continue
            }

            var duplicatedRequest = collections[collectionIndex].requests[requestIndex]
            duplicatedRequest.id = newID
            duplicatedRequest.name = trimmedName
            collections[collectionIndex].requests.insert(duplicatedRequest, at: requestIndex + 1)
            return duplicatedRequest
        }

        return nil
    }

    mutating func moveRequest(id requestID: String, toCollectionID collectionID: String) -> Bool {
        var sourceCollectionIndex: Array<APICollection>.Index?
        var sourceRequestIndex: Array<APIRequest>.Index?

        for collectionIndex in collections.indices {
            guard let requestIndex = collections[collectionIndex].requests.firstIndex(where: { $0.id == requestID }) else {
                continue
            }

            sourceCollectionIndex = collectionIndex
            sourceRequestIndex = requestIndex
            break
        }

        guard let sourceCollectionIndex,
              let sourceRequestIndex,
              let destinationCollectionIndex = collections.firstIndex(where: { $0.id == collectionID })
        else {
            return false
        }

        guard sourceCollectionIndex != destinationCollectionIndex else {
            return true
        }

        let request = collections[sourceCollectionIndex].requests.remove(at: sourceRequestIndex)
        collections[destinationCollectionIndex].requests.append(request)
        return true
    }

    mutating func reorderRequest(id requestID: String, toIndex destinationIndex: Int) -> Bool {
        for collectionIndex in collections.indices {
            guard let requestIndex = collections[collectionIndex].requests.firstIndex(where: { $0.id == requestID }) else {
                continue
            }

            guard collections[collectionIndex].requests.indices.contains(destinationIndex) else {
                return false
            }

            guard requestIndex != destinationIndex else {
                return true
            }

            let request = collections[collectionIndex].requests.remove(at: requestIndex)
            collections[collectionIndex].requests.insert(request, at: destinationIndex)
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

    func request(id requestID: String) -> APIRequest? {
        collections
            .flatMap(\.requests)
            .first { $0.id == requestID }
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
