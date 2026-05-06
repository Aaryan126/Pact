import SwiftUI

@main
struct FocusMirrorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 1180, minHeight: 700)
        }
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
