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
    static var currentStatus: CameraPermissionStatus {
        CameraPermissionStatus(AVCaptureDevice.authorizationStatus(for: .video))
    }

    static func request() async -> CameraPermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : CameraPermissionStatus(AVCaptureDevice.authorizationStatus(for: .video))
    }
}
