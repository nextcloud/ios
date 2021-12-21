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

import UIKit
import NCCommunication

class NCLogin: UIViewController, UITextFieldDelegate, NCLoginQRCodeDelegate {

    @IBOutlet weak var imageBrand: UIImageView!
    @IBOutlet weak var imageBrandConstraintY: NSLayoutConstraint!
    @IBOutlet weak var baseUrl: UITextField!
    @IBOutlet weak var loginAddressDetail: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginImage: UIImageView!
    @IBOutlet weak var qrCode: UIButton!
    @IBOutlet weak var certificate: UIButton!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var textColor: UIColor = .white
    private var textColorOpponent: UIColor = .black
    private var activeTextfieldDiff: CGFloat = 0
    private var activeTextField = UITextField()

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
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithTransparentBackground()
            navBarAppearance.shadowColor = .clear
            navBarAppearance.shadowImage = UIImage()
            self.navigationController?.navigationBar.standardAppearance = navBarAppearance
            self.navigationController?.view.backgroundColor = NCBrandColor.shared.customer
        } else {
            self.navigationController?.navigationBar.isTranslucent = true
            self.navigationController?.navigationBar.shadowImage = UIImage()
            self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
            self.navigationController?.navigationBar.backgroundColor = .clear
            self.navigationController?.navigationBar.barTintColor = NCBrandColor.shared.customer
        }
        self.navigationController?.navigationBar.tintColor = textColor

        if NCManageDatabase.shared.getAccounts()?.count ?? 0 == 0 {

        } else {

            // Cancel Button
            let navigationItemCancel = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.actionCancel))
            navigationItemCancel.tintColor = textColor
            navigationItem.leftBarButtonItem = navigationItemCancel
        }

        self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
        view.backgroundColor = NCBrandColor.shared.customer

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        appDelegate.timerErrorNetworking?.invalidate()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        appDelegate.startTimerErrorNetworking()
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

        guard var url = baseUrl.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if url.count == 0 { return }

        // Check whether baseUrl contain protocol. If not add https:// by default.
        if url.hasPrefix("https") == false && url.hasPrefix("http") == false {
            url = "https://" + url
        }
        self.baseUrl.text = url
        isUrlValid(url: url)
    }

    @IBAction func actionQRCode(_ sender: Any) {

        let qrCode = NCLoginQRCode(delegate: self)
        qrCode.scan()
    }

    @IBAction func actionCertificate(_ sender: Any) {

    }

    // MARK: - Login

    func isUrlValid(url: String) {

        loginButton.isEnabled = false

        NCCommunication.shared.getServerStatus(serverUrl: url) { _, _, versionMajor, _, _, _, errorCode, errorDescription in

            if errorCode == 0 {

                if let host = URL(string: url)?.host {
                    NCNetworking.shared.writeCertificate(host: host)
                }

                NCCommunication.shared.getLoginFlowV2(serverUrl: url) { token, endpoint, login, errorCode, _ in

                    self.loginButton.isEnabled = true

                    // Login Flow V2
                    if errorCode == 0 && NCBrandOptions.shared.use_loginflowv2 && token != nil && endpoint != nil && login != nil {

                        if let loginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb {

                            loginWeb.urlBase = url
                            loginWeb.loginFlowV2Available = true
                            loginWeb.loginFlowV2Token = token!
                            loginWeb.loginFlowV2Endpoint = endpoint!
                            loginWeb.loginFlowV2Login = login!

                            self.navigationController?.pushViewController(loginWeb, animated: true)
                        }

                    // Login Flow
                    } else if versionMajor >= NCGlobal.shared.nextcloudVersion12 {

                        if let loginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb {

                            loginWeb.urlBase = url

                            self.navigationController?.pushViewController(loginWeb, animated: true)
                        }

                    // NO Login flow available
                    } else if versionMajor < NCGlobal.shared.nextcloudVersion12 {

                        let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_webflow_not_available_", comment: ""), preferredStyle: .alert)

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                        self.present(alertController, animated: true, completion: { })
                    }
                }

            } else {

                self.loginButton.isEnabled = true

                if errorCode == NSURLErrorServerCertificateUntrusted {

                    let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                        if let host = URL(string: url)?.host {
                            NCNetworking.shared.writeCertificate(host: host)
                        }
                    }))

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in }))

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { _ in
                        if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController {
                            let viewController = navigationController.topViewController as! NCViewCertificateDetails
                            if let host = URL(string: url)?.host {
                                viewController.host = host
                            }
                            self.present(navigationController, animated: true)
                        }
                    }))

                    self.present(alertController, animated: true)

                } else {

                    let alertController = UIAlertController(title: NSLocalizedString("_connection_error_", comment: ""), message: errorDescription, preferredStyle: .alert)

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
                let webDAV = NCUtilityFileSystem.shared.getWebDAV(account: appDelegate.account)
                let serverUrl = urlBase + "/" + webDAV

                loginButton.isEnabled = false

                NCCommunication.shared.checkServer(serverUrl: serverUrl) { errorCode, errorDescription in

                    self.loginButton.isEnabled = true
                    self.standardLogin(url: urlBase, user: user, password: password, errorCode: errorCode, errorDescription: errorDescription)
                }
            }
        }
    }

    func standardLogin(url: String, user: String, password: String, errorCode: Int, errorDescription: String) {

        if errorCode == 0 {

            if let host = URL(string: url)?.host {
                NCNetworking.shared.writeCertificate(host: host)
            }

            let account = user + " " + url

            if NCManageDatabase.shared.getAccounts() == nil {
                NCUtility.shared.removeAllSettings()
            }
                           
            NCManageDatabase.shared.deleteAccount(account)
            NCManageDatabase.shared.addAccount(account, urlBase: url, user: user, password: password)

            if let activeAccount = NCManageDatabase.shared.setAccountActive(account) {
                appDelegate.settingAccount(activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account))
            }

            if CCUtility.getIntro() {

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitialize)
                self.dismiss(animated: true)

            } else {

                CCUtility.setIntro(true)

                if self.presentingViewController == nil {

                    let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
                    viewController?.modalPresentationStyle = .fullScreen
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitialize)
                    self.appDelegate.window?.rootViewController = viewController
                    self.appDelegate.window?.makeKey()

                } else {

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitialize)
                    self.dismiss(animated: true)
                }
            }

        } else if errorCode == NSURLErrorServerCertificateUntrusted {

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

            let message = NSLocalizedString("_not_possible_connect_to_server_", comment: "") + ".\n" + errorDescription
            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

            self.present(alertController, animated: true, completion: { })
        }
    }
}
