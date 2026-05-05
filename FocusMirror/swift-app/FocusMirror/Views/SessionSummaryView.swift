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
            Text("You worked \(formatMinutes(session.focusedSeconds)) out of \(formatMinutes(session.duration)).")
                .font(.system(size: 36, weight: .semibold))
            Text(session.startTime.formatted(date: .complete, time: .shortened))
                .foregroundStyle(.secondary)
        }
    }
}

private struct TimelineBar: View {
    let session: FocusSession

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(session.segments) { segment in
                    Rectangle()
                        .fill(segment.effectiveState.color)
                        .frame(width: max(2, geometry.size.width * segment.duration / max(session.duration, 1)))
                        .help("\(segment.effectiveState.label), \(formatMinutes(segment.duration))")
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
}

private struct BreakdownView: View {
    let session: FocusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breakdown")
                .font(.title2.weight(.semibold))
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
            Text("Segments")
                .font(.title2.weight(.semibold))
            VStack(spacing: 0) {
                ForEach(session.segments) { segment in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(formatClock(segment.startSeconds)) to \(formatClock(segment.endSeconds))")
                                .font(.headline)
                            Text("\(segment.state.label), confidence \(Int(segment.confidence * 100))%")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Spacer()
                        if segment.userCorrection == .actuallyFocused {
                            Button("Remove correction") {
                                model.update(segmentID: segment.id, in: session.id, correction: nil)
                            }
                        } else {
                            Button("Mark actually focused") {
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
