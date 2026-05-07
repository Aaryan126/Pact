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
            Image(systemName: model.isSessionActive ? "record.circle.fill" : "circle.grid.cross")
        }
        .menuBarExtraStyle(.window)
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
                    .stroke(model.isSessionActive ? Color.red : HomeTheme.primaryBlue, lineWidth: 2.6)
                    .frame(width: 23, height: 23)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("FocusMirror")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text(model.isSessionActive ? "Camera active" : "Ready")
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
