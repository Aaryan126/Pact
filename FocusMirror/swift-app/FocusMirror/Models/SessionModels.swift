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
}

enum SegmentCorrection: String, Codable, CaseIterable, Identifiable {
    case actuallyFocused = "actually_focused"

    var id: String { rawValue }
}

struct FocusSession: Codable, Identifiable, Equatable {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var targetDurationSeconds: TimeInterval?
    var segments: [StateSegment]

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        targetDurationSeconds: TimeInterval?,
        segments: [StateSegment]
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.targetDurationSeconds = targetDurationSeconds
        self.segments = segments
    }

    var duration: TimeInterval {
        max(endTime.timeIntervalSince(startTime), segments.map(\.endSeconds).max() ?? 0)
    }

    var focusedSeconds: TimeInterval {
        segments.reduce(0) { total, segment in
            total + (segment.effectiveState.countsAsFocused ? segment.duration : 0)
        }
    }

    var focusedRatio: Double {
        guard duration > 0 else { return 0 }
        return focusedSeconds / duration
    }

    func breakdown() -> [DetectionState: (count: Int, seconds: TimeInterval)] {
        var result: [DetectionState: (count: Int, seconds: TimeInterval)] = [:]
        for state in DetectionState.allCases {
            result[state] = (0, 0)
        }
        for segment in segments {
            let state = segment.effectiveState
            let current = result[state] ?? (0, 0)
            result[state] = (current.count + 1, current.seconds + segment.duration)
        }
        return result
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
        [.openEnded, .minutes(25), .minutes(50), .minutes(60)]
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
