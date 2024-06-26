//
//  NCLogin.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

import UniformTypeIdentifiers
import UIKit
import NextcloudKit
import SwiftEntryKit
import SwiftUI

class NCLogin: UIViewController, UITextFieldDelegate, NCLoginQRCodeDelegate {

    @IBOutlet weak var imageBrand: UIImageView!
    @IBOutlet weak var imageBrandConstraintY: NSLayoutConstraint!
    @IBOutlet weak var baseUrl: UITextField!
    @IBOutlet weak var loginAddressDetail: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginImage: UIImageView!
    @IBOutlet weak var qrCode: UIButton!
    @IBOutlet weak var certificate: UIButton!

    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private var textColor: UIColor = .white
    private var textColorOpponent: UIColor = .black
    private var activeTextfieldDiff: CGFloat = 0
    private var activeTextField = UITextField()

    private var shareAccounts: [NKShareAccounts.DataAccounts]?

    var loginFlowV2Token = ""
    var loginFlowV2Endpoint = ""
    var loginFlowV2Login = ""

    /// The URL that will show up on the URL field when this screen appears
    var urlBase = ""
    var disableUrlField = false
    var disableCloseButton = false

    // Used for MDM
    var configServerUrl: String?
    var configUsername: String?
    var configPassword: String?
    var configAppPassword: String?

    private var p12Data: Data?
    private var p12Password: String?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Text color
        if NCBrandColor.shared.customer.isTooLight() {
            textColor = .black
            textColorOpponent = .white
        } else if NCBrandColor.shared.customer.isTooDark() {
            textColor = .white
            textColorOpponent = .black
        } else {
            textColor = .white
            textColorOpponent = .black
        }

        // Image Brand
        imageBrand.image = UIImage(named: "logo")

        // Url
        baseUrl.textColor = textColor
        baseUrl.tintColor = textColor
        baseUrl.layer.cornerRadius = 10
        baseUrl.layer.borderWidth = 1
        baseUrl.layer.borderColor = textColor.cgColor
        baseUrl.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: baseUrl.frame.height))
        baseUrl.leftViewMode = .always
        baseUrl.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 35, height: baseUrl.frame.height))
        baseUrl.rightViewMode = .always
        baseUrl.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("_login_url_", comment: ""), attributes: [NSAttributedString.Key.foregroundColor: textColor.withAlphaComponent(0.5)])
        baseUrl.delegate = self
        baseUrl.isEnabled = !disableUrlField

        // Login button
        loginAddressDetail.textColor = textColor
        loginAddressDetail.text = String.localizedStringWithFormat(NSLocalizedString("_login_address_detail_", comment: ""), NCBrandOptions.shared.brand)

        // Login Image
        loginImage.image = UIImage(named: "arrow.right")?.image(color: textColor, size: 100)

        // brand
        if NCBrandOptions.shared.disable_request_login_url {
            baseUrl.text = NCBrandOptions.shared.loginBaseUrl
            baseUrl.isHidden = true
        }

        // qrcode
        qrCode.setImage(UIImage(named: "qrcode")?.image(color: textColor, size: 100), for: .normal)

        // certificate
        certificate.setImage(UIImage(named: "certificate")?.image(color: textColor, size: 100), for: .normal)
        certificate.isHidden = true
        certificate.isEnabled = false

        // navigation
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.shadowColor = .clear
        navBarAppearance.shadowImage = UIImage()
        navBarAppearance.titleTextAttributes = [.foregroundColor: textColor]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: textColor]
        self.navigationController?.navigationBar.standardAppearance = navBarAppearance
        self.navigationController?.view.backgroundColor = NCBrandColor.shared.customer
        self.navigationController?.navigationBar.tintColor = textColor

        if !NCManageDatabase.shared.getAllAccount().isEmpty && !disableCloseButton {
            let navigationItemCancel = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.actionCancel))
            navigationItemCancel.tintColor = textColor
            navigationItem.leftBarButtonItem = navigationItemCancel
        }

        if let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps) {
            // Nextcloud update share accounts
            if let error = appDelegate.updateShareAccounts() {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Create share accounts \(error.localizedDescription)")
            }
            // Nextcloud get share accounts
            if let shareAccounts = NKShareAccounts().getShareAccount(at: dirGroupApps, application: UIApplication.shared) {
                var accountTemp = [NKShareAccounts.DataAccounts]()
                for shareAccount in shareAccounts {
                    if NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "urlBase == %@ AND user == %@", shareAccount.url, shareAccount.user)) == nil {
                        accountTemp.append(shareAccount)
                    }
                }
                if !accountTemp.isEmpty {
                    self.shareAccounts = accountTemp
                    let image = NCUtility().loadImage(named: "person.badge.plus")
                    let navigationItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(openShareAccountsViewController))
                    navigationItem.tintColor = textColor
                    self.navigationItem.rightBarButtonItem = navigationItem
                }
            }
        }

        self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
        view.backgroundColor = NCBrandColor.shared.customer

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        NCNetworking.shared.delegate = self

        handleLoginWithAppConfig()

        baseUrl.text = urlBase
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appDelegate.timerErrorNetworkingDisabled = true

        if self.shareAccounts != nil, let image = UIImage(systemName: "person.badge.plus")?.withTintColor(.white, renderingMode: .alwaysOriginal), let backgroundColor = NCBrandColor.shared.brandElement.lighter(by: 10) {
            let title = String(format: NSLocalizedString("_apps_nextcloud_detect_", comment: ""), NCBrandOptions.shared.brand)
            let description = String(format: NSLocalizedString("_add_existing_account_", comment: ""), NCBrandOptions.shared.brand)
            NCContentPresenter().alertAction(image: image, contentModeImage: .scaleAspectFit, sizeImage: CGSize(width: 45, height: 45), backgroundColor: backgroundColor, textColor: textColor, title: title, description: description, textCancelButton: "_cancel_", textOkButton: "_ok_", attributes: EKAttributes.topFloat) { identifier in
                if identifier == "ok" {
                    self.openShareAccountsViewController()
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appDelegate.timerErrorNetworkingDisabled = false
    }

    private func handleLoginWithAppConfig() {
        let accountCount = NCManageDatabase.shared.getAccounts()?.count ?? 0

        // load AppConfig
        if (NCBrandOptions.shared.disable_multiaccount == false) || (NCBrandOptions.shared.disable_multiaccount == true && accountCount == 0) {
            if let configurationManaged = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed"), NCBrandOptions.shared.use_AppConfig {
                if let serverUrl = configurationManaged[NCGlobal.shared.configuration_serverUrl] as? String {
                    self.configServerUrl = serverUrl
                }

                if let username = configurationManaged[NCGlobal.shared.configuration_username] as? String, !username.isEmpty, username.lowercased() != "username" {
                    self.configUsername = username
                }

                if let password = configurationManaged[NCGlobal.shared.configuration_password] as? String, !password.isEmpty, password.lowercased() != "password" {
                    self.configPassword = password
                }

                if let apppassword = configurationManaged[NCGlobal.shared.configuration_apppassword] as? String, !apppassword.isEmpty, apppassword.lowercased() != "apppassword" {
                    self.configAppPassword = apppassword
                }
            }
        }

        // AppConfig
        if let serverUrl = configServerUrl {
            if let username = self.configUsername, let password = configAppPassword {
                createAccount(server: serverUrl, username: username, password: password)
                return
            } else if let username = self.configUsername, let password = configPassword {
                getAppPassword(serverUrl: serverUrl, username: username, password: password)
                return
            } else {
                urlBase = serverUrl
            }
        }
    }

    // MARK: - TextField

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        actionButtonLogin(self)
        return false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {

        self.activeTextField = textField
    }

    // MARK: - Keyboard notification

    @objc internal func keyboardWillShow(_ notification: Notification?) {

        activeTextfieldDiff = 0

        if let info = notification?.userInfo, let centerObject = self.activeTextField.superview?.convert(self.activeTextField.center, to: nil) {

            let frameEndUserInfoKey = UIResponder.keyboardFrameEndUserInfoKey
            if let keyboardFrame = info[frameEndUserInfoKey] as? CGRect {
                let diff = keyboardFrame.origin.y - centerObject.y - self.activeTextField.frame.height
                if diff < 0 {
                    activeTextfieldDiff = diff
                    imageBrandConstraintY.constant += diff
                }
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        imageBrandConstraintY.constant -= activeTextfieldDiff
    }

    // MARK: - Action

    @objc func actionCancel() {
        dismiss(animated: true) { }
    }

    @IBAction func actionButtonLogin(_ sender: Any) {
        NCNetworking.shared.p12Data = nil
        NCNetworking.shared.p12Password = nil
        login()
    }

    @IBAction func actionQRCode(_ sender: Any) {

        let qrCode = NCLoginQRCode(delegate: self)
        qrCode.scan()
    }

    @IBAction func actionCertificate(_ sender: Any) {

    }

    // MARK: - Share accounts View Controller

    @objc func openShareAccountsViewController() {

        if let shareAccounts = self.shareAccounts, let vc = UIStoryboard(name: "NCShareAccounts", bundle: nil).instantiateInitialViewController() as? NCShareAccounts {

            vc.accounts = shareAccounts
            vc.enableTimerProgress = false
            vc.dismissDidEnterBackground = false
            vc.delegate = self

            let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
            let numberCell = shareAccounts.count
            let height = min(CGFloat(numberCell * Int(vc.heightCell) + 45), screenHeighMax)

            let popup = NCPopupViewController(contentController: vc, popupWidth: 300, popupHeight: height + 20)

            self.present(popup, animated: true)
        }
    }

    // MARK: - Login

    private func login() {
        guard var url = baseUrl.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if url.isEmpty { return }

        // Check whether baseUrl contain protocol. If not add https:// by default.
        if url.hasPrefix("https") == false && url.hasPrefix("http") == false {
            url = "https://" + url
        }
        self.baseUrl.text = url
        isUrlValid(url: url)
    }

    func isUrlValid(url: String, user: String? = nil) {

        loginButton.isEnabled = false

        NextcloudKit.shared.getServerStatus(serverUrl: url) { serverInfoResult in

            switch serverInfoResult {
            case .success(let serverInfo):

                if let host = URL(string: url)?.host {
                    NCNetworking.shared.writeCertificate(host: host)
                }

                NextcloudKit.shared.getLoginFlowV2(serverUrl: url) { token, endpoint, login, _, error in

                    self.loginButton.isEnabled = true

                    // Login Flow V2
                    if error == .success, let token, let endpoint, let login {
                        let vc = UIHostingController(rootView: NCLoginPoll(loginFlowV2Token: token, loginFlowV2Endpoint: endpoint, loginFlowV2Login: login))

                        self.present(vc, animated: true)
                    } else if serverInfo.versionMajor < NCGlobal.shared.nextcloudVersion12 { // No login flow available

                        let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_webflow_not_available_", comment: ""), preferredStyle: .alert)

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                        self.present(alertController, animated: true, completion: { })
                    }
                }

            case .failure(let error):

                self.loginButton.isEnabled = true

                if error.errorCode == NSURLErrorServerCertificateUntrusted {

                    let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                        if let host = URL(string: url)?.host {
                            NCNetworking.shared.writeCertificate(host: host)
                        }
                    }))

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in }))

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { _ in
                        if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                           let viewController = navigationController.topViewController as? NCViewCertificateDetails {
                            if let host = URL(string: url)?.host {
                                viewController.host = host
                            }
                            self.present(navigationController, animated: true)
                        }
                    }))

                    self.present(alertController, animated: true)

                } else {

                    let alertController = UIAlertController(title: NSLocalizedString("_connection_error_", comment: ""), message: error.errorDescription, preferredStyle: .alert)

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                    self.present(alertController, animated: true, completion: { })
                }
            }
        }
    }

    // MARK: - QRCode

    func dismissQRCode(_ value: String?, metadataType: String?) {

        guard var value = value else { return }

        let protocolLogin = NCBrandOptions.shared.webLoginAutenticationProtocol + "login/"

        if value.hasPrefix(protocolLogin) && value.contains("user:") && value.contains("password:") && value.contains("server:") {

            value = value.replacingOccurrences(of: protocolLogin, with: "")
            let valueArray = value.components(separatedBy: "&")
            if valueArray.count == 3 {

                let user = valueArray[0].replacingOccurrences(of: "user:", with: "")
                let password = valueArray[1].replacingOccurrences(of: "password:", with: "")
                let urlBase = valueArray[2].replacingOccurrences(of: "server:", with: "")
                let serverUrl = urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav

                loginButton.isEnabled = false

                NextcloudKit.shared.checkServer(serverUrl: serverUrl) { error in

                    self.loginButton.isEnabled = true
                    self.standardLogin(url: urlBase, user: user, password: password, error: error)
                }
            }
        }
    }

    func standardLogin(url: String, user: String, password: String, error: NKError) {

        if error == .success {

            if let host = URL(string: url)?.host {
                NCNetworking.shared.writeCertificate(host: host)
            }
            let urlBase = url
            let account = user + " " + user

            NextcloudKit.shared.setup(account: account, user: user, userId: user, password: password, urlBase: urlBase)
            NextcloudKit.shared.getUserProfile { _, userProfile, _, error in

                if error == .success, let userProfile {

                    NCManageDatabase.shared.deleteAccount(account)
                    NCManageDatabase.shared.addAccount(account, urlBase: url, user: user, userId: userProfile.userId, password: password)

                    self.appDelegate.changeAccount(account, userProfile: userProfile)

                    let window = UIApplication.shared.firstWindow
                    if window?.rootViewController is NCMainTabBarController {
                        self.dismiss(animated: true)
                    } else {
                        if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                            controller.modalPresentationStyle = .fullScreen
                            controller.view.alpha = 0
                            window?.rootViewController = controller
                            window?.makeKeyAndVisible()
                            UIView.animate(withDuration: 0.5) {
                                controller.view.alpha = 1
                            }
                        }
                    }
                } else {

                    let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: error.errorDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                    self.present(alertController, animated: true)
                }
            }

        } else if error.errorCode == NSURLErrorServerCertificateUntrusted {

            let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                if let host = URL(string: url)?.host {
                    NCNetworking.shared.writeCertificate(host: host)
                }
            }))

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in }))

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { _ in
                if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() {
                    self.present(navigationController, animated: true)
                }
            }))

            self.present(alertController, animated: true)

        } else {

            let message = NSLocalizedString("_not_possible_connect_to_server_", comment: "") + ".\n" + error.errorDescription
            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
            self.present(alertController, animated: true, completion: { })
        }
    }

    private func createAccount(server: String, username: String, password: String) {
        appDelegate.createAccount(server: server, username: username, password: password) { error in
            if error == .success {
                let window = UIApplication.shared.firstWindow
                if window?.rootViewController is NCMainTabBarController {
                    self.dismiss(animated: true)
                } else {
                    if let mainTabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                        mainTabBarController.modalPresentationStyle = .fullScreen
                        mainTabBarController.view.alpha = 0
                        window?.rootViewController = mainTabBarController
                        window?.makeKeyAndVisible()
                        UIView.animate(withDuration: 0.5) {
                            mainTabBarController.view.alpha = 1
                        }
                    }
                }
            }
        }
    }

    private func getAppPassword(serverUrl: String, username: String, password: String) {
        NextcloudKit.shared.getAppPassword(serverUrl: serverUrl, username: username, password: password) { token, _, error in
            if error == .success, let password = token {
                self.createAccount(server: serverUrl, username: username, password: password)
            } else {
                NCContentPresenter().showError(error: error)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}

extension NCLogin: NCShareAccountsDelegate {
    func selected(url: String, user: String) {
        isUrlValid(url: url, user: user)
    }
}

extension NCLogin: ClientCertificateDelegate, UIDocumentPickerDelegate {
    func didAskForClientCertificate() {
        let alertNoCertFound = UIAlertController(title: NSLocalizedString("_no_client_cert_found_", comment: ""), message: NSLocalizedString("_no_client_cert_found_desc_", comment: ""), preferredStyle: .alert)

        alertNoCertFound.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))

        alertNoCertFound.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
            let documentProviderMenu = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pkcs12])
            documentProviderMenu.delegate = self

            self.present(documentProviderMenu, animated: true, completion: nil)
        }))

        present(alertNoCertFound, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let alertEnterPassword = UIAlertController(title: NSLocalizedString("_client_cert_enter_password_", comment: ""), message: "", preferredStyle: .alert)

        alertEnterPassword.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))

        alertEnterPassword.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
            // let documentProviderMenu = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pkcs12])
            NCNetworking.shared.p12Data = try? Data(contentsOf: urls[0])
            NCNetworking.shared.p12Password = alertEnterPassword.textFields?[0].text

            self.login()
        }))

        alertEnterPassword.addTextField { textField in
            textField.isSecureTextEntry = true
        }

        present(alertEnterPassword, animated: true)
    }

    func onIncorrectPassword() {
        NCNetworking.shared.p12Data = nil
        NCNetworking.shared.p12Password = nil

        let alertWrongPassword = UIAlertController(title: NSLocalizedString("_client_cert_wrong_password_", comment: ""), message: "", preferredStyle: .alert)

        alertWrongPassword.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default))

        present(alertWrongPassword, animated: true)
    }
}
