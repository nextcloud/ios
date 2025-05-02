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

    let semaphoreSearchMedia = DispatchSemaphore(value: 1)
    let semaphoreNotificationCenter = DispatchSemaphore(value: 1)

    let layout = NCMediaLayout()
    var layoutType = NCGlobal.shared.mediaLayoutRatio
    var documentPickerViewController: NCDocumentPickerViewController?
    var tabBarSelect: NCMediaSelectTabBar!
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let imageCache = NCImageCache.shared
    var dataSource = NCMediaDataSource()
    let refreshControl = UIRefreshControl()
    var isTop: Bool = true
    var isEditMode = false
    var fileSelect: [String] = []
    var filesExists: ThreadSafeArray<String> = ThreadSafeArray()
    var ocIdDoNotExists: ThreadSafeArray<String> = ThreadSafeArray()
    var searchMediaInProgress: Bool = false
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    let gradient: CAGradientLayer = CAGradientLayer()
    var showOnlyImages = false
    var showOnlyVideos = false
    var timeIntervalSearchNewMedia: TimeInterval = 2.0
    var timerSearchNewMedia: Timer?
    let insetsTop: CGFloat = 65
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

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: mediaSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.register(UINib(nibName: "NCMediaCell", bundle: nil), forCellWithReuseIdentifier: "mediaCell")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: insetsTop, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.accessibilityIdentifier = "NCMedia"

        layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
        collectionView.collectionViewLayout = layout
        layoutType = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "")?.layout ?? global.mediaLayoutRatio

        tabBarSelect = NCMediaSelectTabBar(controller: self.tabBarController, delegate: self)

        titleDate.text = ""

        menuButton.backgroundColor = .clear
        menuButton.layer.cornerRadius = 15
        menuButton.layer.masksToBounds = true
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.configuration = UIButton.Configuration.plain()
        menuButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menuButton.addBlur(style: .systemUltraThinMaterial)

        assistantButton.backgroundColor = .clear
        assistantButton.layer.cornerRadius = 15
        assistantButton.layer.masksToBounds = true
        assistantButton.configuration = UIButton.Configuration.plain()
        assistantButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
        assistantButton.addBlur(style: .systemUltraThinMaterial)

        selectOrCancelButton.backgroundColor = .clear
        selectOrCancelButton.layer.cornerRadius = 15
        selectOrCancelButton.layer.masksToBounds = true
        selectOrCancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
        selectOrCancelButton.addBlur(style: .systemUltraThinMaterial)

        gradient.startPoint = CGPoint(x: 0, y: 0.1)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]
        gradientView.layer.insertSublayer(gradient, at: 0)

        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            self.loadDataSource()
            self.searchMediaUI(true)
        }

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: global.notificationCenterChangeUser), object: nil, queue: nil) { _ in
            self.layoutType = self.database.getLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "")?.layout ?? self.global.mediaLayoutRatio
            self.imageCache.removeAll()
            self.loadDataSource()
            self.searchMediaUI(true)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: global.notificationCenterClearCache), object: nil, queue: nil) { _ in
            self.dataSource.metadatas.removeAll()
            self.imageCache.removeAll()
            self.searchMediaUI(true)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(fileExists(_:)), name: NSNotification.Name(rawValue: global.notificationCenterFileExists), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterDeleteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: global.notificationCenterReloadDataSource), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(networkRemoveAll(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setMediaAppreance()
        if dataSource.metadatas.isEmpty {
            loadDataSource()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(copyMoveFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterCopyMoveFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

        searchNewMedia()
        createMenu()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterCopyMoveFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)

        networkRemoveAll(nil)
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

        tabBarSelect?.setFrame()
        gradient.frame = gradientView.bounds
    }

    func searchNewMedia() {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchMediaUI(_:)), userInfo: nil, repeats: false)
    }

    // MARK: - NotificationCenter

    @objc func networkRemoveAll(_ sender: Any?) {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = nil
        filesExists.removeAll()

        NCNetworking.shared.fileExistsQueue.cancelAll()
        NCNetworking.shared.downloadThumbnailQueue.cancelAll()

        Task {
            let tasks = await NCNetworking.shared.getAllDataTask()
            for task in tasks.filter({ $0.taskDescription == global.taskDescriptionRetrievesProperties }) {
                task.cancel()
            }
        }
    }

    @objc func reloadDataSource(_ notification: NSNotification) {
        self.loadDataSource()
    }

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError
        else {
            return
        }

        // This is only a fail safe "dead lock", I don't think the timeout will ever be called but at least nothing gets stuck, if after 5 sec. (which is a long time in this routine), the semaphore is still locked
        //
        if self.semaphoreNotificationCenter.wait(timeout: .now() + 5) == .timedOut {
            self.semaphoreNotificationCenter.signal()
        }

        if error.errorCode == self.global.errorResourceNotFound,
           let ocIds = userInfo["ocId"] as? [String],
           let ocId = ocIds.first {
            self.database.deleteMetadataOcId(ocId)
            self.loadDataSource {
                self.semaphoreNotificationCenter.signal()
            }
        } else if error != .success {
            self.loadDataSource {
                self.semaphoreNotificationCenter.signal()
            }
        } else {
            semaphoreNotificationCenter.signal()
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
            self.loadDataSource()
            self.searchMediaUI()
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
}

// MARK: -

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !dataSource.metadatas.isEmpty {
            isTop = scrollView.contentOffset.y <= -(insetsTop + view.safeAreaInsets.top - 25)
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

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        let y = view.safeAreaInsets.top
        scrollView.contentOffset.y = -(insetsTop + y)
    }
}

// MARK: -

extension NCMedia: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
        guard let serverUrl else { return }
        let home = utilityFileSystem.getHomeServer(session: session)
        let mediaPath = serverUrl.replacingOccurrences(of: home, with: "")

        database.setAccountMediaPath(mediaPath, account: session.account)

        imageCache.removeAll()
        loadDataSource()
        searchNewMedia()
    }
}
