import Foundation

func formatClock(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}

func formatMinutes(_ seconds: TimeInterval) -> String {
    let minutes = Int((seconds / 60).rounded())
    if minutes == 1 {
        return "1 minute"
    }
    return "\(minutes) minutes"
}

func formatCompactDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let remainingSeconds = total % 60

    if hours > 0 {
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    if minutes > 0 {
        return "\(minutes)m"
    }
    return "\(remainingSeconds)s"
}

func formatWholePercent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

func formatSessionDateRange(start: Date, end: Date) -> String {
    let calendar = Calendar.current
    let dateLabel: String
    if calendar.isDateInToday(start) {
        dateLabel = "Today"
    } else if calendar.isDateInYesterday(start) {
        dateLabel = "Yesterday"
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateLabel = dateFormatter.string(from: start)
    }

    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale.current
    timeFormatter.dateStyle = .none
    timeFormatter.timeStyle = .short

    return "\(dateLabel) · \(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))"
}
