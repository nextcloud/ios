// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import LocalAuthentication

public protocol NCPasscodeDelegate: AnyObject {
    func evaluatePolicy(_ passcodeViewController: TOPasscodeViewController, isCorrectCode: Bool)
    func passcodeReset(_ passcodeViewController: TOPasscodeViewController)
    func requestedAccount(controller: UIViewController?)
}

public extension NCPasscodeDelegate {
    func evaluatePolicy(_ passcodeViewController: TOPasscodeViewController, isCorrectCode: Bool) {}
    func passcodeReset(_ passcodeViewController: TOPasscodeViewController) {}
    func requestedAccount(controller: UIViewController?) {}
}

class NCPasscode: NSObject, TOPasscodeViewControllerDelegate {
    public static let shared: NCPasscode = {
        let instance = NCPasscode()
        return instance
    }()
    var isPasscodeReset: Bool {
        let passcodeCounterFailReset = NCPreferences().passcodeCounterFailReset
        return NCPreferences().resetAppCounterFail && passcodeCounterFailReset >= NCBrandOptions.shared.resetAppPasscodeAttempts
    }

    var isPasscodeCounterFail: Bool {
        let passcodeCounterFail = NCPreferences().passcodeCounterFail
        return passcodeCounterFail >= 3
    }

    var passcodeViewController: TOPasscodeViewController!
    var delegate: NCPasscodeDelegate?
    var viewController: UIViewController?

    override init() {
        super.init()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    func presentPasscode(viewController: UIViewController, delegate: NCPasscodeDelegate?, completion: @escaping () -> Void) {
        if viewController.presentedViewController is TOPasscodeViewController { return }

        var error: NSError?
        self.delegate = delegate
        self.viewController = viewController

        passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: false)
        passcodeViewController.delegate = self
        passcodeViewController.keypadButtonShowLettering = false
        if NCPreferences().touchFaceID, LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if error == nil {
                if LAContext().biometryType == .faceID {
                    passcodeViewController.biometryType = .faceID
                } else if LAContext().biometryType == .touchID {
                    passcodeViewController.biometryType = .touchID
                }
                passcodeViewController.allowBiometricValidation = true
                passcodeViewController.automaticallyPromptForBiometricValidation = false
            }
        }
        viewController.presentedViewController?.dismiss(animated: false)
        viewController.present(passcodeViewController, animated: true, completion: {
            // `present` always runs on main thread so this assumption is correct.
            MainActor.assumeIsolated {
                self.presentTooManyFailedAttemptsAlertIfNeeded(passcodeViewController: self.passcodeViewController)
            }
            completion()
        })
    }

    func enableTouchFaceID() {
        guard NCPreferences().touchFaceID,
              NCPreferences().presentPasscode,
              !isPasscodeCounterFail,
              let passcodeViewController
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, evaluateError in
                if success {
                    DispatchQueue.main.async {
                        passcodeViewController.dismiss(animated: true) {
                            NCPreferences().passcodeCounterFail = 0
                            NCPreferences().passcodeCounterFailReset = 0
                            self.delegate?.evaluatePolicy(passcodeViewController, isCorrectCode: true)
                            if NCPreferences().accountRequest {
                                self.delegate?.requestedAccount(controller: self.viewController)
                            }
                        }
                    }
                } else {
                    if let error = evaluateError {
                        switch error._code {
                            case LAError.userFallback.rawValue, LAError.authenticationFailed.rawValue:
                                NCPreferences().passcodeCounterFail += 1
                                NCPreferences().passcodeCounterFailReset += 1

                                // The biometry reply arrives off the main thread.
                                DispatchQueue.main.async {
                                    self.presentTooManyFailedAttemptsAlertIfNeeded(passcodeViewController: passcodeViewController)
                                }
                            case LAError.biometryLockout.rawValue:
                                LAContext().evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: NSLocalizedString("_deviceOwnerAuthentication_", comment: ""), reply: { success, _ in
                                    if success {
                                        DispatchQueue.main.async {
                                            NCPreferences().passcodeCounterFail = 0
                                            self.enableTouchFaceID()
                                        }
                                    }
                                })
                            default:
                                break
                        }
                    }
                }
            }
        }
    }

    func didInputCorrectPasscode(in passcodeViewController: TOPasscodeViewController) {
        DispatchQueue.main.async {
            passcodeViewController.dismiss(animated: true) {
                NCPreferences().passcodeCounterFail = 0
                NCPreferences().passcodeCounterFailReset = 0
                if NCPreferences().accountRequest {
                    self.delegate?.requestedAccount(controller: self.viewController)
                }
            }
        }
    }

    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
        if code == NCPreferences().passcode {
            self.delegate?.evaluatePolicy(passcodeViewController, isCorrectCode: true)
            return true
        } else {
            NCPreferences().passcodeCounterFail += 1
            NCPreferences().passcodeCounterFailReset += 1

            // Keypad taps are delivered on the main thread.
            MainActor.assumeIsolated {
                presentTooManyFailedAttemptsAlertIfNeeded(passcodeViewController: passcodeViewController)
            }

            self.delegate?.evaluatePolicy(passcodeViewController, isCorrectCode: false)
            return false
        }
    }

    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
        enableTouchFaceID()
    }

    @MainActor
    private func presentTooManyFailedAttemptsAlertIfNeeded(passcodeViewController: TOPasscodeViewController) {
        guard passcodeViewController.presentedViewController == nil else { return }

        // A lockout can elapse while the app is closed; clear it before deciding whether to cover the keypad.
        if let lockoutEnd = NCPreferences().passcodeLockoutEnd, lockoutEnd <= Date() {
            NCPreferences().clearPasscodeFailures()
        }

        if isPasscodeReset {
            passcodeViewController.setContentHidden(true, animated: true)

            let alertController = UIAlertController(title: NSLocalizedString("_reset_wrong_passcode_", comment: ""), message: nil, preferredStyle: .alert)
            passcodeViewController.present(alertController, animated: true)

            delegate?.passcodeReset(passcodeViewController)
        } else if isPasscodeCounterFail {
            passcodeViewController.setContentHidden(true, animated: true)

            UIAlertController.failedPasscode(presenter: passcodeViewController) {
                passcodeViewController.setContentHidden(false, animated: true)
                self.enableTouchFaceID()
            }
        }
    }

    @MainActor
    @objc private func applicationDidBecomeActive() {
        guard let passcodeViewController,
              passcodeViewController.view.window != nil
        else { return }

        presentTooManyFailedAttemptsAlertIfNeeded(passcodeViewController: passcodeViewController)
    }
}
