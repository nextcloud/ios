//
//  NCShareExtension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/04/2021.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

import UIKit
import NCCommunication

class NCShareExtension: UIViewController, NCListCellDelegate, NCEmptyDataSetDelegate, NCRenameFileDelegate, NCAccountRequestDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var commandView: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var commandViewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var createFolderView: UIView!
    @IBOutlet weak var createFolderImage: UIImageView!
    @IBOutlet weak var createFolderLabel: UILabel!

    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var uploadImage: UIImageView!
    @IBOutlet weak var uploadLabel: UILabel!
    
    // -------------------------------------------------------------
    var serverUrl = ""
    var filesName: [String] = []
    // -------------------------------------------------------------
        
    private var emptyDataSet: NCEmptyDataSet?
    private let keyLayout = NCGlobal.shared.layoutViewShareExtension
    private var metadataFolder: tableMetadata?
    private var networkInProgress = false
    private var dataSource = NCDataSource()

    private var layoutForView: NCGlobal.layoutForViewType?
  
    private var heightRowTableView: CGFloat = 50
    private var heightCommandView: CGFloat = 170
    
    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    
    private let refreshControl = UIRefreshControl()
    private var activeAccount: tableAccount!
    private let chunckSize = CCUtility.getChunkSize() * 1000000
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.prefersLargeTitles = false
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.collectionViewLayout = NCListLayout()

        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.shared.brandText
        refreshControl.backgroundColor = NCBrandColor.shared.systemBackground
        refreshControl.addTarget(self, action: #selector(reloadDatasource), for: .valueChanged)
        
        // Command view
        commandView.backgroundColor = NCBrandColor.shared.secondarySystemBackground
        separatorView.backgroundColor = NCBrandColor.shared.separator
        separatorHeightConstraint.constant = 0.5
        
        // Table view
        tableView.separatorColor = NCBrandColor.shared.separator
        tableView.layer.cornerRadius = 10
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 0, height: 1)))
        commandViewHeightConstraint.constant = heightCommandView
        
        // Create folder
        createFolderView.layer.cornerRadius = 10
        createFolderImage.image = NCUtility.shared.loadImage(named: "folder.badge.plus", color: NCBrandColor.shared.label)
        createFolderLabel.text = NSLocalizedString("_create_folder_", comment: "")
        let createFolderGesture = UITapGestureRecognizer(target: self, action:  #selector(actionCreateFolder))
        createFolderView.addGestureRecognizer(createFolderGesture)
        
        // Upload
        uploadView.layer.cornerRadius = 10
        //uploadImage.image = NCUtility.shared.loadImage(named: "square.and.arrow.up", color: NCBrandColor.shared.label)
        uploadLabel.text = NSLocalizedString("_upload_", comment: "")
        uploadLabel.textColor = .systemBlue
        let uploadGesture = UITapGestureRecognizer(target: self, action:  #selector(actionUpload))
        uploadView.addGestureRecognizer(uploadGesture)
                
        // LOG
        let levelLog = CCUtility.getLogLevel()
        let isSimulatorOrTestFlight = NCUtility.shared.isSimulatorOrTestFlight()
        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility.shared.getVersionApp())
        
        NCCommunicationCommon.shared.levelLog = levelLog
        if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
            NCCommunicationCommon.shared.pathLog = pathDirectoryGroup
        }
        if isSimulatorOrTestFlight {
            NCCommunicationCommon.shared.writeLog("Start session with level \(levelLog) " + versionNextcloudiOS + " (Simulator / TestFlight)")
        } else {
            NCCommunicationCommon.shared.writeLog("Start session with level \(levelLog) " + versionNextcloudiOS)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if serverUrl == "" {
        
            if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
                
                setAccount(account: activeAccount.account)
                getFilesExtensionContext { (filesName) in
                    
                    self.filesName = filesName
                    DispatchQueue.main.async {
                        
                        var saveHtml: [String] = []
                        var saveOther: [String] = []
                        
                        for fileName in self.filesName {
                            if (fileName as NSString).pathExtension.lowercased() == "html" {
                                saveHtml.append(fileName)
                            } else {
                                saveOther.append(fileName)
                            }
                        }
                        
                        if saveOther.count > 0 && saveHtml.count > 0 {
                            for file in saveHtml {
                                self.filesName = self.filesName.filter(){$0 != file}
                            }
                        }
                        
                        self.setCommandView()
                    }
                }
                
            } else {
                
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_no_active_account_", comment: ""), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                    self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
                }))
                self.present(alertController, animated: true)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        collectionView.reloadData()
        tableView.reloadData()
    }
    
    // MARK: -

    func setAccount(account: String) {
        
        guard let activeAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else {
            extensionContext?.completeRequest(returningItems: extensionContext?.inputItems, completionHandler: nil)
            return
        }
        self.activeAccount = activeAccount
        
        // NETWORKING
        NCCommunicationCommon.shared.setup(account: activeAccount.account, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account), urlBase: activeAccount.urlBase, userAgent: CCUtility.getUserAgent(), webDav: NCUtilityFileSystem.shared.getWebDAV(account: activeAccount.account), dav: NCUtilityFileSystem.shared.getDAV(), nextcloudVersion: 0, delegate: NCNetworking.shared)
                
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, account: activeAccount.account)
        
        serverUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, account: activeAccount.account)
        
        layoutForView = NCUtility.shared.getLayoutForView(key: keyLayout,serverUrl: serverUrl)
            
        reloadDatasource(withLoadFolder: true)
        setNavigationBar(navigationTitle: NCBrandOptions.shared.brand)
    }
    
    func setNavigationBar(navigationTitle: String) {
        
        navigationItem.title = navigationTitle
        cancelButton.title = NSLocalizedString("_cancel_", comment: "")

        // BACK BUTTON

        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "back"), for: .normal)
        backButton.tintColor = .systemBlue
        backButton.semanticContentAttribute = .forceLeftToRight
        backButton.setTitle(" "+NSLocalizedString("_back_", comment: ""), for: .normal)
        backButton.setTitleColor(.systemBlue, for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped(sender:)), for: .touchUpInside)
        
        // PROFILE BUTTON
                
        var image = NCUtility.shared.loadImage(named: "person.crop.circle")
        let fileNamePath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(activeAccount.user, urlBase: activeAccount.urlBase)) + "-" + activeAccount.user + ".png"
        if let userImage = UIImage(contentsOfFile: fileNamePath) {
            image = userImage
        }
            
        image = NCUtility.shared.createAvatar(image: image, size: 30)
            
        let profileButton = UIButton(type: .custom)
        profileButton.setImage(image, for: .normal)
            
        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, account: activeAccount.account) {
             

            var title = "  "
            if activeAccount?.alias == "" {
                title = title + (activeAccount?.user ?? "")
            } else {
                title = title + (activeAccount?.alias ?? "")
            }
                
            profileButton.setTitle(title, for: .normal)
            profileButton.setTitleColor(.systemBlue, for: .normal)
        }
            
        profileButton.semanticContentAttribute = .forceLeftToRight
        profileButton.sizeToFit()
        profileButton.addTarget(self, action: #selector(profileButtonTapped(sender:)), for: .touchUpInside)
                   
        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, account: activeAccount.account) {

            navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: profileButton)], animated: true)
            
        } else {

            let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            space.width = 20
            
            navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: backButton), space, UIBarButtonItem(customView: profileButton)], animated: true)
        }
    }
    
    func setCommandView() {
                
        var counter: CGFloat = 0
        
        if filesName.count == 0 {
            self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
            return
        } else {
            if filesName.count < 3 {
                counter = CGFloat(filesName.count)
                self.commandViewHeightConstraint.constant = heightCommandView + (self.heightRowTableView * counter)
            } else  {
                counter = 3
                self.commandViewHeightConstraint.constant = heightCommandView + (self.heightRowTableView * counter)
            }
            if filesName.count <= 3 {
                self.tableView.isScrollEnabled = false
            }
            // Label upload button
            uploadLabel.text = NSLocalizedString("_upload_", comment: "") + " \(filesName.count) " + NSLocalizedString("_files_", comment: "")
            // Empty
            emptyDataSet = NCEmptyDataSet.init(view: collectionView, offset: -50*counter, delegate: self)
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Empty
    
    func emptyDataSetView(_ view: NCEmptyView) {
                
        if networkInProgress {
            view.emptyImage.image = UIImage.init(named: "networkInProgress")?.image(color: .gray, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
            view.emptyDescription.text = ""
        } else {
            view.emptyImage.image = UIImage.init(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_files_no_folders_", comment: "")
            view.emptyDescription.text = ""
        }
    }
    
    // MARK: ACTION
    
    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        extensionContext?.completeRequest(returningItems: extensionContext?.inputItems, completionHandler: nil)
    }
    
    @objc func actionCreateFolder() {
        
        let alertController = UIAlertController(title: NSLocalizedString("_create_folder_", comment: ""), message:"", preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.autocapitalizationType = UITextAutocapitalizationType.words
        }
        
        let actionSave = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default) { (action:UIAlertAction) in
            if let fileName = alertController.textFields?.first?.text  {
                self.createFolder(with: fileName)
            }
        }
        
        let actionCancel = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (action:UIAlertAction) in
            print("You've pressed cancel button")
        }
        
        alertController.addAction(actionSave)
        alertController.addAction(actionCancel)
        
        self.present(alertController, animated: true, completion:nil)
    }
    
    @objc func actionUpload() {
        
        if let fileName = filesName.first {
            
            filesName.removeFirst()
            let ocId = NSUUID().uuidString
            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
                
            if NCUtilityFileSystem.shared.moveFile(atPath: (NSTemporaryDirectory() + fileName), toPath: filePath) {
                
                NCUtility.shared.startActivityIndicator(backgroundView: self.view, blurEffect: true)
                                
                let metadata = NCManageDatabase.shared.createMetadata(account: activeAccount.account, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: activeAccount.urlBase, url: "", contentType: "", livePhoto: false)
                
                metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
                metadata.sessionSelector = NCGlobal.shared.selectorUploadFile
                metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
                metadata.status = NCGlobal.shared.metadataStatusWaitUpload
            
                // E2EE
                if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase) {
                    metadata.e2eEncrypted = true
                }
                
                // CHUNCK
                if chunckSize != 0 && metadata.size > chunckSize {
                    metadata.chunk = true
                }
                
                NCNetworking.shared.upload(metadata: metadata) {
                    
                } completion: { (errorCode, errorDescription) in
                    
                    NCUtility.shared.stopActivityIndicator()
                    
                    if errorCode == 0 {
                        self.actionUpload()
                    } else {
                        
                        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocId))
                        NCManageDatabase.shared.deleteChunks(account: self.activeAccount.account, ocId: ocId)
                        
                        let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: errorDescription, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                            self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
                            return
                        }))
                        self.present(alertController, animated: true)
                    }
                }
            }
        } else {
            extensionContext?.completeRequest(returningItems: extensionContext?.inputItems, completionHandler: nil)
            return
        }
    }
    
    @objc func backButtonTapped(sender: Any) {
                
        while serverUrl.last != "/" {
            serverUrl.removeLast()
        }
        serverUrl.removeLast()

        reloadDatasource(withLoadFolder: true)
        
        var navigationTitle = (serverUrl as NSString).lastPathComponent
        if NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, account: activeAccount.account) == serverUrl {
            navigationTitle = NCBrandOptions.shared.brand
        }
        setNavigationBar(navigationTitle: navigationTitle)
    }
    
    func rename(fileName: String, fileNameNew: String) {
        
        if let row = self.filesName.firstIndex(where: {$0 == fileName}) {
            
            if NCUtilityFileSystem.shared.moveFile(atPath: (NSTemporaryDirectory() + fileName), toPath: (NSTemporaryDirectory() + fileNameNew)) {
                filesName[row] = fileNameNew
                tableView.reloadData()
            }
        }
    }
    
    @objc func moreButtonPressed(sender: NCShareExtensionButtonWithIndexPath) {
        
        if let fileName = sender.fileName {
            let alertController = UIAlertController(title: "", message: fileName, preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_file_", comment: ""), style: .default) { (action:UIAlertAction) in
                if let index = self.filesName.firstIndex(of: fileName) {
                    
                    self.filesName.remove(at: index)
                    if self.filesName.count == 0 {
                        self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
                    } else {
                        self.setCommandView()
                    }
                }
            })
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_rename_file_", comment: ""), style: .default) { (action:UIAlertAction) in
                
                if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {
                
                    vcRename.delegate = self
                    vcRename.fileName = fileName
                    vcRename.imagePreview = sender.image

                    let popup = NCPopupViewController(contentController: vcRename, popupWidth: vcRename.width, popupHeight: vcRename.height)
                                            
                    self.present(popup, animated: true)
                }
            })
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (action:UIAlertAction) in })
            
            self.present(alertController, animated: true, completion:nil)
        }
    }
    
    func accountRequestChangeAccount(account: String) {
        setAccount(account: account)
    }
    
    @objc func profileButtonTapped(sender: Any) {
        
        let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
        if accounts.count > 1 {
            
            if let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {
               
                // Only here change the active account 
                for account in accounts {
                    if account.account == self.activeAccount.account {
                        account.active = true
                    } else {
                        account.active = false
                    }
                }
                
                vcAccountRequest.activeAccount = self.activeAccount
                vcAccountRequest.accounts = accounts.sorted { (sorg, dest) -> Bool in
                    return sorg.active && !dest.active
                }
                vcAccountRequest.enableTimerProgress = false
                vcAccountRequest.enableAddAccount = false
                vcAccountRequest.delegate = self
                vcAccountRequest.dismissDidEnterBackground = true

                let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height/5)
                let numberCell = accounts.count
                let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)
                
                let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height+20)
                
                self.present(popup, animated: true)
            }
        }
    }
}

// MARK: - Collection View

extension NCShareExtension: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if let metadata = dataSource.cellForItemAt(indexPath: indexPath) {
            if let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)  {
                
                if metadata.e2eEncrypted && !CCUtility.isEnd(toEndEnabled: activeAccount.account) {
                    let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: NSLocalizedString("_e2e_goto_settings_for_enable_", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                    self.present(alertController, animated: true)
                    return
                }
                
                self.serverUrl = serverUrl
                reloadDatasource(withLoadFolder: true)
                setNavigationBar(navigationTitle: metadata.fileNameView)
            }
        }
    }
}

extension NCShareExtension: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItems = dataSource.numberOfItems()
        emptyDataSet?.numberOfItemsInSection(numberOfItems, section:section)
        return numberOfItems
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        var tableShare: tableShare?
        var isShare = false
        var isMounted = false
        
        // Download preview
        NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: activeAccount.urlBase, view: collectionView, indexPath: indexPath)
        
        if let metadataFolder = metadataFolder {
            isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionShared)
            isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionMounted)
        }
        
        if dataSource.metadataShare[metadata.ocId] != nil {
            tableShare = dataSource.metadataShare[metadata.ocId]
        }
            
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        cell.delegate = self
        
        cell.objectId = metadata.ocId
        cell.indexPath = indexPath
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = NCBrandColor.shared.label
        
        cell.imageSelect.image = nil
        cell.imageStatus.image = nil
        cell.imageLocal.image = nil
        cell.imageFavorite.image = nil
        cell.imageShared.image = nil
        cell.imageMore.image = nil
        
        cell.imageItem.image = nil
        cell.imageItem.backgroundColor = nil
        
        cell.progressView.progress = 0.0
        
        if metadata.directory {
            
            if metadata.e2eEncrypted {
                cell.imageItem.image = NCBrandColor.cacheImages.folderEncrypted
            } else if isShare {
                cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if (tableShare != nil && tableShare?.shareType != 3) {
                cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if (tableShare != nil && tableShare?.shareType == 3) {
                cell.imageItem.image = NCBrandColor.cacheImages.folderPublic
            } else if metadata.mountType == "group" {
                cell.imageItem.image = NCBrandColor.cacheImages.folderGroup
            } else if isMounted {
                cell.imageItem.image = NCBrandColor.cacheImages.folderExternal
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.imageItem.image = NCBrandColor.cacheImages.folderAutomaticUpload
            } else {
                cell.imageItem.image = NCBrandColor.cacheImages.folder
            }
            
            cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date)
            
            let lockServerUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
            let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account, lockServerUrl))
            
            // Local image: offline
            if tableDirectory != nil && tableDirectory!.offline {
                cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
            }
            
        }
        
        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = NCBrandColor.cacheImages.favorite
        }
        
        // Share image
        if (isShare) {
            cell.imageShared.image = NCBrandColor.cacheImages.shared
        } else if (tableShare != nil && tableShare?.shareType == 3) {
            cell.imageShared.image = NCBrandColor.cacheImages.shareByLink
        } else if (tableShare != nil && tableShare?.shareType != 3) {
            cell.imageShared.image = NCBrandColor.cacheImages.shared
        } else {
            cell.imageShared.image = NCBrandColor.cacheImages.canShare
        }
        if metadata.ownerId.count > 0 && metadata.ownerId != activeAccount.userId {
            let fileNameUser = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(activeAccount.user, urlBase: activeAccount.urlBase)) + "-" + metadata.ownerId + ".png"
            if FileManager.default.fileExists(atPath: fileNameUser) {
                cell.imageShared.image = UIImage(contentsOfFile: fileNameUser)
            } else {
                NCCommunication.shared.downloadAvatar(userId: metadata.ownerId, fileNameLocalPath: fileNameUser, size: NCGlobal.shared.avatarSize) { (account, data, errorCode, errorMessage) in
                    if errorCode == 0 && account == self.activeAccount.account {
                        cell.imageShared.image = UIImage(contentsOfFile: fileNameUser)
                    }
                }
            }
        }
        
        cell.imageSelect.isHidden = true
        cell.backgroundView = nil
        cell.hideButtonMore(true)
        cell.hideButtonShare(true)
        cell.selectMode(false)

        // Live Photo
        if metadata.livePhoto {
            cell.imageStatus.image = NCBrandColor.cacheImages.livePhoto
        }
        
        // Remove last separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
            cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }
        
        return cell
    }
}

// MARK: - Table View

extension NCShareExtension: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return heightRowTableView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
}

extension NCShareExtension: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filesName.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
               
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = NCBrandColor.shared.systemBackground
        
        let imageCell = cell.viewWithTag(10) as? UIImageView
        let fileNameCell = cell.viewWithTag(20) as? UILabel
        let moreButton = cell.viewWithTag(30) as? NCShareExtensionButtonWithIndexPath
        let sizeCell = cell.viewWithTag(40) as? UILabel
        
        imageCell?.layer.cornerRadius = 6
        imageCell?.layer.masksToBounds = true

        let fileName = filesName[indexPath.row]
        let resultInternalType = NCCommunicationCommon.shared.getInternalType(fileName: fileName, mimeType: "", directory: false)
       
        if let image = UIImage(contentsOfFile: (NSTemporaryDirectory() + fileName)) {
            imageCell?.image = image.resizeImage(size: CGSize(width: 80, height: 80), isAspectRation: true)
        } else {
            if resultInternalType.iconName.count > 0 {
                imageCell?.image = UIImage.init(named: resultInternalType.iconName)
            } else {
                imageCell?.image = NCBrandColor.cacheImages.file
            }
        }
        
        fileNameCell?.text = fileName
        
        let fileSize = NCUtilityFileSystem.shared.getFileSize(filePath: (NSTemporaryDirectory() + fileName))
        sizeCell?.text = CCUtility.transformedSize(fileSize)
        
        moreButton?.setImage(NCUtility.shared.loadImage(named: "more").image(color: NCBrandColor.shared.label, size: 15), for: .normal)
        moreButton?.indexPath = indexPath
        moreButton?.fileName = fileName
        moreButton?.image = imageCell?.image
        moreButton?.addTarget(self, action:#selector(moreButtonPressed(sender:)), for: .touchUpInside)

        return cell
    }
}

// MARK: - NC API & Algorithm

extension NCShareExtension {

    @objc func reloadDatasource(withLoadFolder: Bool) {
                
        layoutForView = NCUtility.shared.getLayoutForView(key: keyLayout, serverUrl: serverUrl)
                
        let metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", activeAccount.account, serverUrl))
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: layoutForView?.sort, ascending: layoutForView?.ascending, directoryOnTop: layoutForView?.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)
        
        if withLoadFolder {
            loadFolder()
        } else {
            self.refreshControl.endRefreshing()
        }
        
        collectionView.reloadData()
    }
    
    func createFolder(with fileName: String) {
        
        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: activeAccount.account, urlBase: activeAccount.urlBase) { (errorCode, errorDescription) in
            
            if errorCode == 0 {
                self.reloadDatasource(withLoadFolder: true)
            }  else {
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: errorDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                self.present(alertController, animated: true)
            }
        }
    }
    
    func loadFolder() {
        
        networkInProgress = true
        collectionView.reloadData()
        
        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: activeAccount.account) { (_, metadataFolder, _, _, _, _, errorCode, errorDescription) in
            if errorCode != 0 {
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: errorDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                self.present(alertController, animated: true)
            }
            self.networkInProgress = false
            self.metadataFolder = metadataFolder
            self.reloadDatasource(withLoadFolder: false)
        }
    }
    
    func getFilesExtensionContext(completion: @escaping (_ filesName: [String])->())  {
        
        var itemsProvider: [NSItemProvider] = []
        
        var filesName: [String] = []
        
        var conuter = 0
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss-"
        
        // ----------------------------------------------------------------------------------------

        // Image
        func getItem(image: UIImage, fileNameOriginal: String?) {
            
            var fileName: String = ""
            
            if let pngImageData = image.pngData() {
            
                if fileNameOriginal != nil {
                    fileName =  fileNameOriginal!
                } else {
                    fileName = "\(dateFormatter.string(from: Date()))\(conuter).png"
                }
                
                let filenamePath = NSTemporaryDirectory() + fileName
                
                if (try? pngImageData.write(to: URL(fileURLWithPath: filenamePath), options: [.atomic])) != nil {
                    filesName.append(fileName)
                }
            }
        }
        
        // URL
        func getItem(url: NSURL, fileNameOriginal: String?) {
            
            guard let path = url.path else { return }
            
            var fileName: String = ""

            if fileNameOriginal != nil {
                fileName =  fileNameOriginal!
            } else {
                if let ext = url.pathExtension {
                    fileName = "\(dateFormatter.string(from: Date()))\(conuter)." + ext
                }
            }
            
            let filenamePath = NSTemporaryDirectory() + fileName
          
            do {
                try FileManager.default.removeItem(atPath: filenamePath)
            }
            catch { }
            
            do {
                try FileManager.default.copyItem(atPath: path, toPath:filenamePath)
                
                do {
                    let attr : NSDictionary? = try FileManager.default.attributesOfItem(atPath: filenamePath) as NSDictionary?
                    
                    if let _attr = attr {
                        if _attr.fileSize() > 0 {
                            filesName.append(fileName)
                        }
                    }
                    
                } catch { }
            } catch { }
        }
        
        // Data
        func getItem(data: Data, fileNameOriginal: String?, description: String) {
        
            var fileName: String = ""

            if data.count > 0 {
                        
                if fileNameOriginal != nil {
                    fileName =  fileNameOriginal!
                } else {
                    let fullNameArr = description.components(separatedBy: "\"")
                    let fileExtArr = fullNameArr[1].components(separatedBy: ".")
                    let pathExtention = (fileExtArr[fileExtArr.count-1]).uppercased()
                    fileName = "\(dateFormatter.string(from: Date()))\(conuter).\(pathExtention)"
                }
                
                let filenamePath = NSTemporaryDirectory() + fileName
                FileManager.default.createFile(atPath: filenamePath, contents:data, attributes:nil)
                filesName.append(fileName)
            }
        }
        
        // String
        func getItem(string: NSString, fileNameOriginal: String?) {
                        
            var fileName: String = ""
            
            if string.length > 0 {
                        
                fileName = "\(dateFormatter.string(from: Date()))\(conuter).txt"
                let filenamePath = NSTemporaryDirectory() + "\(dateFormatter.string(from: Date()))\(conuter).txt"
                FileManager.default.createFile(atPath: filenamePath, contents:string.data(using: String.Encoding.utf8.rawValue), attributes:nil)
                filesName.append(fileName)
            }
        }
        
        // ----------------------------------------------------------------------------------------
        
        CCUtility.emptyTemporaryDirectory()
        
        guard let inputItems : [NSExtensionItem] = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(filesName)
            return
        }
        
        for item : NSExtensionItem in inputItems {
            if let attachments = item.attachments {
                if attachments.isEmpty { continue }
                for (_, itemProvider) in (attachments.enumerated()) {
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeItem as String) || itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                    
                        itemsProvider.append(itemProvider)
                    }
                }
            }
        }
        
        for itemProvider in itemsProvider {
                        
            var typeIdentifier = ""
            if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeItem as String) { typeIdentifier = kUTTypeItem as String }
            if itemProvider.hasItemConformingToTypeIdentifier("public.url") { typeIdentifier = "public.url" }

            itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil, completionHandler: {(item, error) -> Void in
                
                conuter += 1
                var fileNameOriginal: String?
                                                
                if let url = item as? NSURL {
                    if FileManager.default.fileExists(atPath: url.path ?? "") {
                        fileNameOriginal = url.lastPathComponent!
                    } else if url.scheme?.lowercased().contains("http") == true {
                        fileNameOriginal = "\(dateFormatter.string(from: Date()))\(conuter).html"
                    } else {
                        fileNameOriginal = "\(dateFormatter.string(from: Date()))\(conuter)"
                    }
                }
                
                if error == nil {
                                                        
                    if let image = item as? UIImage {
                       getItem(image: image, fileNameOriginal: fileNameOriginal)
                    }
                    
                    if let url = item as? URL {
                        getItem(url: url as NSURL, fileNameOriginal: fileNameOriginal)
                    }
                    
                    if let data = item as? Data {
                        getItem(data: data, fileNameOriginal: fileNameOriginal, description: itemProvider.description)
                    }
                    
                    if let string = item as? NSString {
                        getItem(string: string, fileNameOriginal: fileNameOriginal)
                    }
                }
                
                if conuter == itemsProvider.count {
                    completion(filesName)
                }
            })
        }
    }
}

/*
let task = URLSession.shared.downloadTask(with: urlitem) { localURL, urlResponse, error in
    
    if let localURL = localURL {
        
        if fileNameOriginal != nil {
            fileName =  fileNameOriginal!
        } else {
            let ext = url.pathExtension
            fileName = "\(dateFormatter.string(from: Date()))\(conuter)." + ext
        }
        
        let filenamePath = NSTemporaryDirectory() + fileName
      
        do {
            try FileManager.default.removeItem(atPath: filenamePath)
        }
        catch { }
        
        do {
            try FileManager.default.copyItem(atPath: localURL.path, toPath:filenamePath)
            
            do {
                let attr : NSDictionary? = try FileManager.default.attributesOfItem(atPath: filenamePath) as NSDictionary?
                
                if let _attr = attr {
                    if _attr.fileSize() > 0 {
                        
                        filesName.append(fileName)
                    }
                }
                
            } catch let error {
                outError = error
            }
            
        } catch let error {
            outError = error
        }
    }
    
    if index + 1 == attachments.count {
        completion(filesName, outError)
    }
}
task.resume()
*/

class NCShareExtensionButtonWithIndexPath: UIButton {
    var indexPath:IndexPath?
    var fileName: String?
    var image: UIImage?
}
