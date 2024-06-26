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

    @objc func makeShipDetailsUI(account: String, rootViewController: UIViewController?) -> UIViewController {

        let details = NCViewE2EE(account: account, rootViewController: rootViewController)
        let vc = UIHostingController(rootView: details)
        vc.title = NSLocalizedString("_e2e_settings_", comment: "")
        return vc
    }
}

class NCManageE2EE: NSObject, ObservableObject, NCEndToEndInitializeDelegate, TOPasscodeViewControllerDelegate {

    let endToEndInitialize = NCEndToEndInitialize()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    var passcodeType = ""

    @Published var rootViewController: UIViewController?
    @Published var isEndToEndEnabled: Bool = false
    @Published var statusOfService: String = NSLocalizedString("_status_in_progress_", comment: "")

    init(rootViewController: UIViewController?) {
        super.init()
        self.rootViewController = rootViewController
        endToEndInitialize.delegate = self
        isEndToEndEnabled = NCKeychain().isEndToEndEnabled(account: appDelegate.account)
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

    func endToEndInitializeSuccess(metadata: tableMetadata?) {
        isEndToEndEnabled = true
    }

    // MARK: - Passcode

    @objc func requestPasscodeType(_ passcodeType: String) {

        let laContext = LAContext()
        var error: NSError?

        let passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: true)
        passcodeViewController.delegate = self
        passcodeViewController.keypadButtonShowLettering = false
        if NCKeychain().touchFaceID, laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if error == nil {
                if laContext.biometryType == .faceID {
                    passcodeViewController.biometryType = .faceID
                    passcodeViewController.allowBiometricValidation = true
                } else if laContext.biometryType == .touchID {
                    passcodeViewController.biometryType = .touchID
                }
                passcodeViewController.allowBiometricValidation = true
                passcodeViewController.automaticallyPromptForBiometricValidation = true
            }
        }

        self.passcodeType = passcodeType
        rootViewController?.present(passcodeViewController, animated: true)
    }

    @objc func correctPasscode() {

        switch self.passcodeType {
        case "startE2E":
            endToEndInitialize.initEndToEndEncryption(viewController: rootViewController, metadata: nil)
        case "readPassphrase":
            if let e2ePassphrase = NCKeychain().getEndToEndPassphrase(account: appDelegate.account) {
                print("[INFO]Passphrase: " + e2ePassphrase)
                let message = "\n" + NSLocalizedString("_e2e_settings_the_passphrase_is_", comment: "") + "\n\n\n" + e2ePassphrase
                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_copy_passphrase_", comment: ""), style: .default, handler: { _ in
                    UIPasteboard.general.string = e2ePassphrase
                }))
                rootViewController?.present(alertController, animated: true)
            }
        case "removeLocallyEncryption":
            let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_remove_", comment: ""), message: NSLocalizedString("_e2e_settings_remove_message_", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_", comment: ""), style: .default, handler: { _ in
                NCKeychain().clearAllKeysEndToEnd(account: self.appDelegate.account)
                self.isEndToEndEnabled = NCKeychain().isEndToEndEnabled(account: self.appDelegate.account)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default, handler: { _ in }))
            rootViewController?.present(alertController, animated: true)
        default:
            break
        }
    }

    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {

        if code == NCKeychain().passcode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.correctPasscode()
            }
            return true
        } else {
            return false
        }
    }

    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {

        LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, _ in
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

    @ObservedObject var manageE2EE: NCManageE2EE
    @State var account: String
    @State var rootViewController: UIViewController?

    init(account: String, rootViewController: UIViewController?) {
        self.manageE2EE = NCManageE2EE(rootViewController: rootViewController)
        self.account = account
        self.rootViewController = rootViewController
    }

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
                                .font(Font.system(.body).weight(.light))
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
                                .font(Font.system(.body).weight(.light))
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCKeychain().passcode != nil {
                            manageE2EE.requestPasscodeType("readPassphrase")
                        } else {
                            NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }

                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_remove_", comment: ""))
                        } icon: {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCKeychain().passcode != nil {
                            manageE2EE.requestPasscodeType("removeLocallyEncryption")
                        } else {
                            NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }

#if DEBUG
                    DeleteCerificateSection()
#endif
                }

            } else {

                List {

                    Section(header: Text(""), footer: Text(manageE2EE.statusOfService + "\n\n" + "End-to-End Encryption " + NCGlobal.shared.capabilityE2EEApiVersion)) {
                        HStack {
                            Label {
                                Text(NSLocalizedString("_e2e_settings_start_", comment: ""))
                            } icon: {
                                Image(systemName: "play.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let passcode = NCKeychain().passcode {
                                manageE2EE.requestPasscodeType("startE2E")
                            } else {
                                NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
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
                        .font(Font.system(.body).weight(.light))
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EECertificate { _, error in
                    if error == .success {
                        NCContentPresenter().messageNotification("E2E delete certificate", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .success)
                    } else {
                        NCContentPresenter().messageNotification("E2E delete certificate", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
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
                        .font(Font.system(.body).weight(.light))
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EEPrivateKey { _, error in
                    if error == .success {
                        NCContentPresenter().messageNotification("E2E delete privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .success)
                    } else {
                        NCContentPresenter().messageNotification("E2E delete privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
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
                Section(header: SectionView(height: 50, text: "Section Header View")) {
                    Label {
                        Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .font(Font.system(.body).weight(.light))
                            .foregroundColor(.green)
                    }
                }
                Section(header: SectionView(text: "Section Header View 42")) {
                    Label {
                        Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .font(Font.system(.body).weight(.light))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct NCViewE2EE_Previews: PreviewProvider {
    static var previews: some View {

        // swiftlint:disable force_cast
        let account = (UIApplication.shared.delegate as! AppDelegate).account
        NCViewE2EE(account: account, rootViewController: nil)
        // swiftlint:enable force_cast
    }
}
