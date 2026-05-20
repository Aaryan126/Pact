import SwiftUI

struct OnboardingView: View {
    @Environment(\.scenePhase) private var scenePhase
    let onComplete: () -> Void
    @State private var permissionStatus = CameraPermission.currentStatus
    @State private var hasCameraDevice = CameraPermission.hasVideoCaptureDevice

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

            VStack(alignment: .leading, spacing: 14) {
                PermissionStatusRow(
                    title: "Camera access required",
                    detail: permissionDetail,
                    systemImage: permissionSystemImage,
                    color: permissionColor
                )

                Button(permissionButtonTitle) {
                    Task {
                        refreshPermissionState()
                        guard hasCameraDevice else { return }

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

                if !canContinue {
                    Text(permissionResolutionMessage)
                        .foregroundStyle(HomeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(48)
        .onAppear {
            refreshPermissionState()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshPermissionState()
            }
        }
    }

    private var canContinue: Bool {
        hasCameraDevice && permissionStatus == .authorized
    }

    private var permissionButtonTitle: String {
        guard hasCameraDevice else { return "Connect Camera" }
        switch permissionStatus {
        case .authorized:
            return "Continue"
        case .notDetermined:
            return "Allow Camera Access"
        case .denied, .restricted:
            return "Open Camera Settings"
        }
    }

    private var permissionDetail: String {
        guard hasCameraDevice else {
            return "Connect a camera before starting. Clarity cannot measure sessions without one."
        }
        switch permissionStatus {
        case .authorized:
            return "Camera access is on. Clarity can run local focus sessions."
        case .notDetermined:
            return "Allow camera access to use Clarity. No images or video are saved."
        case .denied, .restricted:
            return "Camera access is off. Turn it on in System Settings to use Clarity."
        }
    }

    private var permissionResolutionMessage: String {
        guard hasCameraDevice else {
            return "Connect a built-in or external camera, then reopen Clarity."
        }
        return CameraPermission.settingsGuidanceMessage
    }

    private var permissionSystemImage: String {
        guard hasCameraDevice else { return "video.slash.fill" }
        return permissionStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var permissionColor: Color {
        guard hasCameraDevice else { return Color(red: 1.0, green: 0.34, blue: 0.34) }
        return permissionStatus == .authorized ? .green : Color(red: 1.0, green: 0.34, blue: 0.34)
    }

    private func refreshPermissionState() {
        hasCameraDevice = CameraPermission.hasVideoCaptureDevice
        permissionStatus = CameraPermission.currentStatus
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

private struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HomeTheme.primaryText)
                Text(detail)
                    .foregroundStyle(HomeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
