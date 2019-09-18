//
//  NCAppConfigView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/09/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

@objc protocol NCAppConfigViewDelegate: class {
    func loginSuccess(_: NSInteger)
    @objc optional func appConfigViewDismiss()
}

class NCAppConfigView: UIViewController {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @objc var serverUrl: String?
    @objc var username: String?
    @objc var password: String?
    @objc weak var delegate: NCAppConfigViewDelegate?

    @IBOutlet weak var logoImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = NCBrandColor.sharedInstance.brand
        
        let serverConfig = UserDefaults.standard.dictionary(forKey: NCBrandConfiguration.sharedInstance.configuration_key)
        serverUrl = serverConfig?[NCBrandConfiguration.sharedInstance.configuration_serverUrl] as? String
        username = serverConfig?[NCBrandConfiguration.sharedInstance.configuration_username] as? String
        password = serverConfig?[NCBrandConfiguration.sharedInstance.configuration_password] as? String
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Stop timer error network
        appDelegate.timerErrorNetworking.invalidate()
        
        OCNetworking.sharedManager()?.getAppPassword(serverUrl, username: username, password: password, completion: { (token, message, errorCode) in
            if errorCode == 0 {
                
            } else {
                self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
        })
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Start timer error network
        appDelegate.startTimerErrorNetworking()
    }
}
