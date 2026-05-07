import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    let openSession: (UUID) -> Void
    @State private var cameraMessage: String?

    var body: some View {
        @Bindable var model = model

        ZStack {
            HomeTheme.windowBackground
                .ignoresSafeArea()

            HStack(spacing: 0) {
                startPanel(model: model)
                    .frame(width: 430, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .leading)

                Rectangle()
                    .fill(HomeTheme.border)
                    .frame(width: 1)

                HistoryView(openSession: openSession)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
    }

    private func startPanel(model: AppModel) -> some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 0) {
            AppMark()
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 12) {
                Text("Start session")
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)

                Text("FocusMirror observes silently and\nsummarizes screen focus after you\nend the session.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: true, vertical: true)
            }

            Rectangle()
                .fill(HomeTheme.border)
                .frame(height: 1)
                .padding(.top, 15)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 9) {
                Text("Length")
                    .font(.system(size: 15, weight: .semibold))

                SessionLengthSegmentedControl(selection: $model.selectedLength)
                    .frame(width: 318, height: 34)
            }

            Button {
                Task {
                    let status = await CameraPermission.request()
                    guard status == .authorized else {
                        cameraMessage = "Camera permission is required before starting."
                        return
                    }
                    model.startSession()
                }
            } label: {
                ZStack {
                    HomeTheme.primaryBlue
                    Label("Start", systemImage: "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 318, height: 43)
            }
            .buttonStyle(.plain)
            .frame(width: 318, height: 43)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.top, 20)

            if let error = model.engineError ?? cameraMessage {
                Text(error)
                    .foregroundStyle(Color(red: 1.0, green: 0.28, blue: 0.30))
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
        }
        .frame(width: 318, alignment: .leading)
        .padding(.leading, 66)
        .frame(maxHeight: .infinity, alignment: .leading)
    }
}

private struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                }

            Circle()
                .stroke(HomeTheme.primaryBlue, lineWidth: 4.5)
                .frame(width: 41, height: 41)

            Circle()
                .stroke(HomeTheme.primaryBlue.opacity(0.70), lineWidth: 4)
                .frame(width: 52, height: 52)
        }
        .frame(width: 60, height: 60)
        .shadow(color: .black.opacity(0.38), radius: 14, x: 0, y: 8)
    }
}

private struct SessionLengthSegmentedControl: View {
    @Binding var selection: SessionLength

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(SessionLength.allCases.enumerated()), id: \.element.id) { index, length in
                Button {
                    selection = length
                } label: {
                    Text(length.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == length ? .white : HomeTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if selection == length {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(HomeTheme.primaryBlue)
                            .padding(2)
                    }
                }

                if index < SessionLength.allCases.count - 1 {
                    Rectangle()
                        .fill(HomeTheme.segmentDivider)
                        .frame(width: 1, height: 24)
                }
            }
        }
        .background(HomeTheme.segmentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

enum HomeTheme {
    static let chromeBackground = Color(red: 0.010, green: 0.013, blue: 0.020)
    static let windowBackground = LinearGradient(
        colors: [
            Color(red: 0.035, green: 0.043, blue: 0.060),
            Color(red: 0.006, green: 0.008, blue: 0.014)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panelBackground = windowBackground
    static let historyRowBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.105),
            Color.white.opacity(0.045)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panelStroke = Color.white.opacity(0.13)
    static let border = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.62)
    static let primaryBlue = Color(red: 0.02, green: 0.40, blue: 0.98)
    static let segmentBackground = Color.white.opacity(0.045)
    static let segmentDivider = Color.white.opacity(0.16)
}
