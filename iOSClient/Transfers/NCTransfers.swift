//
//  NCTransfers.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/09/2020.
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
import NextcloudKit
import RealmSwift

class NCTransfers: NCCollectionViewCommon, NCTransferCellDelegate {
    private var metadataTemp: tableMetadata?
    private var transferProgressMap: [String: Float] = [:]

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_transfers_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewTransfers
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImageName = "arrow.left.arrow.right.circle"
        emptyTitle = "_no_transfer_"
        emptyDescription = "_no_transfer_sub_"
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        listLayout.itemHeight = 105
        self.database.setLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl, layout: NCGlobal.shared.layoutList)
        self.navigationItem.title = titleCurrentFolder
        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor

        let close = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .done) {
            self.dismiss(animated: true)
        }

        self.navigationItem.leftBarButtonItems = [close]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadDataSource()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Task {
            await NCNetworking.shared.verifyZombie()
        }
    }

    // MARK: TAP EVENT

    override func tapMoreGridItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any) {
        guard let metadata = self.database.getMetadataFromOcIdAndocIdTransfer(ocIdTransfer) else { return }
        NCNetworking.shared.cancelTask(metadata: metadata)
    }

    override func longPressMoreListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_all_task_", comment: ""), style: .default, handler: { _ in
            NCNetworking.shared.cancelAllTask()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.reloadDataSource()
            }
        }))

        self.present(alertController, animated: true, completion: nil)
    }

    override func longPressListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }

        if let metadata = self.database.getMetadataFromOcIdAndocIdTransfer(ocIdTransfer) {
            metadataTemp = metadata
            let touchPoint = gestureRecognizer.location(in: collectionView)
            becomeFirstResponder()
            let startTaskItem = UIMenuItem(title: NSLocalizedString("_force_start_", comment: ""), action: #selector(startTask(_:)))
            UIMenuController.shared.menuItems = [startTaskItem]
            UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0))
        }
    }

    override func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) { }

    @objc func startTask(_ notification: Any) {
        guard let metadata = metadataTemp else { return }
        let cameraRoll = NCCameraRoll()

        Task {
            let metadatas = await cameraRoll.extractCameraRoll(from: metadata)
            for metadata in metadatas {
                if let metadata = self.database.setMetadataStatusAndReturn(ocId: metadata.ocId,
                                                                           status: NCGlobal.shared.metadataStatusUploading) {
                    NCNetworking.shared.uploadHub(metadata: metadata)
                }
            }
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action != #selector(startTask(_:)) { return false }
        guard let metadata = metadataTemp else { return false }
        if metadata.isDirectoryE2EE { return false }

        if metadata.isUpload {
            return true
        }

        return false
    }

    // MARK: - Collection View

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return nil
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // nothing
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "transferCell", for: indexPath) as? NCTransferCell)!
        guard let metadata = self.dataSource.getResultMetadata(indexPath: indexPath) else {
            return cell
        }
        cell.delegate = self
        cell.ocId = metadata.ocId
        cell.ocIdTransfer = metadata.ocIdTransfer
        cell.user = metadata.ownerId
        cell.serverUrl = metadata.serverUrl
        cell.fileName = metadata.fileNameView
        cell.imageItem?.image = imageCache.getImageFile()
        cell.imageItem?.backgroundColor = nil
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = NCBrandColor.shared.textColor

        // Restore previously cached progress for this file transfer, or reset to 0 if not found
        let key = "\(metadata.serverUrl)|\(metadata.fileNameView)"
        let progress = transferProgressMap[key] ?? 0
        cell.setProgress(progress: progress)

        let serverUrlHome = utilityFileSystem.getHomeServer(session: session)
        var pathText = metadata.serverUrl.replacingOccurrences(of: serverUrlHome, with: "")
        if pathText.isEmpty { pathText = "/" }
        cell.labelPath.text = pathText
        cell.setButtonMore(image: imageCache.getImageButtonStop())

        /// Image item
        if !metadata.iconName.isEmpty {
            cell.imageItem?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
        } else {
            cell.imageItem?.image = imageCache.getImageFile()
        }

        /// Status and Info
        let user = (metadata.user == session.user ? "" : " - " + metadata.account)
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitCreateFolder:
            cell.imageStatus?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_create_folder_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitDelete:
            cell.imageStatus?.image = utility.loadImage(named: "trash.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_delete_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitFavorite:
            cell.imageStatus?.image = utility.loadImage(named: "star.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_favorite_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitCopy:
            cell.imageStatus?.image = utility.loadImage(named: "c.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_copy_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitMove:
            cell.imageStatus?.image = utility.loadImage(named: "m.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_move_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitRename:
            cell.imageStatus?.image = utility.loadImage(named: "a.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_rename_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.imageStatus?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_download_", comment: "") + user
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size)
        case NCGlobal.shared.metadataStatusDownloading:
            if #available(iOS 17.0, *) {
                cell.imageStatus?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            }
            cell.labelStatus.text = NSLocalizedString("_status_downloading_", comment: "") + user
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size)
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.imageStatus?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_upload_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusUploading:
            if #available(iOS 17.0, *) {
                cell.imageStatus?.image = utility.loadImage(named: "arrowshape.up.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            }
            cell.labelStatus.text = NSLocalizedString("_status_uploading_", comment: "") + user
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size)
        case NCGlobal.shared.metadataStatusDownloadError, NCGlobal.shared.metadataStatusUploadError:
            cell.imageStatus?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_upload_error_", comment: "") + user
            cell.labelInfo.text = metadata.sessionError
        default:
            cell.imageStatus?.image = nil
            cell.labelStatus.text = ""
            cell.labelInfo.text = ""
        }

        if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan && !(NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi) {
            cell.labelInfo.text = NSLocalizedString("_waiting_for_", comment: "") + " " + NSLocalizedString("_reachable_wifi_", comment: "")
        }
        cell.accessibilityLabel = metadata.fileNameView + ", " + (cell.labelInfo.text ?? "")

        /// Remove last separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
            cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }

        return cell
    }

    // MARK: - DataSource

    override func reloadDataSource() {
        Task.detached {
            let predicate = NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal)
            let sortDescriptors = [
                RealmSwift.SortDescriptor(keyPath: "status", ascending: false),
                RealmSwift.SortDescriptor(keyPath: "sessionDate", ascending: true)
            ]

            let metadatas = await self.database.getMetadatasAsync(predicate: predicate, sortDescriptors: sortDescriptors, limit: 100)
            if let metadatas, !metadatas.isEmpty {
                self.dataSource = await NCCollectionViewDataSource(metadatas: metadatas, layoutForView: self.layoutForView)
            } else {
                await self.dataSource.removeAll()
            }

            await super.reloadDataSource()
        }
    }

    override func getServerData() {
        reloadDataSource()
    }

    // MARK: - Transfers Delegate
    override func transferChange(status: String, metadatasError: [tableMetadata: NKError]) {
        debouncer.call {
            self.reloadDataSource()
        }
    }

    override func transferChange(status: String, metadata: tableMetadata, error: NKError) {
        debouncer.call {
            self.reloadDataSource()
        }
    }

    override func transferReloadData(serverUrl: String?, status: Int?) {
        debouncer.call {
            self.reloadDataSource()
        }
    }

    override func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) {
        let key = "\(serverUrl)|\(fileName)"
        transferProgressMap[key] = progress

        DispatchQueue.main.async {
            for case let cell as NCTransferCell in self.collectionView.visibleCells {
                if cell.serverUrl == serverUrl && cell.fileName == fileName {
                    cell.setProgress(progress: progress)
                    cell.labelInfo?.text = self.utilityFileSystem.transformedSize(totalBytesExpected) + " - " + self.utilityFileSystem.transformedSize(totalBytes)
                }
            }
        }
    }
}
