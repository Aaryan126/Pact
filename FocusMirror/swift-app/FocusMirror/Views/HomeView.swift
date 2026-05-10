import AppKit
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
            HStack(alignment: .top) {
                AppMark()

                Spacer()

                AppearanceModePicker(selection: $model.appearanceMode)
                    .frame(width: 138)
                    .padding(.top, 5)
            }
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 12) {
                Text("Start session")
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .foregroundStyle(HomeTheme.primaryText)

                Text("FocusMirror observes silently and\nsummarizes focused time after you\nend the session.")
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
                    .foregroundStyle(HomeTheme.primaryText)

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
                            HomeTheme.markHighlight,
                            HomeTheme.markBase
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(HomeTheme.border, lineWidth: 1)
                }

            Circle()
                .stroke(HomeTheme.primaryBlue, lineWidth: 4.5)
                .frame(width: 41, height: 41)

            Circle()
                .stroke(HomeTheme.primaryBlue.opacity(0.70), lineWidth: 4)
                .frame(width: 52, height: 52)
        }
        .frame(width: 60, height: 60)
        .shadow(color: HomeTheme.shadow, radius: 14, x: 0, y: 8)
    }
}

struct AppearanceModePicker: View {
    @Binding var selection: AppAppearanceMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppAppearanceMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selection == mode ? .white : HomeTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if selection == mode {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(HomeTheme.primaryBlue)
                            .padding(2)
                    }
                }
            }
        }
        .background(HomeTheme.segmentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(HomeTheme.border, lineWidth: 1)
        }
        .accessibilityLabel("Appearance")
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
                .stroke(HomeTheme.border, lineWidth: 1)
        }
    }
}

enum HomeTheme {
    static let chromeBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.970, green: 0.975, blue: 0.982, alpha: 1),
        dark: NSColor(calibratedRed: 0.010, green: 0.013, blue: 0.020, alpha: 1)
    )
    static let windowBackground = LinearGradient(
        colors: [
            adaptiveColor(
                light: NSColor(calibratedRed: 0.988, green: 0.991, blue: 0.996, alpha: 1),
                dark: NSColor(calibratedRed: 0.035, green: 0.043, blue: 0.060, alpha: 1)
            ),
            adaptiveColor(
                light: NSColor(calibratedRed: 0.954, green: 0.963, blue: 0.974, alpha: 1),
                dark: NSColor(calibratedRed: 0.006, green: 0.008, blue: 0.014, alpha: 1)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panelBackground = windowBackground
    static let historyRowBackground = LinearGradient(
        colors: [
            adaptiveColor(
                light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.92),
                dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.105)
            ),
            adaptiveColor(
                light: NSColor(calibratedRed: 0.982, green: 0.986, blue: 0.992, alpha: 0.86),
                dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.045)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panelStroke = adaptiveColor(
        light: NSColor(calibratedRed: 0.824, green: 0.847, blue: 0.878, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.13)
    )
    static let border = adaptiveColor(
        light: NSColor(calibratedRed: 0.850, green: 0.870, blue: 0.895, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.08)
    )
    static let divider = adaptiveColor(
        light: NSColor(calibratedRed: 0.890, green: 0.902, blue: 0.918, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.10)
    )
    static let primaryText = adaptiveColor(
        light: NSColor(calibratedRed: 0.035, green: 0.045, blue: 0.062, alpha: 1),
        dark: NSColor(calibratedRed: 0.970, green: 0.980, blue: 0.995, alpha: 1)
    )
    static let secondaryText = adaptiveColor(
        light: NSColor(calibratedRed: 0.390, green: 0.420, blue: 0.480, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.62)
    )
    static let primaryBlue = Color(red: 0.02, green: 0.40, blue: 0.98)
    static let segmentBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.918, green: 0.934, blue: 0.956, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.045)
    )
    static let segmentDivider = adaptiveColor(
        light: NSColor(calibratedRed: 0.810, green: 0.836, blue: 0.875, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.16)
    )
    static let cardBackground = adaptiveColor(
        light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.96),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.055)
    )
    static let subtleBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.960, green: 0.968, blue: 0.980, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.040)
    )
    static let markHighlight = adaptiveColor(
        light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.12)
    )
    static let markBase = adaptiveColor(
        light: NSColor(calibratedRed: 0.930, green: 0.946, blue: 0.968, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.035)
    )
    static let shadow = adaptiveColor(
        light: NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.110, alpha: 0.10),
        dark: NSColor(calibratedRed: 0.000, green: 0.000, blue: 0.000, alpha: 0.38)
    )

    static func chromeNSColor(for mode: AppAppearanceMode) -> NSColor {
        switch mode {
        case .light:
            NSColor(calibratedRed: 0.970, green: 0.975, blue: 0.982, alpha: 1)
        case .dark:
            NSColor(calibratedRed: 0.010, green: 0.013, blue: 0.020, alpha: 1)
        }
    }

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return bestMatch == .darkAqua ? dark : light
        })
    }
}
