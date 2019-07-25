//
//  NCShareUserMenuView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/2019.
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

import Foundation
import FSCalendar

class NCShareUserMenuView: UIView, UIGestureRecognizerDelegate, NCShareNetworkingDelegate, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    @IBOutlet weak var switchCanReshare: UISwitch!
    @IBOutlet weak var labelCanReshare: UILabel!
    
    @IBOutlet weak var switchSetExpirationDate: UISwitch!
    @IBOutlet weak var labelSetExpirationDate: UILabel!
    @IBOutlet weak var fieldSetExpirationDate: UITextField!
    
    @IBOutlet weak var imageNoteToRecipient: UIImageView!
    @IBOutlet weak var labelNoteToRecipient: UILabel!
    @IBOutlet weak var fieldNoteToRecipient: UITextField!
    
    @IBOutlet weak var buttonUnshare: UIButton!
    @IBOutlet weak var labelUnshare: UILabel!
    @IBOutlet weak var imageUnshare: UIImageView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    public let width: CGFloat = 250
    public let height: CGFloat = 340
    private var tableShare: tableShare?
    public var metadata: tableMetadata?
    
    public var viewWindow: UIView?
    public var viewWindowCalendar: UIView?
    
    override func awakeFromNib() {
        
        self.frame.size.width = width
        self.frame.size.height = height
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 5
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.2
        
        switchCanReshare.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchCanReshare.onTintColor = NCBrandColor.sharedInstance.brand
        switchSetExpirationDate.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchSetExpirationDate.onTintColor = NCBrandColor.sharedInstance.brand
        
        fieldSetExpirationDate.inputView = UIView()
        
        imageNoteToRecipient.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 100, height: 100, color: UIColor(red: 76/255, green: 76/255, blue: 76/255, alpha: 1))
        imageUnshare.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 100, height: 100, color: UIColor(red: 76/255, green: 76/255, blue: 76/255, alpha: 1))
    }
    
    func unLoad() {
        viewWindowCalendar?.removeFromSuperview()
        viewWindow?.removeFromSuperview()
        
        viewWindowCalendar = nil
        viewWindow = nil
    }
    
    func reloadData(idRemoteShared: Int) {
        tableShare = NCManageDatabase.sharedInstance.getTableShare(account: metadata!.account, idRemoteShared: idRemoteShared)
        
        // Can reshare
        if tableShare != nil && tableShare!.permissions > Int(k_read_share_permission) {
            //switchAllowEditing.setOn(true, animated: false)
        } else {
            //switchAllowEditing.setOn(false, animated: false)
        }
        
        // Set expiration date
        if tableShare != nil && tableShare!.expirationDate != nil {
            switchSetExpirationDate.setOn(true, animated: false)
            fieldSetExpirationDate.isEnabled = true
            
            let dateFormatter = DateFormatter()
            dateFormatter.formatterBehavior = .behavior10_4
            dateFormatter.dateStyle = .medium
            fieldSetExpirationDate.text = dateFormatter.string(from: tableShare!.expirationDate! as Date)
        } else {
            switchSetExpirationDate.setOn(false, animated: false)
            fieldSetExpirationDate.isEnabled = false
            fieldSetExpirationDate.text = ""
        }
        
        // Note to recipient
        if tableShare != nil {
            fieldNoteToRecipient.text = tableShare!.note
        } else {
            fieldNoteToRecipient.text = ""
        }
    }
    
    // delegate networking
    
    func readShareCompleted(errorCode: Int) {
        reloadData(idRemoteShared: tableShare?.idRemoteShared ?? 0)
    }
    
    func shareCompleted(errorCode: Int) {
        unLoad()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "reloadDataNCShare"), object: nil, userInfo: nil)
    }
    
    func unShareCompleted() {
        unLoad()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "reloadDataNCShare"), object: nil, userInfo: nil)
    }
    
    func updateShareWithError(idRemoteShared: Int) {
        reloadData(idRemoteShared: idRemoteShared)
    }
}
