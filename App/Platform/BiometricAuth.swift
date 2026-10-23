// ARMOR-IOS-CONTROL - the phone's own question (Face ID, Touch ID or the passcode) put to the person, with LocalAuthentication and nothing else to install.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import LocalAuthentication
import ArmorCore

struct PhoneAuth: DeviceAuth {
    func availability() -> LockAvailability {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { return .biometric }
        // Face ID/Touch ID missing or not enrolled: the passcode alone still works if the phone has one
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) ? .deviceCredential : .none
    }

    func authenticate(title: String, subtitle: String) async -> AuthResult {
        let context = LAContext()
        context.localizedReason = subtitle
        var error: NSError?
        // deviceOwnerAuthentication: Face ID or Touch ID, with the passcode of the phone as the way out of it
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return .unavailable }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: subtitle)
            return ok ? .success : .failed("")
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel, .userFallback: return .cancelled
            case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled: return .unavailable
            default: return .failed(error.localizedDescription)
            }
        } catch { return .failed(error.localizedDescription) }
    }
}
