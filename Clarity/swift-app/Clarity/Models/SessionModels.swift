import Foundation

struct StateSegment: Codable, Identifiable, Equatable {
    var id: UUID
    var startSeconds: TimeInterval
    var endSeconds: TimeInterval
    var state: DetectionState
    var confidence: Double
    var userCorrection: SegmentCorrection?

    init(
        id: UUID = UUID(),
        startSeconds: TimeInterval,
        endSeconds: TimeInterval,
        state: DetectionState,
        confidence: Double,
        userCorrection: SegmentCorrection? = nil
    ) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.state = state
        self.confidence = confidence
        self.userCorrection = userCorrection
    }

    var duration: TimeInterval {
        max(0, endSeconds - startSeconds)
    }

    var effectiveState: DetectionState {
        switch userCorrection {
        case .actuallyFocused: .focused
        case .none: state
        }
    }

    var countsAsConfirmedWork: Bool {
        state.countsAsFocused || userCorrection == .actuallyFocused
    }
}

enum SessionCompletionReason: String, Codable, Equatable {
    case manual
    case targetCompleted = "target_completed"
}

enum SegmentCorrection: String, Codable, CaseIterable, Identifiable {
    case actuallyFocused = "actually_focused"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .actuallyFocused: "Actually focused work"
        }
    }
}

struct FocusSession: Codable, Identifiable, Equatable {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var targetDurationSeconds: TimeInterval?
    var completionReason: SessionCompletionReason?
    var segments: [StateSegment]

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        targetDurationSeconds: TimeInterval?,
        completionReason: SessionCompletionReason? = nil,
        segments: [StateSegment]
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.targetDurationSeconds = targetDurationSeconds
        self.completionReason = completionReason
        self.segments = segments
    }

    var duration: TimeInterval {
        max(endTime.timeIntervalSince(startTime), segments.map(\.endSeconds).max() ?? 0)
    }

    var screenFocusedSeconds: TimeInterval {
        segments.reduce(0) { total, segment in
            total + (segment.state.countsAsFocused ? segment.duration : 0)
        }
    }

    var confirmedWorkSeconds: TimeInterval {
        segments.reduce(0) { total, segment in
            total + (segment.countsAsConfirmedWork ? segment.duration : 0)
        }
    }

    var correctedSeconds: TimeInterval {
        segments.reduce(0) { total, segment in
            total + (segment.userCorrection == .actuallyFocused ? segment.duration : 0)
        }
    }

    var reviewSeconds: TimeInterval {
        segments.reduce(0) { total, segment in
            switch segment.state {
            case .lookingDown, .uncertain:
                total + segment.duration
            case .focused, .away, .talking, .eyesClosed:
                total
            }
        }
    }

    var screenFocusedRatio: Double {
        guard duration > 0 else { return 0 }
        return screenFocusedSeconds / duration
    }

    var confirmedWorkRatio: Double {
        guard duration > 0 else { return 0 }
        return confirmedWorkSeconds / duration
    }

    var focusedSeconds: TimeInterval {
        confirmedWorkSeconds
    }

    var focusedRatio: Double {
        confirmedWorkRatio
    }

    func breakdown() -> [DetectionState: (count: Int, seconds: TimeInterval)] {
        var result: [DetectionState: (count: Int, seconds: TimeInterval)] = [:]
        for state in DetectionState.allCases {
            result[state] = (0, 0)
        }
        for segment in segments {
            let current = result[segment.state] ?? (0, 0)
            result[segment.state] = (current.count + 1, current.seconds + segment.duration)
        }
        return result
    }

    var detectedStateSummaries: [FocusSessionStateSummary] {
        let breakdown = breakdown()
        return DetectionState.allCases.map { state in
            let value = breakdown[state] ?? (0, 0)
            return FocusSessionStateSummary(
                state: state,
                count: value.count,
                seconds: value.seconds,
                totalSeconds: duration
            )
        }
    }

    func detectedSummary(for state: DetectionState) -> FocusSessionStateSummary {
        detectedStateSummaries.first { $0.state == state } ?? FocusSessionStateSummary(
            state: state,
            count: 0,
            seconds: 0,
            totalSeconds: duration
        )
    }
}

struct FocusSessionStateSummary: Identifiable, Equatable {
    let state: DetectionState
    let count: Int
    let seconds: TimeInterval
    let totalSeconds: TimeInterval

    var id: String { state.id }

    var ratio: Double {
        guard totalSeconds > 0 else { return 0 }
        return seconds / totalSeconds
    }
}

struct EngineEvent: Decodable {
    let type: String
    let elapsedSeconds: TimeInterval
    let state: DetectionState
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case type
        case elapsedSeconds = "elapsed_seconds"
        case state
        case confidence
    }
}

enum SessionLength: Hashable, CaseIterable, Identifiable {
    case openEnded
    case minutes(Int)

    static var allCases: [SessionLength] {
        [.openEnded, .minutes(25), .minutes(30), .minutes(50), .minutes(60)]
    }

    var id: String {
        switch self {
        case .openEnded: "open"
        case .minutes(let value): "\(value)"
        }
    }

    var label: String {
        switch self {
        case .openEnded: "Open"
        case .minutes(let value): "\(value)m"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .openEnded: nil
        case .minutes(let value): TimeInterval(value * 60)
        }
    }
}
