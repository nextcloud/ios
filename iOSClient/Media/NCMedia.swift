// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

class NCMedia: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!

    let layout = NCMediaLayout()
    let gradientLayer = CAGradientLayer()
    var layoutType = NCGlobal.shared.mediaLayoutRatio
    var documentPickerViewController: NCDocumentPickerViewController?
    var tabBarSelect: NCMediaSelectTabBar!
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let imageCache = NCImageCache.shared
    let networking = NCNetworking.shared
    var dataSource = NCMediaDataSource()
    var isEditMode = false
    var fileSelect: [String] = []
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    var showOnlyImages = false
    var showOnlyVideos = false
    var timeIntervalSearchNewMedia: TimeInterval = 2.0
    var timerSearchNewMedia: Timer?
    let livePhotoImage = NCUtility().loadImage(named: "livephoto", colors: [.white])
    let playImage = NCUtility().loadImage(named: "play.fill", colors: [.white])
    var photoImage = UIImage()
    var videoImage = UIImage()
    var pinchGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer()

    var lastScale: CGFloat = 1.0
    var currentScale: CGFloat = 1.0
    var maxColumns: Int {
        let screenWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let column = Int(screenWidth / 55)

        return column
    }
    var transitionColumns = false
    var lastNumberOfColumns: Int = 0
    var numberOfColumns: Int = 0 {
        didSet {
            guard oldValue > 0,
                  numberOfColumns != oldValue else {
                return
            }

            let oldExtension = global.getSizeExtension(column: oldValue)
            let newExtension = global.getSizeExtension(column: numberOfColumns)

            guard oldExtension != newExtension else {
                return
            }

            cacheWindowTask?.cancel()
            cacheWindowTask = nil
            lastCacheCenterIndex = nil

            imageCache.removeAll()
            missingImageCacheKeys.removeAll()
        }
    }
    let cacheWindowRadius = NCImageCache.shared.maximumCachedImages / 2
    let cacheWindowUpdateThreshold = NCImageCache.shared.maximumCachedImages / 6
    var lastCacheCenterIndex: Int?
    var cacheWindowTask: Task<Void, Never>?
    var missingImageCacheKeys: Set<String> = []
    struct ImageCacheWindowItem: Sendable {
        let ocId: String
        let etag: String
    }
    private func imageCacheKey(ocId: String, etag: String, ext: String) -> String {
        "\(ocId)-\(etag)-\(ext)"
    }

    let debouncerLoadDataSource = NCDebouncer(delay: .seconds(3), maxEventCount: 10)
    let debouncerSearch = NCDebouncer(delay: .seconds(2), maxEventCount: 10)

    struct CollectionViewScrollAnchor {
        let ocId: String
        let deltaX: CGFloat
        let deltaY: CGFloat
    }

    var searchMediaTask: Task<Void, Never>?
    var buildDataSourceTask: Task<Void, Never>?

    var searchMediaInProgress: Bool = false {
        didSet {
            guard oldValue != searchMediaInProgress else {
                return
            }

            updateLeftBarButtonItems(
                date: navigationItem.leftBarButtonItems?.first === buttonDateBarItem ? buttonDateBarItem : nil,
                activity: searchMediaInProgress
            )
        }
    }

    internal lazy var buttonDateBarItem = UIBarButtonItem(
        title: nil,
        style: .plain,
        target: self,
        action: #selector(presentMediaDatePicker)
    )

    internal lazy var searchActivityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()

    internal lazy var searchActivityBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(customView: searchActivityIndicator)
    }()

    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: tabBarController)
    }

    @MainActor
    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var isViewActived: Bool {
        return self.isViewLoaded && self.view.window != nil
    }

    var isPinchGestureActive: Bool {
        return pinchGesture.state == .began || pinchGesture.state == .changed
    }

    @MainActor
    var sceneIdentifier: String {
        (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier ?? ""
    }

    @MainActor
    internal var windowScene: UIWindowScene? {
       SceneManager.shared.getWindowScene(controller: self.tabBarController as? NCMainTabBarController)
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCMediaSectionHeader", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionHeader")
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: mediaSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.register(UINib(nibName: "NCMediaCell", bundle: nil), forCellWithReuseIdentifier: "mediaCell")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.accessibilityIdentifier = "NCMedia"
        // collectionView.contentInsetAdjustmentBehavior = .never

        layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
        collectionView.collectionViewLayout = layout
        layoutType = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "", layoutType: global.mediaLayoutRatio).layout

        // Gradient Layer
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 0, y: 1)

        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.55).cgColor,
            UIColor.black.withAlphaComponent(0.40).cgColor,
            UIColor.black.withAlphaComponent(0.25).cgColor,
            UIColor.black.withAlphaComponent(0.15).cgColor,
            UIColor.black.withAlphaComponent(0.08).cgColor,
            UIColor.black.withAlphaComponent(0.04).cgColor,
            UIColor.black.withAlphaComponent(0.015).cgColor,
            UIColor.clear.cgColor
        ]

        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.leftBarButtonItem = nil

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: global.notificationCenterChangeUser), object: nil, queue: nil) { [weak self] notification in
            guard let self else {
                return
            }
            Task { @MainActor in
                guard let userInfo = notification.userInfo,
                   let account = userInfo["account"] as? String else {
                    return
                }

                self.layoutType = self.database.getLayoutForView(account: account, key: self.global.layoutViewMedia, serverUrl: "").layout

                self.cacheWindowTask?.cancel()
                self.cacheWindowTask = nil
                self.lastCacheCenterIndex = nil
                self.imageCache.removeAll()
                self.missingImageCacheKeys.removeAll()

                await self.searchMediaUI(true)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: global.notificationCenterClearCache), object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.cacheWindowTask?.cancel()
                self.cacheWindowTask = nil
                self.lastCacheCenterIndex = nil
                self.imageCache.removeAll()
                self.missingImageCacheKeys.removeAll()

                self.dataSource.clearCompactMetadatas()
                await self.searchMediaUI(true)
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else {
                return
            }

            Task {
                await self.networkRemoveAll()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if tabBarSelect == nil {
            tabBarSelect = NCMediaSelectTabBar(
                controller: self.tabBarController,
                viewController: self,
                delegate: self
            )
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            await (self.navigationController as? NCMediaNavigationController)?
                .setNavigationRightItems()

            if #unavailable(iOS 26.0) {
                (self.navigationController as? NCMediaNavigationController)?
                    .updateRightBarButtonsTint(to: .white)
            }
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.networking.transferDispatcher.addDelegate(self)

            guard !Task.isCancelled else {
                return
            }

            await self.loadDataSource()

            guard !Task.isCancelled else {
                return
            }

            self.collectionView.layoutIfNeeded()
            self.setTitleDate()
            self.updateImageCacheWindow()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

        searchNewMedia()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        searchMediaTask?.cancel()
        searchMediaTask = nil

        buildDataSourceTask?.cancel()
        buildDataSourceTask = nil

        cacheWindowTask?.cancel()
        cacheWindowTask = nil
        lastCacheCenterIndex = nil

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.debouncerSearch.cancel()
            await self.debouncerLoadDataSource.cancel()

            await self.networking.transferDispatcher.removeDelegate(self)
            await self.networkRemoveAll()
        }

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    func searchNewMedia() {
        timerSearchNewMedia?.invalidate()

        timerSearchNewMedia = Timer.scheduledTimer(withTimeInterval: timeIntervalSearchNewMedia, repeats: false) { [weak self] _ in
            guard let self else {
                return
            }
            self.searchMediaTask?.cancel()
            self.searchMediaTask = Task { [weak self] in
                guard let self else {
                    return
                }
                await self.searchMediaUI()
            }
        }
    }

    // MARK: - NotificationCenter

    func networkRemoveAll() async {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = nil

        let tasks = await networking.getAllDataTask()
        for task in tasks.filter({ $0.taskDescription == global.taskDescriptionRetrievesProperties }) {
            task.cancel()
        }
    }

    @objc func enterForeground(_ notification: NSNotification) {
        searchNewMedia()
    }

    func buildMediaPhotoVideo(columnCount: Int) {
        var pointSize: CGFloat = 0

        switch columnCount {
        case 0...1: pointSize = 60
        case 2...3: pointSize = 30
        case 4...5: pointSize = 25
        default: pointSize = 20
        }
        if let image = UIImage(systemName: "photo.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal) {
            photoImage = image
        }
        if let image = UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal) {
            videoImage = image
        }
    }

    // MARK: - Image Cache

    @MainActor
    func updateImageCacheWindow() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems.sorted()

        guard !visibleIndexPaths.isEmpty else {
            return
        }

        let centerIndexPath = visibleIndexPaths[visibleIndexPaths.count / 2]
        guard let centerIndex = dataSource.globalIndex(for: centerIndexPath) else {
            return
        }

        if let lastCacheCenterIndex,
           abs(centerIndex - lastCacheCenterIndex) < cacheWindowUpdateThreshold {
            return
        }

        lastCacheCenterIndex = centerIndex

        cacheWindowTask?.cancel()

        cacheWindowTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadImageCacheWindow(around: centerIndex)
        }
    }

    @MainActor
    private func loadImageCacheWindow(around centerIndex: Int) async {
        let metadataCount = dataSource.compactMetadatas.count

        guard metadataCount > 0 else {
            return
        }

        let lowerBound = max(0, centerIndex - cacheWindowRadius)
        let upperBound = min(metadataCount, centerIndex + cacheWindowRadius + 1)
        let ext = global.getSizeExtension(column: numberOfColumns)
        let userId = session.userId
        let urlBase = session.urlBase

        let items = dataSource.compactMetadatas[lowerBound..<upperBound].map {
            ImageCacheWindowItem(ocId: $0.ocId, etag: $0.etag)
        }

        var cacheHits = 0
        var diskReads = 0
        var knownMissingImages = 0
        var newMissingImages = 0
        var loadedImages = 0

        print("[MEDIA CACHE] START center: \(centerIndex) range: \(lowerBound)..<\(upperBound) items: \(items.count) ext: \(ext)")

        for item in items {
            guard !Task.isCancelled else {
                print("[MEDIA CACHE] CANCELLED center: \(centerIndex) hits: \(cacheHits) diskReads: \(diskReads) knownMissing: \(knownMissingImages) newMissing: \(newMissingImages) loaded: \(loadedImages)")
                return
            }

            let key = imageCacheKey(ocId: item.ocId, etag: item.etag, ext: ext)

            if missingImageCacheKeys.contains(key) {
                knownMissingImages += 1
                continue
            }

            if imageCache.getImageCache(ocId: item.ocId, etag: item.etag, ext: ext) != nil {
                cacheHits += 1
                continue
            }

            diskReads += 1

            let image = await Task.detached(priority: .utility) {
                autoreleasepool {
                    NCUtility().getImage(
                        ocId: item.ocId,
                        etag: item.etag,
                        ext: ext,
                        userId: userId,
                        urlBase: urlBase
                    )
                }
            }.value

            guard !Task.isCancelled else {
                print("[MEDIA CACHE] CANCELLED center: \(centerIndex) hits: \(cacheHits) diskReads: \(diskReads) knownMissing: \(knownMissingImages) newMissing: \(newMissingImages) loaded: \(loadedImages)")
                return
            }

            guard let image else {
                missingImageCacheKeys.insert(key)
                newMissingImages += 1
                continue
            }

            imageCache.addImageCache(
                ocId: item.ocId,
                etag: item.etag,
                image: image,
                ext: ext
            )

            loadedImages += 1
        }

        print("[MEDIA CACHE] END center: \(centerIndex) hits: \(cacheHits) diskReads: \(diskReads) knownMissing: \(knownMissingImages) newMissing: \(newMissingImages) loaded: \(loadedImages)")
    }
}

// MARK: -

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        setTitleDate()

        if !dataSource.compactMetadatas.isEmpty {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        if !decelerate {
            updateImageCacheWindow()
            searchNewMedia()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateImageCacheWindow()
        searchNewMedia()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        lastCacheCenterIndex = nil
        updateImageCacheWindow()
    }
}

// MARK: -

extension NCMedia: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session, controller: NCMainTabBarController?) {
        guard let serverUrl else { return }

        Task {
            let home = utilityFileSystem.getHomeServer(session: session)
            let mediaPath = serverUrl.replacingOccurrences(of: home, with: "")

            await database.setAccountMediaPathAsync(mediaPath, account: session.account)

            self.imageCache.removeAll()
            self.missingImageCacheKeys.removeAll()

            await self.debouncerLoadDataSource.call {
                await self.loadDataSource()
            }
            searchNewMedia()
        }
    }
}
