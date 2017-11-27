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

    let fontButton = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedStringKey.foregroundColor: UIColor.black]
    let fontEncrypted = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedStringKey.foregroundColor: NCBrandColor.sharedInstance.encrypted as UIColor]
    let fontCancel = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue-Bold", size: 17)!, NSAttributedStringKey.foregroundColor: UIColor.black]
    let fontDisable = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedStringKey.foregroundColor: UIColor.darkGray]

    let colorLightGray = UIColor(red: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1)
    let colorGray = UIColor(red: 150.0/255.0, green: 150.0/255.0, blue: 150.0/255.0, alpha: 1)
    var colorIcon = NCBrandColor.sharedInstance.brand
    
    @objc init (themingColor : UIColor) {
        
        super.init()
        colorIcon = themingColor
    }
    
    @objc func createMenuPlain(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)!
        
        actionSheet.animationDuration = 0.2
        actionSheet.automaticallyTintButtonImages = 0
        
        actionSheet.buttonHeight = 50.0
        actionSheet.cancelButtonHeight = 50.0
        actionSheet.separatorHeight = 5.0
        
        actionSheet.separatorColor = NCBrandColor.sharedInstance.seperator
        
        actionSheet.buttonTextAttributes = fontButton
        actionSheet.encryptedButtonTextAttributes = fontEncrypted
        actionSheet.cancelButtonTextAttributes = fontCancel
        actionSheet.disableButtonTextAttributes = fontDisable
        
        actionSheet.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_photos_videos_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "menuUploadPhoto"), color: colorGray), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFotoVideoPlain))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_file_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "menuUploadFile"), color: colorGray), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFilePlain))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_file_text_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), color: colorGray), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFileText))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_create_folder_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), color: colorIcon), backgroundColor: UIColor.white, height: 50.0 ,type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFolderPlain))
        })
        
        /*
        if appDelegate.isCryptoCloudMode {
        
            actionSheet.addButton(withTitle: NSLocalizedString("_upload_encrypted_mode", comment: ""), image: UIImage(named: "actionSheetLock"), backgroundColor: colorLightGray, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
                self.createMenuEncrypted(view: view)
            })
        }
        */
        
        actionSheet.show()
        
        CCUtility.setCreateMenuEncrypted(false)
    }
    
    @objc func createMenuEncrypted(view : UIView) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let actionSheet = AHKActionSheet.init(view: view, title: nil)!
        
        actionSheet.animationDuration = 0.2
        
        actionSheet.buttonHeight = 50.0
        actionSheet.cancelButtonHeight = 50.0
        actionSheet.separatorHeight = 5.0
        
        actionSheet.separatorColor = NCBrandColor.sharedInstance.seperator

        actionSheet.buttonTextAttributes = fontButton
        actionSheet.encryptedButtonTextAttributes = fontEncrypted
        actionSheet.cancelButtonTextAttributes = fontCancel
        actionSheet.disableButtonTextAttributes = fontDisable
        
        actionSheet.cancelButtonTitle = NSLocalizedString("_cancel_", comment: "")
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_photos_videos_", comment: ""), image: UIImage(named: "menuUploadPhotoCrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFotoVideoEncrypted))
        })

        actionSheet.addButton(withTitle: NSLocalizedString("_upload_file_", comment: ""), image: UIImage(named: "menuUploadFileCrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFileEncrypted))
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_create_folder_", comment: ""), image: UIImage(named: "foldercrypto"), backgroundColor: UIColor.white, height: 50.0, type: AHKActionSheetButtonType.encrypted, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.returnCreate(Int(k_returnCreateFolderEncrypted))
        })

        actionSheet.addButton(withTitle: NSLocalizedString("_upload_plain_mode_", comment: ""), image: UIImage(named: "menuUploadPlainMode"), backgroundColor: colorLightGray, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            self.createMenuPlain(view: view)
        })
        
        actionSheet.show()
        
        CCUtility.setCreateMenuEncrypted(true)
    }
}

// MARK: - CreateFormUploadAssets

@objc protocol createFormUploadAssetsDelegate {
    
    func dismissFormUploadAssets()
}

class CreateFormUploadAssets: XLFormViewController, CCMoveDelegate {
    
    var serverUrl : String = ""
    var titleServerUrl : String?
    var assets: NSMutableArray = []
    var cryptated : Bool = false
    var session : String = ""
    weak var delegate: createFormUploadAssetsDelegate?
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @objc convenience init(serverUrl : String, assets : NSMutableArray, cryptated : Bool, session : String, delegate: createFormUploadAssetsDelegate) {
        
        self.init()
        
        if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
            titleServerUrl = "/"
        } else {
            titleServerUrl = (serverUrl as NSString).lastPathComponent
        }
        
        self.serverUrl = serverUrl
        self.assets = assets
        self.cryptated = cryptated
        self.session = session
        self.delegate = delegate
        
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

        // Section: Add File Name Type

        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)

        row = XLFormRowDescriptor(tag: "addFileNameType", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_filenametype_photo_video_", comment: ""))
        row.value = CCUtility.getFileNameType(k_keyFileNameType)
        section.addFormRow(row)
        
        // Section: Rename File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "maskFileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        
        let fileNameMask : String = CCUtility.getFileNameMask(k_keyFileNameMask)
        if fileNameMask.count > 0 {
            row.value = fileNameMask
        }
        section.addFormRow(row)
        
        // Section: Preview File Name
        
        //section = XLFormSectionDescriptor.formSection()
        //form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "previewFileName", rowType: XLFormRowDescriptorTypeTextView, title: "")
        row.height = 180
        row.cellConfig.setObject(NCBrandColor.sharedInstance.backgroundView, forKey: "backgroundColor" as NSCopying)
        row.cellConfig.setObject(NCBrandColor.sharedInstance.backgroundView, forKey: "textView.backgroundColor" as NSCopying)

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
        else if formRow.tag == "addFileNameType" {
            CCUtility.setFileNameType((formRow.value! as AnyObject).boolValue, key: k_keyFileNameType)
            self.reloadForm()
        }
        else if formRow.tag == "maskFileName" {
            
            let fileName = formRow.value as? String
            
            self.form.delegate = nil
            
            if let fileName = fileName {
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
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        
        self.tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        self.reloadForm()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)

        self.delegate?.dismissFormUploadAssets()        
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
            return "    " + NSLocalizedString("_add_filenametype_", comment: "")
        case 3:
            return "    " + NSLocalizedString("_rename_filename_", comment: "")
        case 4:
            return String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM,MMM,DD,YY,YYYY and HH,hh,mm,ss,ampm")
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

    func moveServerUrl(to serverUrlTo: String!, title: String!) {
    
        self.serverUrl = serverUrlTo
        
        if let title = title {
            
            self.titleServerUrl = title
            
        } else {
            
            self.titleServerUrl = "/"
        }
        
        self.reloadForm()
    }
    
    @objc func save() {
        
        self.dismiss(animated: true, completion: {
            
            let useFolderPhotoRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useFolderPhoto")!
            let useSubFolderRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useSubFolder")!
            var useSubFolder : Bool = false
            
            if (useFolderPhotoRow.value! as AnyObject).boolValue == true {
                
                self.serverUrl = NCManageDatabase.sharedInstance.getAccountAutoUploadPath(self.appDelegate.activeUrl)
                useSubFolder = (useSubFolderRow.value! as AnyObject).boolValue
            }
            
            self.appDelegate.activeMain.uploadFileAsset(self.assets, serverUrl: self.serverUrl, useSubFolder: useSubFolder, session: self.session)
        })
    }

    @objc func cancel() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Utility
    
    func previewFileName(valueRename : String?) -> String {
        
        var returnString : String = ""
        let asset = assets[0] as! PHAsset
        
        if let valueRename = valueRename {
            
            let valueRenameTrimming = valueRename.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if valueRenameTrimming.count > 0 {
                
                self.form.delegate = nil
                CCUtility.setFileNameMask(valueRenameTrimming, key: k_keyFileNameMask)
                self.form.delegate = self
                
                returnString = CCUtility.createFileName(asset.value(forKey: "filename"), fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType)
            } else {
                
                CCUtility.setFileNameMask("", key: k_keyFileNameMask)
                returnString = CCUtility.createFileName(asset.value(forKey: "filename"), fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: nil, keyFileNameType: k_keyFileNameType)
            }
            
        } else {
            
            CCUtility.setFileNameMask("", key: k_keyFileNameMask)
            returnString = CCUtility.createFileName(asset.value(forKey: "filename"), fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: nil, keyFileNameType: k_keyFileNameType)
        }
        
        return String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM,MMM,DD,YY,YYYY and HH,hh,mm,ss,ampm") + ":" + "\n\n" + returnString
    }
    
    @objc func changeDestinationFolder(_ sender: XLFormRowDescriptor) {
        
        self.deselectFormRow(sender)
        
        let storyboard : UIStoryboard = UIStoryboard(name: "CCMove", bundle: nil)
        let navigationController = storyboard.instantiateViewController(withIdentifier: "CCMove") as! UINavigationController
        let viewController : CCMove = navigationController.topViewController as! CCMove
        
        viewController.delegate = self;
        viewController.tintColor = NCBrandColor.sharedInstance.brandText
        viewController.barTintColor = NCBrandColor.sharedInstance.brand
        viewController.tintColorTitle = NCBrandColor.sharedInstance.brandText
        viewController.move.title = NSLocalizedString("_select_", comment: "");
        viewController.networkingOperationQueue =  appDelegate.netQueue
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
    
}

class CreateFormUploadFile: XLFormViewController, CCMoveDelegate {
    
    var serverUrl = ""
    var titleServerUrl = ""
    var fileName = ""
    var text = ""
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    convenience init(serverUrl: String, text: String, fileName: String) {
        
        self.init()
        
        if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
            titleServerUrl = "/"
        } else {
            titleServerUrl = (serverUrl as NSString).lastPathComponent
        }
        
        self.fileName = fileName
        self.serverUrl = serverUrl
        self.text = text
        
        initializeForm()
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
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.value = fileName
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "fileName" {
            
            self.form.delegate = nil
            
            if let fileNameNew = formRow.value {
                 self.fileName = CCUtility.removeForbiddenCharactersServer(fileNameNew as! String)
            }
        
            self.title = fileName

            self.form.delegate = self
        }
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItemStyle.plain, target: self, action: #selector(save))
        
        self.navigationItem.rightBarButtonItem = saveButton
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        self.reloadForm()
    }
    
    func reloadForm() {
        
        self.form.delegate = nil
        
        let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
        buttonDestinationFolder.title = self.titleServerUrl
        
        self.title = fileName
        
        self.tableView.reloadData()
        
        self.form.delegate = self
    }
    
    // MARK: - Action
    
    func moveServerUrl(to serverUrlTo: String!, title: String!) {
        
        self.serverUrl = serverUrlTo
        
        if let title = title {
            
            self.titleServerUrl = title
            
        } else {
            
            self.titleServerUrl = "/"
        }
        
        self.reloadForm()
    }
    
    @objc func save() {
        
        let rowFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "fileName")!
        guard let name = rowFileName.value else {
            return
        }
        let ext = (name as! NSString).pathExtension.uppercased()
        var fileNameSave = ""
        
        switch ext
        {
            case "":
                fileNameSave = name as! String + ".txt"
            
            case "TXT":
                fileNameSave = name as! String
            
            default:
                fileNameSave = (name as! NSString).deletingPathExtension + ".txt"
        }
        
        self.dismiss(animated: true, completion: {
            
            let data = self.text.data(using: .utf8)
            let success = FileManager.default.createFile(atPath: "\(self.appDelegate.directoryUser!)/\(fileNameSave)", contents: data, attributes: nil)
            
            if success {
                CCNetworking.shared().uploadFile(fileNameSave, serverUrl: self.serverUrl, session: k_upload_session, taskStatus: Int(k_taskStatusResume), selector: nil, selectorPost: nil, errorCode: 0, delegate: self.appDelegate.activeMain)
            } else {
                self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
            }
        })
    }
    
    func cancel() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func changeDestinationFolder(_ sender: XLFormRowDescriptor) {
        
        self.deselectFormRow(sender)
        
        let storyboard : UIStoryboard = UIStoryboard(name: "CCMove", bundle: nil)
        let navigationController = storyboard.instantiateViewController(withIdentifier: "CCMove") as! UINavigationController
        let viewController : CCMove = navigationController.topViewController as! CCMove
        
        viewController.delegate = self;
        viewController.tintColor = NCBrandColor.sharedInstance.brandText
        viewController.barTintColor = NCBrandColor.sharedInstance.brand
        viewController.tintColorTitle = NCBrandColor.sharedInstance.brandText
        viewController.move.title = NSLocalizedString("_select_", comment: "");
        viewController.networkingOperationQueue =  appDelegate.netQueue
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
}


