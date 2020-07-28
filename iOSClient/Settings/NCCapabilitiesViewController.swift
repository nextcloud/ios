//
//  NCCapabilitiesViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/07/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCCapabilitiesViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var imageFileSharing: UIImageView!
    @IBOutlet weak var imageStatusFileSharing: UIImageView!
    
    @IBOutlet weak var imageDirectEditing: UIImageView!
    @IBOutlet weak var imageStatusDirectEditing: UIImageView!
    
    @IBOutlet weak var imageExternalSite: UIImageView!
    @IBOutlet weak var imageStatusExternalSite: UIImageView!
    
    private var account: String = ""
    private var imageEnable: UIImage?
    private var imageDisable: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("_capabilities_", comment: "")
               
        let closeButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(close))
        self.navigationItem.leftBarButtonItem = closeButton
        
        imageEnable = CCGraphics.changeThemingColorImage(UIImage.init(named: "circle"), width: 50, height: 50, color: .green)
        imageDisable = CCGraphics.changeThemingColorImage(UIImage.init(named: "circle"), width: 50, height: 50, color: .red)
        imageFileSharing.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: .gray)
        imageDirectEditing.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "document"), width: 100, height: 100, color: .gray)
        imageExternalSite.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "country"), width: 100, height: 100, color: .gray)

        guard let account = NCManageDatabase.sharedInstance.getAccountActive() else { return }
        self.account = account.account
        
        if let jsonText = NCManageDatabase.sharedInstance.getCapabilities(account: account.account) {
            textView.text = jsonText
            readCapabilities()
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: "_no_capabilities_found_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorInternalError), forced: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
   
    @objc func close() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func readCapabilities() {
        
        if NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false) {
            imageStatusFileSharing.image = imageEnable
        } else {
            imageStatusFileSharing.image = imageDisable
        }
        
        if NCManageDatabase.sharedInstance.getDirectEditingCreators(account: account) != nil {
            imageStatusDirectEditing.image = imageEnable
        } else {
            imageStatusDirectEditing.image = imageDisable
        }
        
        if NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: false) {
            imageStatusExternalSite.image = imageEnable
        } else {
            imageStatusExternalSite.image = imageDisable
        }
    }
}
