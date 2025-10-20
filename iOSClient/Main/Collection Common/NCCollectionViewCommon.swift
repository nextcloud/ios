// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import RealmSwift
import NextcloudKit
import EasyTipView

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCPhotoCellDelegate, NCSectionFirstHeaderDelegate, NCSectionFooterDelegate, NCSectionFirstHeaderEmptyDataDelegate, NCAccountSettingsModelDelegate, NCTransferDelegate, UIAdaptivePresentationControllerDelegate, UIContextMenuInteractionDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let imageCache = NCImageCache.shared
    var dataSource = NCCollectionViewDataSource()
    let networking = NCNetworking.shared
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    var pinchGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer()

    var autoUploadFileName = ""
    var autoUploadDirectory = ""
    let refreshControl = UIRefreshControl()
    var searchController: UISearchController?
    var backgroundImageView = UIImageView()
    var serverUrl: String = ""
    var isEditMode = false
    var isDirectoryE2EE = false
    var fileSelect: [String] = []
    var metadataFolder: tableMetadata?
    var richWorkspaceText: String?
    var sectionFirstHeader: NCSectionFirstHeader?
    var sectionFirstHeaderEmptyData: NCSectionFirstHeaderEmptyData?
    var isSearchingMode: Bool = false
    var networkSearchInProgress: Bool = false
    var layoutForView: NCDBLayoutForView?
    var searchDataSourceTask: URLSessionTask?
    var providers: [NKSearchProvider]?
    var searchResults: [NKSearchResult]?
    var listLayout = NCListLayout()
    var gridLayout = NCGridLayout()
    var mediaLayout = NCMediaLayout()
    var layoutType = NCGlobal.shared.layoutList
    var literalSearch: String?
    var tabBarSelect: NCCollectionViewCommonSelectTabBar?
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    var tipViewAccounts: EasyTipView?

    // DECLARE
    var layoutKey = ""
    var titleCurrentFolder = ""
    var titlePreviusFolder: String?
    var enableSearchBar: Bool = false
    var headerRichWorkspaceDisable: Bool = false

    var emptyImageName: String?
    var emptyImageColors: [UIColor]?
    var emptyTitle: String = ""

    var emptyDescription: String = ""
    var emptyDataPortaitOffset: CGFloat = 0
    var emptyDataLandscapeOffset: CGFloat = -20

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

    let heightHeaderRecommendations: CGFloat = 160
    let heightHeaderSection: CGFloat = 30

    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: tabBarController)
    }

    var isLayoutPhoto: Bool {
        layoutForView?.layout == global.layoutPhotoRatio || layoutForView?.layout == global.layoutPhotoSquare
    }

    var isLayoutGrid: Bool {
        layoutForView?.layout == global.layoutGrid
    }

    var isLayoutList: Bool {
        layoutForView?.layout == global.layoutList
    }

    var showDescription: Bool {
        !headerRichWorkspaceDisable && NCPreferences().showDescription
    }

    var isRecommendationActived: Bool {
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        return self.serverUrl == self.utilityFileSystem.getHomeServer(session: self.session) && capabilities.recommendations
    }

    var infoLabelsSeparator: String {
        layoutForView?.layout == global.layoutList ? " - " : ""
    }

    @MainActor
    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var mainNavigationController: NCMainNavigationController? {
        self.navigationController as? NCMainNavigationController
    }

    var sceneIdentifier: String {
        (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier ?? ""
    }

    var isNumberOfItemsInAllSectionsNull: Bool {
        var totalItems = 0
        for section in 0..<self.collectionView.numberOfSections {
            totalItems += self.collectionView.numberOfItems(inSection: section)
        }
        return totalItems == 0
    }

    var numberOfItemsInAllSections: Int {
        var totalItems = 0
        for section in 0..<self.collectionView.numberOfSections {
            totalItems += self.collectionView.numberOfItems(inSection: section)
        }
        return totalItems
    }

    var isPinchGestureActive: Bool {
        return pinchGesture.state == .began || pinchGesture.state == .changed
    }

    func isRecommendationActived() async -> Bool {
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        return self.serverUrl == self.utilityFileSystem.getHomeServer(session: self.session) && capabilities.recommendations
    }

    internal let debouncer = NCDebouncer()

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.presentationController?.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.accessibilityIdentifier = "NCCollectionViewCommon"

        view.backgroundColor = .systemBackground
        collectionView.backgroundColor = .systemBackground
        refreshControl.tintColor = .clear

        if enableSearchBar {
            searchController = UISearchController(searchResultsController: nil)
            searchController?.searchResultsUpdater = self
            searchController?.obscuresBackgroundDuringPresentation = false
            searchController?.delegate = self
            searchController?.searchBar.delegate = self
            searchController?.searchBar.autocapitalizationType = .none
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = true
        }

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.register(UINib(nibName: "NCPhotoCell", bundle: nil), forCellWithReuseIdentifier: "photoCell")
        collectionView.register(UINib(nibName: "NCTransferCell", bundle: nil), forCellWithReuseIdentifier: "transferCell")

        // Header
        collectionView.register(UINib(nibName: "NCSectionFirstHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeader")
        collectionView.register(UINib(nibName: "NCSectionFirstHeader", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeader")
        collectionView.register(UINib(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        collectionView.register(UINib(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionHeader")
        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: mediaSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            Task { @MainActor in
                // Perform async server forced
                await self.getServerData(forced: true)

                // Stop the refresh control after data is loaded
                self.refreshControl.endRefreshing()

                // Wait 1.5 seconds before resetting the button alpha
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self.mainNavigationController?.resetPlusButtonAlpha()
            }
        }

        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressCollecationView(_:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)

        collectionView.prefetchDataSource = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        let dropInteraction = UIDropInteraction(delegate: self)
        self.navigationController?.navigationItem.leftBarButtonItems?.first?.customView?.addInteraction(dropInteraction)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (view: NCCollectionViewCommon, _) in
            guard let self else { return }

            self.sectionFirstHeader?.setRichWorkspaceColor(style: view.traitCollection.userInterfaceStyle)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterChangeTheming), object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.collectionView.reloadData()
        }

        DispatchQueue.main.async {
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if titlePreviusFolder != nil {
            navigationController?.navigationBar.topItem?.title = titlePreviusFolder
        }
        navigationItem.title = titleCurrentFolder

        if tabBarSelect == nil {
            tabBarSelect = NCCollectionViewCommonSelectTabBar(controller: self.controller, viewController: self, delegate: self)
        }

        isEditMode = false

        Task {
            await (self.navigationController as? NCMainNavigationController)?.setNavigationLeftItems()
            await (self.navigationController as? NCMainNavigationController)?.setNavigationRightItems()
        }

        layoutForView = database.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl)
        if isLayoutList {
            collectionView?.collectionViewLayout = listLayout
            self.layoutType = global.layoutList
        } else if isLayoutGrid {
            collectionView?.collectionViewLayout = gridLayout
            self.layoutType = global.layoutGrid
        } else if layoutForView?.layout == global.layoutPhotoRatio {
            collectionView?.collectionViewLayout = mediaLayout
            self.layoutType = global.layoutPhotoRatio
        } else if layoutForView?.layout == global.layoutPhotoSquare {
            collectionView?.collectionViewLayout = mediaLayout
            self.layoutType = global.layoutPhotoSquare
        }

        collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeRichWorkspaceWebView), name: NSNotification.Name(rawValue: global.notificationCenterCloseRichWorkspaceWebView), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.networking.cancelUnifiedSearchFiles()
        dismissTip()

        // Cancel Queue & Retrieves Properties
        self.networking.downloadThumbnailQueue.cancelAll()
        self.networking.unifiedSearchQueue.cancelAll()
        searchDataSourceTask?.cancel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        Task {
            await NCNetworking.shared.transferDispatcher.removeDelegate(self)
        }

        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterCloseRichWorkspaceWebView), object: nil)

        removeImageCache(metadatas: self.dataSource.getMetadatas())
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        let viewController = presentationController.presentedViewController

        if viewController is NCViewerRichWorkspaceWebView {
            closeRichWorkspaceWebView()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut) {
                self.collectionView?.collectionViewLayout.invalidateLayout()
            }
            animator.startAnimation()
        })

        self.dismissTip()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    // MARK: - Transfer Delegate

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) { }

    func transferChange(status: String, metadata: tableMetadata, destination: String?, error: NKError) {
        guard session.account == metadata.account else { return }

        if error != .success,
           error.errorCode != global.errorResourceNotFound {
            NCContentPresenter().showError(error: error)
        }

        self.debouncer.call {
            switch status {
            // UPLOADED, UPLOADED LIVEPHOTO, DELETE
            case self.global.networkingStatusUploaded,
                self.global.networkingStatusDelete,
                self.global.networkingStatusCopyMove:
                if self.isSearchingMode {
                    self.networkSearch()
                } else if self.serverUrl == metadata.serverUrl || destination == self.serverUrl {
                    Task {
                        await self.reloadDataSource()
                    }
                }
            // DOWNLOAD
            case self.global.networkingStatusDownloaded:
                Task {
                    if metadata.serverUrl == self.serverUrl {
                        await self.reloadDataSource()
                    }
                }
            case self.global.networkingStatusDownloadCancel:
                Task {
                    if metadata.serverUrl == self.serverUrl {
                        await self.reloadDataSource()
                    }
                }
            // CREATE FOLDER
            case self.global.networkingStatusCreateFolder:
                if metadata.serverUrl == self.serverUrl, metadata.sessionSelector != self.global.selectorUploadAutoUpload {
                    self.pushMetadata(metadata)
                }
            // RENAME
            case self.global.networkingStatusRename:
                self.debouncer.call {
                    if self.isSearchingMode {
                        self.networkSearch()
                    } else if self.serverUrl == metadata.serverUrl {
                        Task {
                            await self.reloadDataSource()
                        }
                    }
                }
            // FAVORITE
            case self.global.networkingStatusFavorite:
                self.debouncer.call {
                    if self.isSearchingMode {
                        self.networkSearch()
                    } else if self is NCFavorite {
                        Task {
                            await self.reloadDataSource()
                        }
                    } else if self.serverUrl == metadata.serverUrl {
                        Task {
                            await self.reloadDataSource()
                        }
                    }
                }
            default:
                break
            }
        }
    }

    func transferReloadData(serverUrl: String?, requestData: Bool, status: Int?) {
        self.debouncer.call {
            if requestData {
                if self.isSearchingMode {
                    self.networkSearch()
                } else if ( self.serverUrl == serverUrl) || serverUrl == nil {
                    Task {
                        await self.getServerData()
                    }
                }
            } else {
                if self.isSearchingMode {
                    guard status != self.global.metadataStatusWaitDelete,
                          status != self.global.metadataStatusWaitRename,
                          status != self.global.metadataStatusWaitMove,
                          status != self.global.metadataStatusWaitCopy,
                          status != self.global.metadataStatusWaitFavorite else {
                        return
                    }
                    self.networkSearch()
                } else if ( self.serverUrl == serverUrl) || serverUrl == nil {
                    Task {
                        await self.reloadDataSource()
                    }
                }
            }
        }
    }

    // MARK: - NotificationCenter

    @objc func applicationWillResignActive(_ notification: NSNotification) {
        mainNavigationController?.resetPlusButtonAlpha()
    }

    @objc func closeRichWorkspaceWebView() {
        Task {
            await self.reloadDataSource()
        }
    }

    // MARK: - Layout

    func changeLayout(layoutForView: NCDBLayoutForView) {
        let homeServer = utilityFileSystem.getHomeServer(urlBase: session.urlBase, userId: session.userId)
        let numFoldersLayoutsForView = self.database.getLayoutsForView(keyStore: layoutForView.keyStore)?.count ?? 1

        func changeLayout(withSubFolders: Bool) {
            if self.layoutForView?.layout == layoutForView.layout {
                self.layoutForView = self.database.setLayoutForView(layoutForView: layoutForView, withSubFolders: withSubFolders)
                Task {
                    await self.reloadDataSource()
                }
                return
            }

            self.layoutForView = self.database.setLayoutForView(layoutForView: layoutForView, withSubFolders: withSubFolders)
            layoutForView.layout = layoutForView.layout
            self.layoutType = layoutForView.layout

            collectionView.reloadData()

            switch layoutForView.layout {
            case global.layoutList:
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: true)
            case global.layoutGrid:
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true)
            case global.layoutPhotoSquare, global.layoutPhotoRatio:
                self.collectionView.setCollectionViewLayout(self.mediaLayout, animated: true)
            default:
                break
            }

            self.collectionView.collectionViewLayout.invalidateLayout()

            Task {
                await (self.navigationController as? NCMainNavigationController)?.updateRightMenu()
            }
        }

        if serverUrl == homeServer || numFoldersLayoutsForView == 1 {
            changeLayout(withSubFolders: false)
        } else {
            let alertController = UIAlertController(title: NSLocalizedString("_propagate_layout_", comment: ""), message: nil, preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                changeLayout(withSubFolders: true)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in
                changeLayout(withSubFolders: false)
            }))

            self.present(alertController, animated: true)
        }
    }

    func getNavigationTitle() -> String {
        let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
        if let tblAccount,
           !tblAccount.alias.isEmpty {
            return tblAccount.alias
        }
        return NCBrandOptions.shared.brand
    }

    func accountSettingsDidDismiss(tblAccount: tableAccount?, controller: NCMainTabBarController?) { }

    @MainActor
    func showLoadingTitle() {
        // Don't show spinner on iPad root folder
        if UIDevice.current.userInterfaceIdiom == .pad,
           (self.serverUrl == self.utilityFileSystem.getHomeServer(session: self.session)) || self.serverUrl.isEmpty {
            return
        }

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        self.navigationItem.titleView = container
    }

    @MainActor
    func restoreDefaultTitle() {
        self.navigationItem.titleView = nil
        self.navigationItem.title = self.titleCurrentFolder
    }

    // MARK: - SEARCH

    func searchController(enabled: Bool) {
        guard enableSearchBar else { return }
        searchController?.searchBar.isUserInteractionEnabled = enabled
        if enabled {
            searchController?.searchBar.alpha = 1
        } else {
            searchController?.searchBar.alpha = 0.3

        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        self.literalSearch = searchController.searchBar.text
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearchingMode = true
        self.providers?.removeAll()
        self.dataSource.removeAll()
        Task {
            await self.reloadDataSource()
        }
        // TIP
        dismissTip()
        //
        mainNavigationController?.hiddenPlusButton(true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if isSearchingMode && self.literalSearch?.count ?? 0 >= 2 {
            networkSearch()
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.networking.cancelUnifiedSearchFiles()

        self.isSearchingMode = false
        self.literalSearch = ""
        self.providers?.removeAll()
        self.dataSource.removeAll()
        Task {
            await self.reloadDataSource()
        }
        //
        mainNavigationController?.hiddenPlusButton(false)
    }

    // MARK: - TAP EVENT

    func tapMoreListItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any) {
        tapMoreGridItem(with: ocId, ocIdTransfer: ocIdTransfer, image: image, sender: sender)
    }

    func tapMorePhotoItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any) {
        tapMoreGridItem(with: ocId, ocIdTransfer: ocIdTransfer, image: image, sender: sender)
    }

    func tapShareListItem(with ocId: String, ocIdTransfer: String, sender: Any) {
        guard let metadata = self.database.getMetadataFromOcId(ocId) else { return }

        NCDownloadAction.shared.openShare(viewController: self, metadata: metadata, page: .sharing)
    }

    func tapMoreGridItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any) {
        guard let metadata = self.database.getMetadataFromOcId(ocId) else { return }
        toggleMenu(metadata: metadata, image: image, sender: sender)
    }

    func tapRichWorkspace(_ sender: Any) {
        if let navigationController = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateInitialViewController() as? UINavigationController {
            if let viewerRichWorkspace = navigationController.topViewController as? NCViewerRichWorkspace {
                viewerRichWorkspace.richWorkspaceText = richWorkspaceText ?? ""
                viewerRichWorkspace.serverUrl = serverUrl
                viewerRichWorkspace.delegate = self

                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true, completion: nil)
            }
        }
    }

    func tapRecommendationsButtonMenu(with metadata: tableMetadata, image: UIImage?, sender: Any?) {
        toggleMenu(metadata: metadata, image: image, sender: sender)
    }

    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?) {
        unifiedSearchMore(metadataForSection: metadataForSection)
    }

    func tapRecommendations(with metadata: tableMetadata) {
        didSelectMetadata(metadata, withOcIds: false)
    }

    func longPressListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressGridItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressMoreListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressPhotoItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressMoreGridItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    @objc func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        openMenuItems(with: nil, gestureRecognizer: gestureRecognizer)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            return nil
        }, actionProvider: { _ in
            return nil
        })
    }

    func openMenuItems(with objectId: String?, gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }

        var listMenuItems: [UIMenuItem] = []
        let touchPoint = gestureRecognizer.location(in: collectionView)

        becomeFirstResponder()

        if !serverUrl.isEmpty {
            listMenuItems.append(UIMenuItem(title: NSLocalizedString("_paste_file_", comment: ""), action: #selector(pasteFilesMenu(_:))))
        }

        if !listMenuItems.isEmpty {
            UIMenuController.shared.menuItems = listMenuItems
            UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0))
        }
    }

    // MARK: - Menu Item

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if #selector(pasteFilesMenu(_:)) == action {
            if !UIPasteboard.general.items.isEmpty, !(metadataFolder?.e2eEncrypted ?? false) {
                return true
            }
        } else if #selector(copyMenuFile(_:)) == action {
            return true
        } else if #selector(moveMenuFile(_:)) == action {
            return true
        }

        return false
    }

    @objc func pasteFilesMenu(_ sender: Any?) {
        Task {
            await NCDownloadAction.shared.pastePasteboard(serverUrl: serverUrl, account: session.account, controller: self.controller)
        }
    }

    // MARK: - DataSource

    @MainActor
    func reloadDataSource() async {
        if !isSearchingMode {
            Task.detached {
                if await self.isRecommendationActived() {
                    await self.networking.createRecommendations(session: self.session, serverUrl: self.serverUrl, collectionView: self.collectionView)
                }
            }
        }

        UIView.transition(with: self.collectionView,
                          duration: 0.20,
                          options: .transitionCrossDissolve,
                          animations: { self.collectionView.reloadData() },
                          completion: nil)

        await (self.navigationController as? NCMainNavigationController)?.updateRightMenu()
    }

    func getServerData(forced: Bool = false) async { }

    @objc func networkSearch() {
        guard !networkSearchInProgress else {
            return
        }
        guard !session.account.isEmpty,
              let literalSearch = literalSearch,
              !literalSearch.isEmpty else {
            return
        }
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()

        self.networkSearchInProgress = true
        self.dataSource.removeAll()
        Task {
            await self.reloadDataSource()
        }

        if capabilities.serverVersionMajor >= global.nextcloudVersion20 {
            self.networking.unifiedSearchFiles(literal: literalSearch, account: session.account) { task in
                self.searchDataSourceTask = task
                Task {
                    await self.reloadDataSource()
                }
            } providers: { account, searchProviders in
                self.providers = searchProviders
                self.searchResults = []
                self.dataSource = NCCollectionViewDataSource(metadatas: [],
                                                             layoutForView: self.layoutForView,
                                                             providers: self.providers,
                                                             searchResults: self.searchResults,
                                                             account: account)
            } update: { _, _, searchResult, metadatas in
                guard let metadatas, !metadatas.isEmpty, self.isSearchingMode, let searchResult else { return }
                self.networking.unifiedSearchQueue.addOperation(NCCollectionViewUnifiedSearch(collectionViewCommon: self, metadatas: metadatas, searchResult: searchResult))
            } completion: { _, _ in
                Task {
                    await self.reloadDataSource()
                }
                self.networkSearchInProgress = false
            }
        } else {
            self.networking.searchFiles(literal: literalSearch, account: session.account) { task in
                self.searchDataSourceTask = task
                Task {
                    await self.reloadDataSource()
                }
            } completion: { metadatasSearch, error in
                Task {
                    guard let metadatasSearch,
                            error == .success,
                            self.isSearchingMode
                    else {
                        self.networkSearchInProgress = false
                        await self.reloadDataSource()
                        return
                    }
                    let ocId = metadatasSearch.map { $0.ocId }
                    let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "ocId IN %@", ocId),
                                                                          withLayout: self.layoutForView,
                                                                          withAccount: self.session.account)

                    self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                                 layoutForView: self.layoutForView,
                                                                 providers: self.providers,
                                                                 searchResults: self.searchResults,
                                                                 account: self.session.account)
                    self.networkSearchInProgress = false
                    await self.reloadDataSource()
                }
            }
        }
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) {
        guard let metadataForSection = metadataForSection, let lastSearchResult = metadataForSection.lastSearchResult, let cursor = lastSearchResult.cursor, let term = literalSearch else { return }

        metadataForSection.unifiedSearchInProgress = true
        self.collectionView?.reloadData()

        self.networking.unifiedSearchFilesProvider(id: lastSearchResult.id, term: term, limit: 5, cursor: cursor, account: session.account) { task in
            self.searchDataSourceTask = task
            Task {
                await self.reloadDataSource()
            }
        } completion: { _, searchResult, metadatas, error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }

            metadataForSection.unifiedSearchInProgress = false
            guard let searchResult = searchResult, let metadatas = metadatas else { return }
            self.dataSource.appendMetadatasToSection(metadatas, metadataForSection: metadataForSection, lastSearchResult: searchResult)

            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        }
    }

    // MARK: - Push metadata

    func pushMetadata(_ metadata: tableMetadata) {
        guard let navigationCollectionViewCommon = self.controller?.navigationCollectionViewCommon else {
            return
        }
        let serverUrlPush = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)

        // Set Last Opening Date
        Task {
            await database.setDirectoryLastOpeningDateAsync(ocId: metadata.ocId)
        }

        if let viewController = navigationCollectionViewCommon.first(where: { $0.navigationController == self.navigationController && $0.serverUrl == serverUrlPush})?.viewController, viewController.isViewLoaded {
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {
                viewController.serverUrl = serverUrlPush
                viewController.titlePreviusFolder = navigationItem.title
                viewController.titleCurrentFolder = metadata.fileNameView

                navigationCollectionViewCommon.append(NavigationCollectionViewCommon(serverUrl: serverUrlPush, navigationController: self.navigationController, viewController: viewController))

                navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }

    // MARK: - Header size

    func getHeaderHeight(section: Int) -> (heightHeaderRichWorkspace: CGFloat,
                                           heightHeaderRecommendations: CGFloat,
                                           heightHeaderSection: CGFloat) {
        var heightHeaderRichWorkspace: CGFloat = 0
        var heightHeaderRecommendations: CGFloat = 0
        var heightHeaderSection: CGFloat = 0

        if showDescription,
           !isSearchingMode,
           let richWorkspaceText = self.richWorkspaceText,
           !richWorkspaceText.trimmingCharacters(in: .whitespaces).isEmpty {
            heightHeaderRichWorkspace = UIScreen.main.bounds.size.height / 6
        }

        if isRecommendationActived,
           !isSearchingMode,
           NCPreferences().showRecommendedFiles,
           !self.database.getRecommendedFiles(account: self.session.account).isEmpty {
            heightHeaderRecommendations = self.heightHeaderRecommendations
            heightHeaderSection = self.heightHeaderSection
        }

        if isSearchingMode || layoutForView?.groupBy != "none" || self.dataSource.numberOfSections() > 1 {
            if section == 0 {
                return (heightHeaderRichWorkspace, heightHeaderRecommendations, self.heightHeaderSection)
            } else {
                return (0, 0, self.heightHeaderSection)
            }
        } else {
            return (heightHeaderRichWorkspace, heightHeaderRecommendations, heightHeaderSection)
        }
    }

    func sizeForHeaderInSection(section: Int) -> CGSize {
        var height: CGFloat = 0
        let isLandscape = view.bounds.width > view.bounds.height
        let isIphone = UIDevice.current.userInterfaceIdiom == .phone

        if self.dataSource.isEmpty() {
            height = utility.getHeightHeaderEmptyData(view: view, portraitOffset: emptyDataPortaitOffset, landscapeOffset: emptyDataLandscapeOffset)
        } else if isEditMode || (isLandscape && isIphone) {
            return CGSize.zero
        } else {
            let (heightHeaderRichWorkspace, heightHeaderRecommendations, heightHeaderSection) = getHeaderHeight(section: section)
            height = heightHeaderRichWorkspace + heightHeaderRecommendations + heightHeaderSection
        }

        return CGSize(width: collectionView.frame.width, height: height)
    }

    // MARK: - Footer size

    func sizeForFooterInSection(section: Int) -> CGSize {
        guard let controller else {
            return CGSize.zero
        }
        let sections = dataSource.numberOfSections()
        let bottomAreaInsets: CGFloat = controller.tabBar.safeAreaInsets.bottom == 0 ? 34 : 0
        let height = controller.tabBar.frame.height + bottomAreaInsets

        if isEditMode {
            return CGSize(width: collectionView.frame.width, height: 90 + height)
        }

        if isSearchingMode {
            return CGSize(width: collectionView.frame.width, height: 50)
        }

        if section == sections - 1 {
            return CGSize(width: collectionView.frame.width, height: height)
        } else {
            return CGSize(width: collectionView.frame.width, height: 0)
        }
    }
}
