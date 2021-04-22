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

import Foundation
import NCCommunication

class NCShareExtension: UIViewController, NCListCellDelegate, NCEmptyDataSetDelegate, NCRenameFileDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var commandViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var createFolderButton: UIButton!
    @IBOutlet weak var createFolderLabel: UILabel!
    @IBOutlet weak var uploadButton: UIButton!

    // -------------------------------------------------------------
    var titleCurrentFolder = NCBrandOptions.shared.brand
    var serverUrl = ""
    var filesName: [String] = []
    // -------------------------------------------------------------
        
    private var emptyDataSet: NCEmptyDataSet?
    private let keyLayout = NCGlobal.shared.layoutViewShareExtension
    private var metadataFolder: tableMetadata?
    private var networkInProgress = false
    private var dataSource = NCDataSource()

    private var sort: String = ""
    private var ascending: Bool = true
    private var directoryOnTop: Bool = true
    private var layout = ""
    private var groupBy = ""
    private var titleButton = ""
    private var itemForLine = 0
    private var heightRowTableView: CGFloat = 50
    
    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    
    private var shares: [tableShare]?
    private let refreshControl = UIRefreshControl()
    private var activeAccount: tableAccount!
        
    // COLOR
    
    var labelColor: UIColor {
        get {
            if #available(iOS 13, *) {
                return .label
            } else {
                return .black
            }
        }
    }
    
    var separatorColor: UIColor {
        get {
            if #available(iOS 13, *) {
                return .separator
            } else {
                return UIColor(hex: "#3C3C434A")!
            }
        }
    }
   
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.prefersLargeTitles = false
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.collectionViewLayout = NCListLayout()

        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.shared.brandText
        refreshControl.backgroundColor = NCBrandColor.shared.backgroundView
        refreshControl.addTarget(self, action: #selector(reloadDatasource), for: .valueChanged)
        
        // Empty
        emptyDataSet = NCEmptyDataSet.init(view: collectionView, offset: -50, delegate: self)
        separatorView.backgroundColor = separatorColor
        tableView.separatorColor = separatorColor
        //tableView.layer.borderColor = separatorColor.cgColor
        tableView.layer.borderWidth = 0
        tableView.layer.cornerRadius = 10.0
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 0, height: 1)))
        createFolderLabel.text = NSLocalizedString("_create_folder_", comment: "")
        uploadButton.setTitle(NSLocalizedString("_save_files_", comment: ""), for: .normal)
        
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
        
            guard let account = NCManageDatabase.shared.getAccountActive() else {
                extensionContext?.completeRequest(returningItems: extensionContext?.inputItems, completionHandler: nil)
                return
            }
            self.activeAccount = account
            
            let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
          
            // NETWORKING
            NCCommunicationCommon.shared.setup(account: account.account, user: account.user, userId: account.userId, password: CCUtility.getPassword(account.account), urlBase: account.urlBase, userAgent: CCUtility.getUserAgent(), webDav: NCUtilityFileSystem.shared.getWebDAV(account: account.account), dav: NCUtilityFileSystem.shared.getDAV(), nextcloudVersion: serverVersionMajor, delegate: NCNetworking.shared)
                    
            // get auto upload folder
            autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
            autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, account: activeAccount.account)
            
            (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: keyLayout,serverUrl: serverUrl)
                   
            // Load data source
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, account: activeAccount.account)
            getFilesExtensionContext { (filesName, error) in
                DispatchQueue.main.async {
                    self.filesName = filesName
                    self.setCommandView()
                }
            }
                
            shares = NCManageDatabase.shared.getTableShares(account: activeAccount.account, serverUrl: serverUrl)
            reloadDatasource(withLoadFolder: true)
            setNavigationBar()
        }
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

    func setNavigationBar() {
        
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
             
            let account = NCManageDatabase.shared.getAccountActive()
            var title = "  "
            if account?.alias == "" {
                title = title + (account?.user ?? "")
            } else {
                title = title + (account?.alias ?? "")
            }
                
            profileButton.setTitle(title, for: .normal)
            profileButton.setTitleColor(.systemBlue, for: .normal)
        }
            
        profileButton.semanticContentAttribute = .forceLeftToRight
        profileButton.sizeToFit()
        profileButton.addTarget(self, action: #selector(profileButtonTapped(sender:)), for: .touchUpInside)
                   
        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, account: activeAccount.account) {

            navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: profileButton)], animated: true)
            navigationItem.title = titleCurrentFolder
            
        } else {

            let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            space.width = 20
            
            navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: backButton), space, UIBarButtonItem(customView: profileButton)], animated: true)
            navigationItem.title = ""
        }
    }
    
    func setCommandView() {
        
        if filesName.count == 0 {
            self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
            return
        } else {
            if filesName.count < 3 {
                self.commandViewHeightConstraint.constant = 140 + (self.heightRowTableView * CGFloat(filesName.count))
            } else  {
                self.commandViewHeightConstraint.constant = 140 + (self.heightRowTableView * 3)
            }
            if filesName.count <= 3 {
                self.tableView.isScrollEnabled = false
            }
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
            view.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
            view.emptyDescription.text = ""
        }
    }
    
    // MARK: ACTION
    
    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        extensionContext?.completeRequest(returningItems: extensionContext?.inputItems, completionHandler: nil)
    }
    
    @IBAction func actionCreateFolder(_ sender: UIButton) {
        
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
    
    @IBAction func actionUpload(_ sender: UIButton) {
        
    }
    
    @objc func backButtonTapped(sender: Any) {
        
        while serverUrl.last != "/" {
            serverUrl.removeLast()
        }
        serverUrl.removeLast()
        
        shares = NCManageDatabase.shared.getTableShares(account: activeAccount.account, serverUrl: serverUrl)
        reloadDatasource(withLoadFolder: true)
        setNavigationBar()
    }
    
    func rename(fileName: String, fileNameNew: String) {
        
        if let row = self.filesName.firstIndex(where: {$0 == fileName}) {
            
            if NCUtilityFileSystem.shared.moveFile(atPath: (NSTemporaryDirectory() + fileName), toPath: (NSTemporaryDirectory() + fileNameNew)) {
                filesName[row] = fileNameNew
                tableView.reloadData()
            }
        }
    }
    
    @objc func renameButtonPressed(sender: NCShareExtensionButtonWithIndexPath) {
        
        if let fileName = sender.fileName {
            if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {
            
                vcRename.delegate = self
                vcRename.fileName = fileName
                vcRename.imagePreview = sender.image

                let popup = NCPopupViewController(contentController: vcRename, popupWidth: 300, popupHeight: 360)
                                        
                self.present(popup, animated: true)
            }
        }
    }
    
    @objc func deleteButtonPressed(sender: NCShareExtensionButtonWithIndexPath) {
        if let index = sender.indexPath?.row {
            filesName.remove(at: index)
            setCommandView()
        }
    }
    
    @objc func profileButtonTapped(sender: Any) {
    }
    
    func tapShareListItem(with objectId: String, sender: Any) {
    }
    
    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {
    }
    
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
}

// MARK: - Collection View

extension NCShareExtension: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
        guard let serverUrlTemp = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName) else { return }
        
        serverUrl = serverUrlTemp
        shares = NCManageDatabase.shared.getTableShares(account: activeAccount.account, serverUrl: serverUrl)
        reloadDatasource(withLoadFolder: true)
        setNavigationBar()
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
        cell.labelTitle.textColor = labelColor
        cell.separator.backgroundColor = separatorColor
        cell.separatorHeight(size: 0.5)
        
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
            
        } else {
            
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                cell.imageItem.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            } else {
                if metadata.hasPreview {
                    cell.imageItem.backgroundColor = .lightGray
                } else {
                    if metadata.iconName.count > 0 {
                        cell.imageItem.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.imageItem.image = NCBrandColor.cacheImages.file
                    }
                }
            }
            
            cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
            
            // image local
            if dataSource.metadataOffLine.contains(metadata.ocId) {
                cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
            } else if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                cell.imageLocal.image = NCBrandColor.cacheImages.local
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
       
        let imageCell = cell.viewWithTag(10) as? UIImageView
        let fileNameCell = cell.viewWithTag(20) as? UILabel
        let renameButton = cell.viewWithTag(30) as? NCShareExtensionButtonWithIndexPath
        let deleteButton = cell.viewWithTag(40) as? NCShareExtensionButtonWithIndexPath

        imageCell?.layer.cornerRadius = 6
        imageCell?.layer.masksToBounds = true

        let fileName = filesName[indexPath.row]
        imageCell?.image = NCUtility.shared.loadImage(named: "file")
        if let image = UIImage(contentsOfFile: (NSTemporaryDirectory() + fileName)) {
            imageCell?.image = image
        }
        
        fileNameCell?.text = fileName
        
        renameButton?.setImage(NCUtility.shared.loadImage(named: "pencil").image(color: labelColor, size: 15), for: .normal)
        renameButton?.indexPath = indexPath
        renameButton?.fileName = fileName
        renameButton?.image = imageCell?.image
        renameButton?.addTarget(self, action:#selector(renameButtonPressed(sender:)), for: .touchUpInside)

        deleteButton?.setImage(NCUtility.shared.loadImage(named: "trash").image(color: .red, size: 15), for: .normal)
        deleteButton?.indexPath = indexPath
        deleteButton?.fileName = fileName
        deleteButton?.image = imageCell?.image
        deleteButton?.addTarget(self, action:#selector(deleteButtonPressed(sender:)), for: .touchUpInside)
        
        return cell
    }
}

// MARK: - NC API & Algorithm

extension NCShareExtension {

    @objc func reloadDatasource(withLoadFolder: Bool) {
                
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: keyLayout, serverUrl: serverUrl)
                
        let metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", activeAccount.account, serverUrl))
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)
        
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
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    func loadFolder() {
        
        networkInProgress = true
        collectionView.reloadData()
        
        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: activeAccount.account) { (_, metadataFolder, _, _, _, errorCode, errorDescription) in
            if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
            self.networkInProgress = false
            self.metadataFolder = metadataFolder
            self.reloadDatasource(withLoadFolder: false)
        }
    }
    
    func getFilesExtensionContext(completion: @escaping (_ filesName: [String], _ error: Error?)->())  {
        
        var filesName: [String] = []
        var conuter = 0
        var outError: Error? = nil
        
        CCUtility.emptyTemporaryDirectory()
                
        if let inputItems : [NSExtensionItem] = extensionContext?.inputItems as? [NSExtensionItem] {
            
            for item : NSExtensionItem in inputItems {
                
                if let attachments = item.attachments {
                    
                    if attachments.isEmpty {
                        
                        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        completion(filesName, outError)
                        return
                    }
                    
                    for (index, current) in (attachments.enumerated()) {
                        
                        if current.hasItemConformingToTypeIdentifier(kUTTypeItem as String) || current.hasItemConformingToTypeIdentifier("public.url") {
                            
                            var typeIdentifier = ""
                            if current.hasItemConformingToTypeIdentifier(kUTTypeItem as String) { typeIdentifier = kUTTypeItem as String }
                            if current.hasItemConformingToTypeIdentifier("public.url") { typeIdentifier = "public.url" }
                            
                            current.loadItem(forTypeIdentifier: typeIdentifier, options: nil, completionHandler: {(item, error) -> Void in
                                
                                var fileNameOriginal: String?
                                var fileName: String = ""
                                
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss-"
                                conuter += 1
                                
                                if let url = item as? NSURL {
                                    fileNameOriginal = url.lastPathComponent!
                                }
                                
                                if error == nil {
                                                                        
                                    if let image = item as? UIImage {
                                        
                                        print("item as UIImage")
                                        
                                        if let pngImageData = image.pngData() {
                                        
                                            if fileNameOriginal != nil {
                                                fileName =  fileNameOriginal!
                                            } else {
                                                fileName = "\(dateFormatter.string(from: Date()))\(conuter).png"
                                            }
                                            
                                            let filenamePath = NSTemporaryDirectory() + fileName
                                            
                                            let result = (try? pngImageData.write(to: URL(fileURLWithPath: filenamePath), options: [.atomic])) != nil
                                        
                                            if result {
                                                filesName.append(fileName)
                                            }
                                            
                                        } else {
                                         
                                            print("Error image nil")
                                        }
                                    }
                                    
                                    if let url = item as? URL {
                                        
                                        print("item as url: \(String(describing: item))")
                                        
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
                                            try FileManager.default.copyItem(atPath: url.path, toPath:filenamePath)
                                            
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
                                    
                                    if let data = item as? Data {
                                        
                                        if data.count > 0 {
                                        
                                            print("item as NSdata")
                                        
                                            if fileNameOriginal != nil {
                                                fileName =  fileNameOriginal!
                                            } else {
                                                let description = current.description
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
                                    
                                    if let data = item as? NSString {
                                        
                                        if data.length > 0 {
                                        
                                            print("item as NSString")
                                        
                                            let fileName = "\(dateFormatter.string(from: Date()))\(conuter).txt"
                                            let filenamePath = NSTemporaryDirectory() + fileName
                                        
                                            FileManager.default.createFile(atPath: filenamePath, contents:data.data(using: String.Encoding.utf8.rawValue), attributes:nil)
                                        
                                            filesName.append(fileName)
                                        }
                                    }
                                    
                                    if index + 1 == attachments.count {
                                        completion(filesName, outError)
                                    }
                                    
                                } else {
                                    completion( filesName, error)
                                }
                            })
                        }
                    } // end for
                } else {
                    completion(filesName, outError)
                }
            }
        } else {
            completion(filesName, outError)
        }
    }
}

class NCShareExtensionButtonWithIndexPath: UIButton {
    var indexPath:IndexPath?
    var fileName: String?
    var image: UIImage?
}
