import SwiftUI

enum DetectionState: String, Codable, CaseIterable, Identifiable {
    case focused
    case away
    case lookingDown = "looking_down"
    case talking
    case eyesClosed = "eyes_closed"
    case uncertain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .focused: "Focused"
        case .away: "Away"
        case .lookingDown: "Looking down"
        case .talking: "Talking"
        case .eyesClosed: "Eyes closed"
        case .uncertain: "Uncertain"
        }
    }

    var color: Color {
        switch self {
        case .focused: Color(red: 0.12, green: 0.46, blue: 0.29)
        case .away: Color(red: 0.62, green: 0.15, blue: 0.18)
        case .lookingDown: Color(red: 0.76, green: 0.46, blue: 0.12)
        case .talking: Color(red: 0.28, green: 0.32, blue: 0.66)
        case .eyesClosed: Color(red: 0.40, green: 0.28, blue: 0.55)
        case .uncertain: Color(red: 0.42, green: 0.45, blue: 0.48)
        }
    }

    var countsAsFocused: Bool {
        self == .focused
    }
}
