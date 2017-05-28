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
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    let fontButton = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 16)!, NSForegroundColorAttributeName: UIColor(colorLiteralRed: 65.0/255.0, green: 64.0/255.0, blue: 66.0/255.0, alpha: 1.0)]
    let fontEncrypted = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 16)!, NSForegroundColorAttributeName: NCBrandColor.sharedInstance.cryptocloud] as [String : Any]
    let fontCancel = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 16)!, NSForegroundColorAttributeName: NCBrandColor.sharedInstance.brand] as [String : Any]
    let fontDisable = [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 16)!, NSForegroundColorAttributeName: UIColor(colorLiteralRed: 65.0/255.0, green: 64.0/255.0, blue: 66.0/255.0, alpha: 1.0)]

    let colorLightGray = UIColor(colorLiteralRed: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1)
    var colorIcon = NCBrandColor.sharedInstance.brand
    
    init (themingColor : UIColor) {
        super.init()
        
        colorIcon = themingColor
    }
    
    func createMenuPlain(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)!
        
        actionSheet.animationDuration = 0.2
        actionSheet.automaticallyTintButtonImages = 0
        
        actionSheet.blurRadius = 0.0
        actionSheet.blurTintColor = UIColor(white: 0.0, alpha: 0.50)
        
        actionSheet.buttonHeight = 50.0
        actionSheet.cancelButtonHeight = 50.0
        actionSheet.separatorHeight = 5.0
        
        actionSheet.separatorColor = NCBrandColor.sharedInstance.seperator
        
        actionSheet.buttonTextAttributes = fontButton
        actionSheet.encryptedButtonTextAttributes = fontEncrypted
        actionSheet.cancelButtonTextAttributes = fontCancel
        actionSheet.disableButtonTextAttributes = fontDisable
        
        actionSheet.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet.addButton(withTitle: NSLocalizedString("_create_folder_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), color: colorIcon), backgroundColor: UIColor.white, height: 50.0 ,type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFolderPlain))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_photos_videos_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "menuUploadPhoto"), color: colorIcon), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFotoVideoPlain))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_file_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "menuUploadFile"), color: colorIcon), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFilePlain))
        })
        
        if appDelegate.isCryptoCloudMode {
        
            actionSheet.addButton(withTitle: NSLocalizedString("_upload_encrypted_mode", comment: ""), image: UIImage(named: "actionSheetLock"), backgroundColor: colorLightGray, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
                self.createMenuEncrypted(view: view)
            })
        }
        actionSheet.show()
        
        CCUtility.setCreateMenuEncrypted(false)
    }
    
    func createMenuEncrypted(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)!
        
        actionSheet.animationDuration = 0.2
        
        actionSheet.blurRadius = 0.0
        actionSheet.blurTintColor = UIColor(white: 0.0, alpha: 0.50)

        actionSheet.buttonHeight = 50.0
        actionSheet.cancelButtonHeight = 50.0
        actionSheet.separatorHeight = 5.0
        
        actionSheet.separatorColor = NCBrandColor.sharedInstance.seperator

        actionSheet.buttonTextAttributes = fontButton
        actionSheet.encryptedButtonTextAttributes = fontEncrypted
        actionSheet.cancelButtonTextAttributes = fontCancel
        actionSheet.disableButtonTextAttributes = fontDisable
        
        actionSheet.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet.addButton(withTitle: NSLocalizedString("_create_folder_", comment: ""), image: UIImage(named: "foldercrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFolderEncrypted))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_photos_videos_", comment: ""), image: UIImage(named: "menuUploadPhotoCrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFotoVideoEncrypted))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_file_", comment: ""), image: UIImage(named: "menuUploadFileCrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFileEncrypted))
        })

        actionSheet.addButton(withTitle: NSLocalizedString("_upload_template_", comment: ""), image: UIImage(named: "menuTemplate"), backgroundColor: colorLightGray, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            self.createMenuTemplate(view: view)
        })

        actionSheet.addButton(withTitle: NSLocalizedString("_upload_plain_mode", comment: ""), image: UIImage(named: "menuUploadPlainMode"), backgroundColor: colorLightGray, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            self.createMenuPlain(view: view)
        })
        
        actionSheet.show()
        
        CCUtility.setCreateMenuEncrypted(true)
    }

    func createMenuTemplate(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)!
        
        actionSheet.animationDuration = 0.2
        
        actionSheet.blurRadius = 0.0
        actionSheet.blurTintColor = UIColor(white: 0.0, alpha: 0.50)

        actionSheet.buttonHeight = 50.0
        actionSheet.cancelButtonHeight = 50.0
        actionSheet.separatorHeight = 5.0
        
        actionSheet.separatorColor = NCBrandColor.sharedInstance.seperator

        actionSheet.buttonTextAttributes = fontButton
        actionSheet.encryptedButtonTextAttributes = fontEncrypted
        actionSheet.cancelButtonTextAttributes = fontCancel
        actionSheet.disableButtonTextAttributes = fontDisable
        
        actionSheet.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_notes_", comment: ""), image: UIImage(named: "note"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnNote))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_web_account_", comment: ""), image: UIImage(named: "templateWebAccount"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnAccountWeb))
        })
        
        actionSheet.addButton(withTitle: "", image: nil, backgroundColor: UIColor(colorLiteralRed: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1), height: 10.0, type: AHKActionSheetButtonType.disabled, handler: {(AHKActionSheet) -> Void in
            print("disable")
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_credit_card_", comment: ""), image: UIImage(named: "cartadicredito"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCartaDiCredito))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_atm_", comment: ""), image: UIImage(named: "bancomat"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnBancomat))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_bank_account_", comment: ""), image: UIImage(named: "contocorrente"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnContoCorrente))
        })
        
        actionSheet.addButton(withTitle: "", image: nil, backgroundColor: UIColor(colorLiteralRed: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1), height: 10.0, type: AHKActionSheetButtonType.disabled, handler: {(AHKActionSheet) -> Void in
            print("disable")
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_driving_license_", comment: ""), image: UIImage(named: "patenteguida"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnPatenteGuida))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_id_card_", comment: ""), image: UIImage(named: "cartaidentita"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCartaIdentita))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_add_passport_", comment: ""), image: UIImage(named: "passaporto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnPassaporto))
        })
        
        actionSheet.show()
    }

}

// MARK: - CreateFormUploadAssets

class CreateFormUploadAssets: XLFormViewController, CCMoveDelegate {
    
    var serverUrl : String = ""
    var titleServerUrl : String?
    var assets: NSMutableArray = []
    var cryptated : Bool = false
    var session : String = ""
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    convenience init(_ titleServerUrl : String?, serverUrl : String, assets : NSMutableArray, cryptated : Bool, session : String) {
        
        self.init()
        
        if titleServerUrl == nil || titleServerUrl?.isEmpty == true {
            self.titleServerUrl = "/"
        } else {
            self.titleServerUrl = titleServerUrl
        }
        
        self.serverUrl = serverUrl
        self.assets = assets
        self.cryptated = cryptated
        self.session = session
        
        self.initializeForm()
    }
    
    //MARK: XLFormDescriptorDelegate

    func initializeForm() {

        let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow

        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor
        
        // Section: Destination Folder
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: self.titleServerUrl)
        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, color: NCBrandColor.sharedInstance.brand) as UIImage
        row.cellConfig.setObject(imageFolder, forKey: "imageView.image" as NSCopying)
        row.cellConfig.setObject(UIColor.black, forKey: "textLabel.textColor" as NSCopying)
        row.action.formSelector = #selector(changeDestinationFolder(_:))
        section.addFormRow(row)
        
        // Section: Folder Photo
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "useFolderPhoto", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_photo_camera_", comment: ""))
        row.value = 0
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "useSubFolder", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_autoupload_create_subfolder_", comment: ""))
        row.hidden = "$\("useFolderPhoto") == 0"
        
        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        
        if tableAccount?.autoUploadCreateSubfolder == true {
            row.value = 1
        } else {
            row.value = 0
        }
        section.addFormRow(row)

        // Section: Rename File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "maskFileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        
        let fileNameMask : String = CCUtility.getFileNameMask(k_keyFileNameMask)
        if fileNameMask.characters.count > 0 {
            row.value = fileNameMask
        }
        section.addFormRow(row)
        
        // Section: Preview File Name
        
        //section = XLFormSectionDescriptor.formSection()
        //form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "previewFileName", rowType: XLFormRowDescriptorTypeTextView, title: "")
        row.height = 180
        row.cellConfig.setObject(NCBrandColor.sharedInstance.tableBackground, forKey: "backgroundColor" as NSCopying)
        row.cellConfig.setObject(NCBrandColor.sharedInstance.tableBackground, forKey: "textView.backgroundColor" as NSCopying)

        row.disabled = true
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "useFolderPhoto" {
            
            if (formRow.value! as AnyObject).boolValue  == true {
                
                let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
                buttonDestinationFolder.hidden = true
                
            } else{
                
                let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
                buttonDestinationFolder.hidden = false
            }
        }
        else if formRow.tag == "useSubFolder" {
            
            if (formRow.value! as AnyObject).boolValue  == true {
                
            } else{
                
            }
        }
        else if formRow.tag == "maskFileName" {
            
            let fileName : String? = formRow.value as? String
            
            self.form.delegate = nil
            
            if fileName != nil {
                formRow.value = CCUtility.removeForbiddenCharactersServer(fileName)
            }
            
            self.form.delegate = self
            
            let previewFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "previewFileName")!
            previewFileName.value = self.previewFileName(valueRename: formRow.value as? String)
            
            // reload cell
            if fileName != nil {
                
                if newValue as! String != formRow.value as! String {
                    
                    self.reloadFormRow(formRow)
                    
                    appDelegate.messageNotification("_info_", description: "_forbidden_characters_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
                }
            }
            
            self.reloadFormRow(previewFileName)
        }
    }
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let cancelButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItemStyle.plain, target: self, action: #selector(cancel))
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItemStyle.plain, target: self, action: #selector(save))
        
        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = saveButton
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: NCBrandColor.sharedInstance.navigationBarText]
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        
        self.tableView.backgroundColor = NCBrandColor.sharedInstance.tableBackground
        
        self.reloadForm()
    }

    func reloadForm() {
        
        self.form.delegate = nil
        
        let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
        buttonDestinationFolder.title = self.titleServerUrl
        
        let maskFileName : XLFormRowDescriptor = self.form.formRow(withTag: "maskFileName")!
        let previewFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "previewFileName")!
        previewFileName.value = self.previewFileName(valueRename: maskFileName.value as? String)
        
        self.tableView.reloadData()
        self.form.delegate = self
    }

    //MARK: TableView

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        
        case 0:
            let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
            
            if buttonDestinationFolder.isHidden() {
                return ""
            } else {
                return "    " + NSLocalizedString("_destination_folder_", comment: "")
            }
        case 1:
            return "    " + NSLocalizedString("_use_folder_photos_", comment: "")
        case 2:
            return "    " + NSLocalizedString("_rename_filename_", comment: "")
        case 3:
            return NSLocalizedString("_preview_filename_", comment: "")
        default:
            return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        
        switch section {
           
        /*
        case 2:
            let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "maskFileName")!
            let text = self.writePreviewFileName(buttonDestinationFolder)
            return text
        */
            
        default:
            return ""
        }
    }

    // MARK: - Action

    func moveServerUrl(to serverUrlTo: String!, title: String!, selectedMetadatas: [Any]!) {
        
        self.serverUrl = serverUrlTo
        
        if title == nil {
            
            self.titleServerUrl = "/"
            
        } else {
            
            self.titleServerUrl = title
        }
        
        self.reloadForm()
    }
    
    func save() {
        
        self.dismiss(animated: true, completion: {
            
            let useFolderPhotoRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useFolderPhoto")!
            let useSubFolderRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useSubFolder")!
            var useSubFolder : Bool = false
            
            if (useFolderPhotoRow.value! as AnyObject).boolValue == true {
                
                self.serverUrl = NCManageDatabase.sharedInstance.getAccountAutoUploadPath(self.appDelegate.activeUrl)
                useSubFolder = (useSubFolderRow.value! as AnyObject).boolValue
            }
            
            self.appDelegate.activeMain.uploadFileAsset(self.assets, serverUrl: self.serverUrl, cryptated: self.cryptated, useSubFolder: useSubFolder, session: self.session)
        })
    }

    func cancel() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Utility
    
    func previewFileName(valueRename : String?) -> String {
        
        var returnString : String = ""
        
        if valueRename != nil {
            
            let valueRenameTrimming = valueRename!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if valueRenameTrimming.characters.count > 0 {
                
                self.form.delegate = nil
                CCUtility.setFileNameMask(valueRenameTrimming, key: k_keyFileNameMask)
                self.form.delegate = self
                
                returnString = CCUtility.createFileName(from: assets[0] as! PHAsset, key: k_keyFileNameMask)
                
            } else {
                
                CCUtility.setFileNameMask("", key: k_keyFileNameMask)
                returnString = CCUtility.createFileName(from: assets[0] as! PHAsset, key: nil)
            }
            
        } else {
            
            CCUtility.setFileNameMask("", key: k_keyFileNameMask)
            returnString = CCUtility.createFileName(from: assets[0] as! PHAsset, key: nil)
        }
        
        return NSLocalizedString("_preview_filename_", comment: "") + ":" + "\n\n" + returnString
    }
    
    func changeDestinationFolder(_ sender: XLFormRowDescriptor) {
        
        self.deselectFormRow(sender)
        
        let storyboard : UIStoryboard = UIStoryboard(name: "CCMove", bundle: nil)
        let navigationController = storyboard.instantiateViewController(withIdentifier: "CCMove") as! UINavigationController
        let viewController : CCMove = navigationController.topViewController as! CCMove
        
        viewController.delegate = self;
        viewController.tintColor = NCBrandColor.sharedInstance.navigationBarText
        viewController.barTintColor = NCBrandColor.sharedInstance.brand
        viewController.tintColorTitle = NCBrandColor.sharedInstance.navigationBarText
        viewController.move.title = NSLocalizedString("_select_", comment: "");
        viewController.networkingOperationQueue =  appDelegate.netQueue
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
    
}


