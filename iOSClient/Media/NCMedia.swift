// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

class NCMedia: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var titleDate: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var selectOrCancelButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var assistantButton: UIButton!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var stackView: UIStackView!

    let layout = NCMediaLayout()
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
    var searchMediaInProgress: Bool = false
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    let gradient: CAGradientLayer = CAGradientLayer()
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
        let column = Int(screenWidth / 44)

        return column
    }
    var transitionColumns = false
    var numberOfColumns: Int = 0
    var lastNumberOfColumns: Int = 0

    let debouncer = NCDebouncer(delay: 1)

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

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
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
        collectionView.contentInsetAdjustmentBehavior = .never

        layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
        collectionView.collectionViewLayout = layout
        layoutType = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "", layout: global.mediaLayoutRatio).layout

        titleDate.text = ""
        titleDate?.textColor = .white

        activityIndicator.color = .white

        menuButton.backgroundColor = .clear
        menuButton.layer.cornerRadius = 15
        menuButton.layer.masksToBounds = true
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.configuration = UIButton.Configuration.plain()
        menuButton.setImage(NCUtility().loadImage(named: "ellipsis", colors: [.white]), for: .normal)
        if #available(iOS 26.0, *) {
            menuButton.addBlur(style: .systemUltraThinMaterial, alpha: 0.7)
        } else {
            menuButton.addBlur(style: .systemUltraThinMaterial)
        }

        assistantButton.backgroundColor = .clear
        assistantButton.layer.cornerRadius = 15
        assistantButton.layer.masksToBounds = true
        assistantButton.configuration = UIButton.Configuration.plain()
        assistantButton.setImage(NCUtility().loadImage(named: "sparkles", colors: [.white]), for: .normal)
        if #available(iOS 26.0, *) {
            assistantButton.addBlur(style: .systemUltraThinMaterial, alpha: 0.7)
        } else {
            assistantButton.addBlur(style: .systemUltraThinMaterial)
        }

        selectOrCancelButton.backgroundColor = .clear
        selectOrCancelButton.layer.cornerRadius = 15
        selectOrCancelButton.layer.masksToBounds = true
        selectOrCancelButton.setTitleColor(.white, for: .normal)
        selectOrCancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
        if #available(iOS 26.0, *) {
           selectOrCancelButton.addBlurBackground(style: .systemUltraThinMaterial, alpha: 0.7)
        } else {
            selectOrCancelButton.addBlur(style: .systemUltraThinMaterial)
        }

        gradient.startPoint = CGPoint(x: 0, y: 0.1)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]
        gradientView.layer.insertSublayer(gradient, at: 0)

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: global.notificationCenterChangeUser), object: nil, queue: nil) { _ in
            Task { @MainActor in
                self.layoutType = self.database.getLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "").layout
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

        navigationController?.setNavigationBarHidden(true, animated: false)

        if dataSource.metadatas.isEmpty {
            Task {
                await loadDataSource()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await networking.transferDispatcher.addDelegate(self)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

        searchNewMedia()
        createMenu()
        setColor()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        Task {
            await networking.transferDispatcher.removeDelegate(self)
            await networkRemoveAll()
        }

        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        gradient.frame = gradientView.bounds
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

        networking.downloadThumbnailQueue.cancelAll()

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
}

// MARK: -

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !dataSource.metadatas.isEmpty {
            setColor()
            setTitleDate()
            setNeedsStatusBarAppearanceUpdate()
        } else {
            setColor()
        }
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

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { }
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
