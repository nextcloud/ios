// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LocalAuthentication

/// Owns one passcode operation; persistent protection is shared through Keychain.
@MainActor
final class NCPasscodeModel: ObservableObject {
    enum Mode {
        case authenticate, create, change, disable
    }

    enum Result: Equatable {
        case authenticated, configured, disabled, cancelled, reset
    }

    private enum Step {
        case authenticate, enterNew, confirmNew
    }

    let mode: NCPasscodeModel.Mode
    let allowCancel: Bool
    @Published private(set) var digits = ""
    @Published private(set) var message = ""
    @Published private(set) var lockoutEnd: Date?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var result: NCPasscodeModel.Result?
    @Published private var step: Step
    var onCompletion: (@MainActor (NCPasscodeModel.Result) -> Void)?

    static var isPasscodeReset: Bool {
        NCPreferences().resetAppCounterFail && NCPreferences().passcodeCounterFailReset >= NCBrandOptions.shared.resetAppPasscodeAttempts
    }

    private var isPreview = false
    private var newPasscode = ""
    private var biometricContext: LAContext?
    private var biometricRequest = UUID()
    private var didStart = false
    private let preferences = NCPreferences()

    init(mode: NCPasscodeModel.Mode, allowCancel: Bool) {
        self.mode = mode
        self.allowCancel = allowCancel
        self.step = mode == .create ? .enterNew : .authenticate
    }

#if DEBUG
    /// Preview data never reads or changes stored credentials or starts biometrics.
    static func preview(mode: NCPasscodeModel.Mode = .authenticate, locked: Bool = false) -> NCPasscodeModel {
        let model = NCPasscodeModel(mode: mode, allowCancel: mode != .authenticate)
        model.isPreview = true
        model.digits = locked ? "" : "123"
        model.lockoutEnd = locked ? Date().addingTimeInterval(60) : nil
        return model
    }
#endif

    var title: String {
        switch step {
        case .authenticate: return "Enter Passcode"
        case .enterNew: return "Enter a new passcode"
        case .confirmNew: return "Confirm new passcode"
        }
    }

    var biometricSymbol: String? {
        if isPreview { return step == .authenticate ? "faceid" : nil }
        guard step == .authenticate, mode != .change, preferences.touchFaceID, preferences.passcode != nil else { return nil }
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return nil }
        return context.biometryType == .faceID ? "faceid" : "touchid"
    }

    var canEnterCode: Bool {
        result == nil && lockoutEnd == nil && !isAuthenticating
    }

    func start() async {
        guard !isPreview else { return }
        refreshProtection()
        guard !didStart else { return }
        didStart = true
        await authenticateWithBiometrics()
    }

    /// Re-read shared counters on foreground entry and while the lockout is visible.
    func refreshProtection() {
        guard !isPreview else { return }
        guard result == nil else { return }
        if let deadline = preferences.passcodeLockoutEnd, deadline <= Date() {
            // Expiring the retry delay must preserve the total used for the app-reset threshold.
            preferences.passcodeCounterFail = 0
            preferences.passcodeLockoutEnd = nil
        }
        if Self.isPasscodeReset {
            finish(.reset)
            return
        }
        if preferences.passcodeCounterFail >= 3 && preferences.passcodeLockoutEnd == nil {
            preferences.passcodeLockoutEnd = Date().addingTimeInterval(TimeInterval(NCBrandOptions.shared.passcodeSecondsFail))
        }
        lockoutEnd = preferences.passcodeLockoutEnd
        if lockoutEnd != nil {
            digits = ""
            cancelBiometrics()
        }
    }

    func append(_ digit: Int) {
        refreshProtection()
        guard canEnterCode, (0...9).contains(digit), digits.count < 6 else { return }
        message = ""
        digits += String(digit)
        if digits.count == 6 && !isPreview {
            submit()
        }
    }

    func deleteDigit() {
        guard canEnterCode, !digits.isEmpty else { return }
        digits.removeLast()
    }

    func cancel() {
        guard allowCancel else { return }
        finish(.cancelled)
    }

    func cancelBiometrics() {
        biometricRequest = UUID()
        biometricContext?.invalidate()
        biometricContext = nil
        isAuthenticating = false
    }

    func authenticateWithBiometrics() async {
        guard !isPreview else { return }
        refreshProtection()
        guard canEnterCode, biometricSymbol != nil else { return }
        let context = LAContext()
        let request = UUID()
        biometricRequest = request
        biometricContext = context
        isAuthenticating = true
        defer {
            if biometricRequest == request {
                biometricContext = nil
                isAuthenticating = false
            }
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                           localizedReason: NCBrandOptions.shared.brand)
            guard biometricRequest == request, result == nil else { return }
            refreshProtectionAfterBiometrics(success: success)
        } catch {
            guard biometricRequest == request, result == nil else { return }
            // Cancellation and choosing the keypad are not failed authentication attempts.
            if (error as? LAError)?.code == .authenticationFailed {
                registerFailure()
            }
        }
    }

    private func refreshProtectionAfterBiometrics(success: Bool) {
        refreshProtection()
        guard result == nil, lockoutEnd == nil else { return }
        if success {
            authenticated()
        }
    }

    private func submit() {
        let code = digits
        digits = ""
        switch step {
        case .authenticate:
            guard let saved = preferences.passcode, code == saved else {
                registerFailure()
                return
            }
            authenticated()
        case .enterNew:
            newPasscode = code
            step = .confirmNew
        case .confirmNew:
            guard code == newPasscode else {
                newPasscode = ""
                step = .enterNew
                message = "Passcodes didn't match. Try again."
                return
            }
            preferences.passcode = code
            preferences.clearPasscodeFailures()
            finish(.configured)
        }
    }

    private func authenticated() {
        preferences.clearPasscodeFailures()
        switch mode {
        case .change:
            step = .enterNew
        case .disable:
            guard !NCBrandOptions.shared.enforce_passcode_lock else { return }
            preferences.passcode = nil
            finish(.disabled)
        case .authenticate:
            finish(.authenticated)
        case .create:
            break
        }
    }

    private func registerFailure() {
        preferences.passcodeCounterFail += 1
        preferences.passcodeCounterFailReset += 1
        message = "_passcode_incorrect_"
        refreshProtection()
    }

    private func finish(_ result: NCPasscodeModel.Result) {
        guard self.result == nil else { return }
        self.result = result
        digits = ""
        newPasscode = ""
        cancelBiometrics()
        onCompletion?(result)
    }
}
