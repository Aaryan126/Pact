import SwiftUI

@main
struct FocusMirrorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("FocusMirror", id: "main") {
            RootWindowChrome {
                ContentView()
                    .environment(model)
            }
                .background(WindowConfigurator(contentSize: CGSize(width: 860, height: 470)))
                .frame(minWidth: 840, minHeight: 450)
        }
        .defaultSize(width: 860, height: 470)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarControlView()
                .environment(model)
        } label: {
            Image(systemName: menuBarSystemImage)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSystemImage: String {
        if model.isSessionActive {
            return "record.circle.fill"
        }
        if model.latestCompletedSession != nil {
            return "chart.pie.fill"
        }
        return "circle.grid.cross"
    }
}

private struct MenuBarControlView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var cameraMessage: String?
    @State private var isStarting = false

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()
                .overlay(Color.white.opacity(0.10))

            if model.isSessionActive {
                activeSessionControls
            } else if let session = model.latestCompletedSession {
                completedSessionSummary(session)
            } else {
                startSessionControls(model: model)
            }

            if let message = model.engineError ?? cameraMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.34, blue: 0.34))
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
        .padding(16)
        .frame(width: 306)
        .background(Color(red: 0.035, green: 0.043, blue: 0.060))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }

                Circle()
                    .stroke(headerAccent, lineWidth: 2.6)
                    .frame(width: 23, height: 23)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("FocusMirror")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text(headerStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
            }

            Spacer(minLength: 8)

            Button {
                showMainWindow()
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(HomeTheme.secondaryText)
            .help("Open FocusMirror")
        }
    }

    private var headerStatus: String {
        if model.isSessionActive {
            return "Camera active"
        }
        if model.latestCompletedSession != nil {
            return "Session complete"
        }
        return "Ready"
    }

    private var headerAccent: Color {
        if model.isSessionActive {
            return .red
        }
        if model.latestCompletedSession != nil {
            return MenuBarSummaryPalette.green
        }
        return HomeTheme.primaryBlue
    }

    private var activeSessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(model.activeSessionStartedAt ?? context.date)

                VStack(alignment: .leading, spacing: 5) {
                    Text(formatClock(elapsed))
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("Processing locally. No recording.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                }
            }

            Button(role: .destructive) {
                model.endSession()
            } label: {
                Label("End Session", systemImage: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(Color(red: 0.84, green: 0.12, blue: 0.16))
        }
    }

    private func completedSessionSummary(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 13) {
                MenuBarSummaryRing(progress: session.confirmedWorkRatio)
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Confirmed Work")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeTheme.secondaryText)

                    Text(menuBarPercent(session.confirmedWorkRatio))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("\(compactDuration(session.confirmedWorkSeconds)) of \(compactDuration(session.duration))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            MenuBarTimelineBar(session: session)
                .frame(height: 10)

            HStack(spacing: 7) {
                MenuBarSummaryMetric(
                    title: "Screen",
                    value: compactDuration(session.screenFocusedSeconds),
                    color: MenuBarSummaryPalette.green
                )

                MenuBarSummaryMetric(
                    title: "Review",
                    value: compactDuration(session.reviewSeconds),
                    color: MenuBarSummaryPalette.orange
                )

                MenuBarSummaryMetric(
                    title: "Corrected",
                    value: compactDuration(session.correctedSeconds),
                    color: MenuBarSummaryPalette.purple
                )
            }

            Button {
                cameraMessage = nil
                model.latestCompletedSession = nil
            } label: {
                Label("New Session", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(HomeTheme.primaryBlue)
        }
    }

    private func startSessionControls(model: AppModel) -> some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Length")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomeTheme.secondaryText)

                Picker("Length", selection: $model.selectedLength) {
                    ForEach(SessionLength.allCases) { length in
                        Text(length.label).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Button {
                startSessionFromMenu()
            } label: {
                Label(isStarting ? "Starting..." : "Start Session", systemImage: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(HomeTheme.primaryBlue)
            .disabled(isStarting)
        }
    }

    private func startSessionFromMenu() {
        guard !isStarting else { return }
        isStarting = true
        cameraMessage = nil

        Task {
            let status = await CameraPermission.request()

            await MainActor.run {
                isStarting = false
                guard status == .authorized else {
                    cameraMessage = "Camera permission is required before starting."
                    showMainWindow()
                    return
                }

                model.startSession()
            }
        }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.title == "FocusMirror" }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            return
        }

        openWindow(id: "main")
        DispatchQueue.main.async {
            NSApp.windows.first(where: { $0.title == "FocusMirror" })?.makeKeyAndOrderFront(nil)
        }
    }
}

private struct MenuBarSummaryRing: View {
    let progress: Double

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 7)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    MenuBarSummaryPalette.green,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MenuBarSummaryPalette.green)
        }
        .padding(4)
    }
}

private struct MenuBarTimelineBar: View {
    let session: FocusSession

    var body: some View {
        GeometryReader { geometry in
            if session.segments.isEmpty {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.10))
            } else {
                HStack(spacing: 1) {
                    ForEach(session.segments) { segment in
                        Rectangle()
                            .fill(segment.state.menuBarSummaryColor)
                            .frame(width: max(2, geometry.size.width * segment.duration / max(session.duration, 1)))
                            .overlay(alignment: .bottom) {
                                if segment.userCorrection == .actuallyFocused {
                                    Rectangle()
                                        .fill(MenuBarSummaryPalette.green)
                                        .frame(height: 2)
                                }
                            }
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
}

private struct MenuBarSummaryMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct MenuBarSummaryPalette {
    static let green = Color(red: 0.10, green: 0.84, blue: 0.38)
    static let red = Color(red: 0.92, green: 0.20, blue: 0.25)
    static let orange = Color(red: 1.00, green: 0.49, blue: 0.16)
    static let blue = Color(red: 0.12, green: 0.38, blue: 0.92)
    static let purple = Color(red: 0.58, green: 0.25, blue: 0.95)
    static let gray = Color(red: 0.42, green: 0.49, blue: 0.55)
}

private extension DetectionState {
    var menuBarSummaryColor: Color {
        switch self {
        case .focused: MenuBarSummaryPalette.green
        case .away: MenuBarSummaryPalette.red
        case .lookingDown: MenuBarSummaryPalette.orange
        case .talking: MenuBarSummaryPalette.blue
        case .eyesClosed: MenuBarSummaryPalette.purple
        case .uncertain: MenuBarSummaryPalette.gray
        }
    }
}

private func menuBarPercent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

private func compactDuration(_ seconds: TimeInterval) -> String {
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

private struct RootWindowChrome<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            HomeTheme.windowBackground
                .ignoresSafeArea()

            content
        }
        .background(HomeTheme.windowBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let contentSize: CGSize
    private let chromeBackground = NSColor(
        red: 0.016,
        green: 0.020,
        blue: 0.030,
        alpha: 1.0
    )

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = chromeBackground.cgColor
        DispatchQueue.main.async {
            configureWindow(for: view, context: context)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = chromeBackground.cgColor
        DispatchQueue.main.async {
            configureWindow(for: nsView, context: context)
        }
    }

    private func configureWindow(for view: NSView, context: Context) {
        guard let window = view.window else { return }

        window.title = "FocusMirror"
        window.appearance = NSAppearance(named: .darkAqua)
        window.isOpaque = true
        window.backgroundColor = chromeBackground
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true

        if window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.remove(.fullSizeContentView)
        }

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = chromeBackground.cgColor

        showNativeTrafficLights(in: window)

        if !context.coordinator.hasConfiguredSize {
            context.coordinator.hasConfiguredSize = true
            window.setContentSize(contentSize)
            window.center()
        }
    }

    private func showNativeTrafficLights(in window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for buttonType in buttonTypes {
            window.standardWindowButton(buttonType)?.isHidden = false
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var hasConfiguredSize = false
    }
}
