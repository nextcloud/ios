//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
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

class NCTrash: UIViewController, UIGestureRecognizerDelegate, NCTrashListCellDelegate, NCGridCellDelegate, NCTrashSectionHeaderMenuDelegate, NCEmptyDataSetDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    var trashPath = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var blinkFileId: String?
    var emptyDataSet: NCEmptyDataSet?

    internal let appDelegate = UIApplication.shared.delegate as! AppDelegate

    internal var isEditMode = false
    internal var selectOcId: [String] = []

    private var datasource: [tableTrash] = []
    private var layoutForView: NCGlobal.layoutForViewType?
    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
    private let highHeader: CGFloat = 50
    private let refreshControl = UIRefreshControl()

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.systemBackground
        self.navigationController?.navigationBar.prefersLargeTitles = true

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
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)

        changeTheming()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        self.navigationItem.title = titleCurrentFolder

        layoutForView = NCUtility.shared.getLayoutForView(key: NCGlobal.shared.layoutViewTrash, serverUrl: "", sort: "date", ascending: false, titleButtonHeader: "_sorted_by_date_more_recent_")
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }

        if trashPath == "" {
            guard let userId = (appDelegate.userId as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed) else { return }
            trashPath = appDelegate.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: appDelegate.account) + "/trashbin/" + userId + "/trash/"
        }
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

    @objc func changeTheming() {
        collectionView.reloadData()
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

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
        } else {
            let buttonPosition: CGPoint = (sender as! UIButton).convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }

    func tapMoreListItem(with objectId: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            toggleMenuMoreList(with: objectId, image: image)
        } else {
            let buttonPosition: CGPoint = (sender as! UIButton).convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            toggleMenuMoreGrid(with: objectId, namedButtonMore: namedButtonMore, image: image)
        } else {
            let buttonPosition: CGPoint = (sender as! UIButton).convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }

    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
}

// MARK: - Collection View

extension NCTrash: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        let tableTrash = datasource[indexPath.item]

        if isEditMode {
            if let index = selectOcId.firstIndex(of: tableTrash.fileId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(tableTrash.fileId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }

        if tableTrash.directory {

            let ncTrash: NCTrash = UIStoryboard(name: "NCTrash", bundle: nil).instantiateInitialViewController() as! NCTrash

            ncTrash.trashPath = tableTrash.filePath + tableTrash.fileName
            ncTrash.titleCurrentFolder = tableTrash.trashbinFileName

            self.navigationController?.pushViewController(ncTrash, animated: true)
        }
    }
}

extension NCTrash: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            let trashHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCTrashSectionHeaderMenu

            if collectionView.collectionViewLayout == gridLayout {
                trashHeader.buttonSwitch.setImage(UIImage(named: "switchList")?.image(color: NCBrandColor.shared.gray, size: 25), for: .normal)
            } else {
                trashHeader.buttonSwitch.setImage(UIImage(named: "switchGrid")?.image(color: NCBrandColor.shared.gray, size: 25), for: .normal)
            }

            trashHeader.delegate = self
            trashHeader.backgroundColor = NCBrandColor.shared.systemBackground
            trashHeader.separator.backgroundColor = NCBrandColor.shared.separator
            trashHeader.setStatusButton(datasource: datasource)
            trashHeader.setTitleSorted(datasourceTitleButton: layoutForView?.titleButtonHeader ?? "")

            return trashHeader

        } else {

            let trashFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCTrashSectionFooter

            trashFooter.setTitleLabelFooter(datasource: datasource)

            return trashFooter
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        emptyDataSet?.numberOfItemsInSection(datasource.count, section: section)
        return datasource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let tableTrash = datasource[indexPath.item]
        var image: UIImage?

        if tableTrash.iconName.count > 0 {
            image = UIImage(named: tableTrash.iconName)
        } else {
            image = UIImage(named: "file")
        }

        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
            image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName))
        } else {
            if tableTrash.hasPreview && !CCUtility.fileProviderStoragePreviewIconExists(tableTrash.fileId, etag: tableTrash.fileName) {
                downloadThumbnail(with: tableTrash, indexPath: indexPath)
            }
        }

        if collectionView.collectionViewLayout == listLayout {

            // LIST
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCTrashListCell
            cell.delegate = self

            cell.objectId = tableTrash.fileId
            cell.indexPath = indexPath
            cell.labelTitle.text = tableTrash.trashbinFileName
            cell.labelTitle.textColor = NCBrandColor.shared.label

            if tableTrash.directory {
                cell.imageItem.image = NCBrandColor.cacheImages.folder
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date)
            } else {
                cell.imageItem.image = image
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date) + ", " + CCUtility.transformedSize(tableTrash.size)
            }

            if isEditMode {
                cell.selectMode(true)
                if selectOcId.contains(tableTrash.fileId) {
                    cell.selected(true)
                } else {
                    cell.selected(false)
                }
            } else {
                cell.selectMode(false)
            }

            return cell

        } else {

            // GRID
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self

            cell.fileObjectId = tableTrash.fileId
            cell.labelTitle.text = tableTrash.trashbinFileName
            cell.labelTitle.textColor = NCBrandColor.shared.label
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)

            if tableTrash.directory {
                cell.imageItem.image = NCBrandColor.cacheImages.folder
            } else {
                cell.imageItem.image = image
            }

            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectOcId.contains(tableTrash.fileId) {
                    cell.selected(true)
                } else {
                    cell.selected(false)
                }
            } else {
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            return cell
        }
    }
}

extension NCTrash: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }
}

// MARK: - NC API & Algorithm

extension NCTrash {

    @objc func reloadDataSource() {

        layoutForView = NCUtility.shared.getLayoutForView(key: NCGlobal.shared.layoutViewTrash, serverUrl: "")

        datasource.removeAll()

        guard let tashItems = NCManageDatabase.shared.getTrash(filePath: trashPath, sort: layoutForView?.sort, ascending: layoutForView?.ascending, account: appDelegate.account) else {
            return
        }

        datasource = tashItems
        collectionView.reloadData()

        if self.blinkFileId != nil {
            for item in 0...self.datasource.count-1 {
                if self.datasource[item].fileId.contains(self.blinkFileId!) {
                    let indexPath = IndexPath(item: item, section: 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UIView.animate(withDuration: 0.3) {
                            self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
                        } completion: { _ in
                            if let cell = self.collectionView.cellForItem(at: indexPath) {
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
        }
    }

    @objc func loadListingTrash() {

        NCCommunication.shared.listingTrash(showHiddenFiles: false, queue: NCCommunicationCommon.shared.backgroundQueue) { account, items, errorCode, errorDescription in

            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.shared.deleteTrash(filePath: self.trashPath, account: self.appDelegate.account)
                NCManageDatabase.shared.addTrash(account: account, items: items)
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }

    func downloadThumbnail(with tableTrash: tableTrash, indexPath: IndexPath) {

        let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(tableTrash.fileId, etag: tableTrash.fileName)!
        let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)!

        NCCommunication.shared.downloadPreview(fileNamePathOrFileId: tableTrash.fileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: NCGlobal.shared.sizePreview, heightPreview: NCGlobal.shared.sizePreview, fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: NCGlobal.shared.sizeIcon, etag: nil, endpointTrashbin: true) { account, _, imageIcon, _, _, errorCode, _ in

            if errorCode == 0 && imageIcon != nil && account == self.appDelegate.account {
                if let cell = self.collectionView.cellForItem(at: indexPath) {
                    if cell is NCTrashListCell {
                        (cell as! NCTrashListCell).imageItem.image = imageIcon
                    } else if cell is NCGridCell {
                        (cell as! NCGridCell).imageItem.image = imageIcon
                    }
                }
            }
        }
    }
}
