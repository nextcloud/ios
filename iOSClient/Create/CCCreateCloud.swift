//
//  CCCreateCloud.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/01/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class CreateMenu: NSObject {
    
    func createMenuPlain(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)
        
        actionSheet?.blurRadius = 1.0
        actionSheet?.buttonHeight = 50.0
        actionSheet?.cancelButtonHeight = 50.0
        actionSheet?.selectedBackgroundColor = UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
        actionSheet?.buttonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 65.0/255.0, green: 64.0/255.0, blue: 66.0/255.0, alpha: 1.0)]
        actionSheet?.cryptoButtonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0)]
        actionSheet?.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)
        actionSheet?.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")

        actionSheet?.addButton(withTitle: "Create a new folder", image: UIImage(named: "folder"), type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFolderPlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload photos and videos", image: UIImage(named: "photo"), type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFotoVideoPlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload a file", image: UIImage(named: "importCloud"), type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFilePlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload Encrypted file", image: UIImage(named: "actionSheetLock"), type: AHKActionSheetButtonType.crypto, handler: {(AHKActionSheet) -> Void in
            NSLog("Share tapped")
        })
        
        actionSheet?.show()
    }
}
