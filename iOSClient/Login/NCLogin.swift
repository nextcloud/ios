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


    // MARK: - Life Cycle

    
    
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
