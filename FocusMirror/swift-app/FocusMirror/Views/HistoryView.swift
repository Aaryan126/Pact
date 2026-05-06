import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [UUID]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History")
                .font(.title2.weight(.semibold))

            if model.sessions.isEmpty {
                Text("Past sessions will appear here.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(model.sessions) { session in
                    Button {
                        path.append(session.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.primary)
                            HStack {
                                Text("\(Int((session.screenFocusedRatio * 100).rounded()))% screen focus")
                                Spacer()
                                Text(formatMinutes(session.duration))
                            }
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .padding(24)
    }
}
