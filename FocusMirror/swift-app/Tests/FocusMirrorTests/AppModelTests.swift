import Foundation
import XCTest
@testable import FocusMirror

@MainActor
final class AppModelTests: XCTestCase {
    func testPresetSessionLengthsIncludeThirtyMinutes() {
        XCTAssertEqual(
            SessionLength.allCases.map(\.label),
            ["Open", "25m", "30m", "50m", "60m"]
        )
    }

    func testLegacySessionJSONDecodesWithoutCompletionReason() throws {
        let json = """
        [{
          "id": "11111111-1111-1111-1111-111111111111",
          "startTime": "2026-05-07T10:00:00Z",
          "endTime": "2026-05-07T10:25:00Z",
          "targetDurationSeconds": 1500,
          "segments": []
        }]
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sessions = try decoder.decode([FocusSession].self, from: Data(json.utf8))

        XCTAssertEqual(sessions.first?.targetDurationSeconds, 1500)
        XCTAssertNil(sessions.first?.completionReason)
    }

    func testZeroMinuteTargetCompletesWithoutEngineEvents() async throws {
        let engine = MockEngine()
        let store = MockSessionStore()
        let notifier = MockCompletionNotifier()
        let model = AppModel(store: store, engine: engine, completionNotifier: notifier)
        model.selectedLength = .minutes(0)

        model.startSession()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(model.isSessionActive)
        XCTAssertEqual(model.latestCompletedSession?.completionReason, .targetCompleted)
        XCTAssertEqual(store.savedSessions.count, 1)
        XCTAssertEqual(notifier.notifiedDurations, [0])
        XCTAssertTrue(engine.didStop)
    }

    func testEngineErrorAbortsWithoutSavingCompletedSession() async throws {
        let engine = MockEngine()
        let store = MockSessionStore()
        let model = AppModel(store: store, engine: engine, completionNotifier: MockCompletionNotifier())
        model.selectedLength = .openEnded

        model.startSession()
        engine.onError?("Could not open video source: webcam")
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertFalse(model.isSessionActive)
        XCTAssertNil(model.latestCompletedSession)
        XCTAssertTrue(store.savedSessions.isEmpty)
        XCTAssertTrue(model.engineError?.contains("detection engine failed") == true)
    }
}

@MainActor
private final class MockEngine: EngineProcessControlling {
    var onEvent: ((EngineEvent) -> Void)?
    var onError: ((String) -> Void)?
    var onTermination: ((EngineProcessTermination) -> Void)?
    var didStart = false
    var didStop = false

    func start(fps: Int) throws {
        didStart = true
    }

    func stop() {
        didStop = true
    }
}

private final class MockSessionStore: SessionStoring {
    var savedSessions: [FocusSession] = []

    func loadSessions() throws -> [FocusSession] {
        savedSessions.sorted { $0.startTime > $1.startTime }
    }

    func save(session: FocusSession) throws {
        if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions[index] = session
        } else {
            savedSessions.append(session)
        }
    }

    func deleteAll() throws {
        savedSessions = []
    }

    var dataDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
}

@MainActor
private final class MockCompletionNotifier: SessionCompletionNotifying {
    var notifiedDurations: [TimeInterval?] = []

    func notifySessionCompleted(targetDuration: TimeInterval?) {
        notifiedDurations.append(targetDuration)
    }
}
