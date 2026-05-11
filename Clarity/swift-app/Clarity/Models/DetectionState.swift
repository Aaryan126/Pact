import SwiftUI

enum DetectionState: String, Codable, CaseIterable, Identifiable {
    case focused
    case lookingDown = "looking_down"
    case away
    case talking
    case eyesClosed = "eyes_closed"
    case uncertain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .focused: "Focused"
        case .lookingDown: "Looking Down"
        case .away: "Away From Screen"
        case .talking: "Talking"
        case .eyesClosed: "Eyes Closed"
        case .uncertain: "Uncertain"
        }
    }

    var color: Color {
        switch self {
        case .focused: Color(red: 0.24, green: 0.64, blue: 0.30)
        case .lookingDown: Color(red: 0.24, green: 0.42, blue: 0.86)
        case .away: Color(red: 0.53, green: 0.32, blue: 0.82)
        case .talking: Color(red: 0.98, green: 0.52, blue: 0.16)
        case .eyesClosed: Color(red: 0.92, green: 0.25, blue: 0.45)
        case .uncertain: Color(red: 0.58, green: 0.60, blue: 0.62)
        }
    }

    var countsAsFocused: Bool {
        self == .focused
    }
}
