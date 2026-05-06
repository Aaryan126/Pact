import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var path: [UUID] = []

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            NavigationStack(path: $path) {
                Group {
                    if !hasCompletedOnboarding {
                        OnboardingView {
                            hasCompletedOnboarding = true
                        }
                    } else if model.isSessionActive {
                        ActiveSessionView {
                            model.endSession()
                            if let completed = model.latestCompletedSession {
                                path.append(completed.id)
                            }
                        }
                    } else {
                        HomeView(path: $path)
                    }
                }
                .background(Color.black.ignoresSafeArea())
                .navigationDestination(for: UUID.self) { sessionID in
                    SessionSummaryView(sessionID: sessionID)
                        .background(Color.black.ignoresSafeArea())
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
