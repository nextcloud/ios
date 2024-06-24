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

class NCMedia: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var titleDate: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorTrailing: NSLayoutConstraint!
    @IBOutlet weak var selectOrCancelButton: UIButton!
    @IBOutlet weak var selectOrCancelButtonTrailing: NSLayoutConstraint!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var gradientView: UIView!

    let layout = NCMediaLayout()
    var activeAccount = tableAccount()
    var documentPickerViewController: NCDocumentPickerViewController?
    var tabBarSelect: NCMediaSelectTabBar!
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let imageCache = NCImageCache.shared
    var metadatas: ThreadSafeArray<tableMetadata>?
    var serverUrl = ""
    let refreshControl = UIRefreshControl()
    var loadingTask: Task<Void, any Error>?
    let taskDescriptionRetrievesProperties = "retrievesProperties"
    var isTop: Bool = true
    var isEditMode = false
    var selectOcId: [String] = []
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    let gradient: CAGradientLayer = CAGradientLayer()
    var showOnlyImages = false
    var showOnlyVideos = false
    var lastContentOffsetY: CGFloat = 0
    var timeIntervalSearchNewMedia: TimeInterval = 2.0
    var timerSearchNewMedia: Timer?
    let insetsTop: CGFloat = 75
    let maxImageGrid: CGFloat = 7
    var livePhotoImage = UIImage()
    var playImage = UIImage()
    var photoImage = UIImage()
    var videoImage = UIImage()

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        collectionView.register(UINib(nibName: "NCSectionHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: collectionViewMediaElementKindSectionHeader, withReuseIdentifier: "sectionHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: insetsTop, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        // Drag & Drop
        // Drag & Drop
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
        layout.mediaViewController = self
        collectionView.collectionViewLayout = layout

        tabBarSelect = NCMediaSelectTabBar(tabBarController: self.tabBarController, delegate: self)

        livePhotoImage = utility.loadImage(named: "livephoto", colors: [.white])
        playImage = utility.loadImage(named: "play.fill", colors: [.white])

        titleDate.text = ""

        selectOrCancelButton.backgroundColor = .clear
        selectOrCancelButton.layer.cornerRadius = 15
        selectOrCancelButton.layer.masksToBounds = true
        selectOrCancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
        selectOrCancelButton.addBlur(style: .systemThinMaterial)

        menuButton.backgroundColor = .clear
        menuButton.layer.cornerRadius = 15
        menuButton.layer.masksToBounds = true
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.configuration = UIButton.Configuration.plain()
        menuButton.setImage(NCUtility().loadImage(named: "ellipsis"), for: .normal)
        menuButton.changesSelectionAsPrimaryAction = false
        menuButton.addBlur(style: .systemThinMaterial)

        gradient.startPoint = CGPoint(x: 0, y: 0.1)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]
        gradientView.layer.insertSublayer(gradient, at: 0)

        activeAccount = NCManageDatabase.shared.getActiveAccount() ?? tableAccount()

        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            DispatchQueue.global(qos: .userInteractive).async {
                self.reloadDataSource()
            }
            self.refreshControl.endRefreshing()
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { _ in
            self.activeAccount = NCManageDatabase.shared.getActiveAccount() ?? tableAccount()
            if let metadatas = self.metadatas,
               let metadata = metadatas.first {
                if metadata.account != self.activeAccount.account {
                    self.metadatas = nil
                    self.collectionViewReloadData()
                }
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateMediaCacheEnded), object: nil, queue: nil) { _ in
            if let metadatas = self.imageCache.initialMetadatas() {
                self.metadatas = metadatas
            }
            self.collectionViewReloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setMediaAppreance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        startTimer()
        createMenu()

        if imageCache.createMediaCacheInProgress {
            self.metadatas = nil
            self.collectionViewReloadData()
        } else if let metadatas = imageCache.initialMetadatas() {
            self.metadatas = metadatas
            self.collectionViewReloadData()
        } else {
            DispatchQueue.global(qos: .userInteractive).async {
                self.reloadDataSource()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        // Cancel Queue & Retrieves Properties
        NCNetworking.shared.downloadThumbnailQueue.cancelAll()
        NextcloudKit.shared.sessionManager.session.getTasksWithCompletionHandler { dataTasks, _, _ in
            dataTasks.forEach {
                if $0.taskDescription == self.taskDescriptionRetrievesProperties {
                    $0.cancel()
                }
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.setTitleDate()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if self.traitCollection.userInterfaceStyle == .dark {
            return .lightContent
       } else if isTop {
            return .darkContent
        } else {
            return .lightContent
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let frame = tabBarController?.tabBar.frame {
            tabBarSelect.hostingController.view.frame = frame
        }
        gradient.frame = gradientView.bounds
    }

    func startTimer() {
        // don't start if media chage is in progress
        if imageCache.createMediaCacheInProgress {
            return
        }
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)
    }

    // MARK: - NotificationCenter

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        self.reloadDataSource()
        if error != .success {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func enterForeground(_ notification: NSNotification) {
        startTimer()
    }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String else { return }

        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
           (metadata.isVideo || metadata.isImage) {
            self.reloadDataSource()
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let dragDrop = userInfo["dragdrop"] as? Bool, dragDrop else { return }

        setEditMode(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.reloadDataSource()
            self.searchMediaUI()
        }
    }

    @objc func copyFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let dragDrop = userInfo["dragdrop"] as? Bool, dragDrop else { return }

        setEditMode(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.reloadDataSource()
            self.searchMediaUI()
        }
    }

    // MARK: - Image

    func getImage(metadata: tableMetadata) -> UIImage? {
        let fileNamePathPreview = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)

        if let image = imageCache.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
            return image
        } else if FileManager().fileExists(atPath: fileNamePathPreview), let image = UIImage(contentsOfFile: fileNamePathPreview) {
            return image
        } else if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal,
                  (!utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)),
                  NCNetworking.shared.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
            NCNetworking.shared.downloadThumbnailQueue.addOperation(NCMediaDownloadThumbnaill(metadata: metadata, media: self))
        }
        return nil
    }

    func buildMediaPhotoVideo(columnCount: Int) {
        var pointSize: CGFloat = 0

        switch columnCount {
        case 0...1: pointSize = 60
        case 2...3: pointSize = 30
        case 4...5: pointSize = 25
        case 6...Int(maxImageGrid): pointSize = 20
        default: pointSize = 20
        }
        if let image = UIImage(systemName: "photo.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal) {
            photoImage = image
        }
        if let image = UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal) {
            videoImage = image
        }
    }
}

// MARK: - Collection View

extension NCMedia: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var mediaCell: NCGridMediaCell?
        if let metadata = self.metadatas?[indexPath.row] {
            if let visibleCells = self.collectionView?.indexPathsForVisibleItems.compactMap({ self.collectionView?.cellForItem(at: $0) }) {
                for case let cell as NCGridMediaCell in visibleCells {
                    if cell.ocId == metadata.ocId {
                        mediaCell = cell
                    }
                }
            }
            if isEditMode {
                if let index = selectOcId.firstIndex(of: metadata.ocId) {
                    selectOcId.remove(at: index)
                    mediaCell?.selected(false)
                } else {
                    selectOcId.append(metadata.ocId)
                    mediaCell?.selected(true)

                }
                tabBarSelect.selectCount = selectOcId.count
            } else {
                // ACTIVE SERVERURL
                serverUrl = metadata.serverUrl
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
        self.serverUrl = metadata.serverUrl

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCContextMenu().viewMenu(ocId: metadata.ocId, viewController: self, image: image)
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
        // print("[INFO] n. " + String(indexPaths.count))
    }
}

extension NCMedia: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == "collectionViewMediaElementKindSectionHeader" {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderEmptyData", for: indexPath) as? NCSectionHeaderEmptyData else { return NCSectionHeaderEmptyData() }
            header.emptyImage.image = utility.loadImage(named: "photo", colors: [NCBrandColor.shared.brandElement])
            if loadingTask != nil || imageCache.createMediaCacheInProgress {
                header.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
            } else {
                header.emptyTitle.text = NSLocalizedString("_tutorial_photo_view_", comment: "")
            }
            header.emptyDescription.text = ""
            return header
        }
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var numberOfItemsInSection = 0
        if let metadatas { numberOfItemsInSection = metadatas.count }
        if numberOfItemsInSection == 0 {
            selectOrCancelButton.isHidden = true
            menuButton.isHidden = false
            gradientView.isHidden = true
            activityIndicatorTrailing.constant = 50
        } else if isEditMode {
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = true
            activityIndicatorTrailing.constant = 150
        } else {
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = false
            activityIndicatorTrailing.constant = 150
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.setTitleDate() }
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
              let metadata = metadatas[indexPath.row]
        else {
            return NCGridMediaCell()
        }

        cell.date = metadata.date as Date
        cell.ocId = metadata.ocId
        cell.indexPath = indexPath
        cell.user = metadata.ownerId
        cell.imageStatus.image = nil
        cell.imageItem.contentMode = .scaleAspectFill

        if let image = getImage(metadata: metadata) {
            cell.imageItem.image = image
        } else if !metadata.hasPreview {
            cell.imageItem.backgroundColor = .clear
            cell.imageItem.contentMode = .center
            if metadata.isImage {
                cell.imageItem.image = photoImage
            } else {
                cell.imageItem.image = videoImage
            }
        }

        // Convert OLD Live Photo
        if NCGlobal.shared.isLivePhotoServerAvailable, metadata.isLivePhoto, metadata.isNotFlaggedAsLivePhotoByServer {
            NCNetworking.shared.convertLivePhoto(metadata: metadata)
        }

        if metadata.isAudioOrVideo {
           cell.imageStatus.image = playImage
        } else if metadata.isLivePhoto {
            cell.imageStatus.image = livePhotoImage
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

extension NCMedia: NCMediaLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForHeaderInSection section: Int) -> Float {
        var height: Double = 0
        if metadatas?.count ?? 0 == 0 {
            height = NCGlobal.shared.getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: -20)
        }
        return Float(height)
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForFooterInSection section: Int) -> Float {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSection section: Int) -> UIEdgeInsets {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForHeaderInSection section: Int) -> UIEdgeInsets {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForFooterInSection section: Int) -> UIEdgeInsets {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, minimumInteritemSpacingForSection section: Int) -> Float {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath, columnCount: Int, mediaLayout: String) -> CGSize {
        let size = CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        if mediaLayout == NCGlobal.shared.mediaLayoutRatio {
            guard let metadatas = self.metadatas,
                  let metadata = metadatas[indexPath.row] else { return size }

            if metadata.imageSize != CGSize.zero {
                return metadata.imageSize
            } else if let size = imageCache.getMediaSize(ocId: metadata.ocId, etag: metadata.etag) {
                return size
            }
        }
        return size
    }
}

// MARK: -

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let metadatas, !metadatas.isEmpty {
            isTop = scrollView.contentOffset.y <= -(insetsTop + view.safeAreaInsets.top - 25)
            setColor()
            setNeedsStatusBarAppearanceUpdate()
            if lastContentOffsetY == 0 || lastContentOffsetY / 2 <= scrollView.contentOffset.y || lastContentOffsetY / 2 >= scrollView.contentOffset.y {
                setTitleDate()
                lastContentOffsetY = scrollView.contentOffset.y
            }
        } else {
            setColor()
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
    }
}

// MARK: -

extension NCMedia: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
        guard let serverUrl = serverUrl else { return }
        let home = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        let mediaPath = serverUrl.replacingOccurrences(of: home, with: "")
        NCManageDatabase.shared.setAccountMediaPath(mediaPath, account: activeAccount.account)
        activeAccount = NCManageDatabase.shared.getActiveAccount() ?? tableAccount()
        reloadDataSource()
        startTimer()
    }
}
