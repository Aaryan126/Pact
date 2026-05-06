import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedSessionID: UUID?

    var body: some View {
        ZStack {
            HomeTheme.windowBackground
                .ignoresSafeArea()

            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else if model.isSessionActive {
                ActiveSessionView {
                    model.endSession()
                    if let completed = model.latestCompletedSession {
                        selectedSessionID = completed.id
                    }
                }
            } else if let selectedSessionID {
                SessionSummaryView(sessionID: selectedSessionID) {
                    self.selectedSessionID = nil
                }
            } else {
                HomeView { sessionID in
                    selectedSessionID = sessionID
                }
            }
        }
        .background(HomeTheme.windowBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
