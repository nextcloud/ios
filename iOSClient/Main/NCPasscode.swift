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

// optional func
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
        return passcodeCounterFail > 0 && passcodeCounterFail.isMultiple(of: 3)
    }
    var passcodeViewController: TOPasscodeViewController!
    var delegate: NCPasscodeDelegate?
    var viewController: UIViewController?

    func presentPasscode(viewController: UIViewController, delegate: NCPasscodeDelegate?, completion: @escaping () -> Void) {
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
            self.openAlert(passcodeViewController: self.passcodeViewController)
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
                            if LAContext().biometryType == .faceID {
                                NCPreferences().passcodeCounterFail = 2
                                NCPreferences().passcodeCounterFailReset += 2
                            } else {
                                NCPreferences().passcodeCounterFail = 3
                                NCPreferences().passcodeCounterFailReset += 3
                            }
                            self.openAlert(passcodeViewController: passcodeViewController)
                        case LAError.biometryLockout.rawValue:
                            LAContext().evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: NSLocalizedString("_deviceOwnerAuthentication_", comment: ""), reply: { success, _ in
                                if success {
                                    DispatchQueue.main.async {
                                        NCPreferences().passcodeCounterFail = 0
                                        self.enableTouchFaceID()
                                    }
                                }
                            })
                        case LAError.userCancel.rawValue:
                            NCPreferences().passcodeCounterFail += 1
                            NCPreferences().passcodeCounterFailReset += 1
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
            openAlert(passcodeViewController: passcodeViewController)
            self.delegate?.evaluatePolicy(passcodeViewController, isCorrectCode: false)
            return false
        }
    }

    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
        enableTouchFaceID()
    }

    func openAlert(passcodeViewController: TOPasscodeViewController) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.isPasscodeReset {

                passcodeViewController.setContentHidden(true, animated: true)

                let alertController = UIAlertController(title: NSLocalizedString("_reset_wrong_passcode_", comment: ""), message: nil, preferredStyle: .alert)
                passcodeViewController.present(alertController, animated: true, completion: { })
                self.delegate?.passcodeReset(passcodeViewController)

            } else if self.isPasscodeCounterFail {

                passcodeViewController.setContentHidden(true, animated: true)

                let alertController = UIAlertController(title: NSLocalizedString("_passcode_counter_fail_", comment: ""), message: nil, preferredStyle: .alert)
                passcodeViewController.present(alertController, animated: true, completion: { })

                var seconds = NCBrandOptions.shared.passcodeSecondsFail
                _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    alertController.message = "\(seconds) " + NSLocalizedString("_seconds_", comment: "")
                    seconds -= 1
                    if seconds < 0 {
                        timer.invalidate()
                        alertController.dismiss(animated: true)
                        passcodeViewController.setContentHidden(false, animated: true)
                        NCPreferences().passcodeCounterFail = 0
                        self.enableTouchFaceID()
                    }
                }
            }
        }
    }
}
