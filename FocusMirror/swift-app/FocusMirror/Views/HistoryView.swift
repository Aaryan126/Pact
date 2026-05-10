import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    let openSession: (UUID) -> Void
    @State private var isConfirmingDeleteAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("History")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(HomeTheme.primaryText)

                Spacer()

                if !model.sessions.isEmpty {
                    Button(role: .destructive) {
                        isConfirmingDeleteAll = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HomeTheme.secondaryText)
                    .help("Delete all local session history")
                }
            }
            .frame(width: 334)

            if model.sessions.isEmpty {
                Text("Past sessions will appear here.")
                    .font(.system(size: 14))
                    .foregroundStyle(HomeTheme.secondaryText)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.sessions) { session in
                            historyRow(for: session)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.leading, 32)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .alert("Delete all session history?", isPresented: $isConfirmingDeleteAll) {
            Button("Delete", role: .destructive) {
                model.deleteAllSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes local FocusMirror session records from this Mac.")
        }
    }

    private func historyRow(for session: FocusSession) -> some View {
        Button {
            openSession(session.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(HomeTheme.subtleBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(HomeTheme.border, lineWidth: 1)
                        }

                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(HomeTheme.primaryBlue)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 7) {
                    Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                    Text("\(formatWholePercent(session.screenFocusedRatio)) focused")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HomeTheme.secondaryText)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .medium))
                    Text(formatMinutes(session.duration))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(HomeTheme.secondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .frame(width: 334, height: 72)
            .background(HomeTheme.historyRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(HomeTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
