//
//  NCCreateFormUploadAssets.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/11/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import Foundation
import Queuer

@objc protocol createFormUploadAssetsDelegate {
    
    func dismissFormUploadAssets()
}

class NCCreateFormUploadAssets: XLFormViewController, NCSelectDelegate {
    
    var serverUrl: String = ""
    var titleServerUrl: String?
    var assets: [PHAsset] = []
    var cryptated: Bool = false
    var session: String = ""
    weak var delegate: createFormUploadAssetsDelegate?
    let requestOptions = PHImageRequestOptions()
    var imagePreview: UIImage?
    let targetSizeImagePreview = CGSize(width:100, height: 100)
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc convenience init(serverUrl: String, assets: [PHAsset], cryptated: Bool, session: String, delegate: createFormUploadAssetsDelegate?) {
        
        self.init()
        
        if serverUrl == NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) {
            titleServerUrl = "/"
        } else {
            if let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl)) {
                if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(tableDirectory.ocId) {
                    titleServerUrl = metadata.fileNameView
                } else { titleServerUrl = (serverUrl as NSString).lastPathComponent }
            } else { titleServerUrl = (serverUrl as NSString).lastPathComponent }
        }
        
        self.serverUrl = serverUrl
        self.assets = assets
        self.cryptated = cryptated
        self.session = session
        self.delegate = delegate
        
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.exact
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.highQualityFormat
        requestOptions.isSynchronous = true
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.title = NSLocalizedString("_upload_photos_videos_", comment: "")
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancel))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(save))
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        
        if assets.count == 1 && assets[0].mediaType == PHAssetMediaType.image {
            PHImageManager.default().requestImage(for: assets[0], targetSize: targetSizeImagePreview, contentMode: PHImageContentMode.aspectFill, options: requestOptions, resultHandler: { (image, info) in
                self.imagePreview = image
            })
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)

        changeTheming()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        self.delegate?.dismissFormUploadAssets()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: tableView, collectionView: nil, form: true)
        initializeForm()
        self.reloadForm()
    }
    
    //MARK: XLForm
    
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
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm

        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView
        
        section.addFormRow(row)
        
        // User folder Autoupload
        row = XLFormRowDescriptor(tag: "useFolderAutoUpload", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_use_folder_auto_upload_", comment: ""))
        row.value = 0
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm

        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView
        
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
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView
        
        section.addFormRow(row)

        // Section Mode filename
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_mode_filename_", comment: ""))
        form.addFormSection(section)
        
        // Maintain the original fileName
        
        row = XLFormRowDescriptor(tag: "maintainOriginalFileName", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_maintain_original_filename_", comment: ""))
        row.value = CCUtility.getOriginalFileName(k_keyFileNameOriginal)
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm

        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView
        
        section.addFormRow(row)
        
        // Add File Name Type
        
        row = XLFormRowDescriptor(tag: "addFileNameType", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_add_filenametype_", comment: ""))
        row.value = CCUtility.getFileNameType(k_keyFileNameType)
        row.hidden = "$\("maintainOriginalFileName") == 1"
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm

        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView
        
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
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm

        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textColor"] = NCBrandColor.sharedInstance.textView

        section.addFormRow(row)
        
        // Section: Preview File Name
        
        row = XLFormRowDescriptor(tag: "previewFileName", rowType: XLFormRowDescriptorTypeTextView, title: "")
        row.height = 180
        row.disabled = true
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm

        row.cellConfig["textView.backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm
        row.cellConfig["textView.font"] = UIFont.systemFont(ofSize: 14.0)
        row.cellConfig["textView.textColor"] = NCBrandColor.sharedInstance.textView

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
                    
                    NCContentPresenter.shared.messageNotification("_info_", description: "_forbidden_characters_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorCharactersForbidden), forced: true)
                }
            }
            
            self.reloadFormRow(previewFileName)
        }
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
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, array: [Any], buttonType: String, overwrite: Bool) {
        
        if serverUrl != nil {
            
            self.serverUrl = serverUrl!
            
            if serverUrl == NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) {
                self.titleServerUrl = "/"
            } else {
                if let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account
                    , self.serverUrl)) {
                    if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(tableDirectory.ocId) {
                        titleServerUrl = metadata.fileNameView
                    } else { titleServerUrl = (self.serverUrl as NSString).lastPathComponent }
                } else { titleServerUrl = (self.serverUrl as NSString).lastPathComponent }                
            }
            
            // Update
            let row : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
            row.title = self.titleServerUrl
            self.updateFormRow(row)
        }
    }
    
    /*
    @objc func save() {
        
        self.dismiss(animated: true, completion: {
            
            let useFolderPhotoRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useFolderAutoUpload")!
            let useSubFolderRow : XLFormRowDescriptor  = self.form.formRow(withTag: "useSubFolder")!
            var useSubFolder : Bool = false
            
            if (useFolderPhotoRow.value! as AnyObject).boolValue == true {
                
                self.serverUrl = NCManageDatabase.sharedInstance.getAccountAutoUploadPath(urlBase: self.appDelegate.urlBase, account: self.appDelegate.account)
                useSubFolder = (useSubFolderRow.value! as AnyObject).boolValue
            }
            
            self.appDelegate.activeMain.uploadFileAsset(self.assets, serverUrl: self.serverUrl, useSubFolder: useSubFolder, session: self.session)
        })
    }
    */
    
    @objc func save() {
         
        DispatchQueue.global().async {
        
            let useFolderPhotoRow: XLFormRowDescriptor  = self.form.formRow(withTag: "useFolderAutoUpload")!
            let useSubFolderRow: XLFormRowDescriptor  = self.form.formRow(withTag: "useSubFolder")!
            var useSubFolder: Bool = false
            var metadatasMOV: [tableMetadata] = []
            var metadatasNOConflict: [tableMetadata] = []
            var metadatasUploadInConflict: [tableMetadata] = []

            if (useFolderPhotoRow.value! as AnyObject).boolValue == true {
                self.serverUrl = NCManageDatabase.sharedInstance.getAccountAutoUploadPath(urlBase: self.appDelegate.urlBase, account: self.appDelegate.account)
                useSubFolder = (useSubFolderRow.value! as AnyObject).boolValue
            }
            
            let autoUploadPath = NCManageDatabase.sharedInstance.getAccountAutoUploadPath(urlBase: self.appDelegate.urlBase, account: self.appDelegate.account)
            if autoUploadPath == self.serverUrl {
                if NCNetworking.shared.createFolder(assets: self.assets, selector: selectorUploadFile, useSubFolder: useSubFolder, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase) {
                    NCContentPresenter.shared.messageNotification("_error_", description: "_error_createsubfolders_upload_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError), forced: true)
                    return
                }
            }

            for asset in self.assets {
                    
                var serverUrl = self.serverUrl
                var livePhoto: Bool = false
                let fileName = CCUtility.createFileName(asset.value(forKey: "filename") as? String, fileDate: asset.creationDate, fileType: asset.mediaType, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)!
                let assetDate = asset.creationDate ?? Date()
                let dateFormatter = DateFormatter()
                
                // Detect LivePhoto Upload
                if (asset.mediaSubtypes == PHAssetMediaSubtype.photoLive || asset.mediaSubtypes.rawValue == PHAssetMediaSubtype.photoLive.rawValue + PHAssetMediaSubtype.photoHDR.rawValue) && CCUtility.getLivePhoto() {
                    livePhoto = true
                } 
                
                // Create serverUrl if use sub folder
                if useSubFolder {
                    
                    dateFormatter.dateFormat = "yyyy"
                    let yearString = dateFormatter.string(from: assetDate)
                   
                    dateFormatter.dateFormat = "MM"
                    let monthString = dateFormatter.string(from: assetDate)
                    
                    serverUrl = autoUploadPath + "/" + yearString + "/" + monthString
                }
                
                // Check if is in upload
                let isRecordInSessions = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@ AND session != ''", self.appDelegate.account, serverUrl, fileName), sorted: "fileName", ascending: false)
                if isRecordInSessions.count > 0 {
                    continue
                }
                
                let metadataForUpload = NCManageDatabase.sharedInstance.createMetadata(account: self.appDelegate.account, fileName: fileName, ocId: NSUUID().uuidString, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: "", contentType: "", livePhoto: livePhoto)
                
                metadataForUpload.assetLocalIdentifier = asset.localIdentifier
                metadataForUpload.session = self.session
                metadataForUpload.sessionSelector = selectorUploadFile
                metadataForUpload.size = Double(NCUtilityFileSystem.shared.getFileSize(asset: asset))
                metadataForUpload.status = Int(k_metadataStatusWaitUpload)
                
                if livePhoto {
                    
                    let fileNameMove = (fileName as NSString).deletingPathExtension + ".mov"
                    let ocId = NSUUID().uuidString
                    let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameMove)!
                    
                    let semaphore = Semaphore()
                    CCUtility.extractLivePhotoAsset(asset, filePath: filePath) { (url) in
                        if let url = url {
                            let fileSize = NCUtilityFileSystem.shared.getFileSize(filePath: url.path)
                            let metadataMOVForUpload = NCManageDatabase.sharedInstance.createMetadata(account: self.appDelegate.account, fileName: fileNameMove, ocId:ocId, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: "", contentType: "", livePhoto: livePhoto)

                            metadataForUpload.livePhoto = true
                            metadataMOVForUpload.livePhoto = true
                            
                            metadataMOVForUpload.session = self.session
                            metadataMOVForUpload.sessionSelector = selectorUploadFile
                            metadataMOVForUpload.size = fileSize
                            metadataMOVForUpload.status = Int(k_metadataStatusWaitUpload)
                            metadataMOVForUpload.typeFile = k_metadataTypeFile_video

                            metadatasMOV.append(metadataMOVForUpload)
                        }
                        semaphore.continue()
                    }
                    semaphore.wait()
                }
                
                if NCUtility.shared.getMetadataConflict(account: self.appDelegate.account, serverUrl: serverUrl, fileName: fileName) != nil {
                    metadatasUploadInConflict.append(metadataForUpload)
                } else {
                    metadatasNOConflict.append(metadataForUpload)
                }
            }
            
            // Verify if file(s) exists
            if metadatasUploadInConflict.count > 0 {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if let conflict = UIStoryboard.init(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict {
                        
                        conflict.serverUrl = self.serverUrl
                        conflict.metadatasNOConflict = metadatasNOConflict
                        conflict.metadatasMOV = metadatasMOV
                        conflict.metadatasUploadInConflict = metadatasUploadInConflict
                    
                        self.appDelegate.window.rootViewController?.present(conflict, animated: true, completion: nil)
                    }
                }
                
            } else {
                
                NCManageDatabase.sharedInstance.addMetadatas(metadatasNOConflict)
                NCManageDatabase.sharedInstance.addMetadatas(metadatasMOV)
                
                self.appDelegate.networkingAutoUpload.startProcess()
            }
        
            DispatchQueue.main.async {self.dismiss(animated: true, completion: nil)  }
        }
    }
    
    @objc func cancel() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Utility
    
    func previewFileName(valueRename : String?) -> String {
        
        var returnString: String = ""
        let asset = assets[0]
        
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
        
        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        let viewController = navigationController.topViewController as! NCSelect
        
        viewController.delegate = self
        viewController.hideButtonCreateFolder = false
        viewController.includeDirectoryE2EEncryption = true
        viewController.includeImages = false
        viewController.keyLayout = k_layout_view_move
        viewController.selectFile = false
        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
        viewController.type = ""
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        self.present(navigationController, animated: true, completion: nil)
    }
}
