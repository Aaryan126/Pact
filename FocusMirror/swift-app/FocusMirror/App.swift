import SwiftUI

@main
struct FocusMirrorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("FocusMirror") {
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
            if model.isSessionActive {
                Text("Camera active")
                Button("End Session") {
                    model.endSession()
                }
            } else {
                Text("No active session")
            }
        } label: {
            Image(systemName: model.isSessionActive ? "record.circle.fill" : "circle")
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
