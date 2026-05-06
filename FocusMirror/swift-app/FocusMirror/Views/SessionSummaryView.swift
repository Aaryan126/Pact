import SwiftUI

struct SessionSummaryView: View {
    @Environment(AppModel.self) private var model
    let sessionID: UUID
    let onBack: () -> Void

    private var session: FocusSession? {
        model.session(with: sessionID) ?? model.latestCompletedSession
    }

    var body: some View {
        Group {
            if let session {
                VStack(alignment: .leading, spacing: 10) {
                    SummaryHeader(session: session, onBack: onBack)
                        .frame(height: 56)

                    HStack(spacing: 12) {
                        SummaryStatCard(
                            title: "Screen Focus",
                            value: formatMinutes(session.screenFocusedSeconds),
                            suffix: "of \(formatMinutes(session.duration))",
                            detail: "Screen-facing time before corrections",
                            accent: SummaryPalette.green,
                            systemImage: "scope"
                        )

                        SummaryStatCard(
                            title: "Confirmed Work",
                            value: formatMinutes(session.confirmedWorkSeconds),
                            suffix: nil,
                            detail: session.correctedSeconds > 0 ? "+\(formatMinutes(session.correctedSeconds)) corrected" : "No corrections",
                            accent: SummaryPalette.purple,
                            systemImage: "checkmark.circle"
                        )

                        SummaryStatCard(
                            title: "Reviewable",
                            value: formatMinutes(session.reviewSeconds),
                            suffix: nil,
                            detail: "Head down or uncertain",
                            accent: SummaryPalette.orange,
                            systemImage: "person.crop.circle"
                        )
                    }
                    .frame(height: 84)

                    TimelinePanel(session: session)
                        .frame(height: 66)

                    HStack(alignment: .top, spacing: 12) {
                        BreakdownPanel(session: session)
                            .frame(width: 315, height: 154)

                        SegmentReviewPanel(session: session)
                            .frame(maxWidth: .infinity, minHeight: 154, maxHeight: 154)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(HomeTheme.windowBackground.ignoresSafeArea())
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(HomeTheme.secondaryText)
                    Text("Session not found")
                        .font(.system(size: 20, weight: .semibold))
                    Button("Back") {
                        onBack()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HomeTheme.windowBackground.ignoresSafeArea())
            }
        }
    }
}

private struct SummaryHeader: View {
    let session: FocusSession
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.055))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("Session Summary")
                    .font(.system(size: 19, weight: .semibold))
                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
            }

            Spacer()

            FocusBadge(session: session)
                .frame(width: 190, height: 52)
        }
    }
}

private struct FocusBadge: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 10) {
            ProgressRing(progress: session.screenFocusedRatio)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text("Screen Focus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Before corrections")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
            }

            Spacer(minLength: 4)

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HomeTheme.primaryBlue)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .dashboardCard(tint: HomeTheme.primaryBlue, padding: 0)
    }
}

private struct ProgressRing: View {
    let progress: Double

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(HomeTheme.primaryBlue.opacity(0.22), lineWidth: 4)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(HomeTheme.primaryBlueGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(summaryPercent(progress))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(HomeTheme.primaryBlue)
        }
        .padding(2)
    }
}

private struct SummaryStatCard: View {
    let title: String
    let value: String
    let suffix: String?
    let detail: String
    let accent: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                Circle()
                    .stroke(accent.opacity(0.45), lineWidth: 1)
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if let suffix {
                        Text(suffix)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HomeTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }

                Text(detail)
                    .font(.system(size: 11.8, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .dashboardCard(tint: accent)
    }
}

private struct TimelinePanel: View {
    let session: FocusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(formatClock(session.duration))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .monospacedDigit()
            }

            TimelineBar(session: session)
                .frame(height: 15)
        }
        .dashboardCard(tint: Color.white.opacity(0.12), padding: 13)
    }
}

private struct TimelineBar: View {
    let session: FocusSession

    var body: some View {
        GeometryReader { geometry in
            if session.segments.isEmpty {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Text("No classifications")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(HomeTheme.secondaryText)
                            .padding(.leading, 8)
                    }
            } else {
                HStack(spacing: 1) {
                    ForEach(session.segments) { segment in
                        Rectangle()
                            .fill(segment.state.summaryColor)
                            .frame(width: max(2, geometry.size.width * segment.duration / max(session.duration, 1)))
                            .overlay(alignment: .bottom) {
                                if segment.userCorrection == .actuallyFocused {
                                    Rectangle()
                                        .fill(SummaryPalette.green)
                                        .frame(height: 3)
                                }
                            }
                            .help(timelineHelp(for: segment))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
            }
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

private struct BreakdownPanel: View {
    let session: FocusSession

    private var rows: [(state: DetectionState, value: (count: Int, seconds: TimeInterval))] {
        let breakdown = session.breakdown()
        return DetectionState.allCases.map { state in
            (state, breakdown[state] ?? (0, 0))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Breakdown")
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 4) {
                ForEach(rows, id: \.state.id) { row in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(row.state.summaryColor)
                            .frame(width: 9, height: 9)
                        Text(row.state.label)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(row.value.count)x")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HomeTheme.secondaryText)
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                        Text(formatMinutes(row.value.seconds))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HomeTheme.secondaryText)
                            .frame(width: 66, alignment: .trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .padding(.vertical, 2)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.white.opacity(0.055))
                            .frame(height: 1)
                            .opacity(row.state == DetectionState.allCases.last ? 0 : 1)
                    }
                }
            }
        }
        .dashboardCard(tint: Color.white.opacity(0.12), padding: 13)
    }
}

private struct SegmentReviewPanel: View {
    @Environment(AppModel.self) private var model
    let session: FocusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Segments")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(formatMinutes(session.correctedSeconds)) corrected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
            }

            if session.segments.isEmpty {
                Text("No classified segments for this session.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(session.segments) { segment in
                            segmentRow(segment)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .dashboardCard(tint: Color.white.opacity(0.12), padding: 13)
    }

    private func segmentRow(_ segment: StateSegment) -> some View {
        let isAlreadyFocused = segment.state == .focused || segment.userCorrection == .actuallyFocused

        return HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 3)
                .fill(segment.effectiveState.summaryColor)
                .frame(width: 5, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(formatClock(segment.startSeconds))-\(formatClock(segment.endSeconds))")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()

                HStack(spacing: 7) {
                    Text(segment.state.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                        .lineLimit(1)

                    Text("\(Int(segment.confidence * 100))%")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(segment.state.summaryColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(segment.state.summaryColor.opacity(0.16))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Button {
                let correction: SegmentCorrection? = segment.userCorrection == .actuallyFocused ? nil : .actuallyFocused
                model.update(segmentID: segment.id, in: session.id, correction: correction)
            } label: {
                Text(segment.userCorrection == .actuallyFocused ? "Undo" : "Focused")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 58, height: 27)
                    .contentShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(isAlreadyFocused ? SummaryPalette.green : HomeTheme.primaryBlue)
            .background((isAlreadyFocused ? SummaryPalette.green : HomeTheme.primaryBlue).opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .disabled(segment.state == .focused && segment.userCorrection != .actuallyFocused)
            .opacity(segment.state == .focused && segment.userCorrection != .actuallyFocused ? 0.95 : 1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SummaryPalette {
    static let green = Color(red: 0.10, green: 0.84, blue: 0.38)
    static let red = Color(red: 0.92, green: 0.20, blue: 0.25)
    static let orange = Color(red: 1.00, green: 0.49, blue: 0.16)
    static let blue = Color(red: 0.12, green: 0.38, blue: 0.92)
    static let purple = Color(red: 0.58, green: 0.25, blue: 0.95)
    static let gray = Color(red: 0.42, green: 0.49, blue: 0.55)
}

private extension DetectionState {
    var summaryColor: Color {
        switch self {
        case .focused: SummaryPalette.green
        case .away: SummaryPalette.red
        case .lookingDown: SummaryPalette.orange
        case .talking: SummaryPalette.blue
        case .eyesClosed: SummaryPalette.purple
        case .uncertain: SummaryPalette.gray
        }
    }
}

private extension View {
    func dashboardCard(tint: Color, padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                LinearGradient(
                    colors: [
                        tint.opacity(0.14),
                        Color.white.opacity(0.045)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            }
    }
}

private func summaryPercent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}
