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
    
    @IBOutlet weak var baseUrl: UITextField!
    @IBOutlet weak var user: UITextField!
    @IBOutlet weak var password: UITextField!

    @IBOutlet weak var imageBaseUrl: UIImageView!
    @IBOutlet weak var imageUser: UIImageView!
    @IBOutlet weak var imagePassword: UIImageView!

    @IBOutlet weak var activity: UIActivityIndicatorView!

    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var toggleVisiblePasswordButton: UIButton!
    @IBOutlet weak var loginModeButton: UIButton!
    
    @IBOutlet weak var qrCode: UIButton!
    @IBOutlet weak var certificate: UIButton!

    enum loginMode {
        case traditional, webFlow
    }
    var currentLoginMode: loginMode = .webFlow
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var textColor: UIColor = .white
    var textColorOpponent: UIColor = .black
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = NCBrandColor.shared.customer
        
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
        imageBaseUrl.image = UIImage(named: "loginURL")?.image(color: textColor, size: 50)
        baseUrl.textColor = textColor
        baseUrl.tintColor = textColor
        baseUrl.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("_login_url_", comment: ""), attributes: [NSAttributedString.Key.foregroundColor: textColor.withAlphaComponent(0.5)])
        baseUrl.delegate = self
        
        // User
        imageUser.image = UIImage(named: "loginUser")?.image(color: textColor, size: 50)
        user.textColor = textColor
        user.tintColor = textColor
        user.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("_username_", comment: ""), attributes: [NSAttributedString.Key.foregroundColor: textColor.withAlphaComponent(0.5)])
        user.delegate = self
        
        // password
        imagePassword.image = UIImage(named: "loginPassword")?.image(color: textColor, size: 50)
        password.textColor = textColor
        password.tintColor = textColor
        password.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("_password_", comment: ""), attributes: [NSAttributedString.Key.foregroundColor: textColor.withAlphaComponent(0.5)])
        password.delegate = self
        
        // toggle visible password
        toggleVisiblePasswordButton.setImage(UIImage(named: "visiblePassword")?.image(color: textColor, size: 50), for: .normal)
        
        // login
        loginButton.setTitle(NSLocalizedString("_login_", comment: ""), for: .normal)
        loginButton.backgroundColor = textColor
        loginButton.tintColor = textColorOpponent
        loginButton.layer.cornerRadius = 20
        loginButton.clipsToBounds = true
        
        // type of login
        loginModeButton.setTitle(NSLocalizedString("_traditional_login_", comment: ""), for: .normal)
        loginModeButton.setTitleColor(textColor.withAlphaComponent(0.5), for: .normal)
     
        // brand
        if NCBrandOptions.shared.disable_request_login_url {
            baseUrl.text = NCBrandOptions.shared.loginBaseUrl
            imageBaseUrl.isHidden = true
            baseUrl.isHidden = true
        }
        
        // qrcode
        qrCode.setImage(UIImage(named: "qrcode")?.image(color: textColor, size: 100), for: .normal)
        
        // certificate
        certificate.setImage(UIImage(named: "certificate")?.image(color: textColor, size: 100), for: .normal)
        
        if NCManageDatabase.shared.getAccounts()?.count ?? 0 == 0 {
            imageUser.isHidden = true
            user.isHidden = true
            imagePassword.isHidden = true
            password.isHidden = true
        } else {
            imageUser.isHidden = true
            user.isHidden = true
            imagePassword.isHidden = true
            password.isHidden = true
            
            // Cancel Button
            let navigationItemCancel = UIBarButtonItem.init(barButtonSystemItem: .stop, target: self, action: #selector(self.actionCancel))
            navigationItemCancel.tintColor = textColor
            navigationItem.leftBarButtonItem = navigationItemCancel
        }
        
        self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
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
        return false
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

        if  currentLoginMode == .webFlow {
            
            isUrlValid(url: url)
            
        } else  {
            
            guard let username = user.text else { return }
            guard let password = password.text else { return }
            
            if username.count == 0 { return }
            if password.count == 0 { return }

            loginButton.isEnabled = false
            activity.startAnimating()
            
            NCCommunication.shared.getAppPassword(serverUrl: url, username:  username, password: password) { (token, errorCode, errorDescription) in
                
                self.loginButton.isEnabled = true
                self.activity.stopAnimating()
                
                self.standardLogin(url: url, user: username, password: token ?? "", errorCode: errorCode, errorDescription: errorDescription)
            }
        }
    }
    
    @IBAction func actionToggleVisiblePassword(_ sender: Any) {
        
        let currentPassword = self.password.text
        
        password.isSecureTextEntry = !password.isSecureTextEntry
        password.text = currentPassword
    }
    
    @IBAction func actionLoginModeButton(_ sender: Any) {
                
        if currentLoginMode == .webFlow {
            
            currentLoginMode = .traditional
            imageUser.isHidden = false
            user.isHidden = false
            imagePassword.isHidden = false
            password.isHidden = false
            toggleVisiblePasswordButton.isHidden = false
            
            loginModeButton.setTitle(NSLocalizedString("_web_login_", comment: ""), for: .normal)
            
        } else {
            
            currentLoginMode = .webFlow
            imageUser.isHidden = true
            user.isHidden = true
            imagePassword.isHidden = true
            password.isHidden = true
            toggleVisiblePasswordButton.isHidden = true
            
            loginModeButton.setTitle(NSLocalizedString("_traditional_login_", comment: ""), for: .normal)
        }
    }
    
    @IBAction func actionQRCode(_ sender: Any) {
        
        let qrCode = NCLoginQRCode.init(delegate: self)
        qrCode.scan()
    }
    
    @IBAction func actionCertificate(_ sender: Any) {
        
    }
    
    // MARK: - Login

    func isUrlValid(url: String) {
            
        loginButton.isEnabled = false
        activity.startAnimating()
        
        NCCommunication.shared.getServerStatus(serverUrl: url) { (serverProductName, serverVersion, versionMajor, versionMinor, versionMicro, extendedSupport, errorCode ,errorDescription) in
            
            if errorCode == 0 {
                
                NCNetworking.shared.writeCertificate(url: url)
                
                NCCommunication.shared.getLoginFlowV2(serverUrl: url) { (token, endpoint, login, errorCode, errorDescription) in
                    
                    self.loginButton.isEnabled = true
                    self.activity.stopAnimating()
                                        
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
                    } else if self.currentLoginMode == .webFlow && versionMajor >= NCGlobal.shared.nextcloudVersion12 {
                        
                        if let loginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb {
                            
                            loginWeb.urlBase = url

                            self.navigationController?.pushViewController(loginWeb, animated: true)
                        }
                        
                    // NO Login flow available
                    } else if versionMajor < NCGlobal.shared.nextcloudVersion12 {
                        
                        let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_webflow_not_available_", comment: ""), preferredStyle: .alert)

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in }))
                        
                        self.present(alertController, animated: true, completion: { })
                    }
                }
                
            } else {
               
                self.loginButton.isEnabled = true
                self.activity.stopAnimating()
                
                if errorCode == NSURLErrorServerCertificateUntrusted {
                    
                    let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)
                                
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { action in
                        NCNetworking.shared.writeCertificate(url: url)
                        self.appDelegate.startTimerErrorNetworking()
                    }))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { action in
                        self.appDelegate.startTimerErrorNetworking()
                    }))
                    
                    self.present(alertController, animated: true, completion: {
                        self.appDelegate.timerErrorNetworking?.invalidate()
                    })
                    
                } else {
                    
                    let alertController = UIAlertController(title: NSLocalizedString("_connection_error_", comment: ""), message: errorDescription, preferredStyle: .alert)

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in }))
                    
                    self.present(alertController, animated: true, completion: { })
                }
            }
        }
    }
    
    func standardLogin(url: String, user: String, password: String, errorCode: Int, errorDescription: String) {
        
        if errorCode == 0 {
            
            NCNetworking.shared.writeCertificate(url: url)
            
            let account = user + " " + url
            
            if NCManageDatabase.shared.getAccounts() == nil {
                NCUtility.shared.removeAllSettings()
            }
            
            CCUtility.clearCertificateError(account)
            
            NCManageDatabase.shared.deleteAccount(account)
            NCManageDatabase.shared.addAccount(account, urlBase: url, user: user, password: password)
            
            if let activeAccount = NCManageDatabase.shared.setAccountActive(account) {
                appDelegate.settingAccount(activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account))
            }
            
            if CCUtility.getIntro() {
                
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitializeMain)
                self.dismiss(animated: true)
                
            } else {
                
                CCUtility.setIntro(true)
                
                if self.presentingViewController == nil {
                    
                    let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
                    viewController?.modalPresentationStyle = .fullScreen
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitializeMain)
                    self.appDelegate.window?.rootViewController = viewController
                    self.appDelegate.window?.makeKey()
                    
                } else {
                    
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitializeMain)
                    self.dismiss(animated: true)
                }
            }
        
        } else if errorCode == NSURLErrorServerCertificateUntrusted {
            
            let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)
                        
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { action in
                NCNetworking.shared.writeCertificate(url: url)
                self.appDelegate.startTimerErrorNetworking()
            }))
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { action in
                self.appDelegate.startTimerErrorNetworking()
            }))
            
            self.present(alertController, animated: true, completion: {
                self.appDelegate.timerErrorNetworking?.invalidate()
            })
            
        } else {
            
            let message = NSLocalizedString("_not_possible_connect_to_server_", comment: "") + ".\n" + errorDescription
            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in }))

            self.present(alertController, animated: true, completion: { })
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
                activity.startAnimating()
                
                NCCommunication.shared.checkServer(serverUrl: serverUrl) { (errorCode, errorDescription) in
                
                    self.activity.stopAnimating()
                    self.loginButton.isEnabled = true
                    
                    self.standardLogin(url: urlBase, user: user, password: password, errorCode: errorCode, errorDescription: errorDescription)
                }
            }
        }
    }
    
    // MARK: -
    
    func getDocumentsDirectory() -> URL {

        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
