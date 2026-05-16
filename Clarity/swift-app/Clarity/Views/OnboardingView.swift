import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var permissionStatus = CameraPermission.currentStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("Clarity")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(HomeTheme.primaryText)
                Text("An honest mirror of focused work time.")
                    .font(.title3)
                    .foregroundStyle(HomeTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 14) {
                PrivacyFactRow(title: "Local processing", detail: "Camera frames are processed on this Mac and discarded.")
                PrivacyFactRow(title: "No network during sessions", detail: "The app has no network entitlement in the v1 bundle.")
                PrivacyFactRow(title: "No audio", detail: "Clarity does not request microphone access.")
                PrivacyFactRow(title: "Stored locally", detail: "Only timestamps, detected states, and your corrections are saved.")
                PrivacyFactRow(title: "User-controlled export", detail: "CSV files are written only when you choose an export destination.")
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                Button(permissionStatus.showsSettingsAction ? "Open Settings" : "Continue") {
                    Task {
                        switch permissionStatus {
                        case .authorized:
                            onComplete()
                        case .notDetermined:
                            permissionStatus = await CameraPermission.request()
                            if permissionStatus == .authorized {
                                onComplete()
                            }
                        case .denied, .restricted:
                            CameraPermission.openSettings()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if permissionStatus.showsSettingsAction {
                    Text(CameraPermission.settingsGuidanceMessage)
                        .foregroundStyle(HomeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(48)
        .onAppear {
            permissionStatus = CameraPermission.currentStatus
        }
    }
}

private struct PrivacyFactRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.green)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HomeTheme.primaryText)
                Text(detail)
                    .foregroundStyle(HomeTheme.secondaryText)
            }
        }
    }
}
