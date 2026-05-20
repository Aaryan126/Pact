import Foundation
import Observation

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private static let appearanceModeDefaultsKey = "appearanceMode"
    private static let savedSessionsUnavailableMessage =
        "Clarity could not load saved sessions. You can still start a new session."
    private static let sessionSaveFailedMessage =
        "Session completed, but Clarity could not save it. Check available disk space and try again."
    private static let correctionSaveFailedMessage =
        "Clarity could not save this correction. Check available disk space and try again."
    private static let historyDeleteFailedMessage =
        "Clarity could not clear history. Try again."
    private static let cameraUnavailableMessage =
        "Clarity could not access the camera. Make sure camera access is on and no other app is using the camera, then try again."
    private static let processingStartupFailedMessage =
        "Clarity could not start local focus processing. Quit and reopen Clarity, then try again."
    private static let processingInterruptedMessage =
        "Clarity stopped this session because local focus processing was interrupted. Restart the session when your camera is available."
    private static let processingStalledMessage =
        "Clarity stopped this session because camera processing stopped. Restart the session when your camera is available."

    private let store: any SessionStoring
    private let engine: any EngineProcessControlling
    private let completionNotifier: any SessionCompletionNotifying
    private let engineStallTimeout: TimeInterval
    private var activeStartTime: Date?
    private var activeTargetDuration: TimeInterval?
    private var activeSegments: [StateSegment] = []
    private var lastEventElapsed: TimeInterval = 0
    private var lastEngineEventReceivedAt: Date?
    private var targetCompletionTask: Task<Void, Never>?
    private var engineWatchdogTask: Task<Void, Never>?

    var sessions: [FocusSession] = []
    var activeSessionStartedAt: Date?
    var selectedLength: SessionLength = .minutes(60)
    var latestCompletedSession: FocusSession?
    var engineError: String?
    var appearanceMode: AppAppearanceMode = AppModel.storedAppearanceMode() {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.appearanceModeDefaultsKey)
        }
    }

    init(
        store: any SessionStoring = SessionStore(),
        engine: any EngineProcessControlling = PythonEngineProcess(),
        completionNotifier: any SessionCompletionNotifying = UserNotificationSessionCompletionNotifier(),
        engineStallTimeout: TimeInterval = 30
    ) {
        self.store = store
        self.engine = engine
        self.completionNotifier = completionNotifier
        self.engineStallTimeout = engineStallTimeout
        do {
            self.sessions = try store.loadSessions()
        } catch {
            self.sessions = []
            self.engineError = Self.savedSessionsUnavailableMessage
        }
    }

    private static func storedAppearanceMode() -> AppAppearanceMode {
        guard let rawValue = UserDefaults.standard.string(forKey: appearanceModeDefaultsKey),
              let mode = AppAppearanceMode(rawValue: rawValue) else {
            return .dark
        }
        return mode
    }

    var isSessionActive: Bool {
        activeSessionStartedAt != nil
    }

    var activeTargetDurationSeconds: TimeInterval? {
        activeTargetDuration
    }

    func startSession() {
        guard activeSessionStartedAt == nil else { return }
        engineError = nil
        latestCompletedSession = nil
        let now = Date()
        activeStartTime = now
        activeSessionStartedAt = now
        activeTargetDuration = selectedLength.seconds
        activeSegments = []
        lastEventElapsed = 0
        lastEngineEventReceivedAt = nil

        engine.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.consume(event)
            }
        }
        engine.onError = { [weak self] failure in
            Task { @MainActor in
                self?.handleEngineError(failure)
            }
        }
        engine.onTermination = { [weak self] termination in
            Task { @MainActor in
                self?.handleUnexpectedEngineTermination(termination)
            }
        }
        do {
            try engine.start(fps: 5)
            scheduleTargetCompletion(startedAt: now, targetDuration: activeTargetDuration)
            startEngineWatchdog(startedAt: now)
        } catch {
            engineError = Self.userFacingStartFailureMessage(for: error)
            resetActiveState()
        }
    }

    func endSession() {
        finishSession(reason: .manual)
    }

    func deleteAllSessions() {
        do {
            try store.deleteAll()
            sessions = []
            latestCompletedSession = nil
            engineError = nil
        } catch {
            engineError = Self.historyDeleteFailedMessage
        }
    }

    private func finishSession(reason: SessionCompletionReason) {
        guard let start = activeStartTime else { return }
        cancelActiveTasks()
        engine.stop()

        let targetDuration = activeTargetDuration
        let end: Date
        let finalElapsed: TimeInterval
        if reason == .targetCompleted, let targetDuration {
            end = start.addingTimeInterval(targetDuration)
            finalElapsed = targetDuration
        } else {
            end = Date()
            finalElapsed = max(0, end.timeIntervalSince(start))
        }

        if !activeSegments.isEmpty {
            activeSegments[activeSegments.count - 1].endSeconds = max(
                activeSegments[activeSegments.count - 1].endSeconds,
                lastEventElapsed,
                finalElapsed
            )
        }

        let session = FocusSession(
            startTime: start,
            endTime: end,
            targetDurationSeconds: targetDuration,
            completionReason: reason,
            segments: normalizedActiveSegments(upTo: finalElapsed)
        )

        do {
            try store.save(session: session)
            sessions = try store.loadSessions()
            engineError = nil
        } catch {
            engineError = Self.sessionSaveFailedMessage
        }

        latestCompletedSession = session
        resetActiveState()

        if reason == .targetCompleted {
            completionNotifier.notifySessionCompleted(targetDuration: targetDuration)
        }
    }

    func update(segmentID: UUID, in sessionID: UUID, correction: SegmentCorrection?) {
        guard var session = sessions.first(where: { $0.id == sessionID }) else { return }
        guard let segmentIndex = session.segments.firstIndex(where: { $0.id == segmentID }) else { return }
        session.segments[segmentIndex].userCorrection = correction
        do {
            try store.save(session: session)
            sessions = try store.loadSessions()
            engineError = nil
            if latestCompletedSession?.id == sessionID {
                latestCompletedSession = session
            }
        } catch {
            engineError = Self.correctionSaveFailedMessage
        }
    }

    func session(with id: UUID) -> FocusSession? {
        sessions.first { $0.id == id }
    }

    private func consume(_ event: EngineEvent) {
        guard event.type == "classification", activeSessionStartedAt != nil else { return }
        lastEngineEventReceivedAt = Date()
        lastEventElapsed = max(lastEventElapsed, event.elapsedSeconds)
        if let target = activeTargetDuration, event.elapsedSeconds >= target {
            finishSession(reason: .targetCompleted)
            return
        }

        if activeSegments.isEmpty {
            activeSegments.append(
                StateSegment(
                    startSeconds: max(0, event.elapsedSeconds - 1),
                    endSeconds: event.elapsedSeconds,
                    state: event.state,
                    confidence: event.confidence
                )
            )
            return
        }

        let lastIndex = activeSegments.count - 1
        if activeSegments[lastIndex].state == event.state {
            activeSegments[lastIndex].endSeconds = event.elapsedSeconds
            activeSegments[lastIndex].confidence = (activeSegments[lastIndex].confidence + event.confidence) / 2
        } else {
            activeSegments[lastIndex].endSeconds = event.elapsedSeconds
            activeSegments.append(
                StateSegment(
                    startSeconds: event.elapsedSeconds,
                    endSeconds: event.elapsedSeconds + 1,
                    state: event.state,
                    confidence: event.confidence
                )
            )
        }
    }

    private func scheduleTargetCompletion(startedAt start: Date, targetDuration: TimeInterval?) {
        guard let targetDuration else { return }
        let nanoseconds = UInt64(max(0, targetDuration) * 1_000_000_000)
        targetCompletionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            guard self?.activeStartTime == start else { return }
            self?.finishSession(reason: .targetCompleted)
        }
    }

    private func startEngineWatchdog(startedAt start: Date) {
        engineWatchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                guard let self, self.activeStartTime == start else { return }

                let lastHeartbeat = self.lastEngineEventReceivedAt ?? start
                if Date().timeIntervalSince(lastHeartbeat) >= self.engineStallTimeout {
                    self.abortActiveSession(message: Self.processingStalledMessage)
                    return
                }
            }
        }
    }

    private func handleEngineError(_ failure: EngineProcessFailure) {
        let displayMessage = Self.userFacingRuntimeMessage(for: failure, isSessionActive: isSessionActive)
        if isSessionActive {
            abortActiveSession(message: displayMessage)
        } else {
            engineError = displayMessage
        }
    }

    private func handleUnexpectedEngineTermination(_ termination: EngineProcessTermination) {
        _ = termination
        guard isSessionActive else { return }
        abortActiveSession(message: Self.processingInterruptedMessage)
    }

    private static func userFacingStartFailureMessage(for error: Error) -> String {
        if let processError = error as? EngineProcessError {
            switch processError {
            case .engineNotFound, .pythonRuntimeNotFound:
                return processingStartupFailedMessage
            }
        }
        return processingStartupFailedMessage
    }

    private static func userFacingRuntimeMessage(
        for failure: EngineProcessFailure,
        isSessionActive: Bool
    ) -> String {
        if isCameraFailure(failure) {
            return cameraUnavailableMessage
        }
        return isSessionActive ? processingInterruptedMessage : processingStartupFailedMessage
    }

    private static func isCameraFailure(_ failure: EngineProcessFailure) -> Bool {
        if ["source_open_failed", "camera_unavailable"].contains(failure.code) {
            return true
        }

        let message = failure.message.lowercased()
        return message.contains("camera")
            || message.contains("video source")
            || message.contains("capture")
            || message.contains("webcam")
    }

    private func abortActiveSession(message: String) {
        cancelActiveTasks()
        engine.stop()
        resetActiveState()
        latestCompletedSession = nil
        engineError = message
    }

    private func cancelActiveTasks() {
        targetCompletionTask?.cancel()
        targetCompletionTask = nil
        engineWatchdogTask?.cancel()
        engineWatchdogTask = nil
    }

    private func resetActiveState() {
        activeStartTime = nil
        activeSessionStartedAt = nil
        activeTargetDuration = nil
        activeSegments = []
        lastEventElapsed = 0
        lastEngineEventReceivedAt = nil
    }

    private func normalizedActiveSegments(upTo finalElapsed: TimeInterval) -> [StateSegment] {
        activeSegments.compactMap { segment in
            let start = min(max(0, segment.startSeconds), finalElapsed)
            let end = min(max(start, segment.endSeconds), finalElapsed)
            guard end > start else { return nil }

            var normalized = segment
            normalized.startSeconds = start
            normalized.endSeconds = end
            return normalized
        }
    }
}
