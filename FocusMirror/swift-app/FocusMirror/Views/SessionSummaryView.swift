import SwiftUI

struct SessionSummaryView: View {
    @Environment(AppModel.self) private var model
    let sessionID: UUID

    private var session: FocusSession? {
        model.session(with: sessionID) ?? model.latestCompletedSession
    }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headline(for: session)
                        SummaryMetrics(session: session)
                        TimelineBar(session: session)
                            .frame(height: 42)
                        BreakdownView(session: session)
                        CorrectionList(session: session)
                    }
                    .padding(36)
                    .frame(maxWidth: 980, alignment: .leading)
                }
            } else {
                ContentUnavailableView("Session not found", systemImage: "clock.badge.questionmark")
            }
        }
        .navigationTitle("Session summary")
    }

    private func headline(for session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focused on screen for \(formatMinutes(session.screenFocusedSeconds)) out of \(formatMinutes(session.duration)).")
                .font(.system(size: 36, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Confirmed work: \(formatMinutes(session.confirmedWorkSeconds))")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text(session.startTime.formatted(date: .complete, time: .shortened))
                .foregroundStyle(.secondary)
        }
    }
}

private struct SummaryMetrics: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            MetricTile(
                title: "Screen focus",
                value: formatMinutes(session.screenFocusedSeconds),
                detail: "\(Int((session.screenFocusedRatio * 100).rounded()))% of session"
            )
            MetricTile(
                title: "Confirmed work",
                value: formatMinutes(session.confirmedWorkSeconds),
                detail: session.correctedSeconds > 0 ? "+\(formatMinutes(session.correctedSeconds)) corrected" : "No corrections"
            )
            MetricTile(
                title: "Reviewable",
                value: formatMinutes(session.reviewSeconds),
                detail: "Head down or uncertain"
            )
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct TimelineBar: View {
    let session: FocusSession

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(session.segments) { segment in
                    Rectangle()
                        .fill(segment.state.color)
                        .frame(width: max(2, geometry.size.width * segment.duration / max(session.duration, 1)))
                        .overlay(alignment: .bottom) {
                            if segment.userCorrection == .actuallyFocused {
                                Rectangle()
                                    .fill(DetectionState.focused.color)
                                    .frame(height: 5)
                            }
                        }
                        .help(timelineHelp(for: segment))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .accessibilityLabel("Session timeline")
    }

    private func timelineHelp(for segment: StateSegment) -> String {
        var parts = [segment.state.label, formatMinutes(segment.duration)]
        if let correction = segment.userCorrection {
            parts.append(correction.label)
        }
        return parts.joined(separator: ", ")
    }
}

private struct BreakdownView: View {
    let session: FocusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breakdown")
                .font(.title2.weight(.semibold))
            Text("Observed states before corrections.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                ForEach(DetectionState.allCases) { state in
                    let value = session.breakdown()[state] ?? (0, 0)
                    GridRow {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(state.color)
                                .frame(width: 10, height: 10)
                            Text(state.label)
                        }
                        Text("\(value.count) \(value.count == 1 ? "time" : "times")")
                            .foregroundStyle(.secondary)
                        Text(formatMinutes(value.seconds))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct CorrectionList: View {
    @Environment(AppModel.self) private var model
    let session: FocusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Segments")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("\(formatMinutes(session.correctedSeconds)) corrected")
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(session.segments) { segment in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(formatClock(segment.startSeconds)) to \(formatClock(segment.endSeconds))")
                                .font(.headline)
                            Text("\(segment.state.label), confidence \(Int(segment.confidence * 100))%")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            if let correction = segment.userCorrection {
                                Text(correction.label)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(DetectionState.focused.color)
                            }
                        }
                        Spacer()
                        if segment.userCorrection == .actuallyFocused {
                            Button("Remove correction") {
                                model.update(segmentID: segment.id, in: session.id, correction: nil)
                            }
                        } else {
                            Button("Mark as focused work") {
                                model.update(segmentID: segment.id, in: session.id, correction: .actuallyFocused)
                            }
                            .disabled(segment.state == .focused)
                        }
                    }
                    .padding(.vertical, 12)
                    Divider()
                }
            }
        }
    }
}
