import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let store: SessionStore
    private let engine: PythonEngineProcess
    private var activeStartTime: Date?
    private var activeTargetDuration: TimeInterval?
    private var activeSegments: [StateSegment] = []
    private var lastEventElapsed: TimeInterval = 0

    var sessions: [FocusSession] = []
    var activeSessionStartedAt: Date?
    var selectedLength: SessionLength = .minutes(60)
    var latestCompletedSession: FocusSession?
    var engineError: String?

    init(store: SessionStore = SessionStore(), engine: PythonEngineProcess = PythonEngineProcess()) {
        self.store = store
        self.engine = engine
        self.sessions = store.loadSessions()
    }

    var isSessionActive: Bool {
        activeSessionStartedAt != nil
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

        engine.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.consume(event)
            }
        }
        engine.onError = { [weak self] message in
            Task { @MainActor in
                self?.engineError = message
            }
        }
        do {
            try engine.start()
        } catch {
            engineError = error.localizedDescription
            activeStartTime = nil
            activeSessionStartedAt = nil
            activeTargetDuration = nil
            activeSegments = []
            lastEventElapsed = 0
        }
    }

    func endSession() {
        guard let start = activeStartTime else { return }
        engine.stop()
        let end = Date()
        if !activeSegments.isEmpty {
            activeSegments[activeSegments.count - 1].endSeconds = max(lastEventElapsed, end.timeIntervalSince(start))
        }
        let session = FocusSession(
            startTime: start,
            endTime: end,
            targetDurationSeconds: activeTargetDuration,
            segments: activeSegments
        )
        store.save(session: session)
        sessions = store.loadSessions()
        latestCompletedSession = session
        activeStartTime = nil
        activeSessionStartedAt = nil
        activeTargetDuration = nil
        activeSegments = []
        lastEventElapsed = 0
        engineError = nil
    }

    func update(segmentID: UUID, in sessionID: UUID, correction: SegmentCorrection?) {
        guard var session = sessions.first(where: { $0.id == sessionID }) else { return }
        guard let segmentIndex = session.segments.firstIndex(where: { $0.id == segmentID }) else { return }
        session.segments[segmentIndex].userCorrection = correction
        store.save(session: session)
        sessions = store.loadSessions()
        if latestCompletedSession?.id == sessionID {
            latestCompletedSession = session
        }
    }

    func session(with id: UUID) -> FocusSession? {
        sessions.first { $0.id == id }
    }

    private func consume(_ event: EngineEvent) {
        guard event.type == "classification", activeSessionStartedAt != nil else { return }
        lastEventElapsed = max(lastEventElapsed, event.elapsedSeconds)
        if let target = activeTargetDuration, event.elapsedSeconds >= target {
            endSession()
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
}
