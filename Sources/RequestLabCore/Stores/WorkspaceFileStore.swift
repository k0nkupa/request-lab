import Foundation
import Yams

public final class WorkspaceFileStore: Sendable {
    private static let orderFileName = ".order.yaml"

    private let fileManagerBox: FileManagerBox

    public init(fileManager: FileManager = .default) {
        self.fileManagerBox = FileManagerBox(fileManager: fileManager)
    }

    public func load(from workspaceURL: URL) throws -> APIWorkspace {
        let workspaceFile = workspaceURL.appending(path: "workspace.yaml")
        guard fileManager.fileExists(atPath: workspaceFile.path) else {
            throw RequestLabError.missingWorkspaceFile(workspaceFile)
        }

        let metadata = try decode(WorkspaceMetadata.self, from: workspaceFile)
        let collections = try loadCollections(from: workspaceURL)
        let environments = try loadEnvironments(from: workspaceURL)
        let history = try loadHistory(from: workspaceURL)

        return APIWorkspace(
            id: metadata.id,
            name: metadata.name,
            collections: collections,
            environments: environments,
            history: history
        )
    }

    public func save(_ workspace: APIWorkspace, to workspaceURL: URL) throws {
        let collectionFileNames = try fileNames(
            for: workspace.collections.map(\.name),
            itemKind: "collection"
        )
        let environmentFileNames = try fileNames(
            for: workspace.environments.map(\.name),
            itemKind: "environment"
        )

        let stagingURL = try makeStagingDirectory(for: workspaceURL)
        defer { try? fileManager.removeItem(at: stagingURL) }

        try writeWorkspace(
            workspace,
            to: stagingURL,
            collectionFileNames: collectionFileNames,
            environmentFileNames: environmentFileNames
        )
        try preserveUnrelatedClientFiles(from: workspaceURL, into: stagingURL)
        try commitStagedWorkspace(from: stagingURL, to: workspaceURL)
    }

    private func writeWorkspace(
        _ workspace: APIWorkspace,
        to workspaceURL: URL,
        collectionFileNames: [String],
        environmentFileNames: [String]
    ) throws {
        let collectionsDirectory = workspaceURL.appending(path: "collections")
        let environmentsDirectory = workspaceURL.appending(path: "environments")

        try createDirectory(at: workspaceURL)
        try createDirectory(at: collectionsDirectory)
        try createDirectory(at: environmentsDirectory)
        try createDirectory(at: workspaceURL.appending(path: ".client"))

        let metadata = WorkspaceMetadata(id: workspace.id, name: workspace.name)
        try encode(metadata, to: workspaceURL.appending(path: "workspace.yaml"))

        for (collection, fileName) in zip(workspace.collections, collectionFileNames) {
            let fileURL = collectionsDirectory.appending(path: fileName)
            try encode(collection, to: fileURL)
        }
        try encode(collectionFileNames, to: collectionsDirectory.appending(path: Self.orderFileName))

        for (environment, fileName) in zip(workspace.environments, environmentFileNames) {
            let fileURL = environmentsDirectory.appending(path: fileName)
            try encode(redactedForSharedStorage(environment), to: fileURL)
        }
        try encode(environmentFileNames, to: environmentsDirectory.appending(path: Self.orderFileName))

        try encode(workspace.history, to: workspaceURL.appending(path: ".client/history.yaml"))
    }

    private func commitStagedWorkspace(from stagingURL: URL, to workspaceURL: URL) throws {
        guard fileManager.fileExists(atPath: workspaceURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: workspaceURL)
            return
        }

        let backupURL = try makeBackupDirectoryURL(for: workspaceURL)
        try fileManager.moveItem(at: workspaceURL, to: backupURL)

        do {
            try fileManager.moveItem(at: stagingURL, to: workspaceURL)
            try fileManager.removeItem(at: backupURL)
        } catch {
            if fileManager.fileExists(atPath: workspaceURL.path) {
                try? fileManager.removeItem(at: workspaceURL)
            }
            try? fileManager.moveItem(at: backupURL, to: workspaceURL)
            throw error
        }
    }

    private func loadCollections(from workspaceURL: URL) throws -> [APICollection] {
        try loadYAMLFiles(in: workspaceURL.appending(path: "collections"), as: APICollection.self)
    }

    private func loadEnvironments(from workspaceURL: URL) throws -> [APIEnvironment] {
        try loadYAMLFiles(in: workspaceURL.appending(path: "environments"), as: APIEnvironment.self)
    }

    private func loadHistory(from workspaceURL: URL) throws -> [APIHistoryEntry] {
        let historyFile = workspaceURL.appending(path: ".client/history.yaml")
        guard fileManager.fileExists(atPath: historyFile.path) else {
            return []
        }

        return try decode([APIHistoryEntry].self, from: historyFile)
    }

    private var fileManager: FileManager {
        fileManagerBox.fileManager
    }

    private func loadYAMLFiles<T: Decodable>(in directory: URL, as type: T.Type) throws -> [T] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        let files = try orderedYAMLFiles(in: directory)

        return try files.map { try decode(T.self, from: $0) }
    }

    private func orderedYAMLFiles(in directory: URL) throws -> [URL] {
        let orderFile = directory.appending(path: Self.orderFileName)
        let actualFileNames = try yamlFileNames(in: directory)

        if fileManager.fileExists(atPath: orderFile.path) {
            let listedFileNames = try decode([String].self, from: orderFile)
                .filter { $0 != Self.orderFileName }
            try validateOrderFile(
                listedFileNames: listedFileNames,
                actualFileNames: actualFileNames,
                orderFile: orderFile
            )

            return listedFileNames.map { directory.appending(path: $0) }
        }

        return actualFileNames
            .sorted()
            .map { directory.appending(path: $0) }
    }

    private func yamlFileNames(in directory: URL) throws -> [String] {
        try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "yaml" && $0.lastPathComponent != Self.orderFileName }
        .map(\.lastPathComponent)
    }

    private func createDirectory(at directoryURL: URL) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func makeStagingDirectory(for workspaceURL: URL) throws -> URL {
        let parentURL = workspaceURL.deletingLastPathComponent()
        try createDirectory(at: parentURL)

        let stagingURL = parentURL.appending(
            path: ".\(workspaceURL.lastPathComponent).staging-\(UUID().uuidString)"
        )
        try createDirectory(at: stagingURL)
        return stagingURL
    }

    private func makeBackupDirectoryURL(for workspaceURL: URL) throws -> URL {
        let parentURL = workspaceURL.deletingLastPathComponent()
        try createDirectory(at: parentURL)

        return parentURL.appending(
            path: ".\(workspaceURL.lastPathComponent).backup-\(UUID().uuidString)"
        )
    }

    private func preserveUnrelatedClientFiles(from workspaceURL: URL, into stagingURL: URL) throws {
        let sourceClientDirectory = workspaceURL.appending(path: ".client")
        guard fileManager.fileExists(atPath: sourceClientDirectory.path) else {
            return
        }

        let stagingClientDirectory = stagingURL.appending(path: ".client")
        try createDirectory(at: stagingClientDirectory)

        let clientItems = try fileManager.contentsOfDirectory(
            at: sourceClientDirectory,
            includingPropertiesForKeys: nil
        )
        for clientItem in clientItems where clientItem.lastPathComponent != "history.yaml" {
            let destinationURL = stagingClientDirectory.appending(path: clientItem.lastPathComponent)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: clientItem, to: destinationURL)
        }
    }

    private func validateOrderFile(
        listedFileNames: [String],
        actualFileNames: [String],
        orderFile: URL
    ) throws {
        let listedSet = Set(listedFileNames)
        let actualSet = Set(actualFileNames)
        let duplicateListedFileNames = listedFileNames
            .reduce(into: [String: Int]()) { counts, fileName in
                counts[fileName, default: 0] += 1
            }
            .filter { $0.value > 1 }
            .map(\.key)
            .sorted()
        let unlistedFileNames = actualSet.subtracting(listedSet).sorted()
        let missingFileNames = listedSet.subtracting(actualSet).sorted()

        guard duplicateListedFileNames.isEmpty,
              unlistedFileNames.isEmpty,
              missingFileNames.isEmpty else {
            var details: [String] = []
            if !duplicateListedFileNames.isEmpty {
                details.append("duplicate entries: \(duplicateListedFileNames.joined(separator: ", "))")
            }
            if !unlistedFileNames.isEmpty {
                details.append("unlisted YAML files: \(unlistedFileNames.joined(separator: ", "))")
            }
            if !missingFileNames.isEmpty {
                details.append("listed missing YAML files: \(missingFileNames.joined(separator: ", "))")
            }
            throw RequestLabError.invalidWorkspace(
                "\(orderFile.path) is out of sync (\(details.joined(separator: "; ")))"
            )
        }
    }

    private func redactedForSharedStorage(_ environment: APIEnvironment) -> APIEnvironment {
        var redactedEnvironment = environment
        redactedEnvironment.variables = environment.variables.map { variable in
            guard variable.isSecret else {
                return variable
            }

            var redactedVariable = variable
            redactedVariable.value = nil
            return redactedVariable
        }
        return redactedEnvironment
    }

    private func decode<T: Decodable>(_ type: T.Type, from fileURL: URL) throws -> T {
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return try YAMLDecoder().decode(T.self, from: text)
        } catch let error as RequestLabError {
            throw error
        } catch {
            throw RequestLabError.yamlDecodeFailed("\(fileURL.path): \(error.localizedDescription)")
        }
    }

    private func encode<T: Encodable>(_ value: T, to fileURL: URL) throws {
        do {
            let text = try YAMLEncoder().encode(value)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RequestLabError.yamlEncodeFailed("\(fileURL.path): \(error.localizedDescription)")
        }
    }

    private func fileNames(for names: [String], itemKind: String) throws -> [String] {
        var seenFileNames = Set<String>()
        var resolvedFileNames: [String] = []

        for name in names {
            let resolvedFileName = WorkspaceFileNaming.yamlFileName(for: name)
            guard seenFileNames.insert(resolvedFileName).inserted else {
                throw RequestLabError.invalidWorkspace("Duplicate \(itemKind) filename: \(resolvedFileName)")
            }
            resolvedFileNames.append(resolvedFileName)
        }

        return resolvedFileNames
    }
}

private struct WorkspaceMetadata: Codable, Equatable, Sendable {
    var id: String
    var name: String
}

private struct FileManagerBox: @unchecked Sendable {
    let fileManager: FileManager
}
