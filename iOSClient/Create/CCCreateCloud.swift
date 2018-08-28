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

// MARK: -

class CreateMenuAdd: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    let fontButton = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedStringKey.foregroundColor: UIColor.black]
    let fontEncrypted = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedStringKey.foregroundColor: NCBrandColor.sharedInstance.encrypted as UIColor]
    let fontCancel = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue-Bold", size: 17)!, NSAttributedStringKey.foregroundColor: UIColor.black]
    let fontDisable = [NSAttributedStringKey.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedStringKey.foregroundColor: UIColor.darkGray]

    let colorLightGray = UIColor(red: 250.0/255.0, green: 250.0/255.0, blue: 250.0/255.0, alpha: 1)
    let colorGray = UIColor(red: 150.0/255.0, green: 150.0/255.0, blue: 150.0/255.0, alpha: 1)
    var colorIcon = NCBrandColor.sharedInstance.brandElement
    
    @objc init (themingColor : UIColor) {
        
        super.init()
        colorIcon = themingColor
    }
    
    @objc func createMenu(view : UIView) {
        
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
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_photos_videos_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "media"), multiplier:2, color: colorGray), backgroundColor: NCBrandColor.sharedInstance.backgroundView, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.openAssetsPickerController()
        })
        
/*
#if DEBUG
        if #available(iOS 11.0, *) {
            actionSheet.addButton(withTitle: NSLocalizedString("_scans_document_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "scan"), multiplier:2, color: colorGray), backgroundColor: NCBrandColor.sharedInstance.backgroundView, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
                NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: appDelegate.activeMain, openScan: true)
            })
        }
#endif
*/
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_file_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "file"), multiplier:2, color: colorGray), backgroundColor: NCBrandColor.sharedInstance.backgroundView, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.openImportDocumentPicker()
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_upload_file_text_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), multiplier:2, color: colorGray), backgroundColor: NCBrandColor.sharedInstance.backgroundView, height: 50.0, type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            
            let storyboard = UIStoryboard(name: "NCText", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "NCText")
            controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            appDelegate.activeMain.present(controller, animated: true, completion: nil)
        })
        
        actionSheet.addButton(withTitle: NSLocalizedString("_create_folder_", comment: ""), image: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), multiplier:2, color: colorIcon), backgroundColor: NCBrandColor.sharedInstance.backgroundView, height: 50.0 ,type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            appDelegate.activeMain.createFolder()
        })
        
        actionSheet.show()
    }
}

// MARK: -

@objc protocol createFormUploadAssetsDelegate {
    
    func dismissFormUploadAssets()
}

// MARK: -

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
        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:2, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig.setObject(imageFolder, forKey: "imageView.image" as NSCopying)
        row.cellConfig.setObject(UIColor.black, forKey: "textLabel.textColor" as NSCopying)
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        row.action.formSelector = #selector(changeDestinationFolder(_:))
        section.addFormRow(row)
        
        // Section Switch
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        // Folder Photo
        
        row = XLFormRowDescriptor(tag: "useFolderMedia", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_use_folder_media_", comment: ""))
        row.value = 0
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        section.addFormRow(row)
        
        // Use Sub folder
        row = XLFormRowDescriptor(tag: "useSubFolder", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_autoupload_create_subfolder_", comment: ""))
        row.hidden = "$\("useFolderMedia") == 0"
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        
        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        
        if tableAccount?.autoUploadCreateSubfolder == true {
            row.value = 1
        } else {
            row.value = 0
        }
        section.addFormRow(row)

        // Maintain the original fileName
        
        row = XLFormRowDescriptor(tag: "maintainOriginalFileName", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_maintain_original_filename_", comment: ""))
        row.value = CCUtility.getOriginalFileName(k_keyFileNameOriginal)
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        section.addFormRow(row)
        
        // Add File Name Type

        row = XLFormRowDescriptor(tag: "addFileNameType", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_add_filenametype_", comment: ""))
        row.hidden = "$\("maintainOriginalFileName") == 1"
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        row.value = CCUtility.getFileNameType(k_keyFileNameType)
        section.addFormRow(row)
        
        // Section: Rename File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "maskFileName", rowType: XLFormRowDescriptorTypeAccount, title: (NSLocalizedString("_filename_", comment: ""))+":")
        row.hidden = "$\("maintainOriginalFileName") == 1"
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)

        let fileNameMask : String = CCUtility.getFileNameMask(k_keyFileNameMask)
        if fileNameMask.count > 0 {
            row.value = fileNameMask
        }
        section.addFormRow(row)
        
        // Section: Preview File Name
        
        row = XLFormRowDescriptor(tag: "previewFileName", rowType: XLFormRowDescriptorTypeTextView, title: "")

        row.height = 180
        row.cellConfig.setObject(NCBrandColor.sharedInstance.backgroundView, forKey: "backgroundColor" as NSCopying)
        row.cellConfig.setObject(NCBrandColor.sharedInstance.backgroundView, forKey: "textView.backgroundColor" as NSCopying)

        row.disabled = true
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "useFolderMedia" {
            
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
        else if formRow.tag == "maintainOriginalFileName" {
            CCUtility.setOriginalFileName((formRow.value! as AnyObject).boolValue, key: k_keyFileNameOriginal)
            self.reloadForm()
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
            
            let useFolderPhotoRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useFolderMedia")!
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
        
        var returnString: String = ""
        let asset = assets[0] as! PHAsset
        
        if (CCUtility.getOriginalFileName(k_keyFileNameOriginal)) {
            
            return (NSLocalizedString("_filename_", comment: "") + ": " + (asset.value(forKey: "filename") as! String))
            
        } else if let valueRename = valueRename {
            
            let valueRenameTrimming = valueRename.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if valueRenameTrimming.count > 0 {
                
                self.form.delegate = nil
                CCUtility.setFileNameMask(valueRename, key: k_keyFileNameMask)
                self.form.delegate = self
                
                returnString = CCUtility.createFileName(asset.value(forKey: "filename"), fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)
                
            } else {
                
                CCUtility.setFileNameMask("", key: k_keyFileNameMask)
                returnString = CCUtility.createFileName(asset.value(forKey: "filename"), fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: nil, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)
            }
            
        } else {
            
            CCUtility.setFileNameMask("", key: k_keyFileNameMask)
            returnString = CCUtility.createFileName(asset.value(forKey: "filename"), fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: nil, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)
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
        // E2EE
        viewController.includeDirectoryE2EEncryption = true;
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
    
}

// MARK: -

class CreateFormUploadFileText: XLFormViewController, CCMoveDelegate {
    
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
        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:2, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig.setObject(imageFolder, forKey: "imageView.image" as NSCopying)
        row.cellConfig.setObject(UIColor.black, forKey: "textLabel.textColor" as NSCopying)
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        row.action.formSelector = #selector(changeDestinationFolder(_:))
        section.addFormRow(row)
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
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
        
        if (ext == "") {
            fileNameSave = name as! String + ".txt"
        } else if (CCUtility.isDocumentModifiableExtension(ext)) {
            fileNameSave = name as! String
        } else {
            fileNameSave = (name as! NSString).deletingPathExtension + ".txt"
        }
        
        guard let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(self.serverUrl) else {
            return
        }
        let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "directoryID == %@ AND fileNameView == %@", directoryID, fileNameSave))
        
        if (metadata != nil) {
            
            let alertController = UIAlertController(title: fileNameSave, message: NSLocalizedString("_file_already_exists_", comment: ""), preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { (action:UIAlertAction) in
            }
            
            let overwriteAction = UIAlertAction(title: NSLocalizedString("_overwrite_", comment: ""), style: .cancel) { (action:UIAlertAction) in
                self.dismissAndUpload(fileNameSave, fileID: metadata!.fileID, directoryID: directoryID)
            }
            
            alertController.addAction(cancelAction)
            alertController.addAction(overwriteAction)
            
            self.present(alertController, animated: true, completion:nil)
            
        } else {
           let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(self.serverUrl)!
           dismissAndUpload(fileNameSave, fileID: directoryID + fileNameSave, directoryID: directoryID)
        }
    }
    
    func dismissAndUpload(_ fileNameSave: String, fileID: String, directoryID: String) {
        
        self.dismiss(animated: true, completion: {
            
            let data = self.text.data(using: .utf8)
            let success = FileManager.default.createFile(atPath: CCUtility.getDirectoryProviderStorageFileID(fileID, fileNameView: fileNameSave), contents: data, attributes: nil)
            
            if success {
                
                let metadataForUpload = tableMetadata()
                
                metadataForUpload.account = self.appDelegate.activeAccount
                metadataForUpload.date = NSDate()
                metadataForUpload.directoryID = directoryID
                metadataForUpload.fileID = fileID
                metadataForUpload.fileName = fileNameSave
                metadataForUpload.fileNameView = fileNameSave
                metadataForUpload.session = k_upload_session
                metadataForUpload.sessionSelector = selectorUploadFile
                metadataForUpload.status = Int(k_metadataStatusWaitUpload)
                
                _ = NCManageDatabase.sharedInstance.addMetadata(metadataForUpload)
                self.appDelegate.perform(#selector(self.appDelegate.loadAutoDownloadUpload), on: Thread.main, with: nil, waitUntilDone: true)
                
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: self.serverUrl, fileID: nil, action: Int32(k_action_NULL))
                
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
        // E2EE
        viewController.includeDirectoryE2EEncryption = true;
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
}

//MARK: -

class CreateFormUploadScanDocument: XLFormViewController, CCMoveDelegate {
    
    var serverUrl = ""
    var titleServerUrl = ""
    var arrayFileName = [String]()
    var fileName = "scan.pdf"
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    convenience init(serverUrl: String, arrayFileName: [String]) {
        
        self.init()
        
        if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
            titleServerUrl = "/"
        } else {
            titleServerUrl = (serverUrl as NSString).lastPathComponent
        }
        
        self.serverUrl = serverUrl
        self.arrayFileName = arrayFileName
        
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
        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:2, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig.setObject(imageFolder, forKey: "imageView.image" as NSCopying)
        row.cellConfig.setObject(UIColor.black, forKey: "textLabel.textColor" as NSCopying)
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        row.action.formSelector = #selector(changeDestinationFolder(_:))
        section.addFormRow(row)
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
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
        
        if (ext == "") {
            fileNameSave = name as! String + ".pdf"
        } else {
            fileNameSave = (name as! NSString).deletingPathExtension + ".pdf"
        }
        
        guard let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(self.serverUrl) else {
            return
        }
        let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "directoryID == %@ AND fileNameView == %@", directoryID, fileNameSave))
        
        if (metadata != nil) {
            
            let alertController = UIAlertController(title: fileNameSave, message: NSLocalizedString("_file_already_exists_", comment: ""), preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { (action:UIAlertAction) in
            }
            
            let overwriteAction = UIAlertAction(title: NSLocalizedString("_overwrite_", comment: ""), style: .cancel) { (action:UIAlertAction) in
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "directoryID == %@ AND fileNameView == %@", directoryID, fileNameSave), clearDateReadDirectoryID: directoryID)
                self.dismissAndUpload(fileNameSave, fileID: directoryID + fileNameSave, directoryID: directoryID)
            }
            
            alertController.addAction(cancelAction)
            alertController.addAction(overwriteAction)
            
            self.present(alertController, animated: true, completion:nil)
            
        } else {
            let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(self.serverUrl)!
            dismissAndUpload(fileNameSave, fileID: directoryID + fileNameSave, directoryID: directoryID)
        }
    }
    
    func dismissAndUpload(_ fileNameSave: String, fileID: String, directoryID: String) {
        
        var pdfPages = [PDFPage]()

        guard let fileNameGeneratePDF = CCUtility.getDirectoryProviderStorageFileID(fileID, fileNameView: fileNameSave) else {
            self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
            return
        }
        
        //Generate PDF
        for fileNameImage in self.arrayFileName {
            let fileNameImagePath = CCUtility.getDirectoryScanSelect() + "/" + fileNameImage
            let page = PDFPage.imagePath(fileNameImagePath)
            pdfPages.append(page)
        }
        
        do {
            try PDFGenerator.generate(pdfPages, to: fileNameGeneratePDF)
        } catch {
            self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
            return
        }
        
        //Remove images processed
        for fileNameImage in self.arrayFileName {
            let fileNameImagePath = CCUtility.getDirectoryScanSelect() + "/" + fileNameImage
            CCUtility.removeFile(atPath: fileNameImagePath)
        }
        
        //Remove plist in reader for cache issue
        //let filePlistReader = CCUtility.getDirectoryReaderMetadata() + "/" + (fileNameSave as NSString).deletingPathExtension + ".plist"
        //CCUtility.removeFile(atPath: filePlistReader)
        
        //Create metadata for upload
        let metadataForUpload = tableMetadata()
        
        metadataForUpload.account = self.appDelegate.activeAccount
        metadataForUpload.date = NSDate()
        metadataForUpload.directoryID = directoryID
        metadataForUpload.fileID = fileID
        metadataForUpload.fileName = fileNameSave
        metadataForUpload.fileNameView = fileNameSave
        metadataForUpload.session = k_upload_session
        metadataForUpload.sessionSelector = selectorUploadFile
        metadataForUpload.status = Int(k_metadataStatusWaitUpload)
        
        _ = NCManageDatabase.sharedInstance.addMetadata(metadataForUpload)
        self.appDelegate.perform(#selector(self.appDelegate.loadAutoDownloadUpload), on: Thread.main, with: nil, waitUntilDone: true)
        
        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: self.serverUrl, fileID: nil, action: Int32(k_action_NULL))
        
        self.dismiss(animated: true, completion: nil)
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
        // E2EE
        viewController.includeDirectoryE2EEncryption = true;
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
}

class NCCreateScanDocument : NSObject, ImageScannerControllerDelegate {
    
    @objc static let sharedInstance: NCCreateScanDocument = {
        let instance = NCCreateScanDocument()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewController: UIViewController?
    var openScan: Bool = false
    
    @available(iOS 10, *)
    func openScannerDocument(viewController: UIViewController, openScan: Bool) {
        
        self.viewController = viewController
        self.openScan = openScan
        
        let scannerVC = ImageScannerController()
        scannerVC.imageScannerDelegate = self
        self.viewController?.present(scannerVC, animated: true, completion: nil)
    }
    
    @available(iOS 10, *)
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
        
        scanner.dismiss(animated: true, completion: {
            
            let fileName = CCUtility.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)!
            let fileNamePath = CCUtility.getDirectoryScan() + "/" + fileName
            
            do {
                try UIImagePNGRepresentation(results.scannedImage)?.write(to: NSURL.fileURL(withPath: fileNamePath), options: .atomic)
            } catch { }
            
            if (self.openScan) {
                let storyboard = UIStoryboard(name: "Scan", bundle: nil)
                let controller = storyboard.instantiateInitialViewController()!
                
                controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                self.viewController?.present(controller, animated: true, completion: nil)
            }
        })
    }
    
    @available(iOS 10, *)
    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        scanner.dismiss(animated: true, completion: nil)
    }
    
    @available(iOS 10, *)
    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
        appDelegate.messageNotification("_error_", description: error.localizedDescription, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
        print(error)
    }
}


