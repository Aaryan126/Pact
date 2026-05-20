import AppKit
import AVFoundation
import Foundation

enum CameraPermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted

    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        @unknown default: self = .restricted
        }
    }
}

enum CameraPermission {
    static let settingsGuidanceMessage =
        "Camera access is needed to measure focus sessions. You can continue after enabling camera access in System Settings."

    static var currentStatus: CameraPermissionStatus {
        CameraPermissionStatus(AVCaptureDevice.authorizationStatus(for: .video))
    }

    static var hasVideoCaptureDevice: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    static func request() async -> CameraPermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else {
            return CameraPermissionStatus(status)
        }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : CameraPermissionStatus(AVCaptureDevice.authorizationStatus(for: .video))
    }

    @MainActor
    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension CameraPermissionStatus {
    var showsSettingsAction: Bool {
        switch self {
        case .denied, .restricted:
            return true
        case .authorized, .notDetermined:
            return false
        }
    }
}
