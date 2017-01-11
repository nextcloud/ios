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

// MARK: - CreateMenuAdd

class CreateMenuAdd: NSObject {
    
    let fontButton = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 14)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 65.0/255.0, green: 64.0/255.0, blue: 66.0/255.0, alpha: 1.0)]
    let fontEncrypted = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 14)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0)]
    let fontCancel = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 16)!, NSForegroundColorAttributeName:UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)]
    
    let colorLightGray = UIColor(colorLiteralRed: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1)
    
    func createMenuPlain(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)
        
        actionSheet?.animationDuration = 0.2
        actionSheet?.automaticallyTintButtonImages = 0
        
        actionSheet?.blurRadius = 0.0
        actionSheet?.blurTintColor = UIColor(white: 0.0, alpha: 0.50)
        
        actionSheet?.buttonHeight = 50.0
        actionSheet?.cancelButtonHeight = 50.0
        actionSheet?.separatorHeight = 5.0
        
        actionSheet?.selectedBackgroundColor = UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
        actionSheet?.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)
        
        actionSheet?.buttonTextAttributes = fontButton
        actionSheet?.encryptedButtonTextAttributes = fontEncrypted
        actionSheet?.cancelButtonTextAttributes = fontCancel
        
        actionSheet?.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")

        actionSheet?.addButton(withTitle: "Create a new folder", image: UIImage(named: "createFolderNextcloud"), backgroundColor: UIColor.white, height: 50.0 ,type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFolderPlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload photos and videos", image: UIImage(named: "uploadPhotoNextcloud"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFotoVideoPlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload a file", image: UIImage(named: "uploadFileNextcloud"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFilePlain))
        })
        
        actionSheet?.addButton(withTitle: "Upload Encrypted mode", image: UIImage(named: "actionSheetLock"), backgroundColor: colorLightGray, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
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
        actionSheet?.separatorHeight = 5.0
        
        actionSheet?.selectedBackgroundColor = UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
        actionSheet?.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)

        actionSheet?.buttonTextAttributes = fontButton
        actionSheet?.encryptedButtonTextAttributes = fontEncrypted
        actionSheet?.cancelButtonTextAttributes = fontCancel
        
        actionSheet?.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet?.addButton(withTitle: "Create a new folder", image: UIImage(named: "foldercrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFolderEncrypted))
        })
        
        actionSheet?.addButton(withTitle: "Upload photos and videos", image: UIImage(named: "photocrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFotoVideoEncrypted))
        })
        
        actionSheet?.addButton(withTitle: "Upload a file", image: UIImage(named: "importCloudCrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCreateFileEncrypted))
        })

        actionSheet?.addButton(withTitle: NSLocalizedString("Upload Template", comment: ""), image: UIImage(named: "template"), backgroundColor: colorLightGray, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            self.createMenuTemplate(view: view)
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
        actionSheet?.separatorHeight = 5.0
        
        actionSheet?.selectedBackgroundColor = UIColor(colorLiteralRed: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
        actionSheet?.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)

        actionSheet?.buttonTextAttributes = fontButton
        actionSheet?.encryptedButtonTextAttributes = fontEncrypted
        actionSheet?.cancelButtonTextAttributes = fontCancel
        
        actionSheet?.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_notes_", comment: ""), image: UIImage(named: "note"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnNote))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_web_account_", comment: ""), image: UIImage(named: "baseurl"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnAccountWeb))
        })
        
        actionSheet?.addButton(withTitle: "", image: nil, backgroundColor: UIColor(colorLiteralRed: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1), height: 10.0, type: AHKActionSheetButtonType.disabled, handler: {(AHKActionSheet) -> Void in
            print("disable")
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_credit_card_", comment: ""), image: UIImage(named: "cartadicredito"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCartaDiCredito))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_atm_", comment: ""), image: UIImage(named: "bancomat"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnBancomat))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_bank_account_", comment: ""), image: UIImage(named: "contocorrente"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnContoCorrente))
        })
        
        actionSheet?.addButton(withTitle: "", image: nil, backgroundColor: UIColor(colorLiteralRed: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1), height: 10.0, type: AHKActionSheetButtonType.disabled, handler: {(AHKActionSheet) -> Void in
            print("disable")
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_driving_license_", comment: ""), image: UIImage(named: "patenteguida"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnPatenteGuida))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_id_card_", comment: ""), image: UIImage(named: "cartaidentita"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnCartaIdentita))
        })
        
        actionSheet?.addButton(withTitle: NSLocalizedString("_add_passport_", comment: ""), image: UIImage(named: "passaporto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(returnPassaporto))
        })
        
        actionSheet?.show()
    }

}

// MARK: - CreateFormUpload

class CreateFormUpload: XLFormViewController {
    
    var destinationFolder : String?
    
    convenience init(_ destionationFolder : String?) {
        
        self.init()
        
        if destionationFolder == nil || destionationFolder?.isEmpty == true {
            self.destinationFolder = "/" //NSLocalizedString("_root_", comment: "")
        } else {
            self.destinationFolder = destionationFolder
        }
    
        self.initializeForm()
    }
    
    override func viewDidLoad() {

        super.viewDidLoad()
        
        let cancelButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItemStyle.plain, target: self, action: #selector(cancel))
        
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItemStyle.plain, target: self, action: #selector(save))
        
        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = saveButton
    }
    
    func initializeForm() {
        
        let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow

        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor

        section = XLFormSectionDescriptor.formSection(withTitle: "_destination_folder_") as XLFormSectionDescriptor
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: self.destinationFolder)
        row.cellConfig.setObject(UIImage(named: image_settingsManagePhotos)!, forKey: "imageView.image" as NSCopying)
        section.addFormRow(row)
        
        section = XLFormSectionDescriptor.formSection(withTitle: "A") as XLFormSectionDescriptor
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "FolderPhoto", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: "Save in Pfoto folder")
        section.addFormRow(row)
        row = XLFormRowDescriptor(tag: "der", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: "Subloder")
        section.addFormRow(row)

        section = XLFormSectionDescriptor.formSection(withTitle: "B") as XLFormSectionDescriptor
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "TextFieldAndTextView", rowType: XLFormRowDescriptorTypeName, title: "File name")
        section.addFormRow(row)
        
        self.form = form
    }
    
    func save() {
        
    }

    func cancel() {
        
    }
}


