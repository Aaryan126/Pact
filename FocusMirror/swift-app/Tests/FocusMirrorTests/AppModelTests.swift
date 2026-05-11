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

    func testAppearanceModeDefaultsToDarkAndPersistsSelection() {
        let defaultsKey = "appearanceMode"
        let previousValue = UserDefaults.standard.string(forKey: defaultsKey)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: defaultsKey)
        let initialModel = AppModel(store: MockSessionStore(), engine: MockEngine(), completionNotifier: MockCompletionNotifier())
        XCTAssertEqual(initialModel.appearanceMode, .dark)

        initialModel.appearanceMode = .light
        let reloadedModel = AppModel(store: MockSessionStore(), engine: MockEngine(), completionNotifier: MockCompletionNotifier())
        XCTAssertEqual(reloadedModel.appearanceMode, .light)
    }

    func testDetectionStatePresentationOrderAndLabelsMatchSummaryUI() {
        XCTAssertEqual(
            DetectionState.allCases.map(\.label),
            [
                "Focused",
                "Looking Down",
                "Away From Screen",
                "Talking",
                "Eyes Closed",
                "Uncertain"
            ]
        )
    }

    func testDetectedStateSummariesUseCanonicalOrderAndSessionDuration() {
        let session = FocusSession(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 135 * 60),
            targetDurationSeconds: nil,
            segments: [
                StateSegment(startSeconds: 0, endSeconds: 94 * 60, state: .focused, confidence: 0.9),
                StateSegment(startSeconds: 94 * 60, endSeconds: 112 * 60, state: .lookingDown, confidence: 0.8),
                StateSegment(startSeconds: 112 * 60, endSeconds: 123 * 60, state: .away, confidence: 0.8),
                StateSegment(startSeconds: 123 * 60, endSeconds: 129 * 60, state: .talking, confidence: 0.7),
                StateSegment(startSeconds: 129 * 60, endSeconds: 131 * 60, state: .eyesClosed, confidence: 0.7),
                StateSegment(startSeconds: 131 * 60, endSeconds: 135 * 60, state: .uncertain, confidence: 0.5)
            ]
        )

        let summaries = session.detectedStateSummaries
        XCTAssertEqual(summaries.map(\.state), DetectionState.allCases)
        XCTAssertEqual(summaries.map { Int($0.seconds / 60) }, [94, 18, 11, 6, 2, 4])
        XCTAssertEqual(formatWholePercent(session.detectedSummary(for: .focused).ratio), "70%")
        XCTAssertEqual(formatWholePercent(session.detectedSummary(for: .lookingDown).ratio), "13%")
        XCTAssertEqual(formatWholePercent(session.detectedSummary(for: .away).ratio), "8%")
    }

    func testCompactDurationFormattingMatchesSummaryDesign() {
        XCTAssertEqual(formatCompactDuration(0), "0s")
        XCTAssertEqual(formatCompactDuration(18 * 60), "18m")
        XCTAssertEqual(formatCompactDuration(94 * 60), "1h 34m")
        XCTAssertEqual(formatCompactDuration(135 * 60), "2h 15m")
    }

    func testSessionSummaryCSVUsesReadableSummaryAndTimelineTables() {
        let session = FocusSession(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20 * 60),
            targetDurationSeconds: nil,
            completionReason: .manual,
            segments: [
                StateSegment(startSeconds: 0, endSeconds: 10 * 60, state: .focused, confidence: 0.9),
                StateSegment(
                    startSeconds: 10 * 60,
                    endSeconds: 15 * 60,
                    state: .lookingDown,
                    confidence: 0.8,
                    userCorrection: .actuallyFocused
                ),
                StateSegment(startSeconds: 15 * 60, endSeconds: 20 * 60, state: .away, confidence: 0.7)
            ]
        )

        let csv = SessionSummaryCSVExporter.csv(
            for: session,
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertTrue(csv.hasPrefix("Section,Metric,Value,Duration,Seconds,Percent Of Session,Count\n"))
        XCTAssertTrue(csv.contains("\nSession,Started,\"Jan 1, 1970, 12:00 AM GMT\",,,,\n"))
        XCTAssertTrue(csv.contains("\nSession,Timezone,Greenwich Mean Time (GMT),,,,\n"))
        XCTAssertTrue(csv.contains("\nSession,Total Session Duration,,20m,1200,100.0%,\n"))
        XCTAssertFalse(csv.contains("Focus Summary"))
        XCTAssertTrue(csv.contains("\nActivity Breakdown,Focused,,10m,600,50.0%,1\n"))
        XCTAssertTrue(csv.contains("\nActivity Breakdown,Looking Down,,5m,300,25.0%,1\n"))
        XCTAssertTrue(csv.contains("\n\nSegment,Start Time,End Time,Start Offset,End Offset,State,Duration,Seconds,Percent Of Session,Confidence\n"))
        XCTAssertTrue(csv.contains("1,\"Jan 1, 1970, 12:00 AM GMT\",\"Jan 1, 1970, 12:10 AM GMT\",00:00,10:00,Focused,10m,600,50.0%,90.0%\n"))
        XCTAssertTrue(csv.contains("2,\"Jan 1, 1970, 12:10 AM GMT\",\"Jan 1, 1970, 12:15 AM GMT\",10:00,15:00,Looking Down,5m,300,25.0%,80.0%\n"))
        XCTAssertFalse(csv.contains("User Correction"))
        XCTAssertFalse(csv.contains("Actually focused work"))
    }

    func testSessionSummaryXLSXUsesStyledWorkbookPackage() throws {
        let session = FocusSession(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 80),
            targetDurationSeconds: nil,
            completionReason: .manual,
            segments: [
                StateSegment(startSeconds: 0, endSeconds: 40, state: .focused, confidence: 0.8),
                StateSegment(startSeconds: 40, endSeconds: 80, state: .away, confidence: 0.95)
            ]
        )

        let files = SessionSummaryXLSXExporter.packageFiles(
            for: session,
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let workbook = try SessionSummaryXLSXExporter.xlsx(
            for: session,
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let zipEntries = try storedZipEntries(in: workbook)
        let worksheet = try XCTUnwrap(files.first { $0.path == "xl/worksheets/sheet1.xml" })
        let styles = try XCTUnwrap(files.first { $0.path == "xl/styles.xml" })
        let worksheetXML = String(decoding: worksheet.data, as: UTF8.self)
        let stylesXML = String(decoding: styles.data, as: UTF8.self)

        XCTAssertEqual(Set(files.map(\.path)), [
            "[Content_Types].xml",
            "_rels/.rels",
            "xl/workbook.xml",
            "xl/_rels/workbook.xml.rels",
            "xl/styles.xml",
            "xl/worksheets/sheet1.xml"
        ])
        XCTAssertEqual(Set(zipEntries.keys), Set(files.map(\.path)))
        XCTAssertEqual(Array(workbook.prefix(2)), [0x50, 0x4B])
        XCTAssertEqual(String(decoding: try XCTUnwrap(zipEntries["xl/worksheets/sheet1.xml"]), as: UTF8.self), worksheetXML)
        XCTAssertTrue(worksheetXML.contains("FocusMirror Session Summary"))
        XCTAssertTrue(worksheetXML.contains("Activity Breakdown"))
        XCTAssertFalse(worksheetXML.contains("Focus Summary"))
        XCTAssertTrue(worksheetXML.contains("Percent Of Session"))
        XCTAssertTrue(worksheetXML.contains("1m 20s"))
        XCTAssertTrue(worksheetXML.contains("<col min=\"1\" max=\"1\" width=\"28\" customWidth=\"1\"/>"))
        XCTAssertTrue(stylesXML.contains("formatCode=\"0.0%\""))
        XCTAssertTrue(stylesXML.contains("formatCode=\"[m]:ss\""))
        XCTAssertTrue(stylesXML.contains("formatCode=\"mmm d, yyyy, h:mm AM/PM\""))
        XCTAssertTrue(worksheetXML.contains("s=\"6\"><v>80</v>"))
        XCTAssertTrue(worksheetXML.contains("s=\"7\"><v>1</v>"))
        XCTAssertTrue(worksheetXML.contains("s=\"7\"><v>0.5</v>"))
        XCTAssertTrue(worksheetXML.contains("s=\"8\"><v>25569"))
        XCTAssertTrue(worksheetXML.contains("s=\"9\"><v>0.000462962963</v>"))
        XCTAssertFalse(worksheetXML.contains("<t>80</t>"))
        XCTAssertFalse(worksheetXML.contains("<t>50.0%</t>"))
        XCTAssertFalse(worksheetXML.contains("User Correction"))
    }

    func testLifetimeSummaryXLSXUsesLifetimeTotalsOnly() throws {
        let firstSession = FocusSession(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10 * 60),
            targetDurationSeconds: 10 * 60,
            completionReason: .targetCompleted,
            segments: [
                StateSegment(startSeconds: 0, endSeconds: 5 * 60, state: .focused, confidence: 0.9),
                StateSegment(startSeconds: 5 * 60, endSeconds: 10 * 60, state: .away, confidence: 0.8)
            ]
        )
        let secondSession = FocusSession(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            startTime: Date(timeIntervalSince1970: 86_400),
            endTime: Date(timeIntervalSince1970: 86_400 + (20 * 60)),
            targetDurationSeconds: nil,
            completionReason: .manual,
            segments: [
                StateSegment(startSeconds: 0, endSeconds: 10 * 60, state: .focused, confidence: 0.95),
                StateSegment(
                    startSeconds: 10 * 60,
                    endSeconds: 15 * 60,
                    state: .lookingDown,
                    confidence: 0.75,
                    userCorrection: .actuallyFocused
                ),
                StateSegment(startSeconds: 15 * 60, endSeconds: 20 * 60, state: .uncertain, confidence: 0.5)
            ]
        )

        let files = LifetimeSummaryXLSXExporter.packageFiles(
            for: [secondSession, firstSession],
            generatedAt: Date(timeIntervalSince1970: 172_800),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let workbook = try LifetimeSummaryXLSXExporter.xlsx(
            for: [secondSession, firstSession],
            generatedAt: Date(timeIntervalSince1970: 172_800),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let zipEntries = try storedZipEntries(in: workbook)
        let worksheet = try XCTUnwrap(files.first { $0.path == "xl/worksheets/sheet1.xml" })
        let workbookXML = try XCTUnwrap(files.first { $0.path == "xl/workbook.xml" })
        let worksheetXML = String(decoding: worksheet.data, as: UTF8.self)

        XCTAssertEqual(Set(files.map(\.path)), [
            "[Content_Types].xml",
            "_rels/.rels",
            "xl/workbook.xml",
            "xl/_rels/workbook.xml.rels",
            "xl/styles.xml",
            "xl/worksheets/sheet1.xml"
        ])
        XCTAssertEqual(Set(zipEntries.keys), Set(files.map(\.path)))
        XCTAssertEqual(
            String(decoding: try XCTUnwrap(zipEntries["xl/worksheets/sheet1.xml"]), as: UTF8.self),
            worksheetXML
        )
        XCTAssertTrue(String(decoding: workbookXML.data, as: UTF8.self).contains("Lifetime Summary"))
        XCTAssertTrue(worksheetXML.contains("FocusMirror Lifetime Summary"))
        XCTAssertTrue(worksheetXML.contains("Lifetime"))
        XCTAssertTrue(worksheetXML.contains("Activity Breakdown"))
        XCTAssertTrue(worksheetXML.contains("Percent Of Lifetime"))
        XCTAssertTrue(worksheetXML.contains("Session Count"))
        XCTAssertTrue(worksheetXML.contains("First Session"))
        XCTAssertTrue(worksheetXML.contains("Latest Session"))
        XCTAssertTrue(worksheetXML.contains("Total Recorded Time"))
        XCTAssertTrue(worksheetXML.contains("Average Session Length"))
        XCTAssertTrue(worksheetXML.contains("30m"))
        XCTAssertTrue(worksheetXML.contains("15m"))
        XCTAssertTrue(worksheetXML.contains("Focused"))
        XCTAssertTrue(worksheetXML.contains("Looking Down"))
        XCTAssertTrue(worksheetXML.contains("Away From Screen"))
        XCTAssertTrue(worksheetXML.contains("Uncertain"))
        XCTAssertTrue(worksheetXML.contains("s=\"6\"><v>1800</v>"))
        XCTAssertTrue(worksheetXML.contains("s=\"6\"><v>900</v>"))
        XCTAssertTrue(worksheetXML.contains("s=\"7\"><v>1</v>"))
        XCTAssertTrue(worksheetXML.contains("s=\"7\"><v>0.5</v>"))
        XCTAssertTrue(worksheetXML.contains("s=\"8\"><v>25569"))
        XCTAssertFalse(worksheetXML.contains("Timeline"))
        XCTAssertFalse(worksheetXML.contains("Segment"))
        XCTAssertFalse(worksheetXML.contains("Actually focused work"))
    }

    func testLifetimeSummaryXLSXHandlesEmptyHistory() throws {
        let files = LifetimeSummaryXLSXExporter.packageFiles(
            for: [],
            generatedAt: Date(timeIntervalSince1970: 0),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let worksheet = try XCTUnwrap(files.first { $0.path == "xl/worksheets/sheet1.xml" })
        let worksheetXML = String(decoding: worksheet.data, as: UTF8.self)

        XCTAssertTrue(worksheetXML.contains("FocusMirror Lifetime Summary"))
        XCTAssertTrue(worksheetXML.contains("No sessions recorded"))
        XCTAssertTrue(worksheetXML.contains("Session Count"))
        XCTAssertTrue(worksheetXML.contains("Total Recorded Time"))
        XCTAssertTrue(worksheetXML.contains("Average Session Length"))
        XCTAssertTrue(worksheetXML.contains("Focused"))
        XCTAssertFalse(worksheetXML.contains("Timeline"))
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

private enum TestZipReadError: Error {
    case invalidHeader
    case unsupportedCompression
}

private func storedZipEntries(in data: Data) throws -> [String: Data] {
    let bytes = Array(data)
    var offset = 0
    var entries: [String: Data] = [:]

    while offset + 4 <= bytes.count {
        let signature = uint32LE(bytes, offset)
        if signature == 0x0201_4B50 || signature == 0x0605_4B50 {
            break
        }
        guard signature == 0x0403_4B50, offset + 30 <= bytes.count else {
            throw TestZipReadError.invalidHeader
        }

        let method = uint16LE(bytes, offset + 8)
        guard method == 0 else {
            throw TestZipReadError.unsupportedCompression
        }

        let compressedSize = Int(uint32LE(bytes, offset + 18))
        let filenameLength = Int(uint16LE(bytes, offset + 26))
        let extraLength = Int(uint16LE(bytes, offset + 28))
        let filenameStart = offset + 30
        let dataStart = filenameStart + filenameLength + extraLength
        let dataEnd = dataStart + compressedSize
        guard dataEnd <= bytes.count else {
            throw TestZipReadError.invalidHeader
        }

        let filename = String(decoding: bytes[filenameStart..<(filenameStart + filenameLength)], as: UTF8.self)
        entries[filename] = Data(bytes[dataStart..<dataEnd])
        offset = dataEnd
    }

    return entries
}

private func uint16LE(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

private func uint32LE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
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
