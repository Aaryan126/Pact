import SwiftUI

struct ActiveSessionView: View {
    @Environment(AppModel.self) private var model
    let endSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 42) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 14, height: 14)
                    Text("Camera on. Processing locally. No recording.")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(model.activeSessionStartedAt ?? context.date)
                    Text(formatClock(elapsed))
                        .font(.system(size: 110, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }

                Button(role: .destructive) {
                    endSession()
                } label: {
                    Label("End session", systemImage: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 240, height: 42)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if let error = model.engineError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
                    .padding(.top, 28)
            }

            Spacer()
        }
        .padding(64)
    }
}
