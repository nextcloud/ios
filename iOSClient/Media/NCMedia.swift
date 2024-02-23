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
    var documentPickerViewController: NCDocumentPickerViewController?
    var tabBarSelect: NCMediaSelectTabBar?
    let refreshControl = UIRefreshControl()

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    var metadatas: ThreadSafeArray<tableMetadata>?
    var loadingTask: Task<Void, any Error>?

    var isEditMode = false
    var selectOcId: [String] = []

    var showOnlyImages = false
    var showOnlyVideos = false

    var lastContentOffsetY: CGFloat = 0
    var mediaPath = ""

    var timeIntervalSearchNewMedia: TimeInterval = 2.0
    var timerSearchNewMedia: Timer?
    let insetsTop: CGFloat = 75
    let maxImageGrid: CGFloat = 7

    struct cacheImages {
        static var cellLivePhotoImage = UIImage()
        static var cellPlayImage = UIImage()
        static var cellImage = UIImage()
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        collectionView.register(UINib(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: insetsTop, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            self.refreshControl.endRefreshing()
            self.collectionView.reloadData()
        }

        NCKeychain().mediaLayout = NCGlobal.shared.mediaLayoutDynamic
        selectLayout()
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

        tabBarSelect = NCMediaSelectTabBar(tabBarController: self.tabBarController, delegate: mediaCommandView)

        cacheImages.cellLivePhotoImage = utility.loadImage(named: "livephoto", color: .white)
        cacheImages.cellPlayImage = utility.loadImage(named: "play.fill", color: .white)

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() { self.mediaPath = activeAccount.mediaPath }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { _ in
            self.metadatas = nil
            self.collectionView.reloadData()
            DispatchQueue.main.async { self.reloadDataSource() }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillEnterForeground), object: nil, queue: nil) { _ in
            self.startTimer()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        navigationController?.setMediaAppreance()

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)

        startTimer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.mediaCommandView?.createMenu()

        if let metadatas = NCImageCache.shared.initialMetadatas() {
            self.metadatas = nil
            self.collectionView.reloadData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.metadatas = metadatas
                self.collectionView.reloadData()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if self.traitCollection.userInterfaceStyle == .dark {
            return .lightContent
        } else if let gradient = mediaCommandView?.gradient, gradient.isHidden {
            return .darkContent
        } else {
            return .lightContent
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let frame = tabBarController?.tabBar.frame {
            tabBarSelect?.hostingController.view.frame = frame
        }
    }

    func startTimer() {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)
    }

    // MARK: -

    func selectLayout() {
        let media = NCKeychain().mediaLayout

        if media == NCGlobal.shared.mediaLayoutDynamic {
            let layout = NCMediaDynamicLayout()
            layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
            layout.columSpacing = 2
            layout.rowSpacing = 2
            layout.delegate = self
            collectionView.collectionViewLayout = layout
        } else if media == NCGlobal.shared.mediaLayoutGrid {
            let layout = NCMediaGridLayout()
            layout.sectionHeadersPinToVisibleBounds = true
            collectionView.collectionViewLayout = layout
        }
    }

    // MARK: - NotificationCenter

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        DispatchQueue.global().async {
            self.reloadDataSource()
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
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
        if let image = NCImageCache.shared.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
            return image
        } else if FileManager().fileExists(atPath: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)),
                  let image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            NCImageCache.shared.setMediaImage(ocId: metadata.ocId, etag: metadata.etag, image: image)
            return image
        } else if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal,
                  (!utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)),
                  NCNetworking.shared.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
            NCNetworking.shared.downloadThumbnailQueue.addOperation(NCMediaDownloadThumbnaill(metadata: metadata, collectionView: collectionView))
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
                collectionView.reloadData()
                tabBarSelect?.selectCount = selectOcId.count
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

        if numberOfItemsInSection == 0 {
            mediaCommandView?.selectOrCancelButton.isHidden = true
            mediaCommandView?.menuButton.isHidden = false
            mediaCommandView?.activityIndicatorTrailing.constant = 50
        } else if isEditMode {
            mediaCommandView?.selectOrCancelButton.isHidden = false
            mediaCommandView?.menuButton.isHidden = true
            mediaCommandView?.activityIndicatorTrailing.constant = 150
        } else {
            mediaCommandView?.selectOrCancelButton.isHidden = false
            mediaCommandView?.menuButton.isHidden = false
            mediaCommandView?.activityIndicatorTrailing.constant = 150
        }

        emptyDataSet?.numberOfItemsInSection(numberOfItemsInSection, section: section)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.mediaCommandView?.setTitleDate() }

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

        cell.fileDate = metadata.date as Date
        cell.fileObjectId = metadata.ocId
        cell.indexPath = indexPath
        cell.fileUser = metadata.ownerId
        cell.imageStatus.image = nil
        cell.imageItem.contentMode = .scaleAspectFill

        if !metadata.hasPreview {
            cell.imageItem.backgroundColor = nil
            cell.imageItem.contentMode = .center
            var pointSize: CGFloat = 35
            if let layout = collectionView.collectionViewLayout as? NCMediaDynamicLayout {
                switch layout.itemForLine {
                case 0...1: pointSize = 60
                case 2...3: pointSize = 30
                case 4...5: pointSize = 20
                case 6...Int(maxImageGrid): pointSize = 10
                default: break
                }
            }
            let configuration = UIImage.SymbolConfiguration(pointSize: pointSize)
            if metadata.isImage {
                cell.imageItem.image = UIImage(systemName: "photo.fill", withConfiguration: configuration)?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal)
            } else {
                cell.imageItem.image = UIImage(systemName: "video.fill", withConfiguration: configuration)?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal)
            }
        } else if let image = getImage(metadata: metadata) {
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

        if isEditMode, selectOcId.contains(metadata.ocId) {
            cell.selected(true)
        } else {
            cell.selected(false)
        }

        return cell
    }
}

// MARK: -

extension NCMedia: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }
}

// MARK: -

extension NCMedia: NCMediaDynamicLayoutDelegate {
    func itemSize(_ collectionView: UICollectionView, indexPath: IndexPath, itemForLine: CGFloat) -> CGSize {
        var size = CGSize(width: collectionView.frame.width / itemForLine, height: collectionView.frame.width / itemForLine)
        guard let metadatas = self.metadatas,
              let metadata = metadatas[indexPath.row] else { return size }

        if metadata.imageSize != CGSize.zero {
            size = metadata.imageSize
        } else if let image = NCImageCache.shared.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
            size = image.size
        }
        return size
    }
}

// MARK: -

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let metadatas, !metadatas.isEmpty {
            let isTop = scrollView.contentOffset.y <= -(insetsTop + view.safeAreaInsets.top - 25)
            mediaCommandView?.setColor(isTop: isTop)
            setNeedsStatusBarAppearanceUpdate()
            if lastContentOffsetY == 0 || lastContentOffsetY / 2 <= scrollView.contentOffset.y || lastContentOffsetY / 2 >= scrollView.contentOffset.y {
                mediaCommandView?.setTitleDate()
                lastContentOffsetY = scrollView.contentOffset.y
            }
        } else {
            mediaCommandView?.setColor(isTop: true)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if !decelerate {
                startTimer()
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        startTimer()
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        let y = view.safeAreaInsets.top
        scrollView.contentOffset.y = -(insetsTop + y)
        // seems fix for recalculate the size of cell
        collectionView.reloadData()
    }
}

// MARK: -

extension NCMedia: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], indexPath: [IndexPath], overwrite: Bool, copy: Bool, move: Bool) {
        guard let serverUrl = serverUrl else { return }
        let home = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        mediaPath = serverUrl.replacingOccurrences(of: home, with: "")
        NCManageDatabase.shared.setAccountMediaPath(mediaPath, account: appDelegate.account)
        reloadDataSource()
        startTimer()
    }
}
