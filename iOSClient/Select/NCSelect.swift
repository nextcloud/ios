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
import SwiftUI
import NextcloudKit

@objc protocol NCSelectDelegate {
    @objc func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool)
}

class NCSelect: UIViewController, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, NCEmptyDataSetDelegate {

    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var buttonCancel: UIBarButtonItem!
    @IBOutlet private var bottomContraint: NSLayoutConstraint?

    private var selectCommandViewSelect: NCSelectCommandView?

    @objc enum selectType: Int {
        case select
        case selectCreateFolder
        case copyMove
        case nothing
    }

    // ------ external settings ------------------------------------
    @objc weak var delegate: NCSelectDelegate?
    @objc var typeOfCommandView: selectType = .select

    @objc var includeDirectoryE2EEncryption = false
    @objc var includeImages = false
    @objc var enableSelectFile = false
    @objc var type = ""
    @objc var items: [tableMetadata] = []

    var titleCurrentFolder = NCBrandOptions.shared.brand
    var serverUrl = ""
    // -------------------------------------------------------------

    private var emptyDataSet: NCEmptyDataSet?

    private let layoutKey = NCGlobal.shared.layoutViewMove
    private var serverUrlPush = ""
    private var metadataFolder = tableMetadata()

    private var isEditMode = false
    private var isSearching = false
    private var networkInProgress = false
    private var selectOcId: [String] = []
    private var overwrite = true

    private var dataSource = NCDataSource()
    internal var richWorkspaceText: String?

    private var layoutForView: NCDBLayoutForView?
    internal var headerMenu: NCSectionHeaderMenu?

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""

    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!

    private var backgroundImageView = UIImageView()

    private var activeAccount: tableAccount!
    private let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationController?.presentationController?.delegate = self

        view.backgroundColor = .systemBackground
        selectCommandViewSelect?.separatorView.backgroundColor = .separator

        activeAccount = NCManageDatabase.shared.getActiveAccount()

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        // Header
        collectionView.register(UINib(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .systemBackground

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        buttonCancel.title = NSLocalizedString("_cancel_", comment: "")

        bottomContraint?.constant = window?.rootViewController?.view.safeAreaInsets.bottom ?? 0

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: NCGlobal.shared.heightButtonsView, delegate: self)

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

            bottomContraint?.constant = 80
        }

        if typeOfCommandView == .copyMove {
            selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewCopyMove", owner: self, options: nil)?.first as? NCSelectCommandView
            self.view.addSubview(selectCommandViewSelect!)
            selectCommandViewSelect?.selectView = self
            selectCommandViewSelect?.translatesAutoresizingMaskIntoConstraints = false
            if items.contains(where: { $0.lock }) {
                selectCommandViewSelect?.moveButton?.isEnabled = false
                selectCommandViewSelect?.moveButton?.titleLabel?.isEnabled = false
            }
            selectCommandViewSelect?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.heightAnchor.constraint(equalToConstant: 150).isActive = true

            bottomContraint?.constant = 150
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.navigationItem.title = titleCurrentFolder

        // set the serverUrl
        if serverUrl == "" {
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId)
        }

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, userId: activeAccount.userId, account: activeAccount.account)

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: activeAccount.account, key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }

        loadDatasource(withLoadFolder: true)
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

    @objc func createFolder(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        pushMetadata(metadata)
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
        let alertController = UIAlertController.createFolder(serverUrl: serverUrl, urlBase: activeAccount)
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func valueChangedSwitchOverwrite(_ sender: UISwitch) {
        overwrite = sender.isOn
    }

    // MARK: TAP EVENT

    func tapButtonSwitch(_ sender: Any) {

        if layoutForView?.layout == NCGlobal.shared.layoutGrid {

            // list layout
            headerMenu?.buttonSwitch.accessibilityLabel = NSLocalizedString("_grid_view_", comment: "")
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCManageDatabase.shared.setLayoutForView(account: activeAccount.account, key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.listLayout, animated: true)

        } else {

            // grid layout
            headerMenu?.buttonSwitch.accessibilityLabel = NSLocalizedString("_list_view_", comment: "")
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCManageDatabase.shared.setLayoutForView(account: activeAccount.account, key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true)
        }
    }

    func tapButtonOrder(_ sender: Any) {

        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, account: activeAccount.account, key: layoutKey, sortButton: sender as? UIButton, serverUrl: serverUrl)
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
            NCOperationQueue.shared.downloadAvatar(user: metadata.ownerId, dispalyName: metadata.ownerDisplayName, fileName: fileName, cell: cell, view: collectionView, cellImageView: cell.fileAvatarImageView)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItems = dataSource.numberOfItemsInSection(section)
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

        var isShare = false
        var isMounted = false

        isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionShared)
        isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionMounted)

        // LAYOUT LIST

        if layoutForView?.layout == NCGlobal.shared.layoutList {

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            cell.delegate = self

            cell.fileObjectId = metadata.ocId
            cell.fileUser = metadata.ownerId
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = .label

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
                } else if !metadata.shareType.isEmpty {
                    metadata.shareType.contains(3) ?
                    (cell.imageItem.image = NCBrandColor.cacheImages.folderPublic) :
                    (cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe)
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderGroup
                } else if isMounted {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderExternal
                } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderAutomaticUpload
                } else {
                    cell.imageItem.image = NCBrandColor.cacheImages.folder
                }
                cell.imageItem.image = cell.imageItem.image?.colorizeFolder(metadata: metadata)

                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date)

            } else {

                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)

                // image local
                if dataSource.metadatasForSection[indexPath.section].metadataOffLine.contains(metadata.ocId) {
                    cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
                } else if CCUtility.fileProviderStorageExists(metadata) {
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
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(3) ?
                (cell.imageShared.image = NCBrandColor.cacheImages.shareByLink) :
                (cell.imageShared.image = NCBrandColor.cacheImages.shared)
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

            // Add TAGS
            cell.setTags(tags: Array(metadata.tags))

            return cell
        }

        // LAYOUT GRID

        if layoutForView?.layout == NCGlobal.shared.layoutGrid {

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self

            cell.fileObjectId = metadata.ocId
            cell.fileUser = metadata.ownerId
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = .label

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
                } else if !metadata.shareType.isEmpty {
                    metadata.shareType.contains(3) ?
                    (cell.imageItem.image = NCBrandColor.cacheImages.folderPublic) :
                    (cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe)
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderGroup
                } else if isMounted {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderExternal
                } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCBrandColor.cacheImages.folderAutomaticUpload
                } else {
                    cell.imageItem.image = NCBrandColor.cacheImages.folder
                }
                cell.imageItem.image = cell.imageItem.image?.colorizeFolder(metadata: metadata)

            } else {

                // image Local
                if dataSource.metadatasForSection[indexPath.section].metadataOffLine.contains(metadata.ocId) {
                    cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
                } else if CCUtility.fileProviderStorageExists(metadata) {
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

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            if indexPath.section == 0 {

                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
                let (_, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: indexPath.section)

                self.headerMenu = header

                if layoutForView?.layout == NCGlobal.shared.layoutGrid  {
                    header.setImageSwitchList()
                    header.buttonSwitch.accessibilityLabel = NSLocalizedString("_list_view_", comment: "")
                } else {
                    header.setImageSwitchGrid()
                    header.buttonSwitch.accessibilityLabel = NSLocalizedString("_grid_view_", comment: "")
                }

                header.delegate = self

                header.setButtonsCommand(heigt: 0)
                header.setButtonsView(heigt: NCGlobal.shared.heightButtonsView)
                header.setStatusButtonsView(enable: !dataSource.getMetadataSourceForAllSections().isEmpty)
                header.setSortedTitle(layoutForView?.titleButtonHeader ?? "")

                header.setRichWorkspaceHeight(heightHeaderRichWorkspace)
                header.setRichWorkspaceText(richWorkspaceText)

                header.setSectionHeight(heightHeaderSection)
                if heightHeaderSection == 0 {
                    header.labelSection.text = ""
                } else {
                    header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                }
                header.labelSection.textColor = .label

                return header

            } else {

                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionHeader

                header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                header.labelSection.textColor = NCBrandColor.shared.brandElement

                return header
            }

        } else {

            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
            let sections = dataSource.numberOfSections()
            let section = indexPath.section

            footer.setTitleLabel("")
            footer.separatorIsHidden(true)

            if sections == 1 || section == sections - 1 {
                let info = dataSource.getFooterInformationAllMetadatas()
                footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size)
            } else {
                footer.separatorIsHidden(false)
            }

            return footer
        }
    }
}

extension NCSelect: UICollectionViewDelegateFlowLayout {

    func getHeaderHeight(section:Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {

        var headerRichWorkspace: CGFloat = 0

        if let richWorkspaceText = richWorkspaceText {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 0 && !isSearching {
                headerRichWorkspace = UIScreen.main.bounds.size.height / 6
            }
        }

        if isSearching || layoutForView?.layout == NCGlobal.shared.layoutGrid  || dataSource.numberOfSections() > 1 {
            if section == 0 {
                return (NCGlobal.shared.heightButtonsView, headerRichWorkspace, NCGlobal.shared.heightSection)
            } else {
                return (0, 0, NCGlobal.shared.heightSection)
            }
        } else {
            return (NCGlobal.shared.heightButtonsView, headerRichWorkspace, 0)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {

        let (heightHeaderCommands, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: section)
        let heightHeader = heightHeaderCommands + heightHeaderRichWorkspace + heightHeaderSection

        return CGSize(width: collectionView.frame.width, height: heightHeader)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {

        let sections = dataSource.numberOfSections()

        if section == sections - 1 {
            return CGSize(width: collectionView.frame.width, height: NCGlobal.shared.endHeightFooter)
        } else {
            return CGSize(width: collectionView.frame.width, height: NCGlobal.shared.heightFooter)
        }
    }
}

// MARK: -

extension NCSelect {

    @objc func reloadDataSource() {
        loadDatasource(withLoadFolder: false)
    }

    @objc func loadDatasource(withLoadFolder: Bool) {

        var predicate: NSPredicate?
        var groupByField = "name"
        
        layoutForView = NCManageDatabase.shared.getLayoutForView(account: activeAccount.account, key: layoutKey, serverUrl: serverUrl)

        // set GroupField for Grid
        if layoutForView?.layout == NCGlobal.shared.layoutGrid {
            groupByField = "classFile"
        }

        if includeDirectoryE2EEncryption {

            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND (directory == true OR classFile == 'image')", activeAccount.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", activeAccount.account, serverUrl)
            }

        } else {

            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND (directory == true OR classFile == 'image')", activeAccount.account, serverUrl)
            } else if enableSelectFile {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false", activeAccount.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND directory == true", activeAccount.account, serverUrl)
            }
        }

        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: predicate!)
        self.dataSource = NCDataSource(metadatas: metadatas,
                                       account: activeAccount.account,
                                       sort: layoutForView?.sort,
                                       ascending: layoutForView?.ascending,
                                       directoryOnTop: layoutForView?.directoryOnTop,
                                       favoriteOnTop: true,
                                       filterLivePhoto: true,
                                       groupByField: groupByField)

        if withLoadFolder {
            loadFolder()
        }

        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace

        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    func loadFolder() {

        networkInProgress = true
        collectionView.reloadData()

        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: activeAccount.account) { _, _, _, _, _, _, error in
            if error != .success {
                NCContentPresenter.shared.showError(error: error)
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
        separatorView.backgroundColor = .separator

        overwriteSwitch?.onTintColor = NCBrandColor.shared.brand
        overwriteLabel?.text = NSLocalizedString("_overwrite_", comment: "")

        selectButton?.layer.cornerRadius = 15
        selectButton?.layer.masksToBounds = true
        selectButton?.setTitle(NSLocalizedString("_select_", comment: ""), for: .normal)
        selectButton?.backgroundColor = NCBrandColor.shared.brand
        selectButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        selectButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        createFolderButton?.layer.cornerRadius = 15
        createFolderButton?.layer.masksToBounds = true
        createFolderButton?.setTitle(NSLocalizedString("_create_folder_", comment: ""), for: .normal)
        createFolderButton?.backgroundColor = NCBrandColor.shared.brand
        createFolderButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        createFolderButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        copyButton?.layer.cornerRadius = 15
        copyButton?.layer.masksToBounds = true
        copyButton?.setTitle(NSLocalizedString("_copy_", comment: ""), for: .normal)
        copyButton?.backgroundColor = NCBrandColor.shared.brand
        copyButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        copyButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        moveButton?.layer.cornerRadius = 15
        moveButton?.layer.masksToBounds = true
        moveButton?.setTitle(NSLocalizedString("_move_", comment: ""), for: .normal)
        moveButton?.backgroundColor = NCBrandColor.shared.brand
        moveButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        moveButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)
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

// MARK: - UIViewControllerRepresentable

struct NCSelectViewControllerRepresentable: UIViewControllerRepresentable {

    typealias UIViewControllerType = UINavigationController
    var delegate: NCSelectDelegate

    func makeUIViewController(context: Context) -> UINavigationController {

        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController?.topViewController as? NCSelect

        viewController?.delegate = delegate
        viewController?.typeOfCommandView = .selectCreateFolder
        viewController?.includeDirectoryE2EEncryption = true

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }
}

struct SelectView: UIViewControllerRepresentable {

    typealias UIViewControllerType = UINavigationController

    @Binding var serverUrl: String

    class Coordinator: NSObject, NCSelectDelegate {

        var parent: SelectView

        init(_ parent: SelectView) {
            self.parent = parent
        }

        func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
            if let serverUrl = serverUrl {
                self.parent.serverUrl = serverUrl
            }
        }
    }

    func makeUIViewController(context: Context) -> UINavigationController {

        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController?.topViewController as? NCSelect

        viewController?.delegate = context.coordinator
        viewController?.typeOfCommandView = .selectCreateFolder
        viewController?.includeDirectoryE2EEncryption = true

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}


