// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

protocol NCMediaSelectionDelegate: AnyObject {
    func didUpdateSelection(files: [String])
}

class NCMedia: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var titleDate: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var titleConstraint: NSLayoutConstraint!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var gradientViewHeightContsraint: NSLayoutConstraint!

    // Called when initial media data has finished loading
    var onInitialLoadCompleted: (() -> Void)?

    let semaphoreSearchMedia = DispatchSemaphore(value: 1)
    let semaphoreNotificationCenter = DispatchSemaphore(value: 1)

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
    let refreshControl = UIRefreshControl()
    var isTop: Bool = true
    var isEditMode = false
//    var fileSelect: [String] = []
    // 1. Add this property here (NOT in an extension)
    weak var selectionDelegate: NCMediaSelectionDelegate?

    // 2. Find your existing fileSelect array and add the didSet
    var fileSelect: [String] = [] {
        didSet {
            selectionDelegate?.didUpdateSelection(files: fileSelect)
        }
    }
    var filesExists: ThreadSafeArray<String> = ThreadSafeArray()
    var ocIdDoNotExists: ThreadSafeArray<String> = ThreadSafeArray()
    var searchMediaInProgress: Bool = false
    // Tracks whether we have completed an explicit preload before presentation
    private var didCompleteInitialPreload = false
    private var explicitPreloadTask: Task<Void, Never>?

    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    var showOnlyImages = false
    var showOnlyVideos = false
    var timeIntervalSearchNewMedia: TimeInterval = 2.0
    var timerSearchNewMedia: Timer?
    let insetsTop: CGFloat = 0//75//65
    let livePhotoImage = NCUtility().loadImage(named: "livephoto", colors: [.white])
    let playImage = NCUtility().loadImage(named: "play.fill", colors: [.white])
    var photoImage = UIImage()
    var videoImage = UIImage()
    var pinchGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer()
    var metadatas: ThreadSafeArray<tableMetadata>?

    var lastScale: CGFloat = 1.0
    var currentScale: CGFloat = 1.0
    var maxColumns: Int {
        let screenWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let column = Int(screenWidth / 44)

        return column
    }
    var transitionColumns = false
    var numberOfColumns: Int = 0
    var lastNumberOfColumns: Int = 0
    var loadingTask: Task<Void, any Error>?
    var mediaCommandView: NCMediaCommandView?
    var activeAccount = tableAccount()
    var lastContentOffsetY: CGFloat = 0
    let maxImageGrid: CGFloat = 7
    var hiddenCellMetadats: ThreadSafeArray<String> = ThreadSafeArray()

    var isInGeneralPhotosSelectionContext: Bool = false

    let debouncerLoadDataSource = NCDebouncer(maxEventCount: 10)
    let debouncerSearch = NCDebouncer(maxEventCount: 10)

    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: tabBarController)
    }

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var isViewActived: Bool {
        return self.isViewLoaded && self.view.window != nil
    }

    var isPinchGestureActive: Bool {
        return pinchGesture.state == .began || pinchGesture.state == .changed
    }

    var sceneIdentifier: String {
        (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier ?? ""
    }

//    var isInGeneralPhotosSelectionContext: Bool = false

    // MARK: - Programmatic Preload API
    /// Preloads the media data (data source and initial search) so that the controller is ready when presented.
    /// Safe to call while the media tab hasn't been opened yet. Idempotent across multiple calls.
    @MainActor
    func preloadIfNeeded() {
        // Avoid re-running if already completed
        if didCompleteInitialPreload { return }
        // Cancel any previous explicit preload
        explicitPreloadTask?.cancel()
        explicitPreloadTask = Task { [weak self] in
            guard let self else { return }
            // Ensure view is loaded to set up collectionView/layout safely
            _ = self.view
            // Run the same loading sequence used in view lifecycle, but explicitly
            await self.loadDataSource()
            await self.searchMediaUI(true)
            self.didCompleteInitialPreload = true
            await MainActor.run {
                self.onInitialLoadCompleted?()
            }
        }
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarAppearance()

        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: mediaSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.register(UINib(nibName: "NCMediaCell", bundle: nil), forCellWithReuseIdentifier: "mediaCell")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        collectionView.contentInset = isInGeneralPhotosSelectionContext ? UIEdgeInsets(top: 10, left: 0, bottom: 50, right: 0) : UIEdgeInsets(top: insetsTop, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.accessibilityIdentifier = "NCMedia"
        // collectionView.contentInsetAdjustmentBehavior = .never

        layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
        collectionView.collectionViewLayout = layout
        layoutType = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "", layout: global.mediaLayoutRatio).layout

//        tabBarSelect = NCMediaSelectTabBar(controller: self.tabBarController, viewController: self, delegate: self)

        titleDate.text = ""
        titleDate.isHidden = true

        isEditMode = isInGeneralPhotosSelectionContext ? true : false

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

        gradientLayer.locations = [0.0, 0.20, 0.40, 0.60, 0.75, 0.85, 0.95, 1.0]
        gradientView.layer.insertSublayer(gradientLayer, at: 0)

        activeAccount = NCManageDatabase.shared.getActiveTableAccount() ?? tableAccount()

        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            DispatchQueue.global().async {
                Task {
                    await self.loadDataSource()
                    await self.searchMediaUI(true)
                }
            }
            self.refreshControl.endRefreshing()
        }

        // Title + Activity indicator
        if UIDevice.current.userInterfaceIdiom == .pad {
            titleConstraint.constant = 0
        } else {
            if #available(iOS 26.0, *) {
                titleConstraint.constant = -44
            } else {
                titleConstraint.constant = -34
            }
        }

        titleDate.text = ""
        titleDate?.textColor = .white
        activityIndicator.color = .white

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: global.notificationCenterChangeUser), object: nil, queue: nil) { notification in
            Task { @MainActor in
                guard let userInfo = notification.userInfo,
                   let account = userInfo["account"] as? String else {
                    return
                }

                self.layoutType = self.database.getLayoutForView(account: account, key: self.global.layoutViewMedia, serverUrl: "").layout
                self.imageCache.removeAll()
                await self.loadDataSource()
                await self.searchMediaUI(true)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: global.notificationCenterClearCache), object: nil, queue: nil) { _ in
            Task {
                await self.dataSource.clearMetadatas()
                self.imageCache.removeAll()
                await self.searchMediaUI(true)
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(fileExists(_:)), name: NSNotification.Name(rawValue: global.notificationCenterFileExists), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterDeleteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: global.notificationCenterReloadDataSource), object: nil)

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            Task {
                await self.networkRemoveAll()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if tabBarSelect == nil {
            tabBarSelect = NCMediaSelectTabBar(controller: self.tabBarController, viewController: self, delegate: self)
        }
//        navigationController?.setMediaAppreance()

        Task {
            await (self.navigationController as? NCMediaNavigationController)?.setNavigationRightItems()
            if #unavailable(iOS 26.0) {
                (self.navigationController as? NCMediaNavigationController)?.updateRightBarButtonsTint(to: .white)
            }
        }

        if dataSource.metadatas.isEmpty {
            Task {
                await loadDataSource()
            }
        }
        Task {
            if !self.didCompleteInitialPreload {
                await self.loadDataSource()
                await self.searchMediaUI(true)
            }
        }
        AnalyticsHelper.shared.trackEvent(eventName: .SCREEN_EVENT__MEDIA)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Re-evaluate in-app messages after viewDidAppear
        MoEngageAnalytics.shared.displayInAppNotificationSafely(reason: "viewDidAppear")

        Task {
            await networking.transferDispatcher.addDelegate(self)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(copyMoveFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterCopyMoveFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

        if !didCompleteInitialPreload {
            onInitialLoadCompleted?()
        }

        searchNewMedia()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        Task {
            await networking.transferDispatcher.removeDelegate(self)
            await networkRemoveAll()
        }

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterCopyMoveFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

//        if let frame = tabBarController?.tabBar.frame {
//            tabBarSelect.hostingController?.view.frame = frame
//        }
        gradientLayer.frame = gradientView.bounds
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

    func searchNewMedia() {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(withTimeInterval: timeIntervalSearchNewMedia, repeats: false) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                await self.searchMediaUI()
            }
        }
    }

    // MARK: - NotificationCenter

    func networkRemoveAll() async {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = nil
        filesExists.removeAll()

        NCNetworking.shared.fileExistsQueue.cancelAll()
        networking.downloadThumbnailQueue.cancelAll()

        let tasks = await networking.getAllDataTask()
        for task in tasks.filter({ $0.taskDescription == global.taskDescriptionRetrievesProperties }) {
            task.cancel()
        }
    }

    @objc func reloadDataSource(_ notification: NSNotification) {
        Task {
            await self.loadDataSource()
        }
    }

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError
        else {
            return
        }

        // This is only a fail safe "dead lock", I don't think the timeout will ever be called but at least nothing gets stuck, if after 5 sec. (which is a long time in this routine), the semaphore is still locked
        //
//        if self.semaphoreNotificationCenter.wait(timeout: .now() + 5) == .timedOut {
//            self.semaphoreNotificationCenter.signal()
//        }

        if error.errorCode == self.global.errorResourceNotFound,
           let ocIds = userInfo["ocId"] as? [String],
           let ocId = ocIds.first {
            Task {
                await NCManageDatabase.shared.deleteMetadataAsync(ocId: ocId)
                await self.loadDataSource()
//                {
//                    self.semaphoreNotificationCenter.signal()
//                }
            }
        } else if error != .success {
            Task {
                await self.loadDataSource()
            }
//            self.loadDataSource {
//                self.semaphoreNotificationCenter.signal()
//            }
        } else {
//            semaphoreNotificationCenter.signal()
        }
    }

    @objc func enterForeground(_ notification: NSNotification) {
        searchNewMedia()
    }

    @objc func fileExists(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let fileExists = userInfo["fileExists"] as? Bool
        else {
            return
        }

        filesExists.append(ocId)
        if !fileExists {
            ocIdDoNotExists.append(ocId)
        }

        if NCNetworking.shared.fileExistsQueue.operationCount == 0,
           !ocIdDoNotExists.isEmpty,
           let ocIdDoNotExists = self.ocIdDoNotExists.getArray() {
            dataSource.removeMetadata(ocIdDoNotExists)
            database.deleteMetadataOcIds(ocIdDoNotExists)
            self.ocIdDoNotExists.removeAll()
            collectionViewReloadData()
        }
    }

    @objc func copyMoveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let dragDrop = userInfo["dragdrop"] as? Bool,
              dragDrop else { return }

        setEditMode(false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Task {
                await self.loadDataSource()
                await self.searchMediaUI()
            }
        }
    }

    func buildMediaPhotoVideo(columnCount: Int) {
        var pointSize: CGFloat = 0

        switch columnCount {
        case 0...1: pointSize = 60
        case 2...3: pointSize = 30
        case 4...5: pointSize = 25
        case 6...Int(maxColumns): pointSize = 20
        default: pointSize = 20
        }
        if let image = UIImage(systemName: "photo.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal) {
            photoImage = image
        }
        if let image = UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal) {
            videoImage = image
        }
    }

    // MARK: - Command

    func setupMediaCommandView() {
        mediaCommandView?.title.text = ""

        mediaCommandView = Bundle.main.loadNibNamed("NCMediaCommandView", owner: self, options: nil)?.first as? NCMediaCommandView
        self.view.addSubview(mediaCommandView!)
        mediaCommandView?.mediaView = self
//        updateZoomButton()
        mediaCommandView?.collapseControlButtonView(true)
        mediaCommandView?.translatesAutoresizingMaskIntoConstraints = false
        mediaCommandView?.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        mediaCommandView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        mediaCommandView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        mediaCommandView?.heightAnchor.constraint(equalToConstant: 150).isActive = true
        self.updateMediaControlVisibility()
    }

    private func setupForGeneralPhotosSelection() {
        if isInGeneralPhotosSelectionContext {
            gradientViewHeightContsraint.constant = 0
            mediaCommandView?.setupForGeneralPhotosSelection()
            isEditMode = true
        }
    }

    func updateMediaControlVisibility() {

        if let metadatas = self.metadatas, metadatas.isEmpty {
            if !self.showOnlyImages && !self.showOnlyVideos {
                self.mediaCommandView?.toggleEmptyView(isEmpty: true)
                self.mediaCommandView?.isHidden = false
            } else {
                self.mediaCommandView?.toggleEmptyView(isEmpty: true)
                self.mediaCommandView?.isHidden = false
            }
        } else {
            self.mediaCommandView?.toggleEmptyView(isEmpty: false)
            self.mediaCommandView?.isHidden = false
        }
    }
}

// MARK: -

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !dataSource.metadatas.isEmpty {
            isTop = scrollView.contentOffset.y <= -(insetsTop + view.safeAreaInsets.top - 25)
//            setTitleDate()
            if lastContentOffsetY == 0 || lastContentOffsetY / 2 <= scrollView.contentOffset.y || lastContentOffsetY / 2 >= scrollView.contentOffset.y {
                setTitleDate()
                lastContentOffsetY = scrollView.contentOffset.y
            }
            setNeedsStatusBarAppearanceUpdate()
        }
        setElements()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if !decelerate {
                searchNewMedia()
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        searchNewMedia()
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        let y = view.safeAreaInsets.top
        scrollView.contentOffset.y = -(insetsTop + y)
    }
}

// MARK: -

extension NCMedia: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
        guard let serverUrl else { return }

        Task {
            let home = utilityFileSystem.getHomeServer(session: session)
            let mediaPath = serverUrl.replacingOccurrences(of: home, with: "")

            await database.setAccountMediaPathAsync(mediaPath, account: session.account)

            imageCache.removeAll()
            await loadDataSource()
            searchNewMedia()
        }
    }
}

// MARK: - Media Command View

class NCMediaCommandView: UIView {

    @IBOutlet weak var moreView: UIVisualEffectView!
    @IBOutlet weak var gridSwitchButton: UIButton!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var buttonControlWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var zoomInButton: UIButton!
    @IBOutlet weak var zoomOutButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var controlButtonView: UIVisualEffectView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var mediaView: NCMedia?
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        moreView.layer.cornerRadius = 20
        moreView.layer.masksToBounds = true
        controlButtonView.layer.cornerRadius = 20
        controlButtonView.layer.masksToBounds = true
        controlButtonView.effect = UIBlurEffect(style: .dark)
        gradient.frame = bounds
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]
        layer.insertSublayer(gradient, at: 0)
        moreButton.setImage(UIImage(named: "more")!.image(color: .white, size: 25), for: .normal)
        title.text = ""
    }

    func setupForGeneralPhotosSelection() {
        gridSwitchButton.isHidden = true
        moreView.isHidden = true
        title.isHidden = true
        controlButtonView.isHidden = true
        gradient.isHidden = true
    }

    func toggleEmptyView(isEmpty: Bool) {
        if isEmpty {
            UIView.animate(withDuration: 0.3) {
                self.moreView.effect = UIBlurEffect(style: .dark)
                self.gradient.isHidden = true
                self.controlButtonView.isHidden = true
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.moreView.effect = UIBlurEffect(style: .dark)
                self.gradient.isHidden = false
                self.controlButtonView.isHidden = false
            }
        }
    }

    @IBAction func moreButtonPressed(_ sender: UIButton) {
//        mediaView?.openMenuButtonMore(sender)
    }

    @IBAction func zoomInPressed(_ sender: UIButton) {
//        mediaView?.zoomInGrid()
    }

    @IBAction func zoomOutPressed(_ sender: UIButton) {
//        mediaView?.zoomOutGrid()
    }

    @IBAction func gridSwitchButtonPressed(_ sender: Any) {
        self.collapseControlButtonView(false)
    }

    func collapseControlButtonView(_ collapse: Bool) {
        if collapse {
            self.buttonControlWidthConstraint.constant = 40
            UIView.animate(withDuration: 0.25) {
                self.zoomOutButton.isHidden = true
                self.zoomInButton.isHidden = true
                self.separatorView.isHidden = true
                self.gridSwitchButton.isHidden = false
                self.layoutIfNeeded()
            }
        } else {
            self.buttonControlWidthConstraint.constant = 80
            UIView.animate(withDuration: 0.25) {
                self.zoomOutButton.isHidden = false
                self.zoomInButton.isHidden = false
                self.separatorView.isHidden = false
                self.gridSwitchButton.isHidden = true
                self.layoutIfNeeded()
            }
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return moreView.frame.contains(point) || controlButtonView.frame.contains(point)
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = bounds
    }
}

