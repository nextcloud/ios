//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

class NCTrash: NCCollectionViewCommon, NCTrashListCellDelegate, NCTrashSectionHeaderMenuDelegate {

    var trashPath = ""
    var blinkFileId: String?

    var datasource: [tableTrash] = []
    let highHeader: CGFloat = 50

    // MARK: - View Life Cycle

    override func viewDidLoad() {

        view.backgroundColor = NCBrandColor.shared.systemBackground
        self.navigationController?.navigationBar.prefersLargeTitles = true
        titleCurrentFolder = titleCurrentFolder.isEmpty ? NSLocalizedString("_trash_view_", comment: "") : titleCurrentFolder

        // Cell
        collectionView.register(UINib(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        // Header - Footer
        collectionView.register(UINib(nibName: "NCTrashSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib(nibName: "NCTrashSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = NCBrandColor.shared.systemBackground

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = .gray
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: highHeader, delegate: self)

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTrashDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)

        changeTheming()
    }

    override func viewWillAppear(_ animated: Bool) {

        appDelegate.activeViewController = self

        self.navigationItem.title = titleCurrentFolder

        layoutForView = NCUtility.shared.getLayoutForView(key: NCGlobal.shared.layoutViewTrash, serverUrl: "", sort: "date", ascending: false, titleButtonHeader: "_sorted_by_date_more_recent_")
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }

        if trashPath.isEmpty {
            guard let userId = (appDelegate.userId as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed) else { return }
            trashPath = appDelegate.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: appDelegate.account) + "/trashbin/" + userId + "/trash/"
        }
        setNavigationItem()
        reloadDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadListingTrash()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    @objc override func changeTheming() {
        collectionView.reloadData()
    }

    // MARK: - Empty

    override func emptyDataSetView(_ view: NCEmptyView) {
        view.emptyImage.image = UIImage(named: "trash")?.image(color: .gray, size: UIScreen.main.bounds.width)
        view.emptyTitle.text = NSLocalizedString("_trash_no_trash_", comment: "")
        view.emptyDescription.text = NSLocalizedString("_trash_no_trash_description_", comment: "")
    }

    // MARK: TAP EVENT

    func tapSwitchHeaderMenu(sender: Any) {

        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCUtility.shared.setLayoutForView(key: NCGlobal.shared.layoutViewTrash, serverUrl: "", layout: layoutForView?.layout)
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCUtility.shared.setLayoutForView(key: NCGlobal.shared.layoutViewTrash, serverUrl: "", layout: layoutForView?.layout)
        }
    }

    func tapOrderHeaderMenu(sender: Any) {
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: NCGlobal.shared.layoutViewTrash, sortButton: sender as? UIButton, serverUrl: "", hideDirectoryOnTop: true)
    }

    func tapMoreHeaderMenu(sender: Any) {
        toggleMenuMoreHeader()
    }

    func tapRestoreListItem(with ocId: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            restoreItem(with: ocId)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        } // else: undefined sender
    }

    func tapMoreListItem(with objectId: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            toggleMenuMoreList(with: objectId, image: image)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        } // else: undefined sender
    }

    override func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            toggleMenuMoreGrid(with: objectId, namedButtonMore: namedButtonMore, image: image)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        } // else: undefined sender
    }

    override func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    override func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    override func collectionViewSelectAll() {
        selectOcId = datasource.map({ $0.fileId })
        navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(datasource.count)"
        collectionView.reloadData()
    }

    @objc func reloadTrashDataSource() { self.reloadDataSource() }

    @objc override func reloadDataSource() {

        layoutForView = NCUtility.shared.getLayoutForView(key: NCGlobal.shared.layoutViewTrash, serverUrl: "")

        datasource.removeAll()

        guard let tashItems = NCManageDatabase.shared.getTrash(filePath: trashPath, sort: layoutForView?.sort, ascending: layoutForView?.ascending, account: appDelegate.account) else {
            return
        }

        datasource = tashItems
        collectionView.reloadData()
        guard let blinkFileId = blinkFileId else { return }
        for itemIx in 0..<self.datasource.count where self.datasource[itemIx].fileId.contains(blinkFileId) {
            let indexPath = IndexPath(item: itemIx, section: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIView.animate(withDuration: 0.3) {
                    self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
                } completion: { _ in
                    guard let cell = self.collectionView.cellForItem(at: indexPath) else { return }
                    cell.backgroundColor = .darkGray
                    UIView.animate(withDuration: 2) {
                        cell.backgroundColor = .clear
                        self.blinkFileId = nil
                    }
                }
            }
        }
    }
}

// MARK: - NC API & Algorithm

extension NCTrash {

    @objc func loadListingTrash() {

        NCCommunication.shared.listingTrash(showHiddenFiles: false, queue: NCCommunicationCommon.shared.backgroundQueue) { account, items, errorCode, errorDescription in

            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.shared.deleteTrash(filePath: self.trashPath, account: self.appDelegate.account)
                NCManageDatabase.shared.addTrash(account: account, items: items)
            } else if errorCode != 0 {
                NCContentPresenter.shared.showError(description: errorDescription, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }

            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.reloadDataSource()
            }
        }
    }

    func restoreItem(with fileId: String) {

        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: fileId, account: appDelegate.account) else {
            return
        }

        let fileNameFrom = tableTrash.filePath + tableTrash.fileName
        let fileNameTo = appDelegate.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: appDelegate.account) + "/trashbin/" + appDelegate.userId + "/restore/" + tableTrash.fileName

        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true) { account, errorCode, errorDescription in
            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.shared.deleteTrash(fileId: fileId, account: account)
                self.reloadDataSource()
            } else if errorCode != 0 {
                NCContentPresenter.shared.showError(description: errorDescription, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }

    func emptyTrash() {

        let serverUrlFileName = appDelegate.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: appDelegate.account) + "/trashbin/" + appDelegate.userId + "/trash"

        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName) { account, errorCode, errorDescription in
            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.shared.deleteTrash(fileId: nil, account: self.appDelegate.account)
            } else if errorCode != 0 {
                NCContentPresenter.shared.showError(description: errorDescription, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
            self.reloadDataSource()
        }
    }

    func deleteItem(with fileId: String) {

        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: fileId, account: appDelegate.account) else {
            return
        }

        let serverUrlFileName = tableTrash.filePath + tableTrash.fileName

        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName) { account, errorCode, errorDescription in
            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.shared.deleteTrash(fileId: fileId, account: account)
                self.reloadDataSource()
            } else if errorCode != 0 {
                NCContentPresenter.shared.showError(description: errorDescription, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }

    func downloadThumbnail(with tableTrash: tableTrash, indexPath: IndexPath) {

        let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(tableTrash.fileId, etag: tableTrash.fileName)!
        let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)!

        NCCommunication.shared.downloadPreview(
            fileNamePathOrFileId: tableTrash.fileId,
            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
            widthPreview: NCGlobal.shared.sizePreview,
            heightPreview: NCGlobal.shared.sizePreview,
            fileNameIconLocalPath: fileNameIconLocalPath,
            sizeIcon: NCGlobal.shared.sizeIcon,
            etag: nil,
            endpointTrashbin: true) { account, _, imageIcon, _, _, errorCode, _ in
                guard errorCode == 0, let imageIcon = imageIcon, account == self.appDelegate.account,
                      let cell = self.collectionView.cellForItem(at: indexPath) else { return }
                if let cell = cell as? NCTrashListCell {
                    cell.imageItem.image = imageIcon
                } else if let cell = cell as? NCGridCell {
                    cell.imageItem.image = imageIcon
                } // else: undefined cell
            }
    }
}
