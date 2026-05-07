import Foundation

@MainActor
protocol EngineProcessControlling: AnyObject {
    var onEvent: ((EngineEvent) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var onTermination: ((EngineProcessTermination) -> Void)? { get set }

    func start(fps: Int) throws
    func stop()
}

struct EngineProcessTermination: Equatable {
    let status: Int32
    let reason: String
}

@MainActor
final class PythonEngineProcess: EngineProcessControlling {
    var onEvent: ((EngineEvent) -> Void)?
    var onError: ((String) -> Void)?
    var onTermination: ((EngineProcessTermination) -> Void)?

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()
    private var expectedTermination = false
    private let decoder = JSONDecoder()

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(fps: Int = 5) throws {
        guard process == nil else { return }
        expectedTermination = false
        guard let engineRoot = Self.findEngineRoot() else {
            throw EngineProcessError.engineNotFound
        }
        let pythonExecutable = try Self.findPythonExecutable(engineRoot: engineRoot)

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
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.consumeStderr(data)
            }
        }
        process.terminationHandler = { [weak self] terminatedProcess in
            let status = terminatedProcess.terminationStatus
            let reason = terminatedProcess.terminationReason == .exit ? "exited" : "terminated"
            Task { @MainActor in
                let wasExpected = self?.expectedTermination ?? true
                self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
                self?.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                self?.process = nil
                self?.stdoutPipe = nil
                self?.stderrPipe = nil
                self?.stdoutBuffer.removeAll()
                self?.stderrBuffer.removeAll()
                self?.expectedTermination = false

                if !wasExpected {
                    self?.onTermination?(EngineProcessTermination(status: status, reason: reason))
                }
            }
        }

        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            self.process = nil
            self.stdoutPipe = nil
            self.stderrPipe = nil
            stdoutBuffer.removeAll()
            stderrBuffer.removeAll()
            expectedTermination = false
            throw error
        }
    }

    func stop() {
        expectedTermination = true
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        stdoutBuffer.removeAll()
        stderrBuffer.removeAll()
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

    private func consumeStderr(_ data: Data) {
        stderrBuffer.append(data)
        while let newline = stderrBuffer.firstIndex(of: 0x0A) {
            let lineData = stderrBuffer[..<newline]
            stderrBuffer.removeSubrange(...newline)
            consumeStderrLine(Data(lineData))
        }
    }

    private func consumeStderrLine(_ data: Data) {
        guard let message = String(data: data, encoding: .utf8) else { return }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.isBenignEngineStderr(trimmed) else { return }

        if let payload = try? decoder.decode(EngineErrorPayload.self, from: data),
           payload.type == "error" {
            onError?(payload.message)
            return
        }

        onError?(trimmed)
    }

    private static func isBenignEngineStderr(_ message: String) -> Bool {
        if message == "INFO:" || message == "WARNING:" {
            return true
        }

        let benignPrefixes = [
            "INFO:",
            "I0000",
            "W0000"
        ]
        if benignPrefixes.contains(where: { message.hasPrefix($0) }) {
            return true
        }

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

    private static func findPythonExecutable(engineRoot: URL) throws -> URL {
        if let bundledPython = findBundledPython() {
            return bundledPython
        }

        #if DEBUG
        let candidates = [
            engineRoot.appendingPathComponent(".venv39/bin/python"),
            engineRoot.appendingPathComponent(".venv/bin/python"),
            engineRoot.appendingPathComponent("venv/bin/python")
        ]

        if let localPython = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return localPython
        }

        if ProcessInfo.processInfo.environment["FOCUSMIRROR_ALLOW_SYSTEM_PYTHON"] == "1" {
            return URL(fileURLWithPath: "/usr/bin/env")
        }
        #endif

        throw EngineProcessError.pythonRuntimeNotFound
    }

    private static func findBundledPython() -> URL? {
        let roots = [
            Bundle.main.privateFrameworksURL,
            Bundle.main.resourceURL
        ].compactMap { $0 }

        let candidates = roots.flatMap { root in
            [
                root.appendingPathComponent("python-runtime/bin/python3"),
                root.appendingPathComponent("python-runtime/bin/python")
            ]
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

enum EngineProcessError: LocalizedError {
    case engineNotFound
    case pythonRuntimeNotFound

    var errorDescription: String? {
        switch self {
        case .engineNotFound:
            "Could not find bundled python-engine directory."
        case .pythonRuntimeNotFound:
            "Could not find the bundled Python runtime. Rebuild the app with FOCUSMIRROR_VENDOR_PYTHON=1 for release."
        }
    }
}

private struct EngineErrorPayload: Decodable {
    let type: String
    let message: String
}
