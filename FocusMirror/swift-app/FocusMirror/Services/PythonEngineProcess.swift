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

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let pythonExecutable = Self.findBundledPython() ?? URL(fileURLWithPath: "/usr/bin/env")
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
                self?.onError?(message.trimmingCharacters(in: .whitespacesAndNewlines))
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

    private static func findEngineRoot() -> URL? {
        let fileManager = FileManager.default
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("python-engine"),
            URL(fileURLWithPath: fileManager.currentDirectoryPath).deletingLastPathComponent().appendingPathComponent("python-engine"),
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("../python-engine").standardized
        ].compactMap { $0 }

        return candidates.first { url in
            fileManager.fileExists(atPath: url.appendingPathComponent("focusmirror_engine/main.py").path)
        }
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
