import SwiftUI

@main
struct FocusMirrorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("FocusMirror") {
            ContentView()
                .environment(model)
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

private struct WindowConfigurator: NSViewRepresentable {
    let contentSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window, !context.coordinator.hasConfigured else { return }
            context.coordinator.hasConfigured = true
            window.title = "FocusMirror"
            window.setContentSize(contentSize)
            window.center()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Coordinator {
        var hasConfigured = false
    }
}
