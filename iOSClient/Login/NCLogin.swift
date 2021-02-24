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

import Foundation
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

    @IBOutlet weak var login: UIButton!
    @IBOutlet weak var toggleVisiblePassword: UIButton!
    @IBOutlet weak var loginTypeView: UIButton!
    
    @IBOutlet weak var qrCode: UIButton!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var textColor: UIColor = .white
    var textColorOpponent: UIColor = .black
    var cancelButton: UIBarButtonItem?


    // MARK: - Life Cycle

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
        
        // Cancel Button
        cancelButton = UIBarButtonItem.init(barButtonSystemItem: .stop, target: self, action: #selector(self.actionCancel))
        cancelButton?.tintColor = textColor
        
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
        toggleVisiblePassword.setImage(UIImage(named: "visiblePassword")?.image(color: textColor, size: 50), for: .normal)
        
        // login
        login.setTitle(NSLocalizedString("_login_", comment: ""), for: .normal)
        login.backgroundColor = textColor
        login.tintColor = textColor
        login.layer.cornerRadius = 20
        login.clipsToBounds = true
        
        // type of login
        loginTypeView.setTitle(NSLocalizedString("_traditional_login_", comment: ""), for: .normal)
        loginTypeView.setTitleColor(textColor.withAlphaComponent(0.5), for: .normal)
     
        // brand
        if NCBrandOptions.shared.disable_request_login_url {
            baseUrl.text = NCBrandOptions.shared.loginBaseUrl
            imageBaseUrl.isHidden = true
            baseUrl.isHidden = true
        }
        
        // qrcode
        qrCode.setImage(UIImage(named: "qrcode")?.image(color: textColor, size: 100), for: .normal)
        
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
            navigationItem.leftBarButtonItem = cancelButton
        }

    }
    
    @objc func actionCancel() {
        dismiss(animated: true) { }
    }
    
    
    // MARK: - QRCode

    func dismissQRCode(_ value: String?, metadataType: String?) {
        
        guard var value = value else { return }
        
        let protocolLogin = NCBrandOptions.shared.webLoginAutenticationProtocol + "login/"
        
        if value.hasPrefix("protocolLogin") && value.contains("user:") && value.contains("password:") && value.contains("server:") {
            
            value = value.replacingOccurrences(of: protocolLogin, with: "")
            let valueArray = value.components(separatedBy: "&")
            if valueArray.count == 3 {
                user.text = valueArray[0].replacingOccurrences(of: "user:", with: "")
                password.text = valueArray[1].replacingOccurrences(of: "password:", with: "")
                baseUrl.text = valueArray[2].replacingOccurrences(of: "server:", with: "")
                
                // Check whether baseUrl contain protocol. If not add https:// by default.
                if (baseUrl.text?.hasPrefix("https") ?? false) == false && (baseUrl.text?.hasPrefix("http") ?? false) == false {
                    self.baseUrl.text = "https://" + (self.baseUrl.text ?? "")
                }
                
                login.isEnabled = false
                activity.startAnimating()
                
                let webDAV = NCUtilityFileSystem.shared.getWebDAV(account: appDelegate.account)
                let serverUrl = (baseUrl.text ?? "") + "/" + webDAV
                
                NCCommunication.shared.checkServer(serverUrl: serverUrl) { (errorCode, errorDescription) in
                    
                    self.activity.stopAnimating()
                    self.login.isEnabled = true
                    
                    // [self afterLoginWithUrl:url user:user token:token errorCode:errorCode message:errorDescription];
                }
            }
        }
    }
}
