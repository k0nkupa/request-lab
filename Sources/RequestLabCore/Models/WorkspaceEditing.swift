import Foundation

public extension APIWorkspace {
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
}
