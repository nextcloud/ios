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

import Realm
import UIKit
import NextcloudKit

class NCTrash: UIViewController, NCSelectableNavigationView, NCTrashListCellDelegate, NCSectionHeaderMenuDelegate, NCEmptyDataSetDelegate, NCGridCellDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    var trashPath = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var blinkFileId: String?
    var emptyDataSet: NCEmptyDataSet?
    var selectableDataSource: [RealmSwiftObject] { datasource }

    internal let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    internal var isEditMode = false
    internal var selectOcId: [String] = []

    var datasource: [tableTrash] = []
    var layoutForView: NCDBLayoutForView?
    var listLayout: NCListLayout!
    var gridLayout: NCGridLayout!

    private let refreshControl = UIRefreshControl()

    // MARK: - View Life Cycle

    override func viewDidLoad() {

        view.backgroundColor = .systemBackground
        self.navigationController?.navigationBar.prefersLargeTitles = true

        // Cell
        collectionView.register(UINib(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        // Header - Footer
        collectionView.register(UINib(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .systemBackground

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = .gray
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: NCGlobal.shared.heightButtonsView + NCGlobal.shared.heightButtonsCommand, delegate: self)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {

        appDelegate.activeViewController = self

        navigationController?.setFileAppreance()
        navigationItem.title = titleCurrentFolder

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, serverUrl: "")
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
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

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {
        view.emptyImage.image = UIImage(named: "trash")?.image(color: .gray, size: UIScreen.main.bounds.width)
        view.emptyTitle.text = NSLocalizedString("_trash_no_trash_", comment: "")
        view.emptyDescription.text = NSLocalizedString("_trash_no_trash_description_", comment: "")
    }

    // MARK: TAP EVENT

    func tapButtonSwitch(_ sender: Any) {

        if collectionView.collectionViewLayout == gridLayout {

            // list layout
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, serverUrl: "", layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.listLayout, animated: true)

        } else {

            // grid layout
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, serverUrl: "", layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true)
        }
    }

    func tapButtonOrder(_ sender: Any) {
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, sortButton: sender as? UIButton, serverUrl: "", hideDirectoryOnTop: true)
    }

    func tapButtonMore(_ sender: Any) {
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
            toggleMenuMore(with: objectId, image: image, isGridCell: false)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        } // else: undefined sender
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            toggleMenuMore(with: objectId, image: image, isGridCell: true)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }

    func tapButton1(_ sender: Any) {

        if isEditMode {
            if selectOcId.isEmpty { return }
            self.selectOcId.forEach(self.restoreItem)
            self.tapSelect()
        } else {
            if datasource.isEmpty { return }
            datasource.forEach({ self.restoreItem(with: $0.fileId) })
        }
    }

    func tapButton2(_ sender: Any) {

        if isEditMode {
            if selectOcId.isEmpty { return }
            let alert = UIAlertController(title: NSLocalizedString("_trash_delete_selected_", comment: ""), message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_delete_", comment: ""), style: .destructive, handler: { _ in
                self.selectOcId.forEach(self.deleteItem)
                self.tapSelect()
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in }))
            self.present(alert, animated: true, completion: nil)
        } else {
            if datasource.isEmpty { return }
            let alert = UIAlertController(title: NSLocalizedString("_trash_delete_all_description_", comment: ""), message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_trash_delete_all_", comment: ""), style: .destructive, handler: { _ in
                self.emptyTrash()
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    // MARK: - DataSource

    @objc func reloadDataSource(forced: Bool = true) {

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, serverUrl: "")
        datasource.removeAll()
        guard let trashPath = self.getTrashPath(), let tashItems = NCManageDatabase.shared.getTrash(filePath: trashPath, sort: layoutForView?.sort, ascending: layoutForView?.ascending, account: appDelegate.account) else {
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

    func getTrashPath() -> String? {

        if self.trashPath.isEmpty {
            guard let userId = (appDelegate.userId as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed) else { return nil }
            let trashPath = appDelegate.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/trashbin/" + userId + "/trash/"
            return trashPath
        } else {
            return self.trashPath
        }
    }
}

// MARK: - NC API & Algorithm

extension NCTrash {

    @objc func loadListingTrash() {

        NextcloudKit.shared.listingTrash(showHiddenFiles: false) { account, items, _, error in

            DispatchQueue.main.async { self.refreshControl.endRefreshing() }

            guard error == .success, account == self.appDelegate.account, let trashPath = self.getTrashPath() else {
                NCContentPresenter.shared.showError(error: error)
                return
            }

            NCManageDatabase.shared.deleteTrash(filePath: trashPath, account: self.appDelegate.account)
            NCManageDatabase.shared.addTrash(account: account, items: items)

            self.reloadDataSource()
        }
    }

    func restoreItem(with fileId: String) {

        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: fileId, account: appDelegate.account) else { return }
        let fileNameFrom = tableTrash.filePath + tableTrash.fileName
        let fileNameTo = appDelegate.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/trashbin/" + appDelegate.userId + "/restore/" + tableTrash.fileName

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true) { account, error in

            guard error == .success, account == self.appDelegate.account else {
                NCContentPresenter.shared.showError(error: error)
                return
            }

            NCManageDatabase.shared.deleteTrash(fileId: fileId, account: account)
            self.reloadDataSource()
        }
    }

    func emptyTrash() {

        let serverUrlFileName = appDelegate.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/trashbin/" + appDelegate.userId + "/trash"

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName) { account, error in

            guard error == .success, account == self.appDelegate.account else {
                NCContentPresenter.shared.showError(error: error)
                return
            }

            NCManageDatabase.shared.deleteTrash(fileId: nil, account: self.appDelegate.account)
            self.reloadDataSource()
        }
    }

    func deleteItem(with fileId: String) {

        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: fileId, account: appDelegate.account) else { return }
        let serverUrlFileName = tableTrash.filePath + tableTrash.fileName

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName) { account, error in

            guard error == .success, account == self.appDelegate.account else {
                NCContentPresenter.shared.showError(error: error)
                return
            }

            NCManageDatabase.shared.deleteTrash(fileId: fileId, account: account)
            self.reloadDataSource()
        }
    }

    func downloadThumbnail(with tableTrash: tableTrash, indexPath: IndexPath) {

        let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(tableTrash.fileId, etag: tableTrash.fileName)!
        let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)!

        NextcloudKit.shared.downloadPreview(
            fileNamePathOrFileId: tableTrash.fileId,
            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
            widthPreview: NCGlobal.shared.sizePreview,
            heightPreview: NCGlobal.shared.sizePreview,
            fileNameIconLocalPath: fileNameIconLocalPath,
            sizeIcon: NCGlobal.shared.sizeIcon,
            etag: nil,
            endpointTrashbin: true) { account, _, imageIcon, _, _, error in
                guard error == .success, let imageIcon = imageIcon, account == self.appDelegate.account,
                      let cell = self.collectionView.cellForItem(at: indexPath) else { return }
                if let cell = cell as? NCTrashListCell {
                    cell.imageItem.image = imageIcon
                } else if let cell = cell as? NCGridCell {
                    cell.imageItem.image = imageIcon
                } // else: undefined cell
            }
    }
}
