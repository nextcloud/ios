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
    @IBOutlet weak var fileActionsHeader: FileActionsHeader?

    let layout = NCMediaLayout()
    var layoutType = NCGlobal.shared.mediaLayoutRatio
    var activeAccount = tableAccount()
    var documentPickerViewController: NCDocumentPickerViewController?
    var tabBarSelect: NCCollectionViewCommonSelectToolbar!
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
    let maxImageGrid: CGFloat = 7
    var livePhotoImage = UIImage()
    var playImage = UIImage()
    var photoImage = UIImage()
    var videoImage = UIImage()
    var accountButtonFactory: AccountButtonFactory!

    var selectionState: FileActionsHeaderSelectionState {
        let selectedItemsCount = selectOcId.count
        if selectedItemsCount == metadatas?.count {
            return .all
        }
        
        return selectedItemsCount == 0 ? .none : .some(selectedItemsCount)
    }
    
    private var appBackground: UIColor? {
        UIColor(named: "AppBackground")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = appBackground
        collectionView.backgroundColor = appBackground
        activeAccount = NCManageDatabase.shared.getActiveAccount() ?? tableAccount()

        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
        collectionView.collectionViewLayout = layout
        layoutType = NCManageDatabase.shared.getLayoutForView(account: activeAccount.account, key: NCGlobal.shared.layoutViewMedia, serverUrl: "")?.layout ?? NCGlobal.shared.mediaLayoutRatio

        tabBarSelect = NCCollectionViewCommonSelectToolbar(delegate: self, displayedButtons: [.delete])

        livePhotoImage = utility.loadImage(named: "livephoto", colors: [.white])
        playImage = utility.loadImage(named: "play.fill", colors: [.white])

        gradient.startPoint = CGPoint(x: 0, y: 0.1)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]

        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            DispatchQueue.global(qos: .userInteractive).async {
                self.reloadDataSource()
            }
            self.refreshControl.endRefreshing()
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { _ in
            self.activeAccount = NCManageDatabase.shared.getActiveAccount() ?? tableAccount()
            self.layoutType = NCManageDatabase.shared.getLayoutForView(account: self.activeAccount.account, key: NCGlobal.shared.layoutViewMedia, serverUrl: "")?.layout ?? NCGlobal.shared.mediaLayoutRatio
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
        
        accountButtonFactory = AccountButtonFactory(onAccountDetailsOpen: { [weak self] in self?.setEditMode(false) },
                                                          presentVC: { [weak self] vc in self?.present(vc, animated: true) })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarAppearance()
        navigationItem.largeTitleDisplayMode = .never
        
        setNavigationRightItems()
        setNavigationLeftItems()
        updateHeadersView()
        
        if self.navigationController?.viewControllers.count == 1 {
            let logo = UIImage(resource: .ionosEasyStorageLogo).withTintColor(UIColor(resource: .NavigationBar.logoTint))
            navigationItem.titleView = UIImageView(image: logo)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        startTimer()

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
            tabBarSelect.hostingController?.view.frame = frame
        }
    }

    func startTimer() {
        // don't start if media chage is in progress
        if imageCache.createMediaCacheInProgress {
            return
        }
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI), userInfo: nil, repeats: false)
    }
    
    func updateHeadersView() {
        fileActionsHeader?.showViewModeButton(false)
        fileActionsHeader?.setIsEditingMode(isEditingMode: isEditMode)
        updateHeadersMenu()
        fileActionsHeader?.onSelectModeChange = { [weak self] isSelectionMode in
            self?.setEditMode(isSelectionMode)
            self?.updateHeadersView()
            self?.fileActionsHeader?.setSelectionState(selectionState: .none)
        }
        
        fileActionsHeader?.onSelectAll = { [weak self] in
            guard let self = self else { return }
            self.selectAllOrDeselectAll()
            tabBarSelect.update(selectOcId: selectOcId)
            self.fileActionsHeader?.setSelectionState(selectionState: selectionState)
        }
    }
    
    func selectAllOrDeselectAll() {
        guard let metadatas = self.metadatas else {return}
        if !selectOcId.isEmpty, metadatas.count == selectOcId.count {
            selectOcId = []
        } else {
            selectOcId = metadatas.compactMap({ $0.ocId })
        }
        collectionView.reloadData()
    }
    
    func updateHeadersMenu() {
        fileActionsHeader?.setSortingMenu(sortingMenuElements: createMenuElements(), title: NSLocalizedString("_media_options_", tableName: nil, bundle: Bundle.main, value: "Media Options", comment: ""), image: nil)
    }
    
    func setNavigationLeftItems() {
        if isEditMode {
            navigationItem.setLeftBarButtonItems(nil, animated: true)
            return
        }
        let burgerMenuItem = UIBarButtonItem(image: UIImage(resource: .BurgerMenu.bars),
                                             style: .plain,
                                             action: { [weak self] in
            self?.showBurgerMenu()
        })
        burgerMenuItem.tintColor = UIColor(resource: .BurgerMenu.navigationBarButton)
        navigationItem.setLeftBarButtonItems([burgerMenuItem], animated: true)
    }
    
    func showBurgerMenu() {
        self.mainTabBarController?.showBurgerMenu()
    }
    
    func setNavigationRightItems() {
        navigationItem.rightBarButtonItems = [createAccountButton()]
    }
    
    private func createAccountButton() -> UIBarButtonItem {
        accountButtonFactory.createAccountButton()
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

        if let image = imageCache.getPreviewImageCache(ocId: metadata.ocId, etag: metadata.etag) {
            return image
        } else if FileManager().fileExists(atPath: fileNamePathPreview), let image = UIImage(contentsOfFile: fileNamePathPreview) {
            imageCache.addPreviewImageCache(metadata: metadata, image: image)
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

extension NCMedia: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // print("[INFO] n. " + String(indexPaths.count))
    }
}

// MARK: -

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let metadatas, !metadatas.isEmpty {
            isTop = scrollView.contentOffset.y <= -(view.safeAreaInsets.top - 25)
            setNeedsStatusBarAppearanceUpdate()
            if lastContentOffsetY == 0 || lastContentOffsetY / 2 <= scrollView.contentOffset.y || lastContentOffsetY / 2 >= scrollView.contentOffset.y {
                lastContentOffsetY = scrollView.contentOffset.y
            }
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
