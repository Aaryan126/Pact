import Foundation

protocol SessionStoring {
    func loadSessions() throws -> [FocusSession]
    func save(session: FocusSession) throws
    func deleteAll() throws
    var dataDirectory: URL { get }
}

struct SessionStore {
    private let fileURL: URL
    private let initializationError: SessionStoreError?

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let directory = base.appendingPathComponent("FocusMirror", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            initializationError = nil
        } catch {
            initializationError = .directoryCreationFailed(directory, error)
        }
        fileURL = directory.appendingPathComponent("sessions.json")
    }

    func loadSessions() throws -> [FocusSession] {
        if let initializationError {
            throw initializationError
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw SessionStoreError.loadFailed(fileURL, error)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([FocusSession].self, from: data)
                .sorted { $0.startTime > $1.startTime }
        } catch {
            throw SessionStoreError.decodeFailed(fileURL, error)
        }
    }

    func save(session: FocusSession) throws {
        if let initializationError {
            throw initializationError
        }

        var sessions = try loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        try saveAll(sessions.sorted { $0.startTime > $1.startTime })
    }

    func deleteAll() throws {
        if let initializationError {
            throw initializationError
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw SessionStoreError.deleteFailed(fileURL, error)
        }
    }

    var dataDirectory: URL {
        fileURL.deletingLastPathComponent()
    }

    private func saveAll(_ sessions: [FocusSession]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(sessions)
        } catch {
            throw SessionStoreError.encodeFailed(error)
        }

        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw SessionStoreError.saveFailed(fileURL, error)
        }
    }
}

extension SessionStore: SessionStoring {}

enum SessionStoreError: LocalizedError {
    case directoryCreationFailed(URL, Error)
    case loadFailed(URL, Error)
    case decodeFailed(URL, Error)
    case encodeFailed(Error)
    case saveFailed(URL, Error)
    case deleteFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let url, let error):
            "Could not create FocusMirror data folder at \(url.path): \(error.localizedDescription)"
        case .loadFailed(let url, let error):
            "Could not read FocusMirror sessions at \(url.path): \(error.localizedDescription)"
        case .decodeFailed(let url, let error):
            "Could not decode FocusMirror sessions at \(url.path): \(error.localizedDescription)"
        case .encodeFailed(let error):
            "Could not encode FocusMirror sessions: \(error.localizedDescription)"
        case .saveFailed(let url, let error):
            "Could not save FocusMirror sessions at \(url.path): \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            "Could not delete FocusMirror sessions at \(url.path): \(error.localizedDescription)"
        }
    }
}
