//
//  NCPasscode.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
        let passcodeCounterFailReset = NCKeychain().passcodeCounterFailReset
        return NCKeychain().resetAppCounterFail && passcodeCounterFailReset >= NCBrandOptions.shared.resetAppPasscodeAttempts
    }
    var isPasscodeCounterFail: Bool {
        let passcodeCounterFail = NCKeychain().passcodeCounterFail
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
        if NCKeychain().touchFaceID, LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
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
        guard NCKeychain().touchFaceID,
              NCKeychain().presentPasscode,
              !isPasscodeCounterFail,
              let passcodeViewController
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, evaluateError in
                if success {
                    DispatchQueue.main.async {
                        passcodeViewController.dismiss(animated: true) {
                            NCKeychain().passcodeCounterFail = 0
                            NCKeychain().passcodeCounterFailReset = 0
                            self.delegate?.evaluatePolicy(passcodeViewController, isCorrectCode: true)
                            if NCKeychain().accountRequest {
                                self.delegate?.requestedAccount(controller: self.viewController)
                            }
                        }
                    }
                } else {
                    if let error = evaluateError {
                        switch error._code {
                        case LAError.userFallback.rawValue, LAError.authenticationFailed.rawValue:
                            if LAContext().biometryType == .faceID {
                                NCKeychain().passcodeCounterFail = 2
                                NCKeychain().passcodeCounterFailReset += 2
                            } else {
                                NCKeychain().passcodeCounterFail = 3
                                NCKeychain().passcodeCounterFailReset += 3
                            }
                            self.openAlert(passcodeViewController: passcodeViewController)
                        case LAError.biometryLockout.rawValue:
                            LAContext().evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: NSLocalizedString("_deviceOwnerAuthentication_", comment: ""), reply: { success, _ in
                                if success {
                                    DispatchQueue.main.async {
                                        NCKeychain().passcodeCounterFail = 0
                                        self.enableTouchFaceID()
                                    }
                                }
                            })
                        case LAError.userCancel.rawValue:
                            NCKeychain().passcodeCounterFail += 1
                            NCKeychain().passcodeCounterFailReset += 1
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
                NCKeychain().passcodeCounterFail = 0
                NCKeychain().passcodeCounterFailReset = 0
                if NCKeychain().accountRequest {
                    self.delegate?.requestedAccount(controller: self.viewController)
                }
            }
        }
    }

    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
        if code == NCKeychain().passcode {
            self.delegate?.evaluatePolicy(passcodeViewController, isCorrectCode: true)
            return true
        } else {
            NCKeychain().passcodeCounterFail += 1
            NCKeychain().passcodeCounterFailReset += 1
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
                        NCKeychain().passcodeCounterFail = 0
                        self.enableTouchFaceID()
                    }
                }
            }
        }
    }
}
