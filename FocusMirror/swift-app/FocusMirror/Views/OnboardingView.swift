import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var permissionStatus = CameraPermission.currentStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("FocusMirror")
                    .font(.system(size: 44, weight: .semibold))
                Text("An honest mirror of screen focus and confirmed work time.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                PrivacyFactRow(title: "Local processing", detail: "Camera frames are processed on this Mac and discarded.")
                PrivacyFactRow(title: "No network during sessions", detail: "The app has no network entitlement in the v1 bundle.")
                PrivacyFactRow(title: "No audio", detail: "FocusMirror does not request microphone access.")
                PrivacyFactRow(title: "Stored locally", detail: "Only timestamps, detected states, and your corrections are saved.")
            }
            .padding(.vertical, 8)

            HStack(spacing: 12) {
                Button(permissionStatus == .authorized ? "Continue" : "Grant Camera Access") {
                    Task {
                        if permissionStatus == .authorized {
                            onComplete()
                        } else {
                            permissionStatus = await CameraPermission.request()
                            if permissionStatus == .authorized {
                                onComplete()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if permissionStatus == .denied || permissionStatus == .restricted {
                    Text("Camera permission is required to measure sessions.")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(48)
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
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
