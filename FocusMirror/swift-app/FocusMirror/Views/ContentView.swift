import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var path: [UUID] = []

    var body: some View {
        ZStack {
            HomeTheme.windowBackground
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
                .background(HomeTheme.windowBackground.ignoresSafeArea())
                .navigationDestination(for: UUID.self) { sessionID in
                    SessionSummaryView(sessionID: sessionID)
                        .background(HomeTheme.windowBackground.ignoresSafeArea())
                }
            }
            .background(HomeTheme.windowBackground.ignoresSafeArea())
        }
        .background(HomeTheme.windowBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
