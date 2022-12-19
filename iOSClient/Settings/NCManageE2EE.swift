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

@objc class NCManageE2EEInterface: NSObject {
    @objc func makeShipDetailsUI(account: String) -> UIViewController {
        let details = NCViewE2EE(isEndToEndEnabled: CCUtility.isEnd(toEndEnabled: account))
        return UIHostingController(rootView: details)
    }
}

class NCManageE2EE: NSObject, NCEndToEndInitializeDelegate, TOPasscodeViewControllerDelegate {

    let endToEndInitialize = NCEndToEndInitialize()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var passcodeType = ""

    override init() {
        super.init()

        endToEndInitialize.delegate = self
    }

    func endToEndInitializeSuccess() {
       //details.isEndToEndEnabled = true
    }

    // MARK: - Passcode

    @objc func requestPasscodeType(_ passcodeType: String) {

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

    @objc func correctPasscode() {

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

struct NCViewE2EE: View {

    let manageE2EE = NCManageE2EE()
    @State var isEndToEndEnabled: Bool = false

    var body: some View {
        VStack {
            VStack {

                Text("Hello, world! 1 come stai spero bene ma secondo te quanto è lunga questa cosa, Hello, world! 1 come stai spero bene ma secondo te quanto è lunga questa cosa, versione 2 perchè la versione 1 e poi altro testo ")
                    .frame(height: 100)
                    .padding()

                Button(action: {}) {
                    HStack{
                        Image(systemName: "person.crop.circle.fill")
                        Text("This is a button")
                            .padding(.horizontal)
                    }
                    .padding()
                }
                .foregroundColor(Color.white)
                .background(Color.blue)
                .cornerRadius(.infinity)
                .frame(height: 100)

                if isEndToEndEnabled {
                    Text("Activated")
                } else {
                    Button(action: {
                        manageE2EE.endToEndInitialize.initEndToEndEncryption()
                    }, label: {
                        Text("Start")
                    })
                }


                Button(action: {
                    if CCUtility.getPasscode().isEmpty {
                        NCContentPresenter.shared.showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                    } else {
                        manageE2EE.requestPasscodeType("removeLocallyEncryption")
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
            .background(Color.green)
            Spacer()
        }
        .background(Color.gray)
        .navigationTitle("Cifratura End-To-End")
    }
}
