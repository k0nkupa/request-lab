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
