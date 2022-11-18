//
//  NCManageE2EE.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/11/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

import SwiftUI
import NextcloudKit
import TOPasscodeViewController
import LocalAuthentication


@objc
class NCManageE2EEInterface: NSObject, NCEndToEndInitializeDelegate, TOPasscodeViewControllerDelegate {

    let endToEndInitialize = NCEndToEndInitialize()

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var passcodeType = ""

    override init() {
        super.init()

        endToEndInitialize.delegate = self
    }

    @objc func makeShipDetailsUI() -> UIViewController {
        let details = NCManageE2EE()
        return UIHostingController(rootView: details)
    }

    func endToEndInitializeSuccess() {

    }

    // MARK: - Passcode

    func requestPasscodeType(_ passcodeType: String) {

        let laContext = LAContext()
        var error: NSError?

        let passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: true)
        passcodeViewController.delegate = self
        passcodeViewController.keypadButtonShowLettering = false
        if CCUtility.getEnableTouchFaceID() && laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if error == nil {
                if laContext.biometryType == .faceID  {
                    passcodeViewController.biometryType = .faceID
                    passcodeViewController.allowBiometricValidation = true
                } else if laContext.biometryType == .touchID  {
                    passcodeViewController.biometryType = .touchID
                }
                passcodeViewController.allowBiometricValidation = true
                passcodeViewController.automaticallyPromptForBiometricValidation = true
            }
        }

        self.passcodeType = passcodeType
        appDelegate.window?.rootViewController?.present(passcodeViewController, animated: true)
    }

    func correctPasscode() {

        if self.passcodeType == "removeLocallyEncryption" {
            let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_remove_", comment: ""), message: NSLocalizedString("_e2e_settings_remove_message_", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_", comment: ""), style: .default, handler: { action in
                CCUtility.clearAllKeysEnd(toEnd: self.appDelegate.account)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default, handler: { action in }))
            appDelegate.window?.rootViewController?.present(alertController, animated: true)
        }
    }

    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {

        if code == CCUtility.getPasscode() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.correctPasscode()
            }
            return true
        } else {
            return false
        }
    }

    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {

        LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { (success, error) in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    passcodeViewController.dismiss(animated: true)
                    self.correctPasscode()
                }
            }
        }
    }

    func didTapCancel(in passcodeViewController: TOPasscodeViewController) {
        passcodeViewController.dismiss(animated: true)
    }
}

struct NCManageE2EE: View {
    let manageE2EEInterface = NCManageE2EEInterface()

    var body: some View {
        VStack {
            Text("Hello, world! 1")
            Button(action: {
                manageE2EEInterface.endToEndInitialize.initEndToEndEncryption()
            }, label: {
                Text("Start")
            })

            Button(action: {
                if CCUtility.getPasscode().isEmpty {
                    NCContentPresenter.shared.showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                } else {
                    manageE2EEInterface.requestPasscodeType("removeLocallyEncryption")
                }
            }, label: {
                Text(NSLocalizedString("_e2e_settings_remove_", comment: ""))
            })

            #if DEBUG
            Button(action: {

            }, label: {
                Text("Delete Certificate")
            })
            Button(action: {
                NextcloudKit.shared.deleteE2EEPrivateKey { account, error in

                }
            }, label: {
                Text("Delete PrivateKey")
            })
            #endif

        }
        .navigationTitle("Cifratura End-To-End")
    }
}

struct NCManageE2EE_Previews: PreviewProvider {
    static var previews: some View {
        NCManageE2EE()
    }
}
