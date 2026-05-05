import SwiftUI

struct ActiveSessionView: View {
    @Environment(AppModel.self) private var model
    let endSession: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text("Camera on. Processing locally. No recording.")
                        .foregroundStyle(.secondary)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(model.activeSessionStartedAt ?? context.date)
                    Text(formatClock(elapsed))
                        .font(.system(size: 64, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
            }

            Button(role: .destructive) {
                endSession()
            } label: {
                Label("End session", systemImage: "stop.fill")
                    .frame(width: 180)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if let error = model.engineError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
            }
            Spacer()
        }
        .padding(48)
    }
}
