//
//  NCUserStatus.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/05/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
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
import Foundation
import NCCommunication

class NCUserStatus: UIViewController {
    
    @IBOutlet weak var onlineButton: UIButton!
    @IBOutlet weak var onlineImage: UIImageView!
    @IBOutlet weak var onlineLabel: UILabel!
    
    @IBOutlet weak var awayButton: UIButton!
    @IBOutlet weak var awayImage: UIImageView!
    @IBOutlet weak var awayLabel: UILabel!
    
    @IBOutlet weak var dndButton: UIButton!
    @IBOutlet weak var dndImage: UIImageView!
    @IBOutlet weak var dndLabel: UILabel!
    @IBOutlet weak var dndDescrLabel: UILabel!

    @IBOutlet weak var invisibleButton: UIButton!
    @IBOutlet weak var invisibleImage: UIImageView!
    @IBOutlet weak var invisibleLabel: UILabel!
    @IBOutlet weak var invisibleDescrLabel: UILabel!
    
    @IBOutlet weak var statusMessageLabel: UILabel!

    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        onlineButton.layer.cornerRadius = 10
        onlineButton.layer.masksToBounds = true
        //onlineLabel.layer.borderWidth = 0.5
        //onlineLabel.layer.borderColor = NCBrandColor.shared.brand.cgColor
        let onLine = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "online", userMessage: nil)
        onlineImage.image = onLine.onlineStatus
        onlineLabel.text = onLine.statusMessage
        onlineLabel.textColor = NCBrandColor.shared.label
       
        
        awayButton.layer.cornerRadius = 10
        awayButton.layer.masksToBounds = true
        //onlineLabel.layer.borderWidth = 0.5
        //onlineLabel.layer.borderColor = NCBrandColor.shared.brand.cgColor
        let away = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "away", userMessage: nil)
        awayImage.image = away.onlineStatus
        awayLabel.text = away.statusMessage
        awayLabel.textColor = NCBrandColor.shared.label
        
        dndButton.layer.cornerRadius = 10
        dndButton.layer.masksToBounds = true
        //onlineLabel.layer.borderWidth = 0.5
        //onlineLabel.layer.borderColor = NCBrandColor.shared.brand.cgColor
        let dnd = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "dnd", userMessage: nil)
        dndImage.image = dnd.onlineStatus
        dndLabel.text = dnd.statusMessage
        dndLabel.textColor = NCBrandColor.shared.label
        dndDescrLabel.text = dnd.descriptionMessage
        dndDescrLabel.textColor = .darkGray
        
        invisibleButton.layer.cornerRadius = 10
        invisibleButton.layer.masksToBounds = true
        //onlineLabel.layer.borderWidth = 0.5
        //onlineLabel.layer.borderColor = NCBrandColor.shared.brand.cgColor
        let offline = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "offline", userMessage: nil)
        invisibleImage.image = offline.onlineStatus
        invisibleLabel.text = offline.statusMessage
        invisibleLabel.textColor = NCBrandColor.shared.label
        invisibleDescrLabel.text = offline.descriptionMessage
        invisibleDescrLabel.textColor = .darkGray
        
        statusMessageLabel.text = NSLocalizedString("_status_message_", comment: "")
        statusMessageLabel.textColor = NCBrandColor.shared.label

    }
}

/*
@available(iOS 13.0, *)


@available(iOS 13.0, *)
@objc class NCUserStatusViewController: NSObject {
 
    @objc func makeUserStatusUI() -> UIViewController
        
        NCCommunication.shared.getUserStatusPredefinedStatuses { (account, userStatuses, errorCode, errorDescription) in
            if errorCode == 0 {
                if let userStatuses = userStatuses {
                    NCManageDatabase.shared.addUserStatus(userStatuses, account: account, predefined: true)
                }
            }
        }
        
        NCCommunication.shared.getUserStatusRetrieveStatuses(limit: 1000, offset: 0, customUserAgent: nil, addCustomHeaders: nil) { (account, userStatuses, errorCode, errorDescription) in
            if errorCode == 0 {
                if let userStatuses = userStatuses {
                    NCManageDatabase.shared.addUserStatus(userStatuses, account: account, predefined: false)
                }
            }
        }
        
        //let userStatus = NCUserStatus()
        //details.shipName = name
        return
    }
}
*/
