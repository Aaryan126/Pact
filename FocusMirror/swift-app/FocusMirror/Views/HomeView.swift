import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [UUID]
    @State private var cameraMessage: String?

    var body: some View {
        @Bindable var model = model

        ZStack {
            HomeTheme.windowBackground
                .ignoresSafeArea()

            HStack(spacing: 24) {
                startPanel(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                HistoryView(path: $path)
                    .frame(width: 470)
            }
            .padding(.horizontal, 28)
            .padding(.top, 44)
            .padding(.bottom, 42)
        }
        .navigationTitle("")
    }

    private func startPanel(model: AppModel) -> some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                AppMark()
                    .padding(.bottom, 36)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Start session")
                        .font(.system(size: 48, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)

                    Text("FocusMirror observes silently and summarizes screen focus\nafter you end the session.")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(HomeTheme.secondaryText)
                        .lineSpacing(6)
                        .lineLimit(2)
                        .fixedSize(horizontal: true, vertical: true)
                }

                Rectangle()
                    .fill(HomeTheme.border)
                    .frame(height: 1)
                    .padding(.top, 34)
                    .padding(.bottom, 31)

                VStack(alignment: .leading, spacing: 18) {
                    Text("Length")
                        .font(.system(size: 24, weight: .semibold))

                    SessionLengthSegmentedControl(selection: $model.selectedLength)
                        .frame(height: 58)
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
                    Label("Start", systemImage: "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(HomeTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.top, 42)

                if let error = model.engineError ?? cameraMessage {
                    Text(error)
                        .foregroundStyle(Color(red: 1.0, green: 0.28, blue: 0.30))
                        .font(.system(size: 16, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 54)
        .padding(.top, 60)
        .padding(.bottom, 46)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(HomeTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(HomeTheme.panelStroke, lineWidth: 1)
        }
    }
}

private struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }

            Circle()
                .stroke(HomeTheme.primaryBlue, lineWidth: 5)
                .frame(width: 34, height: 34)

            Circle()
                .stroke(HomeTheme.primaryBlue.opacity(0.55), lineWidth: 4)
                .frame(width: 48, height: 48)
        }
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 10)
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
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(selection == length ? .white : HomeTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if selection == length {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(HomeTheme.primaryBlue)
                            .padding(2)
                    }
                }

                if index < SessionLength.allCases.count - 1 {
                    Rectangle()
                        .fill(HomeTheme.segmentDivider)
                        .frame(width: 1, height: 34)
                }
            }
        }
        .background(HomeTheme.segmentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

enum HomeTheme {
    static let windowBackground = Color(red: 0.045, green: 0.046, blue: 0.047)
    static let panelBackground = LinearGradient(
        colors: [
            Color(red: 0.078, green: 0.080, blue: 0.083),
            Color(red: 0.040, green: 0.044, blue: 0.045)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let historyRowBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.105),
            Color.white.opacity(0.045)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panelStroke = Color.white.opacity(0.13)
    static let border = Color.white.opacity(0.12)
    static let secondaryText = Color.white.opacity(0.62)
    static let primaryBlue = Color(red: 0.02, green: 0.43, blue: 0.96)
    static let segmentBackground = Color.white.opacity(0.065)
    static let segmentDivider = Color.white.opacity(0.16)
}
