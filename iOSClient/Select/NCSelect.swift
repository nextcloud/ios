//
//  NCSelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/2018.
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

import UIKit
import NCCommunication

@objc protocol NCSelectDelegate {
    @objc func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool)
}

class NCSelect: UIViewController, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, NCEmptyDataSetDelegate {

    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var buttonCancel: UIBarButtonItem!

    private var selectCommandViewSelect: NCSelectCommandView?

    @objc enum selectType: Int {
        case select
        case selectCreateFolder
        case copyMove
    }

    // ------ external settings ------------------------------------
    @objc weak var delegate: NCSelectDelegate?
    @objc var typeOfCommandView: selectType = .select

    @objc var includeDirectoryE2EEncryption = false
    @objc var includeImages = false
    @objc var enableSelectFile = false
    @objc var type = ""
    @objc var items: [Any] = []

    var titleCurrentFolder = NCBrandOptions.shared.brand
    var serverUrl = ""
    // -------------------------------------------------------------

    private var emptyDataSet: NCEmptyDataSet?

    private let keyLayout = NCGlobal.shared.layoutViewMove
    private var serverUrlPush = ""
    private var metadataFolder = tableMetadata()

    private var isEditMode = false
    private var networkInProgress = false
    private var selectOcId: [String] = []
    private var overwrite = true

    private var dataSource = NCDataSource()
    internal var richWorkspaceText: String?

    private var layoutForView: NCGlobal.layoutForViewType?

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""

    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!

    private let headerHeight: CGFloat = 50
    private var headerRichWorkspaceHeight: CGFloat = 0
    private let footerHeight: CGFloat = 100

    private var shares: [tableShare]?

    private var backgroundImageView = UIImageView()

    private var activeAccount: tableAccount!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationController?.presentationController?.delegate = self

        view.backgroundColor = NCBrandColor.shared.systemBackground

        activeAccount = NCManageDatabase.shared.getActiveAccount()

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        // Header
        collectionView.register(UINib(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = NCBrandColor.shared.systemBackground

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        buttonCancel.title = NSLocalizedString("_cancel_", comment: "")

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: headerHeight, delegate: self)

        // Type of command view
        if typeOfCommandView == .select || typeOfCommandView == .selectCreateFolder {
            if typeOfCommandView == .select {
                selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewSelect", owner: self, options: nil)?.first as? NCSelectCommandView
            } else {
                selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewSelect+CreateFolder", owner: self, options: nil)?.first as? NCSelectCommandView
            }
            self.view.addSubview(selectCommandViewSelect!)
            selectCommandViewSelect?.selectView = self
            selectCommandViewSelect?.translatesAutoresizingMaskIntoConstraints = false

            selectCommandViewSelect?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.heightAnchor.constraint(equalToConstant: 80).isActive = true
        }

        if typeOfCommandView == .copyMove {
            selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewCopyMove", owner: self, options: nil)?.first as? NCSelectCommandView
            self.view.addSubview(selectCommandViewSelect!)
            selectCommandViewSelect?.selectView = self
            selectCommandViewSelect?.translatesAutoresizingMaskIntoConstraints = false

            selectCommandViewSelect?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.heightAnchor.constraint(equalToConstant: 150).isActive = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)

        changeTheming()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.navigationItem.title = titleCurrentFolder

        // set the serverUrl
        if serverUrl == "" {
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(account: activeAccount.account)
        }

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, account: activeAccount.account)

        layoutForView = NCUtility.shared.getLayoutForView(key: keyLayout, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
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

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        // Dismission
    }

    // MARK: - NotificationCenter

    @objc func changeTheming() {

        collectionView.reloadData()
        selectCommandViewSelect?.separatorView.backgroundColor = NCBrandColor.shared.separator
    }

    @objc func createFolder(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                if metadata.serverUrl == serverUrl {
                    pushMetadata(metadata)
                }
            }
        }
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        if networkInProgress {
            view.emptyImage.image = UIImage(named: "networkInProgress")?.image(color: .gray, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
            view.emptyDescription.text = ""
        } else {
            view.emptyImage.image = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
            if includeImages {
                view.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
            } else {
                view.emptyTitle.text = NSLocalizedString("_files_no_folders_", comment: "")
            }
            view.emptyDescription.text = ""
        }
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    func selectButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: false, move: false)
        self.dismiss(animated: true, completion: nil)
    }

    func copyButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: true, move: false)
        self.dismiss(animated: true, completion: nil)
    }

    func moveButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: false, move: true)
        self.dismiss(animated: true, completion: nil)
    }

    func createFolderButtonPressed(_ sender: UIButton) {

        let alertController = UIAlertController(title: NSLocalizedString("_create_folder_", comment: ""), message: "", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.autocapitalizationType = UITextAutocapitalizationType.words
        }

        let actionSave = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default) { (_: UIAlertAction) in
            if let fileName = alertController.textFields?.first?.text {
                self.createFolder(with: fileName)
            }
        }

        let actionCancel = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in
            print("You've pressed cancel button")
        }

        alertController.addAction(actionSave)
        alertController.addAction(actionCancel)

        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func valueChangedSwitchOverwrite(_ sender: UISwitch) {
        overwrite = sender.isOn
    }

    // MARK: TAP EVENT

    func tapSwitchHeader(sender: Any) {

        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutList
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutGrid
        }
    }

    func tapOrderHeader(sender: Any) {

        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: keyLayout, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }

    // MARK: - Push metadata

    func pushMetadata(_ metadata: tableMetadata) {

        guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName) else { return }
        guard let viewController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect else { return }

        self.serverUrlPush = serverUrlPush

        viewController.delegate = delegate
        viewController.typeOfCommandView = typeOfCommandView
        viewController.includeDirectoryE2EEncryption = includeDirectoryE2EEncryption
        viewController.includeImages = includeImages
        viewController.enableSelectFile = enableSelectFile
        viewController.type = type
        viewController.overwrite = overwrite
        viewController.items = items

        viewController.titleCurrentFolder = metadata.fileNameView
        viewController.serverUrl = serverUrlPush

        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - Collection View

extension NCSelect: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }

        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }

        if metadata.directory {

            pushMetadata(metadata)

        } else {

            delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadata, type: type, items: items, overwrite: overwrite, copy: false, move: false)
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension NCSelect: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu

            if collectionView.collectionViewLayout == gridLayout {
                header.buttonSwitch.setImage(UIImage(named: "switchList")?.image(color: NCBrandColor.shared.gray, size: 25), for: .normal)
            } else {
                header.buttonSwitch.setImage(UIImage(named: "switchGrid")?.image(color: NCBrandColor.shared.gray, size: 25), for: .normal)
            }

            header.delegate = self
            header.setStatusButton(count: dataSource.metadatas.count)
            header.setTitleSorted(datasourceTitleButton: layoutForView?.titleButtonHeader ?? "")
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

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }

        // Thumbnail
        if !metadata.directory {
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                (cell as! NCCellProtocol).filePreviewImageView?.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            } else {
                NCOperationQueue.shared.downloadThumbnail(metadata: metadata, placeholder: true, cell: cell, view: collectionView)
            }
        }

        // Avatar
        if metadata.ownerId.count > 0,
           metadata.ownerId != activeAccount.userId,
           activeAccount.account == metadata.account,
           let cell = cell as? NCCellProtocol {
            let fileName = metadata.userBaseUrl + "-" + metadata.ownerId + ".png"
            NCOperationQueue.shared.downloadAvatar(user: metadata.ownerId, dispalyName: metadata.ownerDisplayName, fileName: fileName, cell: cell, view: collectionView)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItems = dataSource.numberOfItems()
        emptyDataSet?.numberOfItemsInSection(numberOfItems, section: section)
        return numberOfItems
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else {
            if layoutForView?.layout == NCGlobal.shared.layoutList {
                return collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            } else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            }
        }

        var tableShare: tableShare?
        var isShare = false
        var isMounted = false

        isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionShared)
        isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionMounted)

        if dataSource.metadataShare[metadata.ocId] != nil {
            tableShare = dataSource.metadataShare[metadata.ocId]
        }

        // LAYOUT LIST

        if layoutForView?.layout == NCGlobal.shared.layoutList {

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            cell.delegate = self

            cell.fileObjectId = metadata.ocId
            cell.fileUser = metadata.ownerId
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
                } else if tableShare != nil && tableShare?.shareType != 3 {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
                } else if tableShare != nil && tableShare?.shareType == 3 {
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
            if isShare {
                cell.imageShared.image = NCBrandColor.cacheImages.shared
            } else if tableShare != nil && tableShare?.shareType == 3 {
                cell.imageShared.image = NCBrandColor.cacheImages.shareByLink
            } else if tableShare != nil && tableShare?.shareType != 3 {
                cell.imageShared.image = NCBrandColor.cacheImages.shared
            } else {
                cell.imageShared.image = NCBrandColor.cacheImages.canShare
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

        if layoutForView?.layout == NCGlobal.shared.layoutGrid {

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self

            cell.fileObjectId = metadata.ocId
            cell.fileUser = metadata.ownerId
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.shared.label

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
                } else if tableShare != nil && tableShare!.shareType != 3 {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
                } else if tableShare != nil && tableShare!.shareType == 3 {
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

extension NCSelect: UICollectionViewDelegateFlowLayout {

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

// MARK: -

extension NCSelect {

    @objc func reloadDataSource() {
        loadDatasource(withLoadFolder: false)
    }

    @objc func loadDatasource(withLoadFolder: Bool) {

        var predicate: NSPredicate?

        layoutForView = NCUtility.shared.getLayoutForView(key: keyLayout, serverUrl: serverUrl)

        if includeDirectoryE2EEncryption {

            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND (directory == true OR classFile == 'image')", activeAccount.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", activeAccount.account, serverUrl)
            }

        } else {

            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND (directory == true OR classFile == 'image')", activeAccount.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND directory == true", activeAccount.account, serverUrl)
            }
        }

        let metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: predicate!)
        self.dataSource = NCDataSource(metadatasSource: metadatasSource, sort: layoutForView?.sort, ascending: layoutForView?.ascending, directoryOnTop: layoutForView?.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)

        if withLoadFolder {
            loadFolder()
        }

        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace

        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    func createFolder(with fileName: String) {

        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: activeAccount.account, urlBase: activeAccount.urlBase) { errorCode, errorDescription in

            if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }

    func loadFolder() {

        networkInProgress = true
        collectionView.reloadData()

        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: activeAccount.account) { _, _, _, _, _, _, errorCode, errorDescription in
            if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
            self.networkInProgress = false
            self.loadDatasource(withLoadFolder: false)
        }
    }
}

// MARK: -

class NCSelectCommandView: UIView {

    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var createFolderButton: UIButton?
    @IBOutlet weak var selectButton: UIButton?
    @IBOutlet weak var copyButton: UIButton?
    @IBOutlet weak var moveButton: UIButton?
    @IBOutlet weak var overwriteSwitch: UISwitch?
    @IBOutlet weak var overwriteLabel: UILabel?
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!

    var selectView: NCSelect?
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {

        separatorHeightConstraint.constant = 0.5
        separatorView.backgroundColor = NCBrandColor.shared.separator

        overwriteLabel?.text = NSLocalizedString("_overwrite_", comment: "")

        selectButton?.layer.cornerRadius = 15
        selectButton?.layer.masksToBounds = true
        selectButton?.setTitle(NSLocalizedString("_select_", comment: ""), for: .normal)

        createFolderButton?.layer.cornerRadius = 15
        createFolderButton?.layer.masksToBounds = true
        createFolderButton?.setTitle(NSLocalizedString("_create_folder_", comment: ""), for: .normal)

        copyButton?.layer.cornerRadius = 15
        copyButton?.layer.masksToBounds = true
        copyButton?.setTitle(NSLocalizedString("_copy_", comment: ""), for: .normal)

        moveButton?.layer.cornerRadius = 15
        moveButton?.layer.masksToBounds = true
        moveButton?.setTitle(NSLocalizedString("_move_", comment: ""), for: .normal)
    }

    @IBAction func createFolderButtonPressed(_ sender: UIButton) {
        selectView?.createFolderButtonPressed(sender)
    }

    @IBAction func selectButtonPressed(_ sender: UIButton) {
        selectView?.selectButtonPressed(sender)
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        selectView?.copyButtonPressed(sender)
    }

    @IBAction func moveButtonPressed(_ sender: UIButton) {
        selectView?.moveButtonPressed(sender)
    }

    @IBAction func valueChangedSwitchOverwrite(_ sender: UISwitch) {
        selectView?.valueChangedSwitchOverwrite(sender)
    }
}
