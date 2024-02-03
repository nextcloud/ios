//
//  NCMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

class NCMedia: UIViewController, NCEmptyDataSetDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    var emptyDataSet: NCEmptyDataSet?
    var mediaCommandView: NCMediaCommandView?
    var layout: NCMediaGridLayout!
    var documentPickerViewController: NCDocumentPickerViewController?

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    var metadatas: ThreadSafeArray<tableMetadata>?
    var isEditMode = false
    var selectOcId: [String] = []

    var showOnlyImages = false
    var showOnlyVideos = false

    let maxImageGrid: CGFloat = 7
    var cellHeigth: CGFloat = 0

    var loadingTask: Task<Void, any Error>?

    var lastContentOffsetY: CGFloat = 0
    var mediaPath = ""

    var timeIntervalSearchNewMedia: TimeInterval = 2.0
    var timerSearchNewMedia: Timer?

    let insetsTop: CGFloat = 75

    struct cacheImages {
        static var cellLivePhotoImage = UIImage()
        static var cellPlayImage = UIImage()
        static var cellImage = UIImage()
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        layout = NCMediaGridLayout()
        layout.itemForLine = CGFloat(NCKeychain().mediaItemForLine)
        layout.sectionHeadersPinToVisibleBounds = true

        collectionView.register(UINib(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: insetsTop, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        collectionView.collectionViewLayout = layout

        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: 0, delegate: self)

        mediaCommandView = Bundle.main.loadNibNamed("NCMediaCommandView", owner: self, options: nil)?.first as? NCMediaCommandView
        self.view.addSubview(mediaCommandView!)
        mediaCommandView?.mediaView = self
        mediaCommandView?.tabBarController = tabBarController
        mediaCommandView?.translatesAutoresizingMaskIntoConstraints = false
        mediaCommandView?.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        mediaCommandView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        mediaCommandView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        mediaCommandView?.heightAnchor.constraint(equalToConstant: 150).isActive = true

        cacheImages.cellLivePhotoImage = utility.loadImage(named: "livephoto", color: .white)
        cacheImages.cellPlayImage = utility.loadImage(named: "play.fill", color: .white)

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() { self.mediaPath = activeAccount.mediaPath }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        navigationController?.setMediaAppreance()

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)

        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)

        if let metadatas = NCImageCache.shared.initialMetadatas() {
            self.metadatas = metadatas
        }

        collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        mediaCommandView?.setTitleDate()
        mediaCommandView?.createMenu()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        collectionView?.collectionViewLayout.invalidateLayout()
        mediaCommandView?.setTitleDate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - NotificationCenter

    @objc func deleteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocIds = userInfo["ocId"] as? [String],
              let error = userInfo["error"] as? NKError else { return }

        if !ocIds.isEmpty {
            var items: [IndexPath] = []
            self.metadatas = self.metadatas?.filter({ !ocIds.contains($0.ocId )})
            if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }) {
                for case let cell as NCGridMediaCell in visibleCells {
                    if let ocId = cell.fileObjectId, ocIds.contains(ocId) {
                        items.append(cell.indexPath)
                    }
                }
                if !items.isEmpty {
                    collectionView?.deleteItems(at: items)
                }
            }
            self.collectionView?.reloadData()
        }

        if error != .success {
            NCContentPresenter().showError(error: error)
        }
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        view.emptyImage.image = UIImage(named: "media")?.image(color: .gray, size: UIScreen.main.bounds.width)
        if loadingTask != nil {
            view.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
        } else {
            view.emptyTitle.text = NSLocalizedString("_tutorial_photo_view_", comment: "")
        }
        view.emptyDescription.text = ""
    }

    // MARK: - Image

    func getImage(metadata: tableMetadata) -> UIImage? {

        if let cachedImage = NCImageCache.shared.getMediaImage(ocId: metadata.ocId, etag: metadata.etag), case let .actual(image) = cachedImage {
            return image
        } else if FileManager().fileExists(atPath: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            if let image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                NCImageCache.shared.setMediaImage(ocId: metadata.ocId, etag: metadata.etag, image: .actual(image))
                return image
            }
        } else {
            if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && (!utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)) {
                if NCNetworking.shared.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
                    NCNetworking.shared.downloadThumbnailQueue.addOperation(NCMediaDownloadThumbnaill(metadata: metadata, collectionView: collectionView))
                }
            }
        }
        return nil
    }
}

// MARK: - Collection View

extension NCMedia: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if let metadata = self.metadatas?[indexPath.row] {
            if isEditMode {
                if let index = selectOcId.firstIndex(of: metadata.ocId) {
                    selectOcId.remove(at: index)
                } else {
                    selectOcId.append(metadata.ocId)
                }
                collectionView.reloadItems(at: [indexPath])
                mediaCommandView?.tabBarSelect?.selectCount = selectOcId.count
            } else {
                // ACTIVE SERVERURL
                appDelegate.activeServerUrl = metadata.serverUrl
                if let metadatas = self.metadatas?.getArray() {
                    NCViewer().view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: getImage(metadata: metadata))
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        guard let cell = collectionView.cellForItem(at: indexPath) as? NCGridMediaCell,
              let metadata = self.metadatas?[indexPath.row] else { return nil }
        let identifier = indexPath as NSCopying
        let image = cell.imageItem.image

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCContextMenu().viewMenu(ocId: metadata.ocId, indexPath: indexPath, viewController: self, image: image)
        })
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {

        animator.addCompletion {
            if let indexPath = configuration.identifier as? IndexPath {
                self.collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
    }
}

extension NCMedia: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // print("[LOG] n. " + String(indexPaths.count))
    }
}

extension NCMedia: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        var numberOfItemsInSection = 0

        if let metadatas {
            numberOfItemsInSection = metadatas.count
        }

        mediaCommandView?.setButtonsHidden(numberOfItemsInSection: numberOfItemsInSection)
        emptyDataSet?.numberOfItemsInSection(numberOfItemsInSection, section: section)

        return numberOfItemsInSection
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        guard let metadatas else { return }

        if !collectionView.indexPathsForVisibleItems.contains(indexPath) && indexPath.row < metadatas.count {
            guard let metadata = metadatas[indexPath.row] else { return }
            for case let operation as NCMediaDownloadThumbnaill in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
            for case let operation as NCOperationConvertLivePhoto in NCNetworking.shared.convertLivePhotoQueue.operations where operation.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridMediaCell,
              let metadatas = self.metadatas,
              let metadata = metadatas[indexPath.row] else { return UICollectionViewCell() }

        self.cellHeigth = cell.frame.size.height

        cell.date = metadata.date as Date
        cell.fileObjectId = metadata.ocId
        cell.indexPath = indexPath
        cell.fileUser = metadata.ownerId
        cell.imageStatus.image = nil

        if let image = getImage(metadata: metadata) {
            cell.imageItem.backgroundColor = nil
            cell.imageItem.image = image
        }

        // Convert OLD Live Photo
        if NCGlobal.shared.isLivePhotoServerAvailable, metadata.isLivePhoto, metadata.isNotFlaggedAsLivePhotoByServer {
            NCNetworking.shared.convertLivePhoto(metadata: metadata)
        }

        if metadata.isAudioOrVideo {
            cell.imageStatus.image = cacheImages.cellPlayImage
        } else if metadata.isLivePhoto {
            cell.imageStatus.image = cacheImages.cellLivePhotoImage
        } else {
            cell.imageStatus.image = nil
        }

        if isEditMode {
            cell.selectMode(true)
            if selectOcId.contains(metadata.ocId) {
                cell.selected(true)
            } else {
                cell.selected(false)
            }
        } else {
            cell.selectMode(false)
        }

        return cell
    }
}

// MARK: - ScrollView

extension NCMedia: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        let isTop = scrollView.contentOffset.y <= -(insetsTop + view.safeAreaInsets.top - 35)

        mediaCommandView?.setColor(isTop: isTop)

        if lastContentOffsetY == 0 || lastContentOffsetY + cellHeigth / 2 <= scrollView.contentOffset.y || lastContentOffsetY - cellHeigth / 2 >= scrollView.contentOffset.y {
            mediaCommandView?.setTitleDate()
            lastContentOffsetY = scrollView.contentOffset.y
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if !decelerate {
                timerSearchNewMedia?.invalidate()
                timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        let y = view.safeAreaInsets.top
        scrollView.contentOffset.y = -(insetsTop + y)
    }
}

// MARK: - NCSelect Delegate

extension NCMedia: NCSelectDelegate {

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], indexPath: [IndexPath], overwrite: Bool, copy: Bool, move: Bool) {

        guard let serverUrl = serverUrl else { return }
        let home = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        mediaPath = serverUrl.replacingOccurrences(of: home, with: "")
        NCManageDatabase.shared.setAccountMediaPath(mediaPath, account: appDelegate.account)
        reloadDataSource()
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(self.searchMediaUI), userInfo: nil, repeats: false)
    }
}
