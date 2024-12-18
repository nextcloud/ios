//
//  NCCollectionViewCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import SwiftUI
import RealmSwift
import NextcloudKit
import EasyTipView

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCPhotoCellDelegate, NCSectionFirstHeaderDelegate, NCSectionFooterDelegate, NCSectionFirstHeaderEmptyDataDelegate, UIAdaptivePresentationControllerDelegate, UIContextMenuInteractionDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var headerTop: NSLayoutConstraint?
	@IBOutlet weak var collectionViewTop: NSLayoutConstraint?
	@IBOutlet weak var fileActionsHeader: FileActionsHeader?
    
    var accountButtonFactory: AccountButtonFactory!

    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let imageCache = NCImageCache.shared
    var dataSource = NCCollectionViewDataSource()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    var pinchGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer()

    var autoUploadFileName = ""
    var autoUploadDirectory = ""
    let refreshControl = UIRefreshControl()
    var searchController: UISearchController?
    var backgroundImageView = UIImageView()
    var serverUrl: String = ""
    var isEditMode = false {
		didSet {
			DispatchQueue.main.async { [weak self] in
				self?.updateHeadersView()
			}
		}
	}
    var isDirectoryEncrypted = false
    var fileSelect: [String] = []
    var selectOcId: [String] = []
    var metadataFolder: tableMetadata?
    var richWorkspaceText: String?
    var sectionFirstHeader: NCSectionFirstHeader?
    var sectionFirstHeaderEmptyData: NCSectionFirstHeaderEmptyData?
	var isSearchingMode: Bool = false {
		didSet {
			DispatchQueue.main.async { [weak self] in
				self?.updateHeadersView()
			}
		}
	}
    var layoutForView: NCDBLayoutForView?
    var dataSourceTask: URLSessionTask?
    var providers: [NKSearchProvider]?
    var searchResults: [NKSearchResult]?
    var listLayout = NCListLayout()
    var gridLayout = NCGridLayout()
    var mediaLayout = NCMediaLayout()
	var layoutType = NCGlobal.shared.layoutList {
		didSet {
			DispatchQueue.main.async { [weak self] in
				self?.updateHeadersView()
			}
		}
	}
    var literalSearch: String?
    var tabBarSelect: NCCollectionViewCommonSelectTabBar!
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []

    // DECLARE
    var layoutKey = ""
    var titleCurrentFolder = ""
    var titlePreviusFolder: String?
    var enableSearchBar: Bool = false
    var headerMenuTransferView = false
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
        !headerRichWorkspaceDisable && NCKeychain().showDescription
    }

    var infoLabelsSeparator: String {
        layoutForView?.layout == global.layoutList ? " - " : ""
    }

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var defaultPredicate: NSPredicate {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND NOT (status IN %@) AND NOT (livePhotoFile != '' AND classFile == %@)", session.account, self.serverUrl, NCGlobal.shared.metadataStatusHideInView, NKCommon.TypeClassFile.video.rawValue)
        return predicate
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

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tabBarSelect = NCCollectionViewCommonSelectTabBar(controller: self.controller, delegate: self)
        self.navigationController?.presentationController?.delegate = self
        collectionView.alwaysBounceVertical = true

        // Color
        view.backgroundColor = NCBrandColor.shared.appBackgroundColor
        collectionView.backgroundColor = NCBrandColor.shared.appBackgroundColor
        refreshControl.tintColor = NCBrandColor.shared.textColor2

        if enableSearchBar {
            searchController = UISearchController(searchResultsController: nil)
            searchController?.searchResultsUpdater = self
            searchController?.obscuresBackgroundDuringPresentation = false
            searchController?.delegate = self
            searchController?.searchBar.delegate = self
            searchController?.searchBar.autocapitalizationType = .none
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = true
            if #available(iOS 16.0, *) {
                navigationItem.preferredSearchBarPlacement = .stacked
            }
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
            self.dataSource.removeAll()
            self.getServerData()
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

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming(_:)), name: NSNotification.Name(rawValue: global.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: global.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getServerData(_:)), name: NSNotification.Name(rawValue: global.notificationCenterGetServerData), object: nil)

        DispatchQueue.main.async {
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
        
        accountButtonFactory = AccountButtonFactory(onAccountDetailsOpen: { [weak self] in self?.setEditMode(false) },
                                                          presentVC: { [weak self] vc in self?.present(vc, animated: true) },
                                                          onMenuOpened: { [weak self] in self?.dismissTip() })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarAppearance()
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.title = titleCurrentFolder
        
        if isCurrentScreenInMainTabBar() && (navigationController?.viewControllers.count == 1) {
            let logo = UIImage(resource: .ionosEasyStorageLogo).withTintColor(UIColor(resource: .NavigationBar.logoTint))
            navigationItem.titleView = UIImageView(image: logo)
        }

        isEditMode = false
        setNavigationLeftItems()
        setNavigationRightItems()

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
		updateHeadersView()
		
        // FIXME: iPAD PDF landscape mode iOS 16
        DispatchQueue.main.async {
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeRichWorkspaceWebView), name: NSNotification.Name(rawValue: global.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeStatusFolderE2EE(_:)), name: NSNotification.Name(rawValue: global.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAvatar(_:)), name: NSNotification.Name(rawValue: global.notificationCenterReloadAvatar), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeLayout(_:)), name: NSNotification.Name(rawValue: global.notificationCenterChangeLayout), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyMoveFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterCopyMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: global.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadCancelFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedLivePhoto(_:)), name: NSNotification.Name(rawValue: global.notificationCenterUploadedLivePhoto), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancelFile(_:)), name: NSNotification.Name(rawValue: global.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: global.notificationCenterProgressTask), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NCNetworking.shared.cancelUnifiedSearchFiles()
        dismissTip()

        // Cancel Queue & Retrieves Properties
        NCNetworking.shared.downloadThumbnailQueue.cancelAll()
        NCNetworking.shared.unifiedSearchQueue.cancelAll()
        dataSourceTask?.cancel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterReloadAvatar), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterChangeLayout), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterCopyMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterUploadedLivePhoto), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterProgressTask), object: nil)

        dataSource.removeImageCache()
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

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }

    // MARK: - NotificationCenter

    @objc func applicationWillResignActive(_ notification: NSNotification) {
        self.refreshControl.endRefreshing()
    }

    @objc func reloadAvatar(_ notification: NSNotification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showTip()
        }
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error.errorCode != global.errorNotModified else { return }

        setNavigationLeftItems()
    }

    @objc func changeTheming(_ notification: NSNotification) {
        self.reloadDataSource()
    }

    @objc func changeLayout(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let layoutForView = userInfo["layoutForView"] as? NCDBLayoutForView,
              account == session.account,
              serverUrl == self.serverUrl
        else { return }

        if self.layoutForView?.layout == layoutForView.layout {
            self.layoutForView = self.database.setLayoutForView(layoutForView: layoutForView)
            self.reloadDataSource()
            return
        }

        self.layoutForView = self.database.setLayoutForView(layoutForView: layoutForView)
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

        self.setNavigationRightItems()
    }

    @objc func reloadDataSource(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as? NSDictionary {
            if let serverUrl = userInfo["serverUrl"] as? String {
                if serverUrl != self.serverUrl {
                    return
                }
            }

            if let clearDataSource = userInfo["clearDataSource"] as? Bool, clearDataSource {
                self.dataSource.removeAll()
            }
        }

        reloadDataSource()
    }

    @objc func getServerData(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary?,
           let serverUrl = userInfo["serverUrl"] as? String {
            if serverUrl != self.serverUrl {
                return
            }
        }

        getServerData()
    }

    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func closeRichWorkspaceWebView() {
        reloadDataSource()
    }

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error != .success {
            NCContentPresenter().showError(error: error)
        }

        reloadDataSource()
    }

    @objc func copyMoveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String,
              account == session.account,
              serverUrl == self.serverUrl else { return }

        reloadDataSource()
    }

    @objc func renameFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let error = userInfo["error"] as? NKError,
              account == session.account,
              serverUrl == self.serverUrl
        else { return }

        if error != .success {
            NCContentPresenter().showError(error: error)
        }

        reloadDataSource()
    }

    @objc func createFolder(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let account = userInfo["account"] as? String,
              account == session.account,
              let withPush = userInfo["withPush"] as? Bool,
              let metadata = database.getMetadataFromOcId(ocId)
        else { return }

        if metadata.serverUrl + "/" + metadata.fileName == self.serverUrl {
            reloadDataSource()
        } else if withPush, metadata.serverUrl == self.serverUrl {
            reloadDataSource()
            if let sceneIdentifier = userInfo["sceneIdentifier"] as? String {
                if sceneIdentifier == controller?.sceneIdentifier {
                    pushMetadata(metadata)
                }
            } else {
                pushMetadata(metadata)
            }
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {
        if self is NCFavorite {
            return reloadDataSource()
        }

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl
        else { return }

        reloadDataSource()
    }

    @objc func downloadStartFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            reloadDataSource()
        } else {
            collectionView?.reloadData()
        }
    }

    @objc func downloadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            reloadDataSource()
        } else {
            collectionView?.reloadData()
        }
    }

    @objc func downloadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            reloadDataSource()
        } else {
            collectionView?.reloadData()
        }
    }

    @objc func uploadStartFile(_ notification: NSNotification) {
        collectionView?.reloadData()
    }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            reloadDataSource()
        } else {
            collectionView?.reloadData()
        }
    }

    @objc func uploadedLivePhoto(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            reloadDataSource()
        } else {
            collectionView?.reloadData()
        }
    }

    @objc func uploadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            reloadDataSource()
        } else {
            collectionView?.reloadData()
        }
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let progressNumber = userInfo["progress"] as? NSNumber,
              let totalBytes = userInfo["totalBytes"] as? Int64,
              let totalBytesExpected = userInfo["totalBytesExpected"] as? Int64,
              let ocId = userInfo["ocId"] as? String,
              let ocIdTransfer = userInfo["ocIdTransfer"] as? String,
              let session = userInfo["session"] as? String
        else { return }

        let chunk: Int = userInfo["chunk"] as? Int ?? 0
        let e2eEncrypted: Bool = userInfo["e2eEncrypted"] as? Bool ?? false

        let transfer = NCTransferProgress.shared.append(NCTransferProgress.Transfer(ocId: ocId, ocIdTransfer: ocIdTransfer, session: session, chunk: chunk, e2eEncrypted: e2eEncrypted, progressNumber: progressNumber, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected))

        // HEADER
        if self.headerMenuTransferView, transfer.session.contains("upload") {
            self.sectionFirstHeader?.setViewTransfer(isHidden: false, progress: transfer.progressNumber.floatValue)
            self.sectionFirstHeaderEmptyData?.setViewTransfer(isHidden: false, progress: transfer.progressNumber.floatValue)
        }
    }
	
    // MARK: - Layout

    func setNavigationLeftItems() {
        if isSearchingMode && (UIDevice.current.userInterfaceIdiom == .phone) {
            navigationItem.leftBarButtonItems = nil
            return
        }
        
        if isCurrentScreenInMainTabBar() {
            navigationItem.leftItemsSupplementBackButton = true
            if navigationController?.viewControllers.count == 1 {
                let burgerMenuItem = UIBarButtonItem(image: UIImage(resource: .BurgerMenu.bars),
                                                     style: .plain,
                                                     action: { [weak self] in
                    self?.showBurgerMenu()
                })
                burgerMenuItem.tintColor = UIColor(resource: .BurgerMenu.navigationBarButton)
                navigationItem.setLeftBarButtonItems([burgerMenuItem], animated: true)
            }
        } else if (layoutKey == NCGlobal.shared.layoutViewRecent) ||
                    (layoutKey == NCGlobal.shared.layoutViewOffline) {
            navigationItem.leftItemsSupplementBackButton = true
            if navigationController?.viewControllers.count == 1 {
                let closeButton = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""),
                                                  style: .plain,
                                                  action: { [weak self] in
                    self?.dismiss(animated: true)
                })
                closeButton.tintColor = NCBrandColor.shared.iconImageColor
                navigationItem.setLeftBarButtonItems([closeButton], animated: true)
            }
        }

        if titlePreviusFolder != nil {
            navigationController?.navigationBar.topItem?.title = titlePreviusFolder
        }

        navigationItem.title = titleCurrentFolder
    }
    
    func showBurgerMenu() {
        self.mainTabBarController?.showBurgerMenu()
    }

	private func saveLayout(_ layoutForView: NCDBLayoutForView) {
		NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
		NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
		setNavigationRightItems()
		updateHeadersView()
	}
	
    func setNavigationRightItems() {
        if isSearchingMode && (UIDevice.current.userInterfaceIdiom == .phone) {
            navigationItem.rightBarButtonItems = nil
            return
        }

        guard layoutKey != NCGlobal.shared.layoutViewTransfers else { return }
        let tabBar = self.tabBarController?.tabBar
        let isTabBarHidden = tabBar?.isHidden ?? true
        let isTabBarSelectHidden = tabBarSelect.isHidden()

        if isEditMode {
            tabBarSelect.update(fileSelect: fileSelect, metadatas: getSelectedMetadatas(), userId: session.userId)
            tabBarSelect.show()
        } else {
            tabBarSelect.hide()
			navigationItem.rightBarButtonItems = layoutKey == NCGlobal.shared.layoutViewFiles ? [createAccountButton()] : []
        }
        // fix, if the tabbar was hidden before the update, set it in hidden
        if isTabBarHidden, isTabBarSelectHidden {
            tabBar?.isHidden = true
        }
    }
    
    private func createAccountButton() -> UIBarButtonItem {
        accountButtonFactory.createAccountButton()
    }

    func getNavigationTitle() -> String {
        let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
        if let tableAccount,
           !tableAccount.alias.isEmpty {
            return tableAccount.alias
        }
        return NCBrandOptions.shared.brand
    }
    
    private func isCurrentScreenInMainTabBar() -> Bool {
        return self.tabBarController is NCMainTabBarController
    }

    // MARK: - SEARCH

    func searchController(enabled: Bool) {
        guard enableSearchBar else { return }
        if enabled {
            navigationItem.searchController = searchController
        } else {
            navigationItem.searchController = nil
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        self.literalSearch = searchController.searchBar.text
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearchingMode = true
        self.providers?.removeAll()
        self.dataSource.removeAll()
        self.reloadDataSource()
        // TIP
        dismissTip()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if isSearchingMode && self.literalSearch?.count ?? 0 >= 2 {
            networkSearch()
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        NCNetworking.shared.cancelUnifiedSearchFiles()
        self.isSearchingMode = false
        self.literalSearch = ""
        self.providers?.removeAll()
        self.dataSource.removeAll()
        self.reloadDataSource()
    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        setNavigationLeftItems()
        setNavigationRightItems()
        navigationItem.title = nil
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        setNavigationLeftItems()
        setNavigationRightItems()
        navigationItem.title = titleCurrentFolder
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

        NCActionCenter.shared.openShare(viewController: self, metadata: metadata, page: .sharing)
    }

    func tapMoreGridItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any) {
        guard let metadata = self.database.getMetadataFromOcId(ocId) else { return }
        toggleMenu(metadata: metadata, image: image)
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

    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?) {
        unifiedSearchMore(metadataForSection: metadataForSection)
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
            listMenuItems.append(UIMenuItem(title: NSLocalizedString("_paste_file_", comment: ""), action: #selector(pasteFilesMenu)))
        }

        if !listMenuItems.isEmpty {
            UIMenuController.shared.menuItems = listMenuItems
            UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0))
        }
    }

    // MARK: - Menu Item

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if #selector(pasteFilesMenu) == action {
            if !UIPasteboard.general.items.isEmpty, !(metadataFolder?.e2eEncrypted ?? false) {
                return true
            }
        } else if #selector(copyMenuFile) == action {
            return true
        } else if #selector(moveMenuFile) == action {
            return true
        }

        return false
    }

    @objc func pasteFilesMenu() {
        NCActionCenter.shared.pastePasteboard(serverUrl: serverUrl, account: session.account, controller: self.controller)
    }

    // MARK: - DataSource

    @objc func reloadDataSource() {
        if isSearchingMode {
            isDirectoryEncrypted = false
        } else {
            isDirectoryEncrypted = NCUtilityFileSystem().isDirectoryE2EE(session: session, serverUrl: serverUrl)
        }

        DispatchQueue.main.async {
            UIView.transition(with: self.collectionView,
                              duration: 0.20,
                              options: .transitionCrossDissolve,
                              animations: { self.collectionView.reloadData() },
                              completion: nil)

            self.setNavigationRightItems()
            self.refreshControl.endRefreshing()
        }
    }

    func getServerData() {
    }

    @objc func networkSearch() {
        guard !session.account.isEmpty,
              let literalSearch = literalSearch,
              !literalSearch.isEmpty else {
            return self.refreshControl.endRefreshing()
        }

        self.dataSource.removeAll()
        self.refreshControl.beginRefreshing()
        self.reloadDataSource()

        if NCCapabilities.shared.getCapabilities(account: session.account).capabilityServerVersionMajor >= global.nextcloudVersion20 {
            NCNetworking.shared.unifiedSearchFiles(literal: literalSearch, account: session.account) { task in
                self.dataSourceTask = task
                self.reloadDataSource()
            } providers: { _, searchProviders in
                self.providers = searchProviders
                self.searchResults = []
                self.dataSource = NCCollectionViewDataSource(metadatas: [], layoutForView: self.layoutForView, providers: self.providers, searchResults: self.searchResults)
            } update: { _, _, searchResult, metadatas in
                guard let metadatas, !metadatas.isEmpty, self.isSearchingMode, let searchResult else { return }
                NCNetworking.shared.unifiedSearchQueue.addOperation(NCCollectionViewUnifiedSearch(collectionViewCommon: self, metadatas: metadatas, searchResult: searchResult))
            } completion: { _, _ in
                self.refreshControl.endRefreshing()
                self.reloadDataSource()
            }
        } else {
            NCNetworking.shared.searchFiles(literal: literalSearch, account: session.account) { task in
                self.dataSourceTask = task
                self.reloadDataSource()
            } completion: { metadatasSearch, error in
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.reloadDataSource()
                }
                guard let metadatasSearch, error == .success, self.isSearchingMode else { return }
                let ocId = metadatasSearch.map { $0.ocId }

                let metadatas = self.database.getResultsMetadatasPredicate(NSPredicate(format: "ocId IN %@", ocId), layoutForView: self.layoutForView)

                self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: self.layoutForView, providers: self.providers, searchResults: self.searchResults)
            }
        }
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) {
        guard let metadataForSection = metadataForSection, let lastSearchResult = metadataForSection.lastSearchResult, let cursor = lastSearchResult.cursor, let term = literalSearch else { return }

        metadataForSection.unifiedSearchInProgress = true
        self.collectionView?.reloadData()

        NCNetworking.shared.unifiedSearchFilesProvider(id: lastSearchResult.id, term: term, limit: 5, cursor: cursor, account: session.account) { task in
            self.dataSourceTask = task
            self.reloadDataSource()
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
        guard let navigationCollectionViewCommon = self.controller?.navigationCollectionViewCommon else { return }
        let serverUrlPush = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)

        if let viewController = navigationCollectionViewCommon.first(where: { $0.navigationController == self.navigationController && $0.serverUrl == serverUrlPush})?.viewController, viewController.isViewLoaded {
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {
                viewController.isRoot = false
                viewController.serverUrl = serverUrlPush
                viewController.titlePreviusFolder = navigationItem.title
                viewController.titleCurrentFolder = metadata.fileNameView

                navigationCollectionViewCommon.append(NavigationCollectionViewCommon(serverUrl: serverUrlPush, navigationController: self.navigationController, viewController: viewController))

                navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }

    // MARK: - Header size

    func isHeaderMenuTransferViewEnabled() -> [tableMetadata]? {
        if headerMenuTransferView,
           NCNetworking.shared.isOnline,
           let results = database.getResultsMetadatas(predicate: NSPredicate(format: "status IN %@", [global.metadataStatusWaitUpload, global.metadataStatusUploading])),
           !results.isEmpty {
            return Array(results)
        }
        return nil
    }

    func getHeaderHeight(section: Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {
        var headerRichWorkspace: CGFloat = 0

        func getHeaderHeight() -> CGFloat {
            var size: CGFloat = 0

            if isHeaderMenuTransferViewEnabled() != nil {
                if !isSearchingMode {
                    size += global.heightHeaderTransfer
                }
            }
            return size
        }

        if let richWorkspaceText = richWorkspaceText, showDescription {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !isSearchingMode {
                headerRichWorkspace = UIScreen.main.bounds.size.height / 6
            }
        }

        if isSearchingMode || layoutForView?.groupBy != "none" || self.dataSource.numberOfSections() > 1 {
            if section == 0 {
                return (getHeaderHeight(), headerRichWorkspace, global.heightSection)
            } else {
                return (0, 0, global.heightSection)
            }
        } else {
            return (getHeaderHeight(), headerRichWorkspace, 0)
        }
    }

    func sizeForHeaderInSection(section: Int) -> CGSize {
        var height: CGFloat = 0

        if isEditMode {
            return CGSize.zero
        } else if self.dataSource.isEmpty() {
            height = utility.getHeightHeaderEmptyData(view: view, portraitOffset: emptyDataPortaitOffset, landscapeOffset: emptyDataLandscapeOffset, isHeaderMenuTransferViewEnabled: isHeaderMenuTransferViewEnabled() != nil)
        } else {
            let (heightHeaderCommands, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: section)
            height = heightHeaderCommands + heightHeaderRichWorkspace + heightHeaderSection
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }

    // MARK: - Footer size

    func sizeForFooterInSection(section: Int) -> CGSize {
        let sections = dataSource.numberOfSections()
        let metadataForSection = self.dataSource.getMetadataForSection(section)
        let isPaginated = metadataForSection?.lastSearchResult?.isPaginated ?? false
        let metadatasCount: Int = metadataForSection?.lastSearchResult?.entries.count ?? 0
        var size = CGSize(width: collectionView.frame.width, height: 0)

        if section == sections - 1 {
            size.height += global.endHeightFooter
        } else {
            size.height += global.heightFooter
        }

        if isSearchingMode && isPaginated && metadatasCount > 0 {
            size.height += global.heightFooterButton
        }
        return size
    }
}

// MARK: -

extension NCCollectionViewCommon {
	// MARK: - Headers view
	
	private var sortTitle: String? {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return nil }
		
		switch layoutForView.sort {
		case "fileName": return NSLocalizedString("_name_", comment: "")
		case "date": return NSLocalizedString("_date_", comment: "")
		case "size": return NSLocalizedString("_size_", comment: "")
		default: return nil
		}
	}
	private var sortDirectionImage: UIImage? {
		guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return nil }
		let imageName = layoutForView.ascending ? "arrow.up" : "arrow.down"
		return UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
	}
	
	private var viewModeImage: UIImage? {
		var imageName: String = ""
		
		switch layoutType {
		case NCGlobal.shared.layoutList: imageName = "FileSelection/view_mode_list"
		case NCGlobal.shared.layoutGrid, NCGlobal.shared.layoutPhotoRatio, NCGlobal.shared.layoutPhotoSquare: imageName = "FileSelection/view_mode_grid"
		default: break
		}
		
		return UIImage(named: imageName)
	}
	
	private func updateHeadersView() {
		fileActionsHeader?.isHidden = isSearchingMode
		collectionViewTop?.constant = isSearchingMode ? 0 : fileActionsHeader?.bounds.height ?? 0
		fileActionsHeader?.setIsEditingMode(isEditingMode: isEditMode)
		
		fileActionsHeader?.setSortingMenu(sortingMenuElements: createSortMenuActions(), title: sortTitle, image: sortDirectionImage)
		fileActionsHeader?.setViewModeMenu(viewMenuElements: createViewModeMenuActions(), image: viewModeImage?.templateRendered())
		
		fileActionsHeader?.onSelectModeChange = { [weak self] isSelectionMode in
			self?.setEditMode(isSelectionMode)
			self?.setNavigationRightItems()
			self?.updateHeadersView()
			self?.fileActionsHeader?.setSelectionState(selectionState: .none)
		}
		
		fileActionsHeader?.onSelectAll = { [weak self] in
			guard let self = self else { return }
			self.selectAll()
			let selectionState: FileActionsHeaderSelectionState = self.selectOcId.count == 0 ? .none : .all
			self.fileActionsHeader?.setSelectionState(selectionState: selectionState)
		}
	}
	
	private func createSortMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return [] }
		   
		   let ascending = layoutForView.ascending
		   let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
		   let isName = layoutForView.sort == "fileName"
		   let isDate = layoutForView.sort == "date"
		   let isSize = layoutForView.sort == "size"

		   let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { [weak self] _ in
			   if isName { // repeated press
				   layoutForView.ascending = !layoutForView.ascending
			   }
			   layoutForView.sort = "fileName"
			   self?.saveLayout(layoutForView)
		   }

		   let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { [weak self]  _ in
			   if isDate { // repeated press
				   layoutForView.ascending = !layoutForView.ascending
			   }
			   layoutForView.sort = "date"
			   self?.saveLayout(layoutForView)
		   }

		   let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { [weak self]  _ in
			   if isSize { // repeated press
				   layoutForView.ascending = !layoutForView.ascending
			   }
			   layoutForView.sort = "size"
			   self?.saveLayout(layoutForView)
		   }

		   let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

		   let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: utility.loadImage(named: "folder"), state: layoutForView.directoryOnTop ? .on : .off) { [weak self]  _ in
			   layoutForView.directoryOnTop = !layoutForView.directoryOnTop
			   self?.saveLayout(layoutForView)
		   }

		   let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop])
		   return [sortSubmenu, additionalSubmenu]
	   }
	
	func createViewModeMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

		let listImage = UIImage(named: "FileSelection/view_mode_list")?.templateRendered()
		let gridImage = UIImage(named: "FileSelection/view_mode_grid")?.templateRendered()

		let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: listImage, state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
			layoutForView.layout = NCGlobal.shared.layoutList
			self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
			self.layoutType = NCGlobal.shared.layoutList

			self.collectionView.reloadData()
			self.collectionView.collectionViewLayout.invalidateLayout()
//			self.collectionView.setCollectionViewLayout(self.listLayout, animated: true) {_ in self.isTransitioning = false }

			self.setNavigationRightItems()
		}

		let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
			layoutForView.layout = NCGlobal.shared.layoutGrid
			self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
			self.layoutType = NCGlobal.shared.layoutGrid

			self.collectionView.reloadData()
			self.collectionView.collectionViewLayout.invalidateLayout()
//			self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true) {_ in self.isTransitioning = false }

			self.setNavigationRightItems()
		}

		let menuPhoto = UIMenu(title: "", options: .displayInline, children: [
			UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutPhotoSquare ? .on : .off) { _ in
				layoutForView.layout = NCGlobal.shared.layoutPhotoSquare
				self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
				self.layoutType = NCGlobal.shared.layoutPhotoSquare

				self.collectionView.reloadData()
				self.collectionView.collectionViewLayout.invalidateLayout()
//				self.collectionView.setCollectionViewLayout(self.mediaLayout, animated: true) {_ in self.isTransitioning = false }

				self.reloadDataSource()
				self.setNavigationRightItems()
			},
			UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutPhotoRatio ? .on : .off) { _ in
				layoutForView.layout = NCGlobal.shared.layoutPhotoRatio
				self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
				self.layoutType = NCGlobal.shared.layoutPhotoRatio

				self.collectionView.reloadData()
				self.collectionView.collectionViewLayout.invalidateLayout()
//				self.collectionView.setCollectionViewLayout(self.mediaLayout, animated: true) {_ in self.isTransitioning = false }

				self.reloadDataSource()
				self.setNavigationRightItems()
			}
		])

		return [list, grid, UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [menuPhoto])]
	}
}
