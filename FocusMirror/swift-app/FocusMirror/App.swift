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
        .windowStyle(.hiddenTitleBar)
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

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 28)

                content
            }
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = chromeBackground.cgColor

        if !context.coordinator.hasConfiguredSize {
            context.coordinator.hasConfiguredSize = true
            window.setContentSize(contentSize)
            window.center()
        }

        positionTrafficLights(in: window)
    }

    private func positionTrafficLights(in window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }
        guard let firstButton = buttons.first, let buttonSuperview = firstButton.superview else { return }

        let buttonSize = firstButton.frame.size
        let originX: CGFloat = 22
        let centerYFromTop: CGFloat = 42
        let originY = buttonSuperview.bounds.height - centerYFromTop - (buttonSize.height / 2)

        for (index, button) in buttons.enumerated() {
            button.setFrameOrigin(
                CGPoint(
                    x: originX + CGFloat(index) * 19,
                    y: originY
                )
            )
        }
    }

    final class Coordinator {
        var hasConfiguredSize = false
    }
}
