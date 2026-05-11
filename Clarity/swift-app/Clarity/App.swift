import AppKit
import SwiftUI

private let mainWindowIdentifier = NSUserInterfaceItemIdentifier("ClarityMainWindow")

@main
struct ClarityApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("", id: "main") {
            RootWindowChrome(appearanceMode: model.appearanceMode) {
                ContentView()
                    .environment(model)
            }
                .background(
                    WindowConfigurator(
                        contentSize: CGSize(width: 1160, height: 720),
                        appearanceMode: model.appearanceMode
                    )
                )
                .frame(minWidth: 960, minHeight: 620)
        }
        .defaultSize(width: 1160, height: 720)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarControlView()
                .environment(model)
                .preferredColorScheme(model.appearanceMode.colorScheme)
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
                .overlay(HomeTheme.divider)

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

            Divider()
                .overlay(HomeTheme.divider)

            AppearanceModePicker(selection: $model.appearanceMode)

        }
        .padding(16)
        .frame(width: 306)
        .background(HomeTheme.cardBackground)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(HomeTheme.subtleBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(HomeTheme.border, lineWidth: 1)
                    }

                Circle()
                    .stroke(headerAccent, lineWidth: 2.6)
                    .frame(width: 23, height: 23)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Clarity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeTheme.primaryText)

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
            .help("Open Clarity")
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
            return DetectionState.focused.color
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
                        .foregroundStyle(HomeTheme.primaryText)

                    Text(activeSessionDetail(elapsed: elapsed))
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

    private func activeSessionDetail(elapsed: TimeInterval) -> String {
        guard let target = model.activeTargetDurationSeconds else {
            return "Open-ended. Processing locally."
        }
        return "\(formatClock(max(0, target - elapsed))) remaining. No recording."
    }

    private func completedSessionSummary(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 13) {
                MenuBarSummaryRing(progress: session.screenFocusedRatio)
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Focused Work")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeTheme.secondaryText)

                    Text(formatWholePercent(session.screenFocusedRatio))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(HomeTheme.primaryText)

                    Text("\(formatCompactDuration(session.screenFocusedSeconds)) of \(formatCompactDuration(session.duration))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            MenuBarTimelineBar(session: session)
                .frame(height: 10)

            HStack(spacing: 7) {
                MenuBarSummaryMetric(
                    title: "Focused",
                    value: formatCompactDuration(session.detectedSummary(for: .focused).seconds),
                    color: DetectionState.focused.color
                )

                MenuBarSummaryMetric(
                    title: "Looking",
                    value: formatCompactDuration(session.detectedSummary(for: .lookingDown).seconds),
                    color: DetectionState.lookingDown.color
                )

                MenuBarSummaryMetric(
                    title: "Away",
                    value: formatCompactDuration(session.detectedSummary(for: .away).seconds),
                    color: DetectionState.away.color
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

        if let window = NSApp.windows.first(where: { $0.identifier == mainWindowIdentifier }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            return
        }

        openWindow(id: "main")
        DispatchQueue.main.async {
            NSApp.windows.first(where: { $0.identifier == mainWindowIdentifier })?.makeKeyAndOrderFront(nil)
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
                .stroke(HomeTheme.border, lineWidth: 7)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    DetectionState.focused.color,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DetectionState.focused.color)
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
                    .fill(HomeTheme.subtleBackground)
            } else {
                ZStack(alignment: .leading) {
                    ForEach(session.segments) { segment in
                        Rectangle()
                            .fill(segment.state.color)
                            .frame(
                                width: max(
                                    1,
                                    min(
                                        geometry.size.width - segmentX(segment, width: geometry.size.width),
                                        geometry.size.width * segment.duration / max(session.duration, 1)
                                    )
                                )
                            )
                            .offset(x: segmentX(segment, width: geometry.size.width))
                            .overlay(alignment: .bottom) {
                                if segment.userCorrection == .actuallyFocused {
                                    Rectangle()
                                        .fill(DetectionState.focused.color)
                                        .frame(height: 2)
                                }
                            }
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
        width * segment.startSeconds / max(session.duration, 1)
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
                .foregroundStyle(HomeTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(HomeTheme.border, lineWidth: 1)
        }
    }
}

private struct RootWindowChrome<Content: View>: View {
    let appearanceMode: AppAppearanceMode
    let content: Content

    init(appearanceMode: AppAppearanceMode, @ViewBuilder content: () -> Content) {
        self.appearanceMode = appearanceMode
        self.content = content()
    }

    var body: some View {
        ZStack {
            HomeTheme.windowBackground
                .ignoresSafeArea()

            content
        }
        .background(HomeTheme.windowBackground.ignoresSafeArea())
        .preferredColorScheme(appearanceMode.colorScheme)
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let contentSize: CGSize
    let appearanceMode: AppAppearanceMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = HomeTheme.chromeNSColor(for: appearanceMode).cgColor
        DispatchQueue.main.async {
            configureWindow(for: view, context: context)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = HomeTheme.chromeNSColor(for: appearanceMode).cgColor
        DispatchQueue.main.async {
            configureWindow(for: nsView, context: context)
        }
    }

    private func configureWindow(for view: NSView, context: Context) {
        guard let window = view.window else { return }
        let chromeBackground = HomeTheme.chromeNSColor(for: appearanceMode)

        window.identifier = mainWindowIdentifier
        window.title = ""
        window.appearance = NSAppearance(named: appearanceMode.nsAppearanceName)
        window.isOpaque = true
        window.backgroundColor = chromeBackground
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        if window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.remove(.fullSizeContentView)
        }

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = chromeBackground.cgColor

        showNativeTrafficLights(in: window)
        context.coordinator.installTitlebarHeightAccessory(in: window)

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
        private weak var window: NSWindow?
        private var titlebarHeightAccessory: NSTitlebarAccessoryViewController?

        func installTitlebarHeightAccessory(in window: NSWindow) {
            if self.window !== window {
                removeTitlebarHeightAccessory()
                self.window = window
            }

            guard titlebarHeightAccessory == nil else { return }

            let spacerView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 54))
            spacerView.wantsLayer = true
            spacerView.layer?.backgroundColor = NSColor.clear.cgColor
            spacerView.alphaValue = 0

            let accessory = NSTitlebarAccessoryViewController()
            accessory.view = spacerView
            accessory.layoutAttribute = .right
            window.addTitlebarAccessoryViewController(accessory)

            titlebarHeightAccessory = accessory
        }

        private func removeTitlebarHeightAccessory() {
            if let titlebarHeightAccessory, let window,
               let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === titlebarHeightAccessory }) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            titlebarHeightAccessory = nil
        }
    }
}

extension AppAppearanceMode {
    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    var nsAppearanceName: NSAppearance.Name {
        switch self {
        case .light: .aqua
        case .dark: .darkAqua
        }
    }
}
