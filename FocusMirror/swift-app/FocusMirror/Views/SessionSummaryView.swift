import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SessionSummaryView: View {
    @Environment(AppModel.self) private var model
    @State private var exportErrorMessage: String?

    let sessionID: UUID
    let onBack: () -> Void

    private var session: FocusSession? {
        model.session(with: sessionID) ?? model.latestCompletedSession
    }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SummaryReferenceHeader(
                            session: session,
                            onHome: onBack,
                            onExport: { exportCSV(for: session) }
                        )

                        SummaryMetricGrid(session: session)
                            .frame(height: 168)
                            .padding(.top, 22)

                        ActivityBreakdownPanel(session: session)
                            .frame(minHeight: 278)

                        SessionTimelinePanel(session: session)
                            .frame(minHeight: 158)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(HomeTheme.windowBackground.ignoresSafeArea())
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(HomeTheme.secondaryText)
                    Text("Session not found")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(HomeTheme.primaryText)
                    Button("Back") {
                        onBack()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HomeTheme.windowBackground.ignoresSafeArea())
            }
        }
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "Unable to write the CSV file.")
        }
    }

    private func exportCSV(for session: FocusSession) {
        let panel = NSSavePanel()
        panel.title = "Export Session Summary"
        panel.prompt = "Export"
        panel.nameFieldStringValue = defaultExportFilename(for: session)
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let csv = SessionSummaryCSVExporter.csv(for: session)
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportErrorMessage = "Could not export session CSV: \(error.localizedDescription)"
        }
    }

    private func defaultExportFilename(for session: FocusSession) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "FocusMirror Session \(formatter.string(from: session.startTime)).csv"
    }
}

private func sessionCompletionReasonLabel(_ session: FocusSession) -> String {
    switch session.completionReason {
    case .targetCompleted:
        return "Target completed"
    case .manual:
        return "Ended manually"
    case .none:
        return "Unknown"
    }
}

private func durationSortedSummaries(_ summaries: [FocusSessionStateSummary]) -> [FocusSessionStateSummary] {
    summaries.sorted { lhs, rhs in
        if lhs.seconds != rhs.seconds {
            return lhs.seconds > rhs.seconds
        }
        return statePresentationIndex(lhs.state) < statePresentationIndex(rhs.state)
    }
}

private func statePresentationIndex(_ state: DetectionState) -> Int {
    DetectionState.allCases.firstIndex(of: state) ?? Int.max
}

private struct SummaryReferenceHeader: View {
    let session: FocusSession
    let onHome: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Summary")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(HomeTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(formatSessionDateRange(start: session.startTime, end: session.endTime))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 22) {
                Text("Total session duration")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .frame(height: 64, alignment: .center)
                Text(formatCompactDuration(session.duration))
                    .font(.system(size: 36, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(HomeTheme.primaryText)
                    .frame(height: 64, alignment: .center)

                SummaryHeaderControlButtons(onHome: onHome, onExport: onExport)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct SummaryHeaderControlButtons: View {
    let onHome: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SummaryHeaderIconButton(systemName: "house", help: "Home", action: onHome)

            Rectangle()
                .fill(HomeTheme.controlStroke)
                .frame(width: 1, height: 56)

            SummaryHeaderIconButton(
                systemName: "square.and.arrow.down",
                help: "Export session summary as CSV",
                action: onExport
            )
        }
        .frame(width: 148, height: 64)
        .background(HomeTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(HomeTheme.controlStroke, lineWidth: 1)
        }
    }
}

private struct SummaryHeaderIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(HomeTheme.primaryText)
                .frame(width: 73.5, height: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct SummaryMetricGrid: View {
    let session: FocusSession

    private var secondarySummaries: [FocusSessionStateSummary] {
        Array(
            durationSortedSummaries(
                session.detectedStateSummaries.filter { $0.state != .focused }
            )
            .prefix(2)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 18
            let availableWidth = geometry.size.width
            let preferredFocusedWidth = availableWidth * 0.44
            let minimumSecondaryWidth: CGFloat = 250
            let focusedWidth = min(
                max(preferredFocusedWidth, 420),
                max(360, availableWidth - (minimumSecondaryWidth * 2) - (spacing * 2))
            )
            let secondaryWidth = max(
                minimumSecondaryWidth,
                (availableWidth - focusedWidth - (spacing * 2)) / 2
            )

            HStack(alignment: .top, spacing: spacing) {
                FocusedWorkCard(
                    summary: session.detectedSummary(for: .focused),
                    width: focusedWidth,
                    height: geometry.size.height
                )

                ForEach(secondarySummaries) { summary in
                    SecondaryMetricCard(
                        summary: summary,
                        width: secondaryWidth,
                        height: geometry.size.height
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }
}

private struct FocusedWorkCard: View {
    let summary: FocusSessionStateSummary
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 42) {
            ZStack {
                Circle()
                    .fill(summary.state.color.opacity(0.13))
                Image(systemName: "scope")
                    .font(.system(size: 50, weight: .regular))
                    .foregroundStyle(summary.state.color)
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 12) {
                Text("Focused Work")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(summary.state.color)
                    .lineLimit(1)

                Text(formatCompactDuration(summary.seconds))
                    .font(.system(size: 42, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(HomeTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .frame(width: width, height: height, alignment: .leading)
        .summaryCard(stroke: summary.state.color.opacity(0.34), fill: summary.state.color.opacity(0.045))
    }
}

private struct SecondaryMetricCard: View {
    let summary: FocusSessionStateSummary
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(summary.state.label)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(summary.state.color)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(formatCompactDuration(summary.seconds))
                .font(.system(size: 38, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(HomeTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 42)
        .frame(width: width, height: height, alignment: .leading)
        .summaryCard(stroke: HomeTheme.border, fill: .clear)
    }
}

private struct ActivityBreakdownPanel: View {
    let session: FocusSession

    private var rows: [FocusSessionStateSummary] {
        durationSortedSummaries(session.detectedStateSummaries)
    }

    private var uncertainSummary: FocusSessionStateSummary {
        session.detectedSummary(for: .uncertain)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                ActivityBreakdownTable(rows: rows, uncertainSummary: uncertainSummary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                ActivityBreakdownChart(rows: rows)
                    .frame(width: 430)
            }

            VStack(alignment: .leading, spacing: 18) {
                ActivityBreakdownTable(rows: rows, uncertainSummary: uncertainSummary)
                ActivityBreakdownChart(rows: rows)
            }
        }
        .padding(24)
        .summaryCard(stroke: HomeTheme.border, fill: .clear)
    }
}

private struct ActivityBreakdownTable: View {
    let rows: [FocusSessionStateSummary]
    let uncertainSummary: FocusSessionStateSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Activity breakdown")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeTheme.primaryText)

                Spacer()

                Text("Uncertain: \(formatCompactDuration(uncertainSummary.seconds)) (\(formatWholePercent(uncertainSummary.ratio)))")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(HomeTheme.secondaryText)
            }

            StateDistributionBar(rows: rows)
                .frame(height: 22)

            VStack(spacing: 0) {
                HStack {
                    Text("State")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Duration")
                        .frame(width: 170, alignment: .leading)
                    Text("% of session")
                        .frame(width: 130, alignment: .trailing)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HomeTheme.secondaryText)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

                ForEach(rows) { row in
                    HStack {
                        Text(row.state.label)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(row.state.color)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(formatCompactDuration(row.seconds))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(HomeTheme.primaryText)
                            .monospacedDigit()
                            .frame(width: 170, alignment: .leading)

                        Text(formatWholePercent(row.ratio))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(HomeTheme.primaryText)
                            .monospacedDigit()
                            .frame(width: 130, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 29)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(HomeTheme.divider)
                            .frame(height: 1)
                            .opacity(row.id == rows.last?.id ? 0 : 1)
                    }
                }
            }
        }
    }
}

private struct ActivityBreakdownChart: View {
    let rows: [FocusSessionStateSummary]

    private let chartSize: CGFloat = 198
    private let legendWidth: CGFloat = 146
    private let contentSpacing: CGFloat = 46
    private let contentOffset: CGFloat = 18

    private var nonZeroRows: [FocusSessionStateSummary] {
        rows.filter { $0.seconds > 0 }
    }

    private var detailRows: [FocusSessionStateSummary] {
        Array(nonZeroRows.prefix(3))
    }

    var body: some View {
        HStack(alignment: .center, spacing: contentSpacing) {
            DonutChart(rows: nonZeroRows)
                .frame(width: chartSize, height: chartSize)

            legend
                .frame(width: legendWidth, alignment: .leading)
        }
        .offset(x: contentOffset)
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, minHeight: 282, alignment: .center)
        .background(HomeTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(HomeTheme.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var legend: some View {
        if detailRows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("0%")
                    .font(.system(size: 32, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(HomeTheme.secondaryText)
                Text("No activity recorded")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(detailRows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatWholePercent(row.ratio))
                            .font(.system(size: 30, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(row.state.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(chartLabel(for: row.state))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(HomeTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
        }
    }

    private func chartLabel(for state: DetectionState) -> String {
        state == .focused ? "Focused Work" : state.label
    }
}

private struct DonutChart: View {
    let rows: [FocusSessionStateSummary]

    private let lineWidth: CGFloat = 48

    private var totalSeconds: TimeInterval {
        rows.reduce(0) { $0 + $1.seconds }
    }

    private var segments: [DonutChartSegment] {
        guard totalSeconds > 0 else { return [] }

        var startRatio = 0.0
        return rows.map { row in
            let span = row.seconds / totalSeconds
            let segment = DonutChartSegment(
                id: row.id,
                color: row.state.color,
                startRatio: startRatio,
                endRatio: startRatio + span
            )
            startRatio += span
            return segment
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(HomeTheme.subtleBackground, lineWidth: lineWidth)

            if let onlySegment = segments.first, segments.count == 1 {
                Circle()
                    .stroke(onlySegment.color, lineWidth: lineWidth)
            } else {
                ForEach(segments) { segment in
                    DonutSlice(
                        startAngle: angle(for: segment.startRatio),
                        endAngle: angle(for: segment.endRatio),
                        lineWidth: lineWidth
                    )
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                }
            }
        }
        .accessibilityLabel("Activity breakdown chart")
    }

    private func angle(for ratio: Double) -> Angle {
        .degrees(-90 + (ratio * 360))
    }
}

private struct DonutChartSegment: Identifiable {
    let id: String
    let color: Color
    let startRatio: Double
    let endRatio: Double
}

private struct DonutSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = max(0, (min(rect.width, rect.height) - lineWidth) / 2)
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

private struct StateDistributionBar: View {
    let rows: [FocusSessionStateSummary]

    private var nonZeroRows: [FocusSessionStateSummary] {
        rows.filter { $0.seconds > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            if nonZeroRows.isEmpty {
                RoundedRectangle(cornerRadius: 4)
                    .fill(HomeTheme.subtleBackground)
            } else {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HomeTheme.subtleBackground)

                    HStack(spacing: 0) {
                        ForEach(nonZeroRows) { row in
                            Rectangle()
                                .fill(row.state.color)
                                .frame(width: segmentWidth(row, totalWidth: geometry.size.width))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(HomeTheme.border, lineWidth: 1)
                }
            }
        }
        .accessibilityLabel("Activity breakdown")
    }

    private func segmentWidth(_ row: FocusSessionStateSummary, totalWidth: CGFloat) -> CGFloat {
        min(totalWidth, max(1, totalWidth * row.ratio))
    }
}

private struct SessionTimelinePanel: View {
    let session: FocusSession

    private var orderedSegments: [StateSegment] {
        session.segments.sorted { lhs, rhs in
            if lhs.startSeconds != rhs.startSeconds {
                return lhs.startSeconds < rhs.startSeconds
            }
            return lhs.endSeconds < rhs.endSeconds
        }
    }

    private var startingState: DetectionState {
        orderedSegments.first?.state ?? .focused
    }

    private var endingState: DetectionState {
        orderedSegments.last?.state ?? .uncertain
    }

    private var highlightedSegment: StateSegment? {
        orderedSegments
            .filter { !$0.state.countsAsFocused }
            .max { $0.duration < $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session timeline")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(HomeTheme.primaryText)

            TimelineTickLabels(session: session)
                .frame(height: 24)

            ProportionalTimelineBar(session: session)
                .frame(height: 24)

            HStack(alignment: .top, spacing: 16) {
                TimelineCallout(
                    title: formattedTimelineTime(session.startTime),
                    state: startingState,
                    alignment: .leading
                )

                Spacer(minLength: 16)

                if let highlightedSegment {
                    TimelineCallout(
                        title: "\(formattedTimelineTime(session.startTime.addingTimeInterval(highlightedSegment.startSeconds))) - \(formattedTimelineTime(session.startTime.addingTimeInterval(highlightedSegment.endSeconds)))",
                        state: highlightedSegment.state,
                        alignment: .leading
                    )
                    .frame(maxWidth: 260)
                }

                Spacer(minLength: 16)

                TimelineCallout(
                    title: formattedTimelineTime(session.endTime),
                    state: endingState,
                    alignment: .trailing
                )
            }
        }
        .padding(24)
        .summaryCard(stroke: HomeTheme.border, fill: .clear)
    }
}

private struct TimelineTickLabels: View {
    let session: FocusSession

    private var ticks: [TimelineTick] {
        timelineTicks(for: session)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(ticks) { tick in
                    Text(tick.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                        .lineLimit(1)
                        .position(
                            x: clampedTickX(tick.offset, width: geometry.size.width),
                            y: 10
                        )
                }
            }
        }
    }

    private func clampedTickX(_ offset: TimeInterval, width: CGFloat) -> CGFloat {
        let x = width * offset / max(session.duration, 1)
        return min(max(x, 28), max(28, width - 28))
    }
}

private struct ProportionalTimelineBar: View {
    let session: FocusSession

    private var orderedSegments: [StateSegment] {
        session.segments.sorted { lhs, rhs in
            if lhs.startSeconds != rhs.startSeconds {
                return lhs.startSeconds < rhs.startSeconds
            }
            return lhs.endSeconds < rhs.endSeconds
        }
    }

    var body: some View {
        GeometryReader { geometry in
            if orderedSegments.isEmpty {
                RoundedRectangle(cornerRadius: 5)
                    .fill(HomeTheme.subtleBackground)
            } else {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(HomeTheme.subtleBackground)

                    ForEach(orderedSegments) { segment in
                        let segmentX = segmentX(segment, width: geometry.size.width)
                        let segmentWidth = segmentWidth(segment, width: geometry.size.width)
                        Rectangle()
                            .fill(segment.state.color)
                            .frame(width: segmentWidth, height: geometry.size.height)
                            .position(x: segmentX + (segmentWidth / 2), y: geometry.size.height / 2)
                            .help("\(segment.state.label), \(formatCompactDuration(segment.duration))")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(HomeTheme.border, lineWidth: 1)
                }
            }
        }
        .accessibilityLabel("Session timeline")
    }

    private func segmentX(_ segment: StateSegment, width: CGFloat) -> CGFloat {
        min(max(0, width * segment.startSeconds / max(session.duration, 1)), width)
    }

    private func segmentWidth(_ segment: StateSegment, width: CGFloat) -> CGFloat {
        max(1, min(width - segmentX(segment, width: width), width * segment.duration / max(session.duration, 1)))
    }
}

private struct TimelineCallout: View {
    let title: String
    let state: DetectionState
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HomeTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(timelineStateLabel(for: state))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(state.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func timelineStateLabel(for state: DetectionState) -> String {
        state == .focused ? "Focused" : state.label
    }
}

private struct TimelineTick: Identifiable {
    let offset: TimeInterval
    let label: String

    var id: TimeInterval { offset }
}

private func timelineTicks(for session: FocusSession) -> [TimelineTick] {
    let total = max(session.duration, 0)
    guard total > 0 else {
        return [TimelineTick(offset: 0, label: formattedTimelineTime(session.startTime))]
    }

    let interval: TimeInterval
    switch total {
    case ...900:
        interval = 300
    case ...3600:
        interval = 900
    case ...10800:
        interval = 1800
    case ...28800:
        interval = 3600
    default:
        interval = 7200
    }

    var offsets: [TimeInterval] = [0]
    var next = interval
    while next < total {
        offsets.append(next)
        next += interval
    }
    if offsets.last.map({ abs($0 - total) > 1 }) ?? true {
        offsets.append(total)
    }

    return offsets.map { offset in
        TimelineTick(
            offset: offset,
            label: formattedTimelineTime(session.startTime.addingTimeInterval(offset))
        )
    }
}

private func formattedTimelineTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private extension View {
    func summaryCard(stroke: Color, fill: Color) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    HomeTheme.cardBackground
                    fill
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(stroke, lineWidth: 1)
            }
            .shadow(color: HomeTheme.shadow, radius: 12, x: 0, y: 6)
    }
}

private enum SessionSummaryCSVExporter {
    private static let headers = [
        "Section",
        "Item",
        "Start Timestamp",
        "End Timestamp",
        "Start Offset",
        "End Offset",
        "Duration",
        "Seconds",
        "Percent Of Session",
        "State",
        "Effective State",
        "Count",
        "Confidence",
        "Correction",
        "Counts As Confirmed Work",
        "Notes"
    ]

    static func csv(for session: FocusSession) -> String {
        let totalDuration = session.duration
        let rows = allRows(for: session, totalDuration: totalDuration)
        return ([headers] + rows)
            .map(csvLine)
            .joined(separator: "\n") + "\n"
    }

    private static func allRows(for session: FocusSession, totalDuration: TimeInterval) -> [[String]] {
        var rows: [[String]] = []

        rows.append(row(section: "Session", item: "Session ID", notes: session.id.uuidString))
        rows.append(row(section: "Session", item: "Started", startTimestamp: timestamp(session.startTime)))
        rows.append(row(section: "Session", item: "Ended", endTimestamp: timestamp(session.endTime)))
        rows.append(row(
            section: "Session",
            item: "Target Duration",
            duration: session.targetDurationSeconds,
            seconds: session.targetDurationSeconds,
            notes: session.targetDurationSeconds == nil ? "Open-ended session" : ""
        ))
        rows.append(row(
            section: "Session",
            item: "Completion Reason",
            notes: sessionCompletionReasonLabel(session)
        ))

        rows.append(row(
            section: "Focus Summary",
            item: "Total Session Time",
            startTimestamp: timestamp(session.startTime),
            endTimestamp: timestamp(session.endTime),
            startOffset: formatClock(0),
            endOffset: formatClock(totalDuration),
            duration: totalDuration,
            seconds: totalDuration,
            percent: totalDuration > 0 ? 1 : 0
        ))
        rows.append(row(
            section: "Focus Summary",
            item: "Focused Work",
            duration: session.screenFocusedSeconds,
            seconds: session.screenFocusedSeconds,
            percent: ratio(session.screenFocusedSeconds, of: totalDuration),
            state: DetectionState.focused.label,
            notes: "Raw focused time before corrections"
        ))
        rows.append(row(
            section: "Focus Summary",
            item: "Confirmed Work",
            duration: session.confirmedWorkSeconds,
            seconds: session.confirmedWorkSeconds,
            percent: ratio(session.confirmedWorkSeconds, of: totalDuration),
            confirmedWork: true,
            notes: "Screen focused plus user-corrected focused segments"
        ))
        rows.append(row(
            section: "Focus Summary",
            item: "Corrected Focus",
            duration: session.correctedSeconds,
            seconds: session.correctedSeconds,
            percent: ratio(session.correctedSeconds, of: totalDuration),
            correction: SegmentCorrection.actuallyFocused.label,
            confirmedWork: true,
            notes: "Time added by user corrections"
        ))
        rows.append(row(
            section: "Focus Summary",
            item: "Reviewable",
            duration: session.reviewSeconds,
            seconds: session.reviewSeconds,
            percent: ratio(session.reviewSeconds, of: totalDuration),
            notes: "Looking down or uncertain time"
        ))

        let detectedBreakdown = session.breakdown()
        for state in DetectionState.allCases {
            let value = detectedBreakdown[state] ?? (0, 0)
            rows.append(row(
                section: "Detected Breakdown",
                item: state.label,
                duration: value.seconds,
                seconds: value.seconds,
                percent: ratio(value.seconds, of: totalDuration),
                state: state.label,
                count: value.count,
                confirmedWork: state.countsAsFocused,
                notes: "Original classified state"
            ))
        }

        let adjustedBreakdown = effectiveBreakdown(for: session)
        for state in DetectionState.allCases {
            let value = adjustedBreakdown[state] ?? (0, 0)
            rows.append(row(
                section: "Correction-Adjusted Breakdown",
                item: state.label,
                duration: value.seconds,
                seconds: value.seconds,
                percent: ratio(value.seconds, of: totalDuration),
                effectiveState: state.label,
                count: value.count,
                confirmedWork: state.countsAsFocused,
                notes: "After user corrections"
            ))
        }

        for (index, segment) in session.segments.sorted(by: { $0.startSeconds < $1.startSeconds }).enumerated() {
            rows.append(row(
                section: "Segments",
                item: "Segment \(index + 1)",
                startTimestamp: timestamp(session.startTime.addingTimeInterval(segment.startSeconds)),
                endTimestamp: timestamp(session.startTime.addingTimeInterval(segment.endSeconds)),
                startOffset: formatClock(segment.startSeconds),
                endOffset: formatClock(segment.endSeconds),
                duration: segment.duration,
                seconds: segment.duration,
                percent: ratio(segment.duration, of: totalDuration),
                state: segment.state.label,
                effectiveState: segment.effectiveState.label,
                confidence: segment.confidence,
                correction: segment.userCorrection?.label ?? "",
                confirmedWork: segment.countsAsConfirmedWork,
                notes: segment.userCorrection == nil ? "" : "User correction applied"
            ))
        }

        return rows
    }

    private static func effectiveBreakdown(for session: FocusSession) -> [DetectionState: (count: Int, seconds: TimeInterval)] {
        var result: [DetectionState: (count: Int, seconds: TimeInterval)] = [:]
        for state in DetectionState.allCases {
            result[state] = (0, 0)
        }
        for segment in session.segments {
            let state = segment.effectiveState
            let current = result[state] ?? (0, 0)
            result[state] = (current.count + 1, current.seconds + segment.duration)
        }
        return result
    }

    private static func row(
        section: String,
        item: String,
        startTimestamp: String = "",
        endTimestamp: String = "",
        startOffset: String = "",
        endOffset: String = "",
        duration: TimeInterval? = nil,
        seconds: TimeInterval? = nil,
        percent: Double? = nil,
        state: String = "",
        effectiveState: String = "",
        count: Int? = nil,
        confidence: Double? = nil,
        correction: String = "",
        confirmedWork: Bool? = nil,
        notes: String = ""
    ) -> [String] {
        [
            section,
            item,
            startTimestamp,
            endTimestamp,
            startOffset,
            endOffset,
            duration.map(formatClock) ?? "",
            seconds.map(roundedSeconds) ?? "",
            percent.map(percentString) ?? "",
            state,
            effectiveState,
            count.map(String.init) ?? "",
            confidence.map(percentString) ?? "",
            correction,
            confirmedWork.map { $0 ? "Yes" : "No" } ?? "",
            notes
        ]
    }

    private static func csvLine(_ fields: [String]) -> String {
        fields.map(csvField).joined(separator: ",")
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func ratio(_ seconds: TimeInterval, of total: TimeInterval) -> Double {
        guard total > 0 else { return 0 }
        return seconds / total
    }

    private static func roundedSeconds(_ seconds: TimeInterval) -> String {
        String(Int(seconds.rounded()))
    }

    private static func percentString(_ value: Double) -> String {
        String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value * 100)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter.string(from: date)
    }
}
