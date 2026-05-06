import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [UUID]

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("History")
                .font(.system(size: 21, weight: .semibold))

            if model.sessions.isEmpty {
                Text("Past sessions will appear here.")
                    .font(.system(size: 14))
                    .foregroundStyle(HomeTheme.secondaryText)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(model.sessions) { session in
                            historyRow(for: session)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 31)
        .padding(.top, 32)
        .padding(.bottom, 28)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func historyRow(for session: FocusSession) -> some View {
        Button {
            path.append(session.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(Int((session.screenFocusedRatio * 100).rounded()))% screen focus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                }

                Spacer()

                Text(formatMinutes(session.duration))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
            }
            .padding(.horizontal, 18)
            .frame(height: 70)
            .background(HomeTheme.historyRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
