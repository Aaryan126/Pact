import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [UUID]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("History")
                .font(.system(size: 29, weight: .semibold))
                .padding(.top, 2)

            if model.sessions.isEmpty {
                Text("Past sessions will appear here.")
                    .font(.system(size: 19))
                    .foregroundStyle(HomeTheme.secondaryText)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.sessions) { session in
                            historyRow(for: session)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 30)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(HomeTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(HomeTheme.panelStroke, lineWidth: 1)
        }
    }

    private func historyRow(for session: FocusSession) -> some View {
        Button {
            path.append(session.id)
        } label: {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(Int((session.screenFocusedRatio * 100).rounded()))% screen focus")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                }

                Spacer()

                Text(formatMinutes(session.duration))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
            }
            .padding(.horizontal, 20)
            .frame(height: 94)
            .background(HomeTheme.historyRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
