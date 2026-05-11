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
                            onExport: { exportSession(for: session) }
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

    private func exportSession(for session: FocusSession) {
        let panel = NSSavePanel()
        panel.title = "Export Session Summary"
        panel.prompt = "Export"
        panel.nameFieldStringValue = defaultExportFilename(for: session)
        panel.allowedContentTypes = [spreadsheetContentType, .commaSeparatedText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            if url.pathExtension.lowercased() == "csv" {
                let csv = SessionSummaryCSVExporter.csv(for: session)
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } else {
                let workbook = try SessionSummaryXLSXExporter.xlsx(for: session)
                try workbook.write(to: url, options: [.atomic])
            }
        } catch {
            exportErrorMessage = "Could not export session summary: \(error.localizedDescription)"
        }
    }

    private func defaultExportFilename(for session: FocusSession) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "FocusMirror Session \(formatter.string(from: session.startTime)).xlsx"
    }

    private var spreadsheetContentType: UTType {
        UTType(filenameExtension: "xlsx") ?? UTType(exportedAs: "org.openxmlformats.spreadsheetml.sheet")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session timeline")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(HomeTheme.primaryText)

            TimelineTickLabels(session: session)
                .frame(height: 24)

            ProportionalTimelineBar(session: session)
                .frame(height: 24)
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

enum SessionSummaryCSVExporter {
    private static let summaryHeaders = [
        "Section",
        "Metric",
        "Value",
        "Duration",
        "Seconds",
        "Percent Of Session",
        "Count"
    ]

    private static let timelineHeaders = [
        "Segment",
        "Start Time",
        "End Time",
        "Start Offset",
        "End Offset",
        "State",
        "Duration",
        "Seconds",
        "Percent Of Session",
        "Confidence"
    ]

    static func csv(for session: FocusSession, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let totalDuration = session.duration
        var lines = ([summaryHeaders] + summaryRows(for: session, totalDuration: totalDuration, timeZone: timeZone, locale: locale)).map(csvLine)
        lines.append("")
        lines += ([timelineHeaders] + timelineRows(for: session, totalDuration: totalDuration, timeZone: timeZone, locale: locale)).map(csvLine)

        return lines.joined(separator: "\n") + "\n"
    }

    private static func summaryRows(
        for session: FocusSession,
        totalDuration: TimeInterval,
        timeZone: TimeZone,
        locale: Locale
    ) -> [[String]] {
        SessionSummaryExportContent.summarySections(
            for: session,
            totalDuration: totalDuration,
            timeZone: timeZone,
            locale: locale
        )
        .flatMap { section in
            section.rows.map { row in
                [
                    section.title,
                    row.metric,
                    row.value,
                    row.duration,
                    row.seconds,
                    row.percent,
                    row.count
                ]
            }
        }
    }

    private static func timelineRows(
        for session: FocusSession,
        totalDuration: TimeInterval,
        timeZone: TimeZone,
        locale: Locale
    ) -> [[String]] {
        SessionSummaryExportContent.timelineRows(
            for: session,
            totalDuration: totalDuration,
            timeZone: timeZone,
            locale: locale
        )
        .map { row in
            [
                row.segment,
                row.startTime,
                row.endTime,
                row.startOffset,
                row.endOffset,
                row.state,
                row.duration,
                row.seconds,
                row.percent,
                row.confidence
            ]
        }
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
}

enum SessionSummaryXLSXExporter {
    static func xlsx(for session: FocusSession, timeZone: TimeZone = .current, locale: Locale = .current) throws -> Data {
        try SimpleZipArchive.archive(files: packageFiles(for: session, timeZone: timeZone, locale: locale))
    }

    static func packageFiles(
        for session: FocusSession,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> [XLSXPackageFile] {
        SpreadsheetWorkbookPackage.packageFiles(
            sheetName: "Session Summary",
            worksheetXML: worksheetXML(for: session, timeZone: timeZone, locale: locale)
        )
    }

    private static func worksheetXML(for session: FocusSession, timeZone: TimeZone, locale: Locale) -> String {
        var builder = WorksheetBuilder()
        let totalDuration = session.duration
        let sections = SessionSummaryExportContent.summarySections(
            for: session,
            totalDuration: totalDuration,
            timeZone: timeZone,
            locale: locale
        )
        let timelineRows = SessionSummaryExportContent.timelineRows(
            for: session,
            totalDuration: totalDuration,
            timeZone: timeZone,
            locale: locale
        )

        builder.addMergedRow(
            "FocusMirror Session Summary",
            fromColumn: 1,
            toColumn: 10,
            style: .title
        )
        builder.addMergedRow(
            "\(SessionSummaryExportFormatting.timestamp(session.startTime, timeZone: timeZone, locale: locale)) - \(SessionSummaryExportFormatting.timestamp(session.endTime, timeZone: timeZone, locale: locale)) | \(SessionSummaryExportFormatting.timeZoneDescription(timeZone, on: session.startTime, locale: locale))",
            fromColumn: 1,
            toColumn: 10,
            style: .subtitle
        )
        builder.addBlankRow()

        for section in sections {
            builder.addMergedRow(section.title, fromColumn: 1, toColumn: 6, style: .section)
            builder.addRow(["Metric", "Value", "Duration", "Seconds", "Percent Of Session", "Count"], style: .header)
            for row in section.rows {
                builder.addStyledRow([
                    .text(row.metric, style: .body),
                    row.valueDate.map { .excelDate($0, timeZone: timeZone, style: .dateTime) }
                        ?? .text(row.value, style: .body),
                    .text(row.duration, style: .body),
                    row.secondsValue.map { .number($0, style: .number) } ?? .blank(style: .number),
                    row.percentValue.map { .number($0, style: .percent) } ?? .blank(style: .percent),
                    row.countValue.map { .number(Double($0), style: .number) } ?? .blank(style: .number)
                ])
            }
            builder.addBlankRow()
        }

        builder.addMergedRow("Timeline", fromColumn: 1, toColumn: 10, style: .section)
        builder.addRow(
            [
                "Segment",
                "Start Time",
                "End Time",
                "Start Offset",
                "End Offset",
                "State",
                "Duration",
                "Seconds",
                "Percent Of Session",
                "Confidence"
            ],
            style: .header
        )

        if timelineRows.isEmpty {
            builder.addMergedRow("No timeline segments recorded", fromColumn: 1, toColumn: 10, style: .body)
        } else {
            for row in timelineRows {
                builder.addStyledRow([
                    .number(Double(row.segmentValue), style: .number),
                    .excelDate(row.startDate, timeZone: timeZone, style: .dateTime),
                    .excelDate(row.endDate, timeZone: timeZone, style: .dateTime),
                    .elapsedTime(row.startOffsetSeconds, style: .elapsedTime),
                    .elapsedTime(row.endOffsetSeconds, style: .elapsedTime),
                    .text(row.state, style: .body),
                    .text(row.duration, style: .body),
                    .number(row.secondsValue, style: .number),
                    .number(row.percentValue, style: .percent),
                    .number(row.confidenceValue, style: .percent)
                ])
            }
        }

        return builder.xml()
    }
}

enum LifetimeSummaryXLSXExporter {
    static func xlsx(
        for sessions: [FocusSession],
        generatedAt: Date = Date(),
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) throws -> Data {
        try SimpleZipArchive.archive(
            files: packageFiles(for: sessions, generatedAt: generatedAt, timeZone: timeZone, locale: locale)
        )
    }

    static func packageFiles(
        for sessions: [FocusSession],
        generatedAt: Date = Date(),
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> [XLSXPackageFile] {
        SpreadsheetWorkbookPackage.packageFiles(
            sheetName: "Lifetime Summary",
            worksheetXML: worksheetXML(for: sessions, generatedAt: generatedAt, timeZone: timeZone, locale: locale)
        )
    }

    private static func worksheetXML(
        for sessions: [FocusSession],
        generatedAt: Date,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        var builder = WorksheetBuilder()
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let sections = LifetimeSummaryExportContent.summarySections(
            for: sessions,
            totalDuration: totalDuration,
            generatedAt: generatedAt,
            timeZone: timeZone,
            locale: locale
        )

        builder.addMergedRow("FocusMirror Lifetime Summary", fromColumn: 1, toColumn: 6, style: .title)
        builder.addMergedRow(
            subtitle(for: sessions, generatedAt: generatedAt, timeZone: timeZone, locale: locale),
            fromColumn: 1,
            toColumn: 6,
            style: .subtitle
        )
        builder.addBlankRow()

        for section in sections {
            builder.addMergedRow(section.title, fromColumn: 1, toColumn: 6, style: .section)
            builder.addRow(["Metric", "Value", "Duration", "Seconds", "Percent Of Lifetime", "Count"], style: .header)
            for row in section.rows {
                builder.addStyledRow([
                    .text(row.metric, style: .body),
                    row.valueDate.map { .excelDate($0, timeZone: timeZone, style: .dateTime) }
                        ?? .text(row.value, style: .body),
                    .text(row.duration, style: .body),
                    row.secondsValue.map { .number($0, style: .number) } ?? .blank(style: .number),
                    row.percentValue.map { .number($0, style: .percent) } ?? .blank(style: .percent),
                    row.countValue.map { .number(Double($0), style: .number) } ?? .blank(style: .number)
                ])
            }
            builder.addBlankRow()
        }

        return builder.xml()
    }

    private static func subtitle(
        for sessions: [FocusSession],
        generatedAt: Date,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        let timeZoneLabel = SessionSummaryExportFormatting.timeZoneDescription(
            timeZone,
            on: sessions.map(\.startTime).min() ?? generatedAt,
            locale: locale
        )
        guard
            let firstStart = sessions.map(\.startTime).min(),
            let latestEnd = sessions.map(\.endTime).max()
        else {
            return "No sessions recorded | \(timeZoneLabel)"
        }

        return "\(sessionCountLabel(sessions.count)) | \(SessionSummaryExportFormatting.timestamp(firstStart, timeZone: timeZone, locale: locale)) - \(SessionSummaryExportFormatting.timestamp(latestEnd, timeZone: timeZone, locale: locale)) | \(timeZoneLabel)"
    }

    private static func sessionCountLabel(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }
}

private enum SpreadsheetWorkbookPackage {
    static func packageFiles(sheetName: String, worksheetXML: String) -> [XLSXPackageFile] {
        [
            XLSXPackageFile(path: "[Content_Types].xml", string: contentTypesXML),
            XLSXPackageFile(path: "_rels/.rels", string: rootRelationshipsXML),
            XLSXPackageFile(path: "xl/workbook.xml", string: workbookXML(sheetName: sheetName)),
            XLSXPackageFile(path: "xl/_rels/workbook.xml.rels", string: workbookRelationshipsXML),
            XLSXPackageFile(path: "xl/styles.xml", string: stylesXML),
            XLSXPackageFile(path: "xl/worksheets/sheet1.xml", string: worksheetXML)
        ]
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """

    private static let rootRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static let workbookRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static func workbookXML(sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="\(xmlEscaped(sheetName))" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """
    }

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <numFmts count="3">
        <numFmt numFmtId="164" formatCode="0.0%"/>
        <numFmt numFmtId="165" formatCode="[m]:ss"/>
        <numFmt numFmtId="166" formatCode="mmm d, yyyy, h:mm AM/PM"/>
      </numFmts>
      <fonts count="4">
        <font><sz val="12"/><color rgb="FF111827"/><name val="Aptos"/></font>
        <font><b/><sz val="12"/><color rgb="FF111827"/><name val="Aptos"/></font>
        <font><b/><sz val="18"/><color rgb="FFFFFFFF"/><name val="Aptos"/></font>
        <font><sz val="11"/><color rgb="FF4B5563"/><name val="Aptos"/></font>
      </fonts>
      <fills count="5">
        <fill><patternFill patternType="none"/></fill>
        <fill><patternFill patternType="gray125"/></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FF1F4FD8"/><bgColor indexed="64"/></patternFill></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFEAF0FF"/><bgColor indexed="64"/></patternFill></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFF8FAFC"/><bgColor indexed="64"/></patternFill></fill>
      </fills>
      <borders count="2">
        <border><left/><right/><top/><bottom/><diagonal/></border>
        <border>
          <left style="thin"><color rgb="FFD1D5DB"/></left>
          <right style="thin"><color rgb="FFD1D5DB"/></right>
          <top style="thin"><color rgb="FFD1D5DB"/></top>
          <bottom style="thin"><color rgb="FFD1D5DB"/></bottom>
          <diagonal/>
        </border>
      </borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="10">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="center"/></xf>
        <xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>
        <xf numFmtId="0" fontId="1" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
        <xf numFmtId="0" fontId="1" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
        <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
        <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment horizontal="right"/></xf>
        <xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right"/></xf>
        <xf numFmtId="166" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>
        <xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right"/></xf>
      </cellXfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
      <dxfs count="0"/>
      <tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleMedium9"/>
    </styleSheet>
    """
}

struct XLSXPackageFile {
    let path: String
    let data: Data

    init(path: String, string: String) {
        self.path = path
        data = Data(string.utf8)
    }
}

private struct ExportSummarySection {
    let title: String
    let rows: [ExportSummaryRow]
}

private struct ExportSummaryRow {
    let metric: String
    let value: String
    let valueDate: Date?
    let duration: String
    let seconds: String
    let secondsValue: Double?
    let percent: String
    let percentValue: Double?
    let count: String
    let countValue: Int?

    init(
        metric: String,
        value: String = "",
        valueDate: Date? = nil,
        duration: TimeInterval? = nil,
        seconds: TimeInterval? = nil,
        percent: Double? = nil,
        count: Int? = nil
    ) {
        self.metric = metric
        self.value = value
        self.valueDate = valueDate
        self.duration = duration.map(SessionSummaryExportFormatting.duration) ?? ""
        self.seconds = seconds.map(SessionSummaryExportFormatting.roundedSeconds) ?? ""
        self.secondsValue = seconds.map { Double(Int($0.rounded())) }
        self.percent = percent.map(SessionSummaryExportFormatting.percent) ?? ""
        self.percentValue = percent
        self.count = count.map(String.init) ?? ""
        self.countValue = count
    }
}

private struct ExportTimelineRow {
    let segment: String
    let segmentValue: Int
    let startTime: String
    let startDate: Date
    let endTime: String
    let endDate: Date
    let startOffset: String
    let startOffsetSeconds: TimeInterval
    let endOffset: String
    let endOffsetSeconds: TimeInterval
    let state: String
    let duration: String
    let seconds: String
    let secondsValue: Double
    let percent: String
    let percentValue: Double
    let confidence: String
    let confidenceValue: Double
}

private enum SessionSummaryExportContent {
    static func summarySections(
        for session: FocusSession,
        totalDuration: TimeInterval,
        timeZone: TimeZone,
        locale: Locale
    ) -> [ExportSummarySection] {
        [
            ExportSummarySection(
                title: "Session",
                rows: sessionRows(for: session, totalDuration: totalDuration, timeZone: timeZone, locale: locale)
            ),
            ExportSummarySection(title: "Activity Breakdown", rows: activityBreakdownRows(for: session))
        ]
    }

    static func timelineRows(
        for session: FocusSession,
        totalDuration: TimeInterval,
        timeZone: TimeZone,
        locale: Locale
    ) -> [ExportTimelineRow] {
        session.segments
            .sorted {
                if $0.startSeconds != $1.startSeconds {
                    return $0.startSeconds < $1.startSeconds
                }
                return $0.endSeconds < $1.endSeconds
            }
            .enumerated()
            .map { index, segment in
                let startDate = session.startTime.addingTimeInterval(segment.startSeconds)
                let endDate = session.startTime.addingTimeInterval(segment.endSeconds)
                let percent = ratio(segment.duration, of: totalDuration)
                return ExportTimelineRow(
                    segment: String(index + 1),
                    segmentValue: index + 1,
                    startTime: SessionSummaryExportFormatting.timestamp(startDate, timeZone: timeZone, locale: locale),
                    startDate: startDate,
                    endTime: SessionSummaryExportFormatting.timestamp(endDate, timeZone: timeZone, locale: locale),
                    endDate: endDate,
                    startOffset: formatClock(segment.startSeconds),
                    startOffsetSeconds: segment.startSeconds,
                    endOffset: formatClock(segment.endSeconds),
                    endOffsetSeconds: segment.endSeconds,
                    state: segment.state.label,
                    duration: SessionSummaryExportFormatting.duration(segment.duration),
                    seconds: SessionSummaryExportFormatting.roundedSeconds(segment.duration),
                    secondsValue: Double(Int(segment.duration.rounded())),
                    percent: SessionSummaryExportFormatting.percent(percent),
                    percentValue: percent,
                    confidence: SessionSummaryExportFormatting.percent(segment.confidence),
                    confidenceValue: segment.confidence
                )
            }
    }

    private static func ratio(_ seconds: TimeInterval, of total: TimeInterval) -> Double {
        guard total > 0 else { return 0 }
        return seconds / total
    }

    private static func sessionRows(
        for session: FocusSession,
        totalDuration: TimeInterval,
        timeZone: TimeZone,
        locale: Locale
    ) -> [ExportSummaryRow] {
        [
            ExportSummaryRow(metric: "Session ID", value: session.id.uuidString),
            ExportSummaryRow(
                metric: "Started",
                value: SessionSummaryExportFormatting.timestamp(session.startTime, timeZone: timeZone, locale: locale),
                valueDate: session.startTime
            ),
            ExportSummaryRow(
                metric: "Ended",
                value: SessionSummaryExportFormatting.timestamp(session.endTime, timeZone: timeZone, locale: locale),
                valueDate: session.endTime
            ),
            ExportSummaryRow(
                metric: "Timezone",
                value: SessionSummaryExportFormatting.timeZoneDescription(timeZone, on: session.startTime, locale: locale)
            ),
            ExportSummaryRow(
                metric: "Target Duration",
                value: session.targetDurationSeconds.map(SessionSummaryExportFormatting.duration) ?? "Open-ended"
            ),
            ExportSummaryRow(metric: "Completion Reason", value: sessionCompletionReasonLabel(session)),
            ExportSummaryRow(
                metric: "Total Session Duration",
                duration: totalDuration,
                seconds: totalDuration,
                percent: totalDuration > 0 ? 1 : 0
            )
        ]
    }

    private static func activityBreakdownRows(for session: FocusSession) -> [ExportSummaryRow] {
        durationSortedSummaries(session.detectedStateSummaries).map { summary in
            ExportSummaryRow(
                metric: summary.state.label,
                duration: summary.seconds,
                seconds: summary.seconds,
                percent: summary.ratio,
                count: summary.count
            )
        }
    }
}

private enum LifetimeSummaryExportContent {
    static func summarySections(
        for sessions: [FocusSession],
        totalDuration: TimeInterval,
        generatedAt: Date,
        timeZone: TimeZone,
        locale: Locale
    ) -> [ExportSummarySection] {
        [
            ExportSummarySection(
                title: "Lifetime",
                rows: lifetimeRows(
                    for: sessions,
                    totalDuration: totalDuration,
                    generatedAt: generatedAt,
                    timeZone: timeZone,
                    locale: locale
                )
            ),
            ExportSummarySection(
                title: "Activity Breakdown",
                rows: activityBreakdownRows(for: sessions, totalDuration: totalDuration)
            )
        ]
    }

    private static func lifetimeRows(
        for sessions: [FocusSession],
        totalDuration: TimeInterval,
        generatedAt: Date,
        timeZone: TimeZone,
        locale: Locale
    ) -> [ExportSummaryRow] {
        let firstSessionStart = sessions.map(\.startTime).min()
        let latestSessionStart = sessions.map(\.startTime).max()
        let averageDuration = sessions.isEmpty ? 0 : totalDuration / Double(sessions.count)
        let timeZoneReferenceDate = firstSessionStart ?? generatedAt

        return [
            ExportSummaryRow(metric: "Session Count", value: String(sessions.count)),
            ExportSummaryRow(
                metric: "First Session",
                value: firstSessionStart.map {
                    SessionSummaryExportFormatting.timestamp($0, timeZone: timeZone, locale: locale)
                } ?? "No sessions recorded",
                valueDate: firstSessionStart
            ),
            ExportSummaryRow(
                metric: "Latest Session",
                value: latestSessionStart.map {
                    SessionSummaryExportFormatting.timestamp($0, timeZone: timeZone, locale: locale)
                } ?? "No sessions recorded",
                valueDate: latestSessionStart
            ),
            ExportSummaryRow(
                metric: "Timezone",
                value: SessionSummaryExportFormatting.timeZoneDescription(
                    timeZone,
                    on: timeZoneReferenceDate,
                    locale: locale
                )
            ),
            ExportSummaryRow(
                metric: "Total Recorded Time",
                duration: totalDuration,
                seconds: totalDuration,
                percent: totalDuration > 0 ? 1 : 0
            ),
            ExportSummaryRow(
                metric: "Average Session Length",
                duration: averageDuration,
                seconds: averageDuration
            )
        ]
    }

    private static func activityBreakdownRows(
        for sessions: [FocusSession],
        totalDuration: TimeInterval
    ) -> [ExportSummaryRow] {
        durationSortedSummaries(activitySummaries(for: sessions, totalDuration: totalDuration)).map { summary in
            ExportSummaryRow(
                metric: summary.state.label,
                duration: summary.seconds,
                seconds: summary.seconds,
                percent: totalDuration > 0 ? summary.ratio : 0,
                count: summary.count
            )
        }
    }

    private static func activitySummaries(
        for sessions: [FocusSession],
        totalDuration: TimeInterval
    ) -> [FocusSessionStateSummary] {
        var totals: [DetectionState: (count: Int, seconds: TimeInterval)] = [:]
        for state in DetectionState.allCases {
            totals[state] = (0, 0)
        }

        for session in sessions {
            for segment in session.segments {
                let current = totals[segment.state] ?? (0, 0)
                totals[segment.state] = (current.count + 1, current.seconds + segment.duration)
            }
        }

        return DetectionState.allCases.map { state in
            let total = totals[state] ?? (0, 0)
            return FocusSessionStateSummary(
                state: state,
                count: total.count,
                seconds: total.seconds,
                totalSeconds: totalDuration
            )
        }
    }
}

private enum SessionSummaryExportFormatting {
    static func timestamp(_ date: Date, timeZone: TimeZone, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy, h:mm a zzz"
        return formatter.string(from: date)
    }

    static func timeZoneDescription(_ timeZone: TimeZone, on date: Date, locale: Locale) -> String {
        let localizedName = timeZone.localizedName(for: .generic, locale: locale)
            ?? timeZone.localizedName(for: .standard, locale: locale)
        let abbreviation = timeZone.abbreviation(for: date)
        switch (localizedName, abbreviation) {
        case let (.some(localizedName), .some(abbreviation)) where !localizedName.contains(abbreviation):
            return "\(localizedName) (\(abbreviation))"
        case let (.some(localizedName), _):
            return localizedName
        case let (_, .some(abbreviation)):
            return abbreviation
        default:
            return timeZone.identifier
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60
        var parts: [String] = []

        if hours > 0 {
            parts.append("\(hours)h")
        }
        if minutes > 0 {
            parts.append("\(minutes)m")
        }
        if remainingSeconds > 0 || parts.isEmpty {
            parts.append("\(remainingSeconds)s")
        }

        return parts.joined(separator: " ")
    }

    static func roundedSeconds(_ seconds: TimeInterval) -> String {
        String(Int(seconds.rounded()))
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value * 100)
    }

    static func excelDateSerial(_ date: Date, timeZone: TimeZone) -> Double {
        var sourceCalendar = Calendar(identifier: .gregorian)
        sourceCalendar.timeZone = timeZone
        let components = sourceCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )

        var excelCalendar = Calendar(identifier: .gregorian)
        excelCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard
            let localDateAsUTC = excelCalendar.date(from: components),
            let excelEpoch = excelCalendar.date(from: DateComponents(year: 1899, month: 12, day: 30))
        else {
            return 0
        }

        return localDateAsUTC.timeIntervalSince(excelEpoch) / 86_400
    }
}

private enum WorksheetStyle: Int {
    case normal = 0
    case title = 1
    case subtitle = 2
    case section = 3
    case header = 4
    case body = 5
    case number = 6
    case percent = 7
    case dateTime = 8
    case elapsedTime = 9
}

private struct WorksheetCell {
    let value: WorksheetCellValue
    let style: WorksheetStyle

    static func text(_ value: String, style: WorksheetStyle) -> WorksheetCell {
        WorksheetCell(value: value.isEmpty ? .blank : .text(value), style: style)
    }

    static func number(_ value: Double, style: WorksheetStyle) -> WorksheetCell {
        WorksheetCell(value: .number(value), style: style)
    }

    static func excelDate(_ date: Date, timeZone: TimeZone, style: WorksheetStyle) -> WorksheetCell {
        WorksheetCell(
            value: .number(SessionSummaryExportFormatting.excelDateSerial(date, timeZone: timeZone)),
            style: style
        )
    }

    static func elapsedTime(_ seconds: TimeInterval, style: WorksheetStyle) -> WorksheetCell {
        WorksheetCell(value: .number(seconds / 86_400), style: style)
    }

    static func blank(style: WorksheetStyle) -> WorksheetCell {
        WorksheetCell(value: .blank, style: style)
    }

    private init(value: WorksheetCellValue, style: WorksheetStyle) {
        self.value = value
        self.style = style
    }
}

private enum WorksheetCellValue {
    case blank
    case text(String)
    case number(Double)
}

private struct WorksheetBuilder {
    private var currentRow = 1
    private var rowXML: [String] = []
    private var mergedRanges: [String] = []

    mutating func addRow(_ values: [String], style: WorksheetStyle) {
        addStyledRow(values.map { .text($0, style: style) })
    }

    mutating func addStyledRow(_ cells: [WorksheetCell]) {
        let cellXML = cells.enumerated()
            .map { index, cell in
                xlsxCellXML(
                    value: cell.value,
                    reference: "\(columnName(index + 1))\(currentRow)",
                    style: cell.style
                )
            }
            .joined()
        rowXML.append("<row r=\"\(currentRow)\">\(cellXML)</row>")
        currentRow += 1
    }

    mutating func addMergedRow(_ value: String, fromColumn: Int, toColumn: Int, style: WorksheetStyle) {
        let start = "\(columnName(fromColumn))\(currentRow)"
        let end = "\(columnName(toColumn))\(currentRow)"
        rowXML.append(
            "<row r=\"\(currentRow)\">\(xlsxCellXML(value: .text(value), reference: start, style: style))</row>"
        )
        mergedRanges.append("\(start):\(end)")
        currentRow += 1
    }

    mutating func addBlankRow() {
        currentRow += 1
    }

    func xml() -> String {
        let merges = mergedRanges.isEmpty
            ? ""
            : "<mergeCells count=\"\(mergedRanges.count)\">\(mergedRanges.map { "<mergeCell ref=\"\($0)\"/>" }.joined())</mergeCells>"

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheetViews>
            <sheetView workbookViewId="0">
              <pane ySplit="3" topLeftCell="A4" activePane="bottomLeft" state="frozen"/>
            </sheetView>
          </sheetViews>
          <cols>
            <col min="1" max="1" width="28" customWidth="1"/>
            <col min="2" max="2" width="34" customWidth="1"/>
            <col min="3" max="3" width="34" customWidth="1"/>
            <col min="4" max="4" width="14" customWidth="1"/>
            <col min="5" max="5" width="16" customWidth="1"/>
            <col min="6" max="6" width="22" customWidth="1"/>
            <col min="7" max="7" width="14" customWidth="1"/>
            <col min="8" max="8" width="12" customWidth="1"/>
            <col min="9" max="9" width="20" customWidth="1"/>
            <col min="10" max="10" width="14" customWidth="1"/>
          </cols>
          <sheetData>
            \(rowXML.joined(separator: "\n    "))
          </sheetData>
          \(merges)
        </worksheet>
        """
    }

    private func xlsxCellXML(value: WorksheetCellValue, reference: String, style: WorksheetStyle) -> String {
        switch value {
        case .blank:
            return "<c r=\"\(reference)\" s=\"\(style.rawValue)\"/>"
        case .number(let value):
            return "<c r=\"\(reference)\" s=\"\(style.rawValue)\"><v>\(excelNumberString(value))</v></c>"
        case .text(let value):
            return "<c r=\"\(reference)\" s=\"\(style.rawValue)\" t=\"inlineStr\"><is><t>\(xmlEscaped(value))</t></is></c>"
        }
    }

    private func columnName(_ index: Int) -> String {
        var value = index
        var result = ""
        while value > 0 {
            value -= 1
            let scalar = UnicodeScalar(65 + (value % 26))!
            result = String(Character(scalar)) + result
            value /= 26
        }
        return result
    }
}

private func excelNumberString(_ value: Double) -> String {
    guard value.isFinite else {
        return "0"
    }

    let formatted = String(format: "%.12f", locale: Locale(identifier: "en_US_POSIX"), value)
    return formatted
        .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
}

private enum SimpleZipArchive {
    static func archive(files: [XLSXPackageFile]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [UInt32] = []

        for file in files {
            guard archive.count <= Int(UInt32.max), file.data.count <= Int(UInt32.max) else {
                throw SimpleZipArchiveError.fileTooLarge
            }

            let filename = Data(file.path.utf8)
            let crc = crc32(file.data)
            let localHeaderOffset = UInt32(archive.count)
            localHeaderOffsets.append(localHeaderOffset)

            archive.appendUInt32LE(0x04034b50)
            archive.appendUInt16LE(20)
            archive.appendUInt16LE(0x0800)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0x0021)
            archive.appendUInt32LE(crc)
            archive.appendUInt32LE(UInt32(file.data.count))
            archive.appendUInt32LE(UInt32(file.data.count))
            archive.appendUInt16LE(UInt16(filename.count))
            archive.appendUInt16LE(0)
            archive.append(filename)
            archive.append(file.data)
        }

        for (index, file) in files.enumerated() {
            let filename = Data(file.path.utf8)
            let crc = crc32(file.data)

            centralDirectory.appendUInt32LE(0x02014b50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0x0800)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0x0021)
            centralDirectory.appendUInt32LE(crc)
            centralDirectory.appendUInt32LE(UInt32(file.data.count))
            centralDirectory.appendUInt32LE(UInt32(file.data.count))
            centralDirectory.appendUInt16LE(UInt16(filename.count))
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(localHeaderOffsets[index])
            centralDirectory.append(filename)
        }

        guard archive.count <= Int(UInt32.max), centralDirectory.count <= Int(UInt32.max), files.count <= Int(UInt16.max) else {
            throw SimpleZipArchiveError.fileTooLarge
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendUInt32LE(0x06054b50)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(UInt16(files.count))
        archive.appendUInt16LE(UInt16(files.count))
        archive.appendUInt32LE(UInt32(centralDirectory.count))
        archive.appendUInt32LE(centralDirectoryOffset)
        archive.appendUInt16LE(0)

        return archive
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB8_8320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private enum SimpleZipArchiveError: LocalizedError {
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            "The spreadsheet is too large to export."
        }
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}

private func xmlEscaped(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(value.count)
    for character in value {
        switch character {
        case "&":
            result += "&amp;"
        case "<":
            result += "&lt;"
        case ">":
            result += "&gt;"
        case "\"":
            result += "&quot;"
        case "'":
            result += "&apos;"
        default:
            result.append(character)
        }
    }
    return result
}
