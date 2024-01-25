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

class NCMedia: UIViewController, NCEmptyDataSetDelegate, NCSelectDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    var emptyDataSet: NCEmptyDataSet?
    var mediaCommandView: NCMediaCommandView?
    var gridLayout: NCGridMediaLayout!
    var documentPickerViewController: NCDocumentPickerViewController?

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    @ThreadSafe internal var metadatas: Results<tableMetadata>?
    var isEditMode = false
    var selectOcId: [String] = []
    var selectIndexPath: [IndexPath] = []

    var showOnlyImages = false
    var showOnlyVideos = false

    let maxImageGrid: CGFloat = 7
    var cellHeigth: CGFloat = 0

    var loadingTask: Task<Void, any Error>?

    var lastContentOffsetY: CGFloat = 0
    var mediaPath = ""

    var timeIntervalSearchNewMedia: TimeInterval = 3.0
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

        collectionView.register(UINib(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: insetsTop, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground

        gridLayout = NCGridMediaLayout()
        gridLayout.itemForLine = CGFloat(NCKeychain().mediaWidthImage)
        gridLayout.sectionHeadersPinToVisibleBounds = true

        collectionView.collectionViewLayout = gridLayout

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: 0, delegate: self)

        mediaCommandView = Bundle.main.loadNibNamed("NCMediaCommandView", owner: self, options: nil)?.first as? NCMediaCommandView
        self.view.addSubview(mediaCommandView!)
        mediaCommandView?.mediaView = self
        mediaCommandView?.translatesAutoresizingMaskIntoConstraints = false
        mediaCommandView?.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        mediaCommandView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        mediaCommandView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        mediaCommandView?.heightAnchor.constraint(equalToConstant: 150).isActive = true
        self.updateMediaControlVisibility()

        collectionView.prefetchDataSource = self

        cacheImages.cellLivePhotoImage = utility.loadImage(named: "livephoto", color: .white)
        cacheImages.cellPlayImage = utility.loadImage(named: "play.fill", color: .white)

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() { self.mediaPath = activeAccount.mediaPath }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        navigationController?.setMediaAppreance()

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        if let metadatas = NCImageCache.shared.initialMetadatas() {
            self.metadatas = metadatas
        }
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)

        collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        mediaCommandTitle()
        mediaCommandView?.createMenu()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        collectionView?.collectionViewLayout.invalidateLayout()
        mediaCommandTitle()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
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

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error == .success,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        self.reloadDataSource()
    }

    // MARK: - Command

    func updateMediaControlVisibility() {

        if let metadatas, metadatas.isEmpty {
            mediaCommandView?.toggleEmptyView(isEmpty: true)
            mediaCommandView?.isHidden = false
        } else {
            mediaCommandView?.toggleEmptyView(isEmpty: false)
            mediaCommandView?.isHidden = false
        }
    }

    func mediaCommandTitle() {

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mediaCommandView?.title.text = ""
            if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }) {
                if let cell = visibleCells.first as? NCGridMediaCell {
                    self.mediaCommandView?.title.text = ""
                    if let date = cell.date {
                        self.mediaCommandView?.title.text = self.utility.getTitleFromDate(date)
                    }
                }
            }
        }
    }

    // MARK: Select Path

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], indexPath: [IndexPath], overwrite: Bool, copy: Bool, move: Bool) {

        guard let serverUrl = serverUrl else { return }
        let home = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        mediaPath = serverUrl.replacingOccurrences(of: home, with: "")
        NCManageDatabase.shared.setAccountMediaPath(mediaPath, account: appDelegate.account)
        reloadDataSource()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(self.searchMediaUI), userInfo: nil, repeats: false)
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
}

// MARK: - Collection View

extension NCMedia: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if let metadata = self.metadatas?[indexPath.row] {
            if isEditMode {
                if let index = selectOcId.firstIndex(of: metadata.ocId) {
                    selectOcId.remove(at: index)
                    selectIndexPath.removeAll(where: { $0 == indexPath })
                } else {
                    selectOcId.append(metadata.ocId)
                    selectIndexPath.append(indexPath)
                }
                if indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) {
                    collectionView.reloadItems(at: [indexPath])
                }
            } else if let metadatas = self.metadatas {
                // ACTIVE SERVERURL
                appDelegate.activeServerUrl = metadata.serverUrl
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridMediaCell
                let arrayMetadatas = Array(metadatas.map { tableMetadata.init(value: $0) })
                NCViewer().view(viewController: self, metadata: metadata, metadatas: arrayMetadatas, imageIcon: cell?.imageItem.image)
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
        emptyDataSet?.numberOfItemsInSection(numberOfItemsInSection, section: section)
        return numberOfItemsInSection
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadatas else { return }
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) && indexPath.row < metadatas.count {
            let metadata = metadatas[indexPath.row]
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
              let metadatas = self.metadatas else { return UICollectionViewCell() }

        if indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) && indexPath.row < metadatas.count {

            let metadata = metadatas[indexPath.row]

            self.cellHeigth = cell.frame.size.height

            cell.date = metadata.date as Date
            cell.fileObjectId = metadata.ocId
            cell.indexPath = indexPath
            cell.fileUser = metadata.ownerId

            if let cachedImage = NCImageCache.shared.getMediaImage(ocId: metadata.ocId, etag: metadata.etag), case let .actual(image) = cachedImage {
                cell.imageItem.backgroundColor = nil
                cell.imageItem.image = image
            } else if FileManager().fileExists(atPath: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                if let image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                    cell.imageItem.backgroundColor = nil
                    cell.imageItem.image = image
                    NCImageCache.shared.setMediaImage(ocId: metadata.ocId, etag: metadata.etag, image: .actual(image))
                }
            } else {
                if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && (!utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)) {
                    if NCNetworking.shared.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
                        NCNetworking.shared.downloadThumbnailQueue.addOperation(NCMediaDownloadThumbnaill(metadata: metadata, collectionView: collectionView))
                    }
                }
                cell.imageStatus.image = nil
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

        } else {

            return cell
        }
    }
}

extension NCMedia: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }
}

// MARK: - ScrollView

extension NCMedia: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if lastContentOffsetY == 0 || lastContentOffsetY + cellHeigth / 2 <= scrollView.contentOffset.y || lastContentOffsetY - cellHeigth / 2 >= scrollView.contentOffset.y {
            mediaCommandTitle()
            lastContentOffsetY = scrollView.contentOffset.y
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if !decelerate {
                timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        let y = view.safeAreaInsets.top
        scrollView.contentOffset.y = -(insetsTop + y)
    }
}

// MARK: - Media Grid Layout

class NCGridMediaLayout: UICollectionViewFlowLayout {

    var marginLeftRight: CGFloat = 2
    var itemForLine: CGFloat = 3

    override init() {
        super.init()

        sectionHeadersPinToVisibleBounds = false

        minimumInteritemSpacing = 0
        minimumLineSpacing = marginLeftRight

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: marginLeftRight, bottom: 0, right: marginLeftRight)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {

                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth

                return CGSize(width: itemWidth, height: itemHeight)
            }

            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
