//
//  CCCreateCloud.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/01/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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
import PDFGenerator
import Sheeeeeeeeet

// MARK: -

class CreateMenuAdd: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    let fontButton = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedString.Key.foregroundColor: UIColor.black]
    let fontEncrypted = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.encrypted as UIColor]
    let fontCancel = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue-Bold", size: 17)!, NSAttributedString.Key.foregroundColor: UIColor.black]
    let fontDisable = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedString.Key.foregroundColor: UIColor.darkGray]

    var colorIcon = NCBrandColor.sharedInstance.brandElement
    
    @objc init (themingColor : UIColor) {
        
        super.init()
        colorIcon = themingColor
    }
    
    @objc func createMenu(viewController: UIViewController, view : UIView) {
        
        var items = [ActionSheetItem]()
        
        items.append(ActionSheetItem(title: NSLocalizedString("_upload_photos_videos_", comment: ""), value: 1, image: CCGraphics.changeThemingColorImage(UIImage(named: "media"), multiplier:1, color: NCBrandColor.sharedInstance.icon)))
        
        items.append(ActionSheetItem(title: NSLocalizedString("_upload_file_", comment: ""), value: 2, image: CCGraphics.changeThemingColorImage(UIImage(named: "file"), multiplier:1, color: NCBrandColor.sharedInstance.icon)))
       
        items.append(ActionSheetItem(title: NSLocalizedString("_upload_file_text_", comment: ""), value: 3, image: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), multiplier:1, color: NCBrandColor.sharedInstance.icon)))
        
        if #available(iOS 11.0, *) {
            items.append(ActionSheetItem(title: NSLocalizedString("_scans_document_", comment: ""), value: 4, image: CCGraphics.changeThemingColorImage(UIImage(named: "scan"), multiplier:2, color: NCBrandColor.sharedInstance.icon)))
        }
        
        items.append(ActionSheetItem(title: NSLocalizedString("_create_folder_", comment: ""), value: 5, image: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), multiplier:1, color: colorIcon)))
        
        // items.append(ActionSheetSectionTitle(title: "Cheap"))
        // items.append(ActionSheetSectionMargin())

        /*
        let appearanceSectionMargin = ActionSheetAppearance.standard
        //appearanceSectionMargin. = 10
        appearanceSectionMargin.backgroundColor = UIColor.red
        let itemSectionMargin = ActionSheetSectionTitle(title: "Cheap")
        itemSectionMargin.customAppearance = appearanceSectionMargin
        items.append(itemSectionMargin)
        */
        
        if let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getRichdocumentsMimetypes() {
            if richdocumentsMimetypes.count > 0 {
                items.append(ActionSheetItem(title: NSLocalizedString("_create_new_document_", comment: ""), value: 6, image: UIImage.init(named: "document_menu")))
                items.append(ActionSheetItem(title: NSLocalizedString("_create_new_spreadsheet", comment: ""), value: 7, image: UIImage(named: "file_xls_menu")))
                items.append(ActionSheetItem(title: NSLocalizedString("_create_new_presentation_", comment: ""), value: 8, image: UIImage(named: "file_ppt_menu")))
            }
        }
        
        items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
        
        let actionSheet = ActionSheet(items: items) { sheet, item in
            if item.value as? Int == 1 { self.appDelegate.activeMain.openAssetsPickerController() }
            if item.value as? Int == 2 { self.appDelegate.activeMain.openImportDocumentPicker() }
            if item.value as? Int == 3 {
                let storyboard = UIStoryboard(name: "NCText", bundle: nil)
                let controller = storyboard.instantiateViewController(withIdentifier: "NCText")
                controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                self.appDelegate.activeMain.present(controller, animated: true, completion: nil)
            }
            if item.value as? Int == 4 {
                if #available(iOS 11.0, *) {
                    NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: self.appDelegate.activeMain, openScan: true)
                }
            }
            if item.value as? Int == 5 { self.appDelegate.activeMain.createFolder() }

            if item.value as? Int == 6 {
                let form = CreateFormUploadRichdocuments.init(typeTemplate: k_richdocument_document)
                let navigationController = UINavigationController.init(rootViewController: form)
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
                
                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }
            if item.value as? Int == 7 { print("Cancel buttons has the value `true`") }
            if item.value as? Int == 8 { print("Cancel buttons has the value `true`") }

            if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
        }
        
        actionSheet.present(in: viewController, from: view)
    }
}

// MARK: -

class CreateFormUploadRichdocuments: XLFormViewController, NCSelectDelegate {
    
    var typeTemplate = ""
    var serverUrl = ""
    var fileNameFolder = ""
    var fileName = ""
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc convenience init(typeTemplate : String) {
        self.init()
        
        self.typeTemplate = typeTemplate
        serverUrl = appDelegate.activeMain.serverUrl
        
        if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
            fileNameFolder = "/"
        } else {
            fileNameFolder = (serverUrl as NSString).lastPathComponent
        }
        
        self.initializeForm()
    }
    
    func initializeForm() {
        
        let form : XLFormDescriptor = XLFormDescriptor(title: NSLocalizedString("_upload_photos_videos_", comment: "")) as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
        
        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor
        
        // Section: Destination Folder
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_save_path_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: fileNameFolder)
        row.action.formSelector = #selector(changeDestinationFolder(_:))
        
        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:1, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig["imageView.image"] = imageFolder
        
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_filename_", comment: ""))
        form.addFormSection(section)
        
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.value = self.fileName
        
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        self.form = form
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.createTemplateRichdocuments(withTemplate: typeTemplate, success: { (listOfTemplate) in
            //
        }, failure: { (message, errorCode) in
            //
        })
        
        let cancelButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancel))
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(save))
        
        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = saveButton
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        
        self.reloadForm()
    }
    
    func reloadForm() {
        
        self.form.delegate = nil
        
        let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
        buttonDestinationFolder.title = fileNameFolder
        
        self.tableView.reloadData()
        self.form.delegate = self
    }
    
    // MARK: - Action
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String) {
        
        guard let serverUrl = serverUrl else {
            return
        }
        
        self.serverUrl = serverUrl
        if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
            fileNameFolder = "/"
        } else {
            fileNameFolder = (serverUrl as NSString).lastPathComponent
        }
        reloadForm()
    }
    
    @objc func changeDestinationFolder(_ sender: XLFormRowDescriptor) {
        
        self.deselectFormRow(sender)
        
        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        let viewController = navigationController.topViewController as! NCSelect
        
        viewController.delegate = self
        viewController.hideButtonCreateFolder = false
        viewController.includeDirectoryE2EEncryption = false
        viewController.includeImages = false
        viewController.layoutViewSelect = k_layout_view_move
        viewController.selectFile = false
        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
        viewController.type = ""

        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @objc func save() {
        
        self.dismiss(animated: true, completion: {
            
            //self.appDelegate.activeMain.uploadFileAsset(self.assets, serverUrl: self.serverUrl, useSubFolder: useSubFolder, session: self.session)
        })
    }
    
    @objc func cancel() {
        
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: -

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

        let form : XLFormDescriptor = XLFormDescriptor(title: NSLocalizedString("_upload_photos_videos_", comment: "")) as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow

        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor
        
        // Section: Destination Folder
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_save_path_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: self.titleServerUrl)
        row.action.formSelector = #selector(changeDestinationFolder(_:))

        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:1, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig["imageView.image"] = imageFolder
        
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // User folder Autoupload
        row = XLFormRowDescriptor(tag: "useFolderAutoUpload", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_use_folder_auto_upload_", comment: ""))
        row.value = 0
        
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // Use Sub folder
        row = XLFormRowDescriptor(tag: "useSubFolder", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_autoupload_create_subfolder_", comment: ""))
        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        if tableAccount?.autoUploadCreateSubfolder == true {
            row.value = 1
        } else {
            row.value = 0
        }
        row.hidden = "$\("useFolderAutoUpload") == 0"

        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)

        section.addFormRow(row)
        
        // Section Mode filename
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_mode_filename_", comment: ""))
        form.addFormSection(section)
        
        // Maintain the original fileName
        
        row = XLFormRowDescriptor(tag: "maintainOriginalFileName", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_maintain_original_filename_", comment: ""))
        row.value = CCUtility.getOriginalFileName(k_keyFileNameOriginal)
        
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // Add File Name Type

        row = XLFormRowDescriptor(tag: "addFileNameType", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_add_filenametype_", comment: ""))
        row.value = CCUtility.getFileNameType(k_keyFileNameType)
        row.hidden = "$\("maintainOriginalFileName") == 1"
        
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)

        section.addFormRow(row)
        
        // Section: Rename File Name
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_filename_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "maskFileName", rowType: XLFormRowDescriptorTypeAccount, title: (NSLocalizedString("_filename_", comment: "")))
        let fileNameMask : String = CCUtility.getFileNameMask(k_keyFileNameMask)
        if fileNameMask.count > 0 {
            row.value = fileNameMask
        }
        row.hidden = "$\("maintainOriginalFileName") == 1"
        
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)

        section.addFormRow(row)
        
        // Section: Preview File Name
        
        row = XLFormRowDescriptor(tag: "previewFileName", rowType: XLFormRowDescriptorTypeTextView, title: "")
        row.height = 180
        row.disabled = true

        row.cellConfig["textView.backgroundColor"] = NCBrandColor.sharedInstance.backgroundView
        row.cellConfig["textView.font"] = UIFont.systemFont(ofSize: 14.0)
        
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "useFolderAutoUpload" {
            
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
        
        let cancelButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancel))
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(save))
        
        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = saveButton
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        
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

    func moveServerUrl(to serverUrlTo: String!, title: String!, type: String!) {
    
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
            
            let useFolderPhotoRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useFolderAutoUpload")!
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
                
                returnString = CCUtility.createFileName(asset.value(forKey: "filename") as! String?, fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)
                
            } else {
                
                CCUtility.setFileNameMask("", key: k_keyFileNameMask)
                returnString = CCUtility.createFileName(asset.value(forKey: "filename") as! String?, fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: nil, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)
            }
            
        } else {
            
            CCUtility.setFileNameMask("", key: k_keyFileNameMask)
            returnString = CCUtility.createFileName(asset.value(forKey: "filename") as! String?, fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: nil, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)
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
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_save_path_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: self.titleServerUrl)
        row.action.formSelector = #selector(changeDestinationFolder(_:))

        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:1, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig["imageView.image"] = imageFolder
        
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_filename_", comment: ""))
        form.addFormSection(section)
        
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.value = self.fileName
        
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "fileName" {
            
            self.form.delegate = nil
            
            if let fileNameNew = formRow.value {
                 self.fileName = CCUtility.removeForbiddenCharactersServer(fileNameNew as? String)
            }
        
            formRow.value = self.fileName
            self.title = fileName
            
            self.updateFormRow(formRow)
            
            self.form.delegate = self
        }
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(save))
        self.navigationItem.rightBarButtonItem = saveButton
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
    }
    
    // MARK: - Action
    
    func moveServerUrl(to serverUrlTo: String!, title: String!, type: String!) {
        
        self.serverUrl = serverUrlTo
        
        if let title = title {
            
            self.titleServerUrl = title
            
        } else {
            
            self.titleServerUrl = "/"
        }
        
        // Update
        let row : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
        row.title = self.titleServerUrl
        self.updateFormRow(row)
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
    
    enum typeDpiQuality {
        case low
        case medium
        case hight
    }
    var dpiQuality: typeDpiQuality = typeDpiQuality.medium
    
    var serverUrl = ""
    var titleServerUrl = ""
    var arrayImages = [UIImage]()
    var fileName = CCUtility.createFileNameDate("scan", extension: "pdf")
    var password : PDFPassword = ""
    var fileType = "PDF"
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    convenience init(serverUrl: String, arrayImages: [UIImage]) {
        
        self.init()
        
        if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
            titleServerUrl = "/"
        } else {
            titleServerUrl = (serverUrl as NSString).lastPathComponent
        }
        
        self.serverUrl = serverUrl
        self.arrayImages = arrayImages
        
        initializeForm()
    }
    
    //MARK: XLFormDescriptorDelegate
    
    func initializeForm() {
        
        let form : XLFormDescriptor = XLFormDescriptor(title: NSLocalizedString("_save_settings_", comment: "")) as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
        
        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor
        
        // Section: Destination Folder
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_save_path_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: self.titleServerUrl)
        row.action.formSelector = #selector(changeDestinationFolder(_:))

        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:1, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig["imageView.image"] = imageFolder

        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // Section: Quality
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_quality_image_title_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "compressionQuality", rowType: XLFormRowDescriptorTypeSlider)
        row.value = 0.5
        row.title = NSLocalizedString("_quality_medium_", comment: "")
        
        row.cellConfig["slider.minimumTrackTintColor"] = NCBrandColor.sharedInstance.brand

        row.cellConfig["slider.maximumValue"] = 1
        row.cellConfig["slider.minimumValue"] = 0
        row.cellConfig["steps"] = 2

        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.center.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)

        // Section: Password
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_pdf_password_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "password", rowType: XLFormRowDescriptorTypePassword, title: NSLocalizedString("_password_", comment: ""))
        
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // Section: File
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_file_creation_", comment: ""))
        form.addFormSection(section)
        
        if arrayImages.count == 1 {
            row = XLFormRowDescriptor(tag: "filetype", rowType: XLFormRowDescriptorTypeSelectorSegmentedControl, title: NSLocalizedString("_file_type_", comment: ""))
            row.selectorOptions = ["PDF","JPG"]
            row.value = "PDF"
            
            row.cellConfig["tintColor"] = NCBrandColor.sharedInstance.brand
            row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
            
            section.addFormRow(row)
        }
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.value = self.fileName

        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)

        section.addFormRow(row)
       
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "fileName" {
            
            self.form.delegate = nil
            
            let fileNameNew = newValue as? String
            
            if fileNameNew != nil {
                self.fileName = CCUtility.removeForbiddenCharactersServer(fileNameNew)
            } else {
                self.fileName = ""
            }
            
            formRow.value = self.fileName
            
            self.updateFormRow(formRow)
            
            self.form.delegate = self
        }
        
        if formRow.tag == "compressionQuality" {
            
            self.form.delegate = nil
            
            //let row : XLFormRowDescriptor  = self.form.formRow(withTag: "descriptionQuality")!
            let newQuality = newValue as? NSNumber
            let compressionQuality = (newQuality?.doubleValue)!
            
            if compressionQuality >= 0.0 && compressionQuality <= 0.3  {
                formRow.title = NSLocalizedString("_quality_low_", comment: "")
                dpiQuality = typeDpiQuality.low
            } else if compressionQuality > 0.3 && compressionQuality <= 0.6 {
                formRow.title = NSLocalizedString("_quality_medium_", comment: "")
                dpiQuality = typeDpiQuality.medium
            } else if compressionQuality > 0.6 && compressionQuality <= 1.0 {
                formRow.title = NSLocalizedString("_quality_high_", comment: "")
                dpiQuality = typeDpiQuality.hight
            }
            
            self.updateFormRow(formRow)
            
            self.form.delegate = self
        }
        
        if formRow.tag == "password" {
            let stringPassword = newValue as? String
            if stringPassword != nil {
                password = PDFPassword(stringPassword!)
            } else {
                password = PDFPassword("")
            }
        }
        
        if formRow.tag == "filetype" {
            fileType = newValue as! String
            
            let rowFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "fileName")!
            let rowPassword : XLFormRowDescriptor  = self.form.formRow(withTag: "password")!
            
            // rowFileName
            guard var name = rowFileName.value else {
                return
            }
            if name as! String == "" {
                name = CCUtility.createFileNameDate("scan", extension: "pdf")
            }
            
            let ext = (name as! NSString).pathExtension.uppercased()
            var newFileName = ""
            
            if (ext == "") {
                newFileName = name as! String + "." + fileType.lowercased()
            } else {
                newFileName = (name as! NSString).deletingPathExtension + "." + fileType.lowercased()
            }
            
            rowFileName.value = newFileName
            
            self.updateFormRow(rowFileName)
            
            // rowPassword
            if fileType == "JPG" {
                rowPassword.value = ""
                password = PDFPassword("")
                rowPassword.disabled = true
            } else {
                rowPassword.disabled = false
            }
            
            self.updateFormRow(rowPassword)
        }
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(save))
        self.navigationItem.rightBarButtonItem = saveButton
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
//        self.tableView.sectionHeaderHeight = 10
//        self.tableView.sectionFooterHeight = 10
//        self.tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        
//        let row : XLFormRowDescriptor  = self.form.formRow(withTag: "fileName")!
//        let rowCell = row.cell(forForm: self)
//        rowCell.becomeFirstResponder()
    }
    
    // MARK: - Action
    
    func moveServerUrl(to serverUrlTo: String!, title: String!, type: String!) {
        
        self.serverUrl = serverUrlTo
        
        if let title = title {
            
            self.titleServerUrl = title
            
        } else {
            
            self.titleServerUrl = "/"
        }
        
        // Update
        let row : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
        row.title = self.titleServerUrl
        self.updateFormRow(row)
    }
    
    @objc func save() {
        
        let rowFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "fileName")!
        guard let name = rowFileName.value else {
            return
        }
        if name as! String == "" {
            return
        }
        
        let ext = (name as! NSString).pathExtension.uppercased()
        var fileNameSave = ""
        
        if (ext == "") {
            fileNameSave = name as! String + "." + fileType.lowercased()
        } else {
            fileNameSave = (name as! NSString).deletingPathExtension + "." + fileType.lowercased()
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
        
        guard let fileNameGenerateExport = CCUtility.getDirectoryProviderStorageFileID(fileID, fileNameView: fileNameSave) else {
            self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
            return
        }
        
        if fileType == "PDF" {
        
            var pdfPages = [PDFPage]()

            //Generate PDF
            for var image in self.arrayImages {
                
                image = changeImageFromQuality(image, dpiQuality: dpiQuality)
                
                guard let data = image.jpegData(compressionQuality: 0.5) else {
                    self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
                    return
                }
                let page = PDFPage.image(UIImage(data: data)!)
                pdfPages.append(page)
            }
            
            do {
                try PDFGenerator.generate(pdfPages, to: fileNameGenerateExport, password: password)
            } catch {
                self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
                return
            }
        }
        
        if fileType == "JPG" {
            
            let image =  changeImageFromQuality(self.arrayImages[0], dpiQuality: dpiQuality)
            
            guard let data = image.jpegData(compressionQuality: CGFloat(0.5)) else {
                self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
                return
            }
            
            do {
                try data.write(to: NSURL.fileURL(withPath: fileNameGenerateExport), options: .atomic)
            } catch {
                self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
                return
            }
        }
        
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
        
        // Request delete all image scanned
        let alertController = UIAlertController(title: "", message: NSLocalizedString("_delete_all_scanned_images_", comment: ""), preferredStyle: .alert)
        
        let actionYes = UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
            
            let path = CCUtility.getDirectoryScan()!
            
            do {
                let filePaths = try FileManager.default.contentsOfDirectory(atPath: path)
                for filePath in filePaths {
                    try FileManager.default.removeItem(atPath: path + "/" + filePath)
                }
            } catch let error as NSError {
                print("Error: \(error.debugDescription)")
            }
            
            self.dismiss(animated: true, completion: nil)
        }
        
        let actionNo = UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
            self.dismiss(animated: true, completion: nil)
        }
        
        alertController.addAction(actionYes)
        alertController.addAction(actionNo)
        self.present(alertController, animated: true, completion:nil)
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
    
    func changeImageFromQuality(_ image: UIImage, dpiQuality: typeDpiQuality) -> UIImage {
        
        let imageWidthInPixels = image.size.width * image.scale
        let imageHeightInPixels = image.size.height * image.scale
        
        switch dpiQuality {
        case typeDpiQuality.low:                        // 72 DPI
            if imageWidthInPixels > 595 || imageHeightInPixels > 842  {
                return CCGraphics.scale(image, to: CGSize(width: 595, height: 842), isAspectRation: true)
            }
        case typeDpiQuality.medium:                     // 150 DPI
            if imageWidthInPixels > 1240 || imageHeightInPixels > 1754  {
                return CCGraphics.scale(image, to: CGSize(width: 1240, height: 1754), isAspectRation: true)
            }
        case typeDpiQuality.hight:                      // 200 DPI
            if imageWidthInPixels > 1654 || imageHeightInPixels > 2339  {
                return CCGraphics.scale(image, to: CGSize(width: 1654, height: 2339), isAspectRation: true)
            }
        }
        
        return image
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
        
        let fileName = CCUtility.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)!
        let fileNamePath = CCUtility.getDirectoryScan() + "/" + fileName
        
        do {
            try results.scannedImage.pngData()?.write(to: NSURL.fileURL(withPath: fileNamePath), options: .atomic)
        } catch { }
        
        scanner.dismiss(animated: true, completion: {
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
    }
}


