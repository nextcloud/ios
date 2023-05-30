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
        let account = (UIApplication.shared.delegate as! AppDelegate).account
        let details = NCViewE2EE(account: account)
        let vc = UIHostingController(rootView: details)
        vc.title = NSLocalizedString("_e2e_settings_", comment: "")
        return vc
    }
}

class NCManageE2EE: NSObject, ObservableObject, NCEndToEndInitializeDelegate, TOPasscodeViewControllerDelegate {

    let endToEndInitialize = NCEndToEndInitialize()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var passcodeType = ""

    @Published var isEndToEndEnabled: Bool = false
    @Published var statusOfService: String = NSLocalizedString("_status_in_progress_", comment: "")

    override init() {
        super.init()

        endToEndInitialize.delegate = self
        isEndToEndEnabled = CCUtility.isEnd(toEndEnabled: appDelegate.account)
        if isEndToEndEnabled {
            statusOfService = NSLocalizedString("_status_e2ee_configured_", comment: "")
        } else {
            endToEndInitialize.statusOfService { error in
                if error == .success {
                    self.statusOfService = NSLocalizedString("_status_e2ee_on_server_", comment: "")
                } else {
                    self.statusOfService = NSLocalizedString("_status_e2ee_not_setup_", comment: "")
                }
            }
        }
    }

    // MARK: - Delegate

    func endToEndInitializeSuccess() {
        isEndToEndEnabled = true
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

        switch self.passcodeType {
        case "startE2E":
            endToEndInitialize.initEndToEndEncryption()
        case "readPassphrase":
            if let e2ePassphrase = CCUtility.getEndToEndPassphrase(appDelegate.account) {
                print("[LOG]Passphrase: " + e2ePassphrase)
                let message = "\n" + NSLocalizedString("_e2e_settings_the_passphrase_is_", comment: "") + "\n\n\n" + e2ePassphrase
                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_copy_passphrase_", comment: ""), style: .default, handler: { action in
                    UIPasteboard.general.string = e2ePassphrase
                }))
                appDelegate.window?.rootViewController?.present(alertController, animated: true)
            }
        case "removeLocallyEncryption":
            let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_remove_", comment: ""), message: NSLocalizedString("_e2e_settings_remove_message_", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_", comment: ""), style: .default, handler: { action in
                CCUtility.clearAllKeysEnd(toEnd: self.appDelegate.account)
                self.isEndToEndEnabled = CCUtility.isEnd(toEndEnabled: self.appDelegate.account)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default, handler: { action in }))
            appDelegate.window?.rootViewController?.present(alertController, animated: true)
        default:
            break
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

// MARK: Views

struct NCViewE2EE: View {

    @ObservedObject var manageE2EE = NCManageE2EE()
    @State var account: String = ""

    var body: some View {

        VStack {

            if manageE2EE.isEndToEndEnabled {

                List {

                    Section(header: Text(""), footer: Text(manageE2EE.statusOfService + "\n\n" + "End-to-End Encryption " + NCGlobal.shared.capabilityE2EEApiVersion)) {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.green)
                        }
                    }

                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_read_passphrase_", comment: ""))
                        } icon: {
                            Image(systemName: "eye")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(Color(UIColor.systemGray))
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let passcode = CCUtility.getPasscode(), !passcode.isEmpty {
                            manageE2EE.requestPasscodeType("readPassphrase")
                        } else {
                            NCContentPresenter.shared.showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }

                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_remove_", comment: ""))
                        } icon: {
                            Image(systemName: "trash.circle")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(Color.red)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let passcode = CCUtility.getPasscode(), !passcode.isEmpty {
                            manageE2EE.requestPasscodeType("removeLocallyEncryption")
                        } else {
                            NCContentPresenter.shared.showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }

#if DEBUG
                    DeleteCerificateSection()
#endif
                }

            } else {

                List {

                    Section(header: Text(""), footer:Text(manageE2EE.statusOfService + "\n\n" + "End-to-End Encryption " + NCGlobal.shared.capabilityE2EEApiVersion)) {
                        HStack {
                            Label {
                                Text(NSLocalizedString("_e2e_settings_start_", comment: ""))
                            } icon: {
                                Image(systemName: "play.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let passcode = CCUtility.getPasscode(), !passcode.isEmpty {
                                manageE2EE.requestPasscodeType("startE2E")
                            } else {
                                NCContentPresenter.shared.showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                            }
                        }
                    }

#if DEBUG
                    DeleteCerificateSection()
#endif
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct DeleteCerificateSection: View {

    var body: some View {

        Section(header: Text("Delete Server keys"), footer: Text("Available only in debug mode")) {

            HStack {
                Label {
                    Text("Delete Certificate")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(UIColor.systemGray))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EECertificate { account, error in
                    if error == .success {
                        NCContentPresenter.shared.messageNotification("E2E delete certificate", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .success)
                    } else {
                        NCContentPresenter.shared.messageNotification("E2E delete certificate", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                    }
                }
            }

            HStack {
                Label {
                    Text("Delete PrivateKey")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(UIColor.systemGray))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EEPrivateKey { account, error in
                    if error == .success {
                        NCContentPresenter.shared.messageNotification("E2E delete privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .success)
                    } else {
                        NCContentPresenter.shared.messageNotification("E2E delete privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                    }
                }
            }
        }
    }
}

// MARK: - Preview / Test

struct SectionView: View {

    @State var height: CGFloat = 0
    @State var text: String = ""

    var body: some View {
        HStack {
            Text(text)
        }
        .frame(maxWidth: .infinity, minHeight: height, alignment: .bottomLeading)
    }
}

struct NCViewE2EETest: View {

    var body: some View {

        VStack {
            List {
                Section(header:SectionView(height: 50, text: "Section Header View")) {
                    Label {
                        Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.green)
                    }
                }
                Section(header:SectionView(text: "Section Header View 42")) {
                    Label {
                        Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct NCViewE2EE_Previews: PreviewProvider {
    static var previews: some View {
        let account = (UIApplication.shared.delegate as! AppDelegate).account
        NCViewE2EE(account: account)
    }
}
