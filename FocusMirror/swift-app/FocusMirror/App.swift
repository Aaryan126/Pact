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
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Color.black
                Text("FocusMirror")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.64))
                    .padding(.leading, 80)
            }
            .frame(height: 31)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }

            content
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let contentSize: CGSize
    private let chromeBackground = NSColor.black

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
    }

    final class Coordinator {
        var hasConfiguredSize = false
    }
}
