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
        
        actionSheet?.animationDuration = 0.2
        
        actionSheet?.blurRadius = 0.0
        actionSheet?.blurTintColor = UIColor(white: 0.0, alpha: 0.50)
        
        actionSheet?.buttonHeight = 50.0
        actionSheet?.cancelButtonHeight = 50.0
        
        actionSheet?.automaticallyTintButtonImages = 0
        
        actionSheet?.selectedBackgroundColor = UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
        actionSheet?.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)

        actionSheet?.buttonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 65.0/255.0, green: 64.0/255.0, blue: 66.0/255.0, alpha: 1.0)]
        actionSheet?.encryptedButtonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0)]
        actionSheet?.cancelButtonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)]
        
        actionSheet?.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")

        actionSheet?.addButton(withTitle: "Create a new folder", image: UIImage(named: "createFolderNextcloud"), type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFolderPlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload photos and videos", image: UIImage(named: "uploadPhotoNextcloud"), type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFotoVideoPlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload a file", image: UIImage(named: "uploadFileNextcloud"), type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFilePlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload Encrypted mode", image: UIImage(named: "actionSheetLock"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            self.createMenuEncrypted(view: view)
        })
        
        actionSheet?.show()
    }
    
    func createMenuEncrypted(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)
        
        actionSheet?.animationDuration = 0.2
        
        actionSheet?.blurRadius = 0.0
        actionSheet?.blurTintColor = UIColor(white: 0.0, alpha: 0.50)

        actionSheet?.buttonHeight = 50.0
        actionSheet?.cancelButtonHeight = 50.0
        
        actionSheet?.selectedBackgroundColor = UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
        actionSheet?.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)

        actionSheet?.buttonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 65.0/255.0, green: 64.0/255.0, blue: 66.0/255.0, alpha: 1.0)]
        actionSheet?.encryptedButtonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0)]
         actionSheet?.cancelButtonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)]
        
        actionSheet?.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet?.addButton(withTitle: NSLocalizedString("Upload Template", comment: ""), image: UIImage(named: "template"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            self.createMenuTemplate(view: view)
        })
        
        actionSheet?.addButton(withTitle: "Create a new folder", image: UIImage(named: "foldercrypto"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFolderEncrypted))
        })
        
        actionSheet?.addButton(withTitle: "Upload photos and videos", image: UIImage(named: "photocrypto"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFotoVideoEncrypted))
        })
        
        actionSheet?.addButton(withTitle: "Upload a file", image: UIImage(named: "importCloudCrypto"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFileEncrypted))
        })

        actionSheet?.show()
    }

    func createMenuTemplate(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)
        
        actionSheet?.animationDuration = 0.2
        
        actionSheet?.blurRadius = 0.0
        actionSheet?.blurTintColor = UIColor(white: 0.0, alpha: 0.50)

        actionSheet?.buttonHeight = 50.0
        actionSheet?.cancelButtonHeight = 50.0
        
        actionSheet?.selectedBackgroundColor = UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
        actionSheet?.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)

        actionSheet?.buttonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 65.0/255.0, green: 64.0/255.0, blue: 66.0/255.0, alpha: 1.0)]
        actionSheet?.encryptedButtonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0)]
         actionSheet?.cancelButtonTextAttributes = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 17)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)]
        
        actionSheet?.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_notes_", comment: ""), image: UIImage(named: "note"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnNote))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_web_account_", comment: ""), image: UIImage(named: "baseurl"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnAccountWeb))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_credit_card_", comment: ""), image: UIImage(named: "cartadicredito"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCartaDiCredito))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_atm_", comment: ""), image: UIImage(named: "bancomat"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnBancomat))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_bank_account_", comment: ""), image: UIImage(named: "contocorrente"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnContoCorrente))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_driving_license_", comment: ""), image: UIImage(named: "patenteguida"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnPatenteGuida))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_id_card_", comment: ""), image: UIImage(named: "cartaidentita"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCartaIdentita))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_passport_", comment: ""), image: UIImage(named: "passaporto"), type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnPassaporto))
        })
        
        actionSheet?.show()
    }

}
