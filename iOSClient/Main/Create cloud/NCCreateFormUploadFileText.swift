//
//  NCCreateFormUploadFileText.swift
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

class NCCreateFormUploadFileText: XLFormViewController, NCSelectDelegate {
    
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
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String) {
        
        if serverUrl != nil {
            
            self.serverUrl = serverUrl!
            
            if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
                self.titleServerUrl = "/"
            } else {
                self.titleServerUrl = (serverUrl! as NSString).lastPathComponent
            }
            
            // Update
            let row : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
            row.title = self.titleServerUrl
            self.updateFormRow(row)
        }
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
        
        guard let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(self.serverUrl, account: appDelegate.activeAccount) else {
            return
        }
        let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "directoryID == %@ AND fileNameView == %@", directoryID, fileNameSave))
        
        if (metadata != nil) {
            
            let alertController = UIAlertController(title: fileNameSave, message: NSLocalizedString("_file_already_exists_", comment: ""), preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { (action:UIAlertAction) in
            }
            
            let overwriteAction = UIAlertAction(title: NSLocalizedString("_overwrite_", comment: ""), style: .cancel) { (action:UIAlertAction) in
                self.dismissAndUpload(fileNameSave, fileID: metadata!.fileID, directoryID: directoryID, serverUrl: self.serverUrl)
            }
            
            alertController.addAction(cancelAction)
            alertController.addAction(overwriteAction)
            
            self.present(alertController, animated: true, completion:nil)
            
        } else {
            let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(self.serverUrl, account: appDelegate.activeAccount)!
            dismissAndUpload(fileNameSave, fileID: directoryID + fileNameSave, directoryID: directoryID, serverUrl: serverUrl)
        }
    }
    
    func dismissAndUpload(_ fileNameSave: String, fileID: String, directoryID: String, serverUrl: String) {
        
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
                metadataForUpload.serverUrl = serverUrl
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
        
        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        let viewController = navigationController.topViewController as! NCSelect
        
        viewController.delegate = self
        viewController.hideButtonCreateFolder = false
        viewController.includeDirectoryE2EEncryption = true
        viewController.includeImages = false
        viewController.layoutViewSelect = k_layout_view_move
        viewController.selectFile = false
        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
        viewController.type = ""
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.present(navigationController, animated: true, completion: nil)
    }
}
