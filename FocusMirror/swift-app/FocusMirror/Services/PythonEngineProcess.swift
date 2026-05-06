import Foundation

@MainActor
final class PythonEngineProcess {
    var onEvent: ((EngineEvent) -> Void)?
    var onError: ((String) -> Void)?

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdoutBuffer = Data()
    private let decoder = JSONDecoder()

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(fps: Int = 5) throws {
        guard process == nil else { return }
        guard let engineRoot = Self.findEngineRoot() else {
            throw EngineProcessError.engineNotFound
        }
        let pythonExecutable = Self.findPythonExecutable(engineRoot: engineRoot)

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = pythonExecutable
        process.arguments = [
            pythonExecutable.lastPathComponent == "env" ? "python3" : nil,
            "-m",
            "focusmirror_engine.main",
            "--source",
            "webcam",
            "--fps",
            "\(fps)"
        ].compactMap { $0 }
        process.currentDirectoryURL = engineRoot
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONPATH"] = engineRoot.path
        environment["PYTHONUNBUFFERED"] = "1"
        environment["MPLCONFIGDIR"] = NSTemporaryDirectory()
        process.environment = environment
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.consumeStdout(data)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let message = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.consumeStderr(message)
            }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
                self?.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                self?.process = nil
                self?.stdoutPipe = nil
                self?.stderrPipe = nil
            }
        }

        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        try process.run()
    }

    func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        stdoutBuffer.removeAll()
    }

    private func consumeStdout(_ data: Data) {
        stdoutBuffer.append(data)
        while let newline = stdoutBuffer.firstIndex(of: 0x0A) {
            let lineData = stdoutBuffer[..<newline]
            stdoutBuffer.removeSubrange(...newline)
            guard !lineData.isEmpty else { continue }
            do {
                let event = try decoder.decode(EngineEvent.self, from: Data(lineData))
                onEvent?(event)
            } catch {
                onError?("Could not decode engine event: \(error.localizedDescription)")
            }
        }
    }

    private func consumeStderr(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.isBenignEngineStderr(trimmed) else { return }
        onError?(trimmed)
    }

    private static func isBenignEngineStderr(_ message: String) -> Bool {
        let benignFragments = [
            "SymbolDatabase.GetPrototype() is deprecated",
            "Feedback manager requires a model with a single signature inference",
            "Created TensorFlow Lite XNNPACK delegate for CPU",
            "All log messages before absl::InitializeLog() is called",
            "GL version:"
        ]
        return benignFragments.contains { message.contains($0) }
    }

    private static func findEngineRoot() -> URL? {
        let fileManager = FileManager.default

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let sourceRepoRoot = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let explicitRoot = ProcessInfo.processInfo.environment["FOCUSMIRROR_ENGINE_ROOT"]
            .map { URL(fileURLWithPath: $0).standardized }

        let anchors = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath),
            Bundle.main.bundleURL,
            Bundle.main.resourceURL,
            sourceRepoRoot
        ].compactMap { $0 }

        var candidates = [
            explicitRoot,
            Bundle.main.resourceURL?.appendingPathComponent("python-engine"),
        ].compactMap { $0 }

        for anchor in anchors {
            candidates.append(contentsOf: engineRootCandidates(from: anchor))
        }

        return candidates.first { isEngineRoot($0) }
    }

    private static func engineRootCandidates(from anchor: URL) -> [URL] {
        var candidates: [URL] = []
        var current = anchor.standardized
        for _ in 0..<8 {
            candidates.append(current.appendingPathComponent("python-engine").standardized)
            if current.lastPathComponent == "python-engine" {
                candidates.append(current)
            }
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else { break }
            current = parent
        }
        return candidates
    }

    private static func isEngineRoot(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("focusmirror_engine/main.py").path)
    }

    private static func findPythonExecutable(engineRoot: URL) -> URL {
        if let bundledPython = findBundledPython() {
            return bundledPython
        }

        let candidates = [
            engineRoot.appendingPathComponent(".venv39/bin/python"),
            engineRoot.appendingPathComponent(".venv/bin/python"),
            engineRoot.appendingPathComponent("venv/bin/python")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
            ?? URL(fileURLWithPath: "/usr/bin/env")
    }

    private static func findBundledPython() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let candidates = [
            resourceURL.appendingPathComponent("python-runtime/bin/python3"),
            resourceURL.appendingPathComponent("python-runtime/bin/python")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

enum EngineProcessError: LocalizedError {
    case engineNotFound

    var errorDescription: String? {
        switch self {
        case .engineNotFound:
            "Could not find bundled python-engine directory."
        }
    }
}
