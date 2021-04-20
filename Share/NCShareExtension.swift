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

class NCShareExtension: UIViewController, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, NCEmptyDataSetDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!

    @IBOutlet fileprivate weak var buttonCancel: UIBarButtonItem!
   
    // -------------------------------------------------------------
    var titleCurrentFolder = NCBrandOptions.shared.brand
    var serverUrl = ""
    // -------------------------------------------------------------
        
    private var emptyDataSet: NCEmptyDataSet?
    
    private let keyLayout = NCGlobal.shared.layoutViewMove
    private var serverUrlPush = ""
    private var metadataTouch: tableMetadata?
    private var metadataFolder = tableMetadata()
    
    private var networkInProgress = false
    
    private var dataSource = NCDataSource()
    internal var richWorkspaceText: String?

    private var sort: String = ""
    private var ascending: Bool = true
    private var directoryOnTop: Bool = true
    private var layout = ""
    private var groupBy = ""
    private var titleButton = ""
    private var itemForLine = 0

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    
    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
        
    private let headerHeight: CGFloat = 50
    private var headerRichWorkspaceHeight: CGFloat = 0
    private let footerHeight: CGFloat = 100
    
    private var shares: [tableShare]?
    
    private let refreshControl = UIRefreshControl()
    
    private var activeAccount: tableAccount!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationController?.presentationController?.delegate = self
        
        activeAccount = NCManageDatabase.shared.getAccountActive()
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.alwaysBounceVertical = true
        
        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.shared.brandText
        refreshControl.backgroundColor = NCBrandColor.shared.brandElement
        refreshControl.addTarget(self, action: #selector(loadDatasource), for: .valueChanged)
        
        // Empty
        emptyDataSet = NCEmptyDataSet.init(view: collectionView, offset: 0, delegate: self)

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)

        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = titleCurrentFolder
        
        // set the serverUrl
        if serverUrl == "" {
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, account: activeAccount.account)
        }
                
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, account: activeAccount.account)
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: keyLayout,serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(itemForLine)
        
        if layout == NCGlobal.shared.layoutList {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
        
        loadDatasource(withLoadFolder: true)

        shares = NCManageDatabase.shared.getTableShares(account: activeAccount.account, serverUrl: serverUrl)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.userInterfaceStyle == .dark {
            
        } else {
            
        }
    }
    
    @objc func changeTheming() {
        view.backgroundColor = NCBrandColor.shared.backgroundView
        collectionView.backgroundColor = NCBrandColor.shared.backgroundView
        collectionView.reloadData()
        refreshControl.backgroundColor = NCBrandColor.shared.backgroundView
    }
    
    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        // Dismission
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
        self.dismiss(animated: true, completion: nil)
    }
    
    func createFolderButtonPressed(_ sender: UIButton) {
        
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
    
    // MARK: TAP EVENT
    
    func tapSwitchHeader(sender: Any) {
        
        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                })
            })
            layout = NCGlobal.shared.layoutList
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                })
            })
            layout = NCGlobal.shared.layoutGrid
        }
    }
    
    func tapOrderHeader(sender: Any) {
        
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: keyLayout, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }
    
    func tapMoreHeader(sender: Any) {
    }
    
    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {
    }
    
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {
    }
    
    func tapShareListItem(with objectId: String, sender: Any) {
    }
    
    func tapRichWorkspace(sender: Any) {
    }
    
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
}

// MARK: - Collection View

extension NCShareExtension: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
                
        if metadata.directory {
            
            guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName) else { return }
            guard let visualController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect else { return }

            self.serverUrlPush = serverUrlPush
            self.metadataTouch = metadata
            
            visualController.titleCurrentFolder = metadataTouch!.fileNameView
            visualController.serverUrl = serverUrlPush
                   
            self.navigationController?.pushViewController(visualController, animated: true)
            
        }
    }
}

extension NCShareExtension: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
            
            if collectionView.collectionViewLayout == gridLayout {
                header.buttonSwitch.setImage(UIImage.init(named: "switchList")?.image(color: NCBrandColor.shared.icon, size: 25), for: .normal)
            } else {
                header.buttonSwitch.setImage(UIImage.init(named: "switchGrid")?.image(color: NCBrandColor.shared.icon, size: 25), for: .normal)
            }
            
            header.delegate = self
            header.setStatusButton(count: dataSource.metadatas.count)
            header.setTitleSorted(datasourceTitleButton: titleButton)
            header.viewRichWorkspaceHeightConstraint.constant = headerRichWorkspaceHeight
            header.setRichWorkspaceText(richWorkspaceText: richWorkspaceText)
            
            return header
            
        } else {
            
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
            
            let info = dataSource.getFilesInformation()
            footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size)
            
            return footer
        }
            
    }
    
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
            if layout == NCGlobal.shared.layoutList {
                return collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            } else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            }
        }
        
        var tableShare: tableShare?
        var isShare = false
        var isMounted = false
        
        // Download preview
        NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: activeAccount.urlBase, view: collectionView, indexPath: indexPath)
        
        isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionShared)
        isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionMounted)
        
        if dataSource.metadataShare[metadata.ocId] != nil {
            tableShare = dataSource.metadataShare[metadata.ocId]
        }
        
        // LAYOUT LIST
        
        if layout == NCGlobal.shared.layoutList {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            cell.delegate = self
            
            cell.objectId = metadata.ocId
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.shared.textView
            cell.separator.backgroundColor = NCBrandColor.shared.separator
            
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
        
        // LAYOUT GRID
        
        if layout == NCGlobal.shared.layoutGrid {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self
            
            cell.objectId = metadata.ocId
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.shared.textView
            
            cell.imageSelect.image = nil
            cell.imageStatus.image = nil
            cell.imageLocal.image = nil
            cell.imageFavorite.image = nil
            
            cell.imageItem.image = nil
            cell.imageItem.backgroundColor = nil
            
            cell.progressView.progress = 0.0

            if metadata.directory {
                
                if metadata.e2eEncrypted {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderEncrypted
                } else if isShare {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
                } else if (tableShare != nil && tableShare!.shareType != 3) {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
                } else if (tableShare != nil && tableShare!.shareType == 3) {
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
                
                // image Local
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
            
            cell.imageSelect.isHidden = true
            cell.backgroundView = nil
            cell.hideButtonMore(true)

            // Live Photo
            if metadata.livePhoto {
                cell.imageStatus.image = NCBrandColor.cacheImages.livePhoto
            }
            
            return cell
        }
        
        return collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
    }
}

extension NCShareExtension: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        headerRichWorkspaceHeight = 0
        
        if let richWorkspaceText = richWorkspaceText {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 0 {
                headerRichWorkspaceHeight = UIScreen.main.bounds.size.height / 4
            }
        }
        
        return CGSize(width: collectionView.frame.width, height: headerHeight + headerRichWorkspaceHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: footerHeight)
    }
}

// MARK: - NC API & Algorithm

extension NCShareExtension {

    @objc func reloadDataSource() {
        loadDatasource(withLoadFolder: false)
    }
    
    @objc func loadDatasource(withLoadFolder: Bool) {
                
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: keyLayout, serverUrl: serverUrl)
                
        let metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account, serverUrl))
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)
        
        if withLoadFolder {
            loadFolder()
        } else {
            self.refreshControl.endRefreshing()
        }
        
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account,serverUrl))
        richWorkspaceText = directory?.richWorkspace
        
        collectionView.reloadData()
    }
    
    func createFolder(with fileName: String) {
        
        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: activeAccount.account, urlBase: activeAccount.urlBase) { (errorCode, errorDescription) in
            
            if errorCode == 0 {
                self.loadDatasource(withLoadFolder: true)
            }  else {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    func loadFolder() {
        
        networkInProgress = true
        collectionView.reloadData()
        
        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: activeAccount.account) { (_, _, _, _, _, errorCode, errorDescription) in
            if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
            self.networkInProgress = false
            self.loadDatasource(withLoadFolder: false)
        }
    }
}
