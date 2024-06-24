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
import Realm
import NextcloudKit
import EasyTipView
import JGProgressHUD

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, NCSectionFooterDelegate, NCSectionHeaderEmptyDataDelegate, NCAccountSettingsModelDelegate, UIAdaptivePresentationControllerDelegate, UIContextMenuInteractionDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""

    var isTransitioning: Bool = false
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let refreshControl = UIRefreshControl()
    var searchController: UISearchController?
    var backgroundImageView = UIImageView()
    var serverUrl: String = ""
    var isEditMode = false
    var selectOcId: [String] = []
    var metadataFolder: tableMetadata?
    var dataSource = NCDataSource()
    var richWorkspaceText: String?
    var headerMenu: NCSectionHeaderMenu?
    var headerEmptyData: NCSectionHeaderEmptyData?
    var isSearchingMode: Bool = false
    var layoutForView: NCDBLayoutForView?
    var dataSourceTask: URLSessionTask?
    var groupByField = "name"
    var providers: [NKSearchProvider]?
    var searchResults: [NKSearchResult]?
    var listLayout: NCListLayout!
    var gridLayout: NCGridLayout!
    var literalSearch: String?
    var tabBarSelect: NCCollectionViewCommonSelectTabBar!
    var timerNotificationCenter: Timer?
    var notificationReloadDataSource: Int = 0
    var notificationReloadDataSourceNetwork: Int = 0

    // DECLARE
    var layoutKey = ""
    var titleCurrentFolder = ""
    var titlePreviusFolder: String?
    var enableSearchBar: Bool = false
    var headerMenuTransferView = false
    var headerRichWorkspaceDisable: Bool = false
    var emptyImage: UIImage?
    var emptyTitle: String = ""
    var emptyDescription: String = ""
    var emptyDataPortaitOffset: CGFloat = 0
    var emptyDataLandscapeOffset: CGFloat = -20

    private var showDescription: Bool {
        !headerRichWorkspaceDisable && NCKeychain().showDescription
    }

    private var infoLabelsSeparator: String {
        layoutForView?.layout == NCGlobal.shared.layoutList ? " - " : ""
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tabBarSelect = NCCollectionViewCommonSelectTabBar(controller: tabBarController as? NCMainTabBarController, delegate: self)
        self.navigationController?.presentationController?.delegate = self

        // CollectionView & layout
        collectionView.alwaysBounceVertical = true
        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Color
        view.backgroundColor = .systemBackground
        collectionView.backgroundColor = .systemBackground
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
        }

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.register(UINib(nibName: "NCTransferCell", bundle: nil), forCellWithReuseIdentifier: "transferCell")

        // Header
        collectionView.register(UINib(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        collectionView.register(UINib(nibName: "NCSectionHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderEmptyData")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        // Refresh Control
        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            self.dataSource.clearDirectory()
            NCManageDatabase.shared.cleanEtagDirectory(account: self.appDelegate.account, serverUrl: self.serverUrl)
            self.reloadDataSourceNetwork()
        }

        // Long Press on CollectionView
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressCollecationView(_:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)

        // Drag & Drop
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        let dropInteraction = UIDropInteraction(delegate: self)
        self.navigationController?.navigationItem.leftBarButtonItems?.first?.customView?.addInteraction(dropInteraction)

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarAppearance()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.title = titleCurrentFolder

        isEditMode = false
        setNavigationLeftItems()
        setNavigationRightItems()

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)
        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }

        // FIXME: iPAD PDF landscape mode iOS 16
        DispatchQueue.main.async {
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        timerNotificationCenter = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(notificationCenterEvents), userInfo: nil, repeats: true)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeRichWorkspaceWebView), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeStatusFolderE2EE(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAvatar(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSourceNetwork(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetwork), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadCancelFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedLivePhoto(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedLivePhoto), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancelFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
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

        timerNotificationCenter?.invalidate()

        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetwork), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedLivePhoto), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {

        let viewController = presentationController.presentedViewController
        if viewController is NCViewerRichWorkspaceWebView {
            closeRichWorkspaceWebView()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        collectionView?.collectionViewLayout.invalidateLayout()
        collectionView?.reloadData()
        dismissTip()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let frame = tabBarController?.tabBar.frame {
            tabBarSelect.hostingController?.view.frame = frame
        }
    }

    // MARK: - NotificationCenter

    @objc func notificationCenterEvents() {
        if notificationReloadDataSource > 0 {
            print("notificationReloadDataSource: \(notificationReloadDataSource)")
            reloadDataSource()
            notificationReloadDataSource = 0
        }
    }

    @objc func applicationWillResignActive(_ notification: NSNotification) {
        self.refreshControl.endRefreshing()
    }

    @objc func reloadAvatar(_ notification: NSNotification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showTip()
        }

        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error.errorCode != NCGlobal.shared.errorNotModified else { return }

        setNavigationLeftItems()
    }

    @objc func changeTheming() {
        collectionView.reloadData()
    }

    @objc func reloadDataSource(_ notification: NSNotification) {
        notificationReloadDataSource += 1
    }

    @objc func reloadDataSourceNetwork(_ notification: NSNotification) {
        var withQueryDB = false
        if let userInfo = notification.userInfo as NSDictionary?,
           let reload = userInfo["withQueryDB"] as? Bool {
            withQueryDB = reload
        }

        if !isSearchingMode {
            reloadDataSourceNetwork(withQueryDB: withQueryDB)
        }
    }

    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        notificationReloadDataSource += 1
    }

    @objc func closeRichWorkspaceWebView() {
        reloadDataSourceNetwork()
    }

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error == .success {
            reloadDataSource()
        } else {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error == .success {
            if !isSearchingMode, let dragDrop = userInfo["dragdrop"] as? Bool, dragDrop {
                setEditMode(false)
                reloadDataSourceNetwork(withQueryDB: true)
            } else {
                reloadDataSource()
            }
        } else {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func copyFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error == .success {
            if !isSearchingMode, let dragDrop = userInfo["dragdrop"] as? Bool, dragDrop {
                setEditMode(false)
                reloadDataSourceNetwork(withQueryDB: true)
            } else {
                reloadDataSource()
            }
        } else {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func renameFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        reloadDataSource()
    }

    @objc func createFolder(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let account = userInfo["account"] as? String,
              account == appDelegate.account,
              let withPush = userInfo["withPush"] as? Bool
        else { return }

        notificationReloadDataSource += 1

        if withPush, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            if let sceneIdentifier = userInfo["sceneIdentifier"] as? String {
                if sceneIdentifier == (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier {
                    pushMetadata(metadata)
                }
            } else {
                pushMetadata(metadata)
            }
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {
        if self is NCFavorite {
            return notificationReloadDataSource += 1
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
              serverUrl == self.serverUrl || self.serverUrl.isEmpty,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        self.notificationReloadDataSource += 1
    }

    @objc func downloadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl || self.serverUrl.isEmpty,
              let account = userInfo["account"] as? String,
              account == appDelegate.account,
              let error = userInfo["error"] as? NKError
        else { return }

        if error != .success {
            NCContentPresenter().showError(error: error)
        }

        notificationReloadDataSource += 1
    }

    @objc func downloadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl || self.serverUrl.isEmpty,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        reloadDataSource()
    }

    @objc func uploadStartFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String,
              !isSearchingMode,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        // Header view trasfer
        if metadata.isTransferInForeground {
            NCNetworking.shared.transferInForegorund = NCNetworking.TransferInForegorund(ocId: ocId, progress: 0)
            DispatchQueue.main.async { self.collectionView?.reloadData() }
        }

        if serverUrl == self.serverUrl, account == appDelegate.account {
            notificationReloadDataSource += 1
        }
    }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocIdTemp = userInfo["ocIdTemp"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if ocIdTemp == NCNetworking.shared.transferInForegorund?.ocId {
            NCNetworking.shared.transferInForegorund = nil
            DispatchQueue.main.async { self.collectionView?.reloadData() }
        }

        if account == appDelegate.account, serverUrl == self.serverUrl {
            notificationReloadDataSource += 1
        }
    }

    @objc func uploadedLivePhoto(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        notificationReloadDataSource += 1
    }

    @objc func uploadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if ocId == NCNetworking.shared.transferInForegorund?.ocId {
            NCNetworking.shared.transferInForegorund = nil
            DispatchQueue.main.async { self.collectionView?.reloadData() }
        }

        if account == appDelegate.account, serverUrl == self.serverUrl {
            reloadDataSource()
        }
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let progressNumber = userInfo["progress"] as? NSNumber,
              let totalBytes = userInfo["totalBytes"] as? Int64,
              let totalBytesExpected = userInfo["totalBytesExpected"] as? Int64,
              let ocId = userInfo["ocId"] as? String
        else { return }

        let chunk: Int = userInfo["chunk"] as? Int ?? 0
        let e2eEncrypted: Bool = userInfo["e2eEncrypted"] as? Bool ?? false

        DispatchQueue.main.async {
            if self.headerMenuTransferView && (chunk > 0 || e2eEncrypted) {
                if NCNetworking.shared.transferInForegorund?.ocId == ocId {
                    NCNetworking.shared.transferInForegorund?.progress = progressNumber.floatValue
                } else {
                    NCNetworking.shared.transferInForegorund = NCNetworking.TransferInForegorund(ocId: ocId, progress: progressNumber.floatValue)
                    self.collectionView.reloadData()
                }
                self.headerMenu?.progressTransfer.progress = progressNumber.floatValue
                self.headerEmptyData?.progressTransfer.progress = progressNumber.floatValue
            } else {
                guard let indexPath = self.dataSource.getIndexPathMetadata(ocId: ocId).indexPath,
                      let cell = self.collectionView?.cellForItem(at: indexPath),
                      let cell = cell as? NCCellProtocol else { return }
                if progressNumber.floatValue == 1 && !(cell is NCTransferCell) {
                    cell.fileProgressView?.isHidden = true
                    cell.fileProgressView?.progress = .zero
                    cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCImageCache.images.buttonMore)
                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                        cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
                    } else {
                        cell.fileInfoLabel?.text = ""
                        cell.fileSubinfoLabel?.text = ""
                    }
                } else {
                    cell.fileProgressView?.isHidden = false
                    cell.fileProgressView?.progress = progressNumber.floatValue
                    cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCImageCache.images.buttonStop)
                    let status = userInfo["status"] as? Int ?? NCGlobal.shared.metadataStatusNormal
                    if status == NCGlobal.shared.metadataStatusDownloading {
                        cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected)
                        cell.fileSubinfoLabel?.text = self.infoLabelsSeparator + "↓ " + self.utilityFileSystem.transformedSize(totalBytes)
                    } else if status == NCGlobal.shared.metadataStatusUploading {
                        if totalBytes > 0 {
                            cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected)
                            cell.fileSubinfoLabel?.text = self.infoLabelsSeparator + "↑ " + self.utilityFileSystem.transformedSize(totalBytes)
                        } else {
                            cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected)
                            cell.fileSubinfoLabel?.text = self.infoLabelsSeparator + "↑ …"
                        }
                    }
                }
            }
        }
    }

    // MARK: - Layout

    func setNavigationLeftItems() {
        guard layoutKey == NCGlobal.shared.layoutViewFiles else { return }
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        let image = utility.loadUserImage(for: appDelegate.user, displayName: activeAccount?.displayName, userBaseUrl: appDelegate)
        let accountButton = AccountSwitcherButton(type: .custom)

        accountButton.setImage(image, for: .normal)
        accountButton.setImage(image, for: .highlighted)
        accountButton.semanticContentAttribute = .forceLeftToRight
        accountButton.sizeToFit()

        let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()

        if !accounts.isEmpty, !NCBrandOptions.shared.disable_multiaccount {
            let accountActions: [UIAction] = accounts.map { account in
                let image = utility.loadUserImage(for: account.user, displayName: account.displayName, userBaseUrl: account)

                var name: String = ""
                var url: String = ""

                if account.alias.isEmpty {
                    name = account.displayName
                    url = (URL(string: account.urlBase)?.host ?? "")
                } else {
                    name = account.alias
                }

                let action = UIAction(title: name, image: image, state: account.active ? .on : .off) { _ in
                    if !account.active {
                        self.appDelegate.changeAccount(account.account, userProfile: nil)
                        self.setEditMode(false)
                    }
                }

                action.subtitle = url

                return action
            }

            let addAccountAction = UIAction(title: NSLocalizedString("_add_account_", comment: ""), image: utility.loadImage(named: "person.crop.circle.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)) { _ in
                self.appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }

            let settingsAccountAction = UIAction(title: NSLocalizedString("_account_settings_", comment: ""), image: utility.loadImage(named: "gear", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let accountSettingsModel = NCAccountSettingsModel(controller: self.tabBarController as? NCMainTabBarController, delegate: self)
                let accountSettingsView = NCAccountSettingsView(model: accountSettingsModel)
                let accountSettingsController = UIHostingController(rootView: accountSettingsView)
                self.present(accountSettingsController, animated: true, completion: nil)
            }

            let addAccountSubmenu = UIMenu(title: "", options: .displayInline, children: [addAccountAction, settingsAccountAction])

            let menu = UIMenu(children: accountActions + [addAccountSubmenu])

            accountButton.menu = menu
            accountButton.showsMenuAsPrimaryAction = true

            accountButton.onMenuOpened = {
                self.dismissTip()
            }
        }

        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: accountButton)], animated: true)

        if titlePreviusFolder != nil {
            navigationController?.navigationBar.topItem?.title = titlePreviusFolder
        }

        navigationItem.title = titleCurrentFolder
    }

    func setNavigationRightItems() {
        guard layoutKey != NCGlobal.shared.layoutViewTransfers else { return }
        let isTabBarHidden = self.tabBarController?.tabBar.isHidden ?? true
        let isTabBarSelectHidden = tabBarSelect.isHidden()

        func createMenuActions() -> [UIMenuElement] {
            guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

            let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: utility.loadImage(named: "checkmark.circle"), attributes: self.dataSource.getMetadataSourceForAllSections().isEmpty ? .disabled : []) { _ in
                self.setEditMode(true)
            }

            let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet"), state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
                self.onListSelected()
                self.setNavigationRightItems()
            }

            let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2"), state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
                self.onGridSelected()
                self.setNavigationRightItems()
            }

            let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

            let ascending = layoutForView.ascending
            let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
            let isName = layoutForView.sort == "fileName"
            let isDate = layoutForView.sort == "date"
            let isSize = layoutForView.sort == "size"

            let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in
                if isName { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "fileName"
                self.saveLayout(layoutForView)
            }

            let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in
                if isDate { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "date"
                self.saveLayout(layoutForView)
            }

            let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in
                if isSize { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "size"
                self.saveLayout(layoutForView)
            }

            let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

            let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: utility.loadImage(named: "folder"), state: layoutForView.directoryOnTop ? .on : .off) { _ in
                layoutForView.directoryOnTop = !layoutForView.directoryOnTop
                self.saveLayout(layoutForView)
            }

            let personalFilesOnly = NCKeychain().getPersonalFilesOnly(account: appDelegate.account)
            let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""), image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors), state: personalFilesOnly ? .on : .off) { _ in
                NCKeychain().setPersonalFilesOnly(account: self.appDelegate.account, value: !personalFilesOnly)
                self.reloadDataSource()
            }

            let showDescriptionKeychain = NCKeychain().showDescription
            let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""), image: utility.loadImage(named: "list.dash.header.rectangle"), attributes: richWorkspaceText == nil ? .disabled : [], state: showDescriptionKeychain && richWorkspaceText != nil ? .on : .off) { _ in
                NCKeychain().showDescription = !showDescriptionKeychain
                self.collectionView.reloadData()
                self.setNavigationRightItems()
            }
            showDescription.subtitle = richWorkspaceText == nil ? NSLocalizedString("_no_description_available_", comment: "") : ""

            if layoutKey == NCGlobal.shared.layoutViewRecent {
                return [select]
            } else {
                var additionalSubmenu = UIMenu()
                if layoutKey == NCGlobal.shared.layoutViewFiles {
                    additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop, personalFilesOnlyAction, showDescription])
                } else {
                    additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop, showDescription])
                }
                return [select, viewStyleSubmenu, sortSubmenu, additionalSubmenu]
            }
        }

        if isEditMode {
            tabBarSelect.update(selectOcId: selectOcId, metadatas: getSelectedMetadatas(), userId: appDelegate.userId)
            tabBarSelect.show()
            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                self.setEditMode(false)
            }
            navigationItem.rightBarButtonItems = [select]
        } else if navigationItem.rightBarButtonItems == nil || (!isEditMode && !tabBarSelect.isHidden()) {
            tabBarSelect.hide()
            let menuButton = UIBarButtonItem(image: utility.loadImage(named: "ellipsis.circle"), menu: UIMenu(children: createMenuActions()))
            menuButton.tintColor = NCBrandColor.shared.iconImageColor
            if layoutKey == NCGlobal.shared.layoutViewFiles {
                let notification = UIBarButtonItem(image: utility.loadImage(named: "bell"), style: .plain) {
                    if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
                        self.navigationController?.pushViewController(viewController, animated: true)
                    }
                }
                notification.tintColor = NCBrandColor.shared.iconImageColor
                navigationItem.rightBarButtonItems = [menuButton, notification]
            } else {
                navigationItem.rightBarButtonItems = [menuButton]
            }
        } else {
            navigationItem.rightBarButtonItems?.first?.menu = navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenuActions())
        }
        // fix, if the tabbar was hidden before the update, set it in hidden
        if isTabBarHidden, isTabBarSelectHidden {
            self.tabBarController?.tabBar.isHidden = true
        }
    }

    func getNavigationTitle() -> String {
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        guard let userAlias = activeAccount?.alias, !userAlias.isEmpty else {
            return NCBrandOptions.shared.brand
        }
        return userAlias
    }

    func accountSettingsDidDismiss(tableAccount: tableAccount?) { }

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
        self.dataSource.clearDataSource()
        self.collectionView.reloadData()
        // TIP
        dismissTip()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if isSearchingMode && self.literalSearch?.count ?? 0 >= 2 {
            reloadDataSourceNetwork()
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        DispatchQueue.global().async {
            NCNetworking.shared.cancelUnifiedSearchFiles()
            self.isSearchingMode = false
            self.literalSearch = ""
            self.providers?.removeAll()
            self.dataSource.clearDataSource()
            self.reloadDataSource()
        }
    }

    // MARK: - TAP EVENT

    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
        tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, image: image, indexPath: indexPath, sender: sender)
    }

    func tapShareListItem(with objectId: String, indexPath: IndexPath, sender: Any) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        NCActionCenter.shared.openShare(viewController: self, metadata: metadata, page: .sharing)
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        if namedButtonMore == NCGlobal.shared.buttonMoreMore || namedButtonMore == NCGlobal.shared.buttonMoreLock {
            toggleMenu(metadata: metadata, indexPath: indexPath, imageIcon: image)
        } else if namedButtonMore == NCGlobal.shared.buttonMoreStop {
            Task {
                await cancelSession(metadata: metadata)
            }
        }
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

    func tapButtonTransfer(_ sender: Any) {
        if let ocId = NCNetworking.shared.transferInForegorund?.ocId,
           let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            Task {
                await cancelSession(metadata: metadata)
            }
        }
    }

    func longPressListItem(with objectId: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func longPressGridItem(with objectId: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func longPressMoreListItem(with objectId: String, namedButtonMore: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) {
    }

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
        NCActionCenter.shared.pastePasteboard(serverUrl: serverUrl, hudView: tabBarController?.view)
    }

    // MARK: - DataSource + NC Endpoint

    func queryDB() { }

    @objc func reloadDataSource(withQueryDB: Bool = true) {
        guard !appDelegate.account.isEmpty, !self.isSearchingMode else { return }

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, userId: appDelegate.userId, account: appDelegate.account)

        // get layout for view
        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl)

        // set GroupField for Grid
        if !isSearchingMode && layoutForView?.layout == NCGlobal.shared.layoutGrid {
            groupByField = "classFile"
        } else {
            groupByField = "name"
        }

        DispatchQueue.global(qos: .userInteractive).async {
            if withQueryDB { self.queryDB() }
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
                self.setNavigationRightItems()
            }
        }
    }

    @objc func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }

    @objc func networkSearch() {
        guard !appDelegate.account.isEmpty, let literalSearch = literalSearch, !literalSearch.isEmpty
        else { return self.refreshControl.endRefreshing() }

        self.dataSource.clearDataSource()
        self.refreshControl.beginRefreshing()
        self.collectionView.reloadData()

        if NCGlobal.shared.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion20 {
            NCNetworking.shared.unifiedSearchFiles(userBaseUrl: appDelegate, literal: literalSearch) { task in
                self.dataSourceTask = task
                self.collectionView.reloadData()
            } providers: { _, searchProviders in
                self.providers = searchProviders
                self.searchResults = []
                self.dataSource = NCDataSource(
                    metadatas: [],
                    account: self.appDelegate.account,
                    sort: self.layoutForView?.sort,
                    ascending: self.layoutForView?.ascending,
                    directoryOnTop: self.layoutForView?.directoryOnTop,
                    favoriteOnTop: true,
                    providers: self.providers,
                    searchResults: self.searchResults)
            } update: { _, _, searchResult, metadatas in
                guard let metadatas, !metadatas.isEmpty, self.isSearchingMode, let searchResult else { return }
                NCNetworking.shared.unifiedSearchQueue.addOperation(NCCollectionViewUnifiedSearch(collectionViewCommon: self, metadatas: metadatas, searchResult: searchResult))
            } completion: { _, _ in
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
        } else {
            NCNetworking.shared.searchFiles(urlBase: appDelegate, literal: literalSearch) { task in
                self.dataSourceTask = task
                self.collectionView.reloadData()
            } completion: { metadatas, error in
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.collectionView.reloadData()
                }
                guard let metadatas = metadatas, error == .success, self.isSearchingMode else { return }
                self.dataSource = NCDataSource(
                    metadatas: metadatas,
                    account: self.appDelegate.account,
                    sort: self.layoutForView?.sort,
                    ascending: self.layoutForView?.ascending,
                    directoryOnTop: self.layoutForView?.directoryOnTop,
                    favoriteOnTop: true,
                    groupByField: self.groupByField,
                    providers: self.providers,
                    searchResults: self.searchResults)
            }
        }
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) {

        guard let metadataForSection = metadataForSection, let lastSearchResult = metadataForSection.lastSearchResult, let cursor = lastSearchResult.cursor, let term = literalSearch else { return }

        metadataForSection.unifiedSearchInProgress = true
        self.collectionView?.reloadData()

        NCNetworking.shared.unifiedSearchFilesProvider(userBaseUrl: appDelegate, id: lastSearchResult.id, term: term, limit: 5, cursor: cursor) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
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
        guard let filesServerUrl = (tabBarController as? NCMainTabBarController)?.filesServerUrl else { return }
        let serverUrlPush = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)

        if let viewController = filesServerUrl[serverUrlPush], viewController.isViewLoaded {
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {
                viewController.isRoot = false
                viewController.serverUrl = serverUrlPush
                viewController.titlePreviusFolder = navigationItem.title
                viewController.titleCurrentFolder = metadata.fileNameView
                filesServerUrl[serverUrlPush] = viewController
                navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
}

// MARK: - E2EE

extension NCCollectionViewCommon: NCEndToEndInitializeDelegate {

    func endToEndInitializeSuccess(metadata: tableMetadata?) {
        if let metadata {
            pushMetadata(metadata)
        }
    }
}

// MARK: - Collection View

extension NCCollectionViewCommon: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }

        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            tabBarSelect.update(selectOcId: selectOcId, metadatas: getSelectedMetadatas(), userId: appDelegate.userId)
            return
        }

        if metadata.e2eEncrypted {
            if NCGlobal.shared.capabilityE2EEEnabled {
                if !NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
                    let e2ee = NCEndToEndInitialize()
                    e2ee.delegate = self
                    e2ee.initEndToEndEncryption(viewController: self.tabBarController, metadata: metadata)
                    return
                }
            } else {
                NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorE2EENotEnabled, errorDescription: "_e2e_server_disabled_"))
                return
            }
        }

        if metadata.directory {

            pushMetadata(metadata)

        } else {

            let imageIcon = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))

            if !metadata.isDirectoryE2EE && (metadata.isImage || metadata.isAudioOrVideo) {
                var metadatas: [tableMetadata] = []
                for metadata in dataSource.getMetadataSourceForAllSections() {
                    if metadata.isImage || metadata.isAudioOrVideo {
                        metadatas.append(metadata)
                    }
                }
                NCViewer().view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: imageIcon)
                return
            }

            if utilityFileSystem.fileProviderStorageExists(metadata) {
                NCViewer().view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
            } else if NextcloudKit.shared.isNetworkReachable(),
                      let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                               session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                               selector: NCGlobal.shared.selectorLoadFileView,
                                                                                               sceneIdentifier: (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier) {
                NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
            } else {
                let error = NKError(errorCode: NCGlobal.shared.errorOffline, errorDescription: "_go_online_")
                NCContentPresenter().showInfo(error: error)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return nil }
        if isEditMode || metadata.classFile == NKCommon.TypeClassFile.url.rawValue { return nil }

        let identifier = indexPath as NSCopying
        var image: UIImage?
        let cell = collectionView.cellForItem(at: indexPath)
        if cell is NCListCell {
            image = (cell as? NCListCell)?.imageItem.image
        } else if cell is NCGridCell {
            image = (cell as? NCGridCell)?.imageItem.image
        }

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

extension NCCollectionViewCommon: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath),
              let cell = (cell as? NCCellProtocol) else { return }
        let existsIcon = utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)

        func downloadAvatar(fileName: String, user: String, dispalyName: String?) {
            if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
                cell.fileAvatarImageView?.contentMode = .scaleAspectFill
                cell.fileAvatarImageView?.image = image
            } else {
                NCNetworking.shared.downloadAvatar(user: user, dispalyName: dispalyName, fileName: fileName, cell: cell, view: collectionView)
            }
        }
        /// CONTENT MODE
        cell.filePreviewImageView?.layer.borderWidth = 0
        if existsIcon {
            cell.filePreviewImageView?.contentMode = .scaleAspectFill
        } else {
            cell.filePreviewImageView?.contentMode = .scaleAspectFit
        }
        cell.fileAvatarImageView?.contentMode = .center

        /// THUMBNAIL
        if !metadata.directory {
            if metadata.hasPreviewBorder {
                cell.filePreviewImageView?.layer.borderWidth = 0.2
                cell.filePreviewImageView?.layer.borderColor = UIColor.lightGray.cgColor
            }
            if metadata.name == NCGlobal.shared.appName {
                if let image = NCImageCache.shared.getIconImage(ocId: metadata.ocId, etag: metadata.etag) {
                    cell.filePreviewImageView?.image = image
                } else if let image = utility.createFilePreviewImage(ocId: metadata.ocId, etag: metadata.etag, fileNameView: metadata.fileNameView, classFile: metadata.classFile, status: metadata.status, createPreviewMedia: !metadata.hasPreview) {
                    let fileNamePathIcon = utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
                    let fileSizeIcon = self.utilityFileSystem.getFileSize(filePath: fileNamePathIcon)
                    if NCImageCache.shared.hasIconImageEnoughSize(fileSizeIcon) {
                        NCImageCache.shared.setIconImage(ocId: metadata.ocId, etag: metadata.etag, image: image)
                    }
                    cell.filePreviewImageView?.image = image
                } else {
                    if metadata.iconName.isEmpty {
                        cell.filePreviewImageView?.image = NCImageCache.images.file
                    } else {
                        cell.filePreviewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true)
                    }
                    if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && !existsIcon {
                        for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId { return }
                        NCNetworking.shared.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, cell: cell, collectionView: collectionView))
                    }
                }
            } else {
                /// APP NAME - UNIFIED SEARCH
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconContacts
                case let str where str.contains("conversation"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconTalk
                case let str where str.contains("calendar"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconCalendar
                case let str where str.contains("deck"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconDeck
                case let str where str.contains("mail"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconMail
                case let str where str.contains("talk"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconTalk
                case let str where str.contains("confirm"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconConfirm
                case let str where str.contains("pages"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconPages
                default:
                    cell.filePreviewImageView?.image = NCImageCache.images.iconFile
                }
                if !metadata.iconUrl.isEmpty {
                    if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                        let fileName = metadata.userBaseUrl + "-" + ownerId + ".png"
                        downloadAvatar(fileName: fileName, user: ownerId, dispalyName: nil)
                    }
                }
            }
        }

        /// AVATAR
        if !metadata.ownerId.isEmpty,
           metadata.ownerId != appDelegate.userId,
           appDelegate.account == metadata.account {
            let fileName = metadata.userBaseUrl + "-" + metadata.ownerId + ".png"
            downloadAvatar(fileName: fileName, user: metadata.ownerId, dispalyName: metadata.ownerDisplayName)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
            for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: NCCellProtocol & UICollectionViewCell
        let permissions = NCPermissions()

        // LAYOUT LIST
        if layoutForView?.layout == NCGlobal.shared.layoutList {
            guard let listCell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell else { return NCListCell() }
            listCell.listCellDelegate = self
            cell = listCell
        } else {
        // LAYOUT GRID
            guard let gridCell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell else { return NCGridCell() }
            gridCell.gridCellDelegate = self
            cell = gridCell
        }

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return cell }

        defer {
            if NCGlobal.shared.disableSharesView || !metadata.isSharable() {
                cell.hideButtonShare(true)
            }
        }

        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder!.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder!.permissions.contains(permissions.permissionMounted)
        }

        cell.fileSelectImage?.image = nil
        cell.fileStatusImage?.image = nil
        cell.fileLocalImage?.image = nil
        cell.fileFavoriteImage?.image = nil
        cell.fileSharedImage?.image = nil
        cell.fileMoreImage?.image = nil
        cell.filePreviewImageView?.image = nil
        cell.filePreviewImageView?.backgroundColor = nil
        cell.fileObjectId = metadata.ocId
        cell.indexPath = indexPath
        cell.fileUser = metadata.ownerId
        cell.fileProgressView?.isHidden = true
        cell.fileProgressView?.progress = 0.0
        cell.hideButtonShare(false)
        cell.hideButtonMore(false)
        cell.titleInfoTrailingDefault()

        if isSearchingMode {
            cell.fileTitleLabel?.text = metadata.fileName
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingTail
            if metadata.name == NCGlobal.shared.appName {
                cell.fileInfoLabel?.text = NSLocalizedString("_in_", comment: "") + " " + utilityFileSystem.getPath(path: metadata.path, user: metadata.user)
            } else {
                cell.fileInfoLabel?.text = metadata.subline
            }
            cell.fileSubinfoLabel?.isHidden = true
        } else {
            cell.fileSubinfoLabel?.isHidden = false
            cell.fileTitleLabel?.text = metadata.fileNameView
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingMiddle
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        if metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusUploading {
            cell.fileProgressView?.isHidden = false
        }

        // Accessibility [shared]
        if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
            let tableDirectory = NCManageDatabase.shared.getTableDirectory(ocId: metadata.ocId)
            if metadata.e2eEncrypted {
                cell.filePreviewImageView?.image = NCImageCache.images.folderEncrypted
            } else if isShare {
                cell.filePreviewImageView?.image = NCImageCache.images.folderSharedWithMe
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(3) ?
                (cell.filePreviewImageView?.image = NCImageCache.images.folderPublic) :
                (cell.filePreviewImageView?.image = NCImageCache.images.folderSharedWithMe)
            } else if !metadata.shareType.isEmpty && metadata.shareType.contains(3) {
                cell.filePreviewImageView?.image = NCImageCache.images.folderPublic
            } else if metadata.mountType == "group" {
                cell.filePreviewImageView?.image = NCImageCache.images.folderGroup
            } else if isMounted {
                cell.filePreviewImageView?.image = NCImageCache.images.folderExternal
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.filePreviewImageView?.image = NCImageCache.images.folderAutomaticUpload
            } else {
                cell.filePreviewImageView?.image = NCImageCache.images.folder
            }

            // Local image: offline
            if let tableDirectory, tableDirectory.offline {
                cell.fileLocalImage?.image = NCImageCache.images.offlineFlag
            }

            // color folder
            cell.filePreviewImageView?.image = cell.filePreviewImageView?.image?.colorizeFolder(metadata: metadata, tableDirectory: tableDirectory)

        } else {

            let tableLocalFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))?.first

            // image local
            if let tableLocalFile, tableLocalFile.offline {
                a11yValues.append(NSLocalizedString("_offline_", comment: ""))
                cell.fileLocalImage?.image = NCImageCache.images.offlineFlag
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.fileLocalImage?.image = NCImageCache.images.local
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.fileFavoriteImage?.image = NCImageCache.images.favorite
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Share image
        if isShare {
            cell.fileSharedImage?.image = NCImageCache.images.shared
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(3) ?
            (cell.fileSharedImage?.image = NCImageCache.images.shareByLink) :
            (cell.fileSharedImage?.image = NCImageCache.images.shared)
        } else {
            cell.fileSharedImage?.image = NCImageCache.images.canShare
        }
        if appDelegate.account != metadata.account {
            cell.fileSharedImage?.image = NCImageCache.images.shared
        }

        // Button More
        if metadata.isInTransfer || metadata.isWaitingTransfer {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCImageCache.images.buttonStop)
        } else if metadata.lock == true {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreLock, image: NCImageCache.images.buttonMoreLock)
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCImageCache.images.buttonMore)
        }

        // Write status on Label Info
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + NSLocalizedString("_status_wait_download_", comment: "")
        case NCGlobal.shared.metadataStatusDownloading:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + "↓ …"
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + NSLocalizedString("_status_wait_upload_", comment: "")
            cell.fileLocalImage?.image = nil
        case NCGlobal.shared.metadataStatusUploading:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + "↑ …"
            cell.fileLocalImage?.image = nil
        case NCGlobal.shared.metadataStatusUploadError:
            if metadata.sessionError.isEmpty {
                cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_upload_", comment: "")
            } else {
                cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_upload_", comment: "") + " " + metadata.sessionError
            }
        default:
            break
        }

        // Live Photo
        if metadata.isLivePhoto {
            cell.fileStatusImage?.image = NCImageCache.images.livePhoto
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        }

        // URL
        if metadata.classFile == NKCommon.TypeClassFile.url.rawValue {
            cell.fileLocalImage?.image = nil
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
            if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                cell.fileUser = ownerId
            }
        }

        // Separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 || isSearchingMode {
            cell.cellSeparatorView?.isHidden = true
        } else {
            cell.cellSeparatorView?.isHidden = false
        }

        // Edit mode
        if isEditMode {
            cell.selectMode(true)
            if selectOcId.contains(metadata.ocId) {
                cell.selected(true)
                a11yValues.append(NSLocalizedString("_selected_", comment: ""))
            } else {
                cell.selected(false)
            }
        } else {
            cell.selectMode(false)
        }

        // Accessibility
        cell.setAccessibility(label: metadata.fileNameView + ", " + (cell.fileInfoLabel?.text ?? "") + (cell.fileSubinfoLabel?.text ?? ""), value: a11yValues.joined(separator: ", "))

        // Color string find in search

        cell.fileTitleLabel?.textColor = NCBrandColor.shared.textColor
        cell.fileTitleLabel?.font = .systemFont(ofSize: 15)

        if isSearchingMode, let literalSearch = self.literalSearch, let title = cell.fileTitleLabel?.text {
            let longestWordRange = (title.lowercased() as NSString).range(of: literalSearch)
            let attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            attributedString.setAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 15), NSAttributedString.Key.foregroundColor: UIColor.systemBlue], range: longestWordRange)
            cell.fileTitleLabel?.attributedText = attributedString
        }

        // Add TAGS
        cell.setTags(tags: Array(metadata.tags))

        // Hide buttons
        if metadata.name != NCGlobal.shared.appName {
            cell.titleInfoTrailingFull()
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        cell.setIconOutlines()

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            if dataSource.getMetadataSourceForAllSections().isEmpty {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderEmptyData", for: indexPath) as? NCSectionHeaderEmptyData else { return NCSectionHeaderEmptyData() }
                self.headerEmptyData = header
                header.delegate = self

                if !isSearchingMode, headerMenuTransferView, let ocId = NCNetworking.shared.transferInForegorund?.ocId {
                    let text = String(format: NSLocalizedString("_upload_foreground_msg_", comment: ""), NCBrandOptions.shared.brand)
                    header.setViewTransfer(isHidden: false, ocId: ocId, text: text, progress: NCNetworking.shared.transferInForegorund?.progress)
                } else {
                    header.setViewTransfer(isHidden: true)
                }

                if isSearchingMode {
                    header.emptyImage.image = utility.loadImage(named: "magnifyingglass", colors: [NCBrandColor.shared.brandElement])
                    if self.dataSourceTask?.state == .running {
                        header.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
                    } else {
                        header.emptyTitle.text = NSLocalizedString("_search_no_record_found_", comment: "")
                    }
                    header.emptyDescription.text = NSLocalizedString("_search_instruction_", comment: "")
                } else if self.dataSourceTask?.state == .running {
                    header.emptyImage.image = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.brandElement])
                    header.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
                    header.emptyDescription.text = ""
                } else {
                    if serverUrl.isEmpty {
                        header.emptyImage.image = emptyImage
                        header.emptyTitle.text = NSLocalizedString(emptyTitle, comment: "")
                        header.emptyDescription.text = NSLocalizedString(emptyDescription, comment: "")
                    } else {
                        header.emptyImage.image = NCImageCache.images.folder
                        header.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
                        header.emptyDescription.text = NSLocalizedString("_no_file_pull_down_", comment: "")
                    }
                }

                return header

            } else if indexPath.section == 0 {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as? NCSectionHeaderMenu else { return NCSectionHeaderMenu() }
                let (_, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: indexPath.section)
                self.headerMenu = header
                header.delegate = self

                if !isSearchingMode, headerMenuTransferView, let ocId = NCNetworking.shared.transferInForegorund?.ocId {
                    let text = String(format: NSLocalizedString("_upload_foreground_msg_", comment: ""), NCBrandOptions.shared.brand)
                    header.setViewTransfer(isHidden: false, ocId: ocId, text: text, progress: NCNetworking.shared.transferInForegorund?.progress)
                } else {
                    header.setViewTransfer(isHidden: true)
                }

                header.setRichWorkspaceHeight(heightHeaderRichWorkspace)
                header.setRichWorkspaceText(richWorkspaceText)

                header.setSectionHeight(heightHeaderSection)
                if heightHeaderSection == 0 {
                    header.labelSection.text = ""
                } else {
                    header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                }
                header.labelSection.textColor = NCBrandColor.shared.textColor

                return header

            } else {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as? NCSectionHeader else { return NCSectionHeader() }

                header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                header.labelSection.textColor = NCBrandColor.shared.textColor

                return header
            }

        } else {

            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return NCSectionFooter() }
            let sections = dataSource.numberOfSections()
            let section = indexPath.section
            let metadataForSection = self.dataSource.getMetadataForSection(indexPath.section)
            let isPaginated = metadataForSection?.lastSearchResult?.isPaginated ?? false
            let metadatasCount: Int = metadataForSection?.metadatas.count ?? 0
            let unifiedSearchInProgress = metadataForSection?.unifiedSearchInProgress ?? false

            footer.delegate = self
            footer.metadataForSection = metadataForSection

            footer.setTitleLabel("")
            footer.setButtonText(NSLocalizedString("_show_more_results_", comment: ""))
            footer.separatorIsHidden(true)
            footer.buttonIsHidden(true)
            footer.hideActivityIndicatorSection()

            if isSearchingMode {
                if sections > 1 && section != sections - 1 {
                    footer.separatorIsHidden(false)
                }

                // If the number of entries(metadatas) is lower than the cursor, then there are no more entries.
                // The blind spot in this is when the number of entries is the same as the cursor. If so, we don't have a way of knowing if there are no more entries.
                // This is as good as it gets for determining last page without server-side flag.
                let isLastPage = (metadatasCount < metadataForSection?.lastSearchResult?.cursor ?? 0) || metadataForSection?.lastSearchResult?.entries.isEmpty == true

                if isSearchingMode && isPaginated && metadatasCount > 0 && !isLastPage {
                    footer.buttonIsHidden(false)
                }

                if unifiedSearchInProgress {
                    footer.showActivityIndicatorSection()
                }
            } else {
                if sections == 1 || section == sections - 1 {
                    let info = dataSource.getFooterInformationAllMetadatas()
                    footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size)
                } else {
                    footer.separatorIsHidden(false)
                }
            }

            return footer
        }
    }
}

extension NCCollectionViewCommon: UICollectionViewDelegateFlowLayout {

    func isHeaderMenuTransferViewEnabled() -> Bool {
        if headerMenuTransferView, let metadata = NCManageDatabase.shared.getMetadataFromOcId(NCNetworking.shared.transferInForegorund?.ocId), metadata.isTransferInForeground {
            return true
        }
        return false
    }

    func getHeaderHeight() -> CGFloat {
        var size: CGFloat = 0

        if isHeaderMenuTransferViewEnabled() {
            if !isSearchingMode {
                size += NCGlobal.shared.heightHeaderTransfer
            }
        } else {
            NCNetworking.shared.transferInForegorund = nil
        }

        return size
    }

    func getHeaderHeight(section: Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {
        var headerRichWorkspace: CGFloat = 0

        if let richWorkspaceText = richWorkspaceText, showDescription {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !isSearchingMode {
                headerRichWorkspace = UIScreen.main.bounds.size.height / 6
            }
        }

        if isSearchingMode || layoutForView?.layout == NCGlobal.shared.layoutGrid || dataSource.numberOfSections() > 1 {
            if section == 0 {
                return (getHeaderHeight(), headerRichWorkspace, NCGlobal.shared.heightSection)
            } else {
                return (0, 0, NCGlobal.shared.heightSection)
            }
        } else {
            return (getHeaderHeight(), headerRichWorkspace, 0)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height: CGFloat = 0
        if isEditMode {
            return CGSize.zero
        } else if dataSource.getMetadataSourceForAllSections().isEmpty {
            height = NCGlobal.shared.getHeightHeaderEmptyData(view: view, portraitOffset: emptyDataPortaitOffset, landscapeOffset: emptyDataLandscapeOffset, isHeaderMenuTransferViewEnabled: isHeaderMenuTransferViewEnabled())
        } else {
            let (heightHeaderCommands, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: section)
            height = heightHeaderCommands + heightHeaderRichWorkspace + heightHeaderSection
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = dataSource.numberOfSections()
        let metadataForSection = self.dataSource.getMetadataForSection(section)
        let isPaginated = metadataForSection?.lastSearchResult?.isPaginated ?? false
        let metadatasCount: Int = metadataForSection?.lastSearchResult?.entries.count ?? 0
        var size = CGSize(width: collectionView.frame.width, height: 0)

        if section == sections - 1 {
            size.height += NCGlobal.shared.endHeightFooter
        } else {
            size.height += NCGlobal.shared.heightFooter
        }

        if isSearchingMode && isPaginated && metadatasCount > 0 {
            size.height += NCGlobal.shared.heightFooterButton
        }

        return size
    }
}

extension NCCollectionViewCommon: EasyTipViewDelegate {
    func showTip() {
        guard !appDelegate.account.isEmpty,
              self is NCFiles,
              self.view.window != nil,
              !NCBrandOptions.shared.disable_multiaccount,
              self.serverUrl == utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId),
              let view = self.navigationItem.leftBarButtonItem?.customView,
              !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest) else { return }

        var preferences = EasyTipView.Preferences()
        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = NCBrandColor.shared.nextcloud
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .top
        preferences.drawing.cornerRadius = 10

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 1.5
        preferences.animating.dismissDuration = 1.5

        if appDelegate.tipView == nil {
            appDelegate.tipView = EasyTipView(text: NSLocalizedString("_tip_accountrequest_", comment: ""), preferences: preferences, delegate: self)
            appDelegate.tipView?.show(forView: view)
        }
    }

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest) {
            NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest)
        }
        appDelegate.tipView?.dismiss()
        appDelegate.tipView = nil
    }
}

extension NCCollectionViewCommon {

    func getAvatarFromIconUrl(metadata: tableMetadata) -> String? {

        var ownerId: String?
        if metadata.iconUrl.contains("http") && metadata.iconUrl.contains("avatar") {
            let splitIconUrl = metadata.iconUrl.components(separatedBy: "/")
            var found: Bool = false
            for item in splitIconUrl {
                if found {
                    ownerId = item
                    break
                }
                if item == "avatar" { found = true}
            }
        }
        return ownerId
    }

    // MARK: - Cancel (Download Upload)

    // sessionIdentifierDownload: String = "com.nextcloud.nextcloudkit.session.download"
    // sessionIdentifierUpload: String = "com.nextcloud.nextcloudkit.session.upload"

    // sessionUploadBackground: String = "com.nextcloud.session.upload.background"
    // sessionUploadBackgroundWWan: String = "com.nextcloud.session.upload.backgroundWWan"
    // sessionUploadBackgroundExtension: String = "com.nextcloud.session.upload.extension"

    func cancelSession(metadata: tableMetadata) async {

        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

        // No session found
        if metadata.session.isEmpty {
            NCNetworking.shared.uploadRequest.removeValue(forKey: fileNameLocalPath)
            NCNetworking.shared.downloadRequest.removeValue(forKey: fileNameLocalPath)
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            return
        }

        // DOWNLOAD FOREGROUND
        if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload {
            if let request = NCNetworking.shared.downloadRequest[fileNameLocalPath] {
                request.cancel()
            } else if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal)
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile),
                                                object: nil,
                                                userInfo: ["ocId": metadata.ocId,
                                                           "serverUrl": metadata.serverUrl,
                                                           "account": metadata.account])
            }
            return
        }

        // DOWNLOAD BACKGROUND
        if metadata.session == NCNetworking.shared.sessionDownloadBackground {
            let session: URLSession? = NCNetworking.shared.sessionManagerDownloadBackground
            if let tasks = await session?.tasks {
                for task in tasks.2 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if task.taskIdentifier == metadata.sessionTaskIdentifier {
                        task.cancel()
                    }
                }
            }
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       session: "",
                                                       sessionError: "",
                                                       selector: "",
                                                       status: NCGlobal.shared.metadataStatusNormal)
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account])
        }

        // UPLOAD FOREGROUND
        if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload {
            if let request = NCNetworking.shared.uploadRequest[fileNameLocalPath] {
                request.cancel()
                NCNetworking.shared.uploadRequest.removeValue(forKey: fileNameLocalPath)
            }
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account])
            return
        }

        // UPLOAD BACKGROUND
        var session: URLSession?
        if metadata.session == NCNetworking.shared.sessionUploadBackground {
            session = NCNetworking.shared.sessionManagerUploadBackground
        } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan {
            session = NCNetworking.shared.sessionManagerUploadBackgroundWWan
        }
        if let tasks = await session?.tasks {
            for task in tasks.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                if task.taskIdentifier == metadata.sessionTaskIdentifier {
                    task.cancel()
                }
            }
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account])
        }
    }
}

// MARK: -

private class AccountSwitcherButton: UIButton {
    var onMenuOpened: (() -> Void)?

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        onMenuOpened?()
    }
}
