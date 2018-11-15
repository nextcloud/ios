//
//  CCCreateCloud.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/11/18.
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

// MARK: -

class NCCreateFormUploadRichdocuments: XLFormViewController, NCSelectDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    
    var typeTemplate = ""
    var serverUrl = ""
    var fileNameFolder = ""
    var fileName = ""
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var collectioView: UICollectionView!

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl) {
            fileNameFolder = "/"
        } else {
            fileNameFolder = (serverUrl as NSString).lastPathComponent
        }
        
        self.initializeForm()
        
        collectioView.delegate = self
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        
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
    }
    
    // MARK: - Tableview (XLForm)

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
        row.value = fileNameFolder
        
        let imageFolder = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, multiplier:1, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        row.cellConfig["imageView.image"] = imageFolder
        
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_filename_", comment: ""))
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.value = fileName
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        
        section.addFormRow(row)
        
        self.form = form
    }
    
    // MARK: - CollectionView
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell()
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
        
        let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
        buttonDestinationFolder.title = fileNameFolder
        
        self.tableView.reloadData()
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
