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
        .onChange(of: model.isSessionActive) { _, isActive in
            if isActive {
                selectedSessionID = nil
            }
        }
        .onChange(of: model.latestCompletedSession?.id) { _, sessionID in
            if let sessionID {
                selectedSessionID = sessionID
            }
        }
    }
}
