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
import Realm
import NextcloudKit
import EasyTipView
import JGProgressHUD
import Queuer

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, NCSectionFooterDelegate, UIAdaptivePresentationControllerDelegate, NCEmptyDataSetDelegate, UIContextMenuInteractionDelegate, NCAccountRequestDelegate, NCSelectableNavigationView {

    @IBOutlet weak var collectionView: UICollectionView!

    internal let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    internal let utilityFileSystem = NCUtilityFileSystem()
    internal let utility = NCUtility()
    internal let refreshControl = UIRefreshControl()
    internal var searchController: UISearchController?
    internal var emptyDataSet: NCEmptyDataSet?
    internal var backgroundImageView = UIImageView()
    internal var serverUrl: String = ""
    internal var isEditMode = false
    internal var selectOcId: [String] = []
    internal var selectIndexPath: [IndexPath] = []
    internal var metadataFolder: tableMetadata?
    internal var dataSource = NCDataSource()
    internal var richWorkspaceText: String?
    internal var headerMenu: NCSectionHeaderMenu?
    internal var isSearchingMode: Bool = false

    internal var layoutForView: NCDBLayoutForView?
    internal var selectableDataSource: [RealmSwiftObject] { dataSource.getMetadataSourceForAllSections() }

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    internal var groupByField = "name"
    internal var providers: [NKSearchProvider]?
    internal var searchResults: [NKSearchResult]?

    internal var listLayout: NCListLayout!
    internal var gridLayout: NCGridLayout!

    internal var literalSearch: String?

    internal var isReloadDataSourceNetworkInProgress: Bool = false

    private var pushed: Bool = false

    private var tipView: EasyTipView?
    private var isTransitioning: Bool = false
    // DECLARE
    internal var layoutKey = ""
    internal var titleCurrentFolder = ""
    internal var titlePreviusFolder: String?
    internal var enableSearchBar: Bool = false
    internal var headerMenuTransferView = false
    internal var headerMenuButtonsView: Bool = true
    internal var headerRichWorkspaceDisable: Bool = false
    internal var emptyImage: UIImage?
    internal var emptyTitle: String = ""
    internal var emptyDescription: String = ""

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.presentationController?.delegate = self

        // CollectionView & layout
        collectionView.alwaysBounceVertical = true
        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Color
        view.backgroundColor = .systemBackground
        collectionView.backgroundColor = .systemBackground
        refreshControl.tintColor = .gray

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

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        // Refresh Control
        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            self.dataSource.clearDirectory()
            self.reloadDataSourceNetwork(isForced: true)
        }

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: getHeaderHeight(), delegate: self)

        // Long Press on CollectionView
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressCollecationView(_:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)

        // TIP
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

        tipView = EasyTipView(text: NSLocalizedString("_tip_accountrequest_", comment: ""), preferences: preferences, delegate: self)

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)
        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeRichWorkspaceWebView), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeStatusFolderE2EE(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAvatar(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSourceNetwork), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetwork), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSourceNetworkForced(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced), object: nil)

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

        if serverUrl.isEmpty {
            appDelegate.activeServerUrl = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        } else {
            appDelegate.activeServerUrl = serverUrl
        }

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        setNavigationItem()

        reloadDataSource()
        if !isSearchingMode {
            reloadDataSourceNetwork()
        }

        // FIXME: iPAD PDF landscape mode iOS 16
        DispatchQueue.main.async {
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetwork), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced), object: nil)

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

        pushed = false

        // REQUEST
        NCNetworking.shared.cancelUnifiedSearchFiles()

        // TIP
        self.tipView?.dismiss()
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {

        let viewController = presentationController.presentedViewController
        if viewController is NCViewerRichWorkspaceWebView {
            closeRichWorkspaceWebView()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.collectionView?.collectionViewLayout.invalidateLayout()
        self.collectionView?.reloadData()
        self.tipView?.dismiss()

        coordinator.animate(alongsideTransition: nil) { _ in
            self.showTip()
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
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
              error.errorCode != NCGlobal.shared.errorNotModified else { return }

        setNavigationItem()
    }

    @objc func changeTheming() {
        collectionView.reloadData()
    }

    @objc func reloadDataSource(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func reloadDataSourceNetworkForced(_ notification: NSNotification) {

        if !isSearchingMode {
            reloadDataSourceNetwork(isForced: true)
        }
    }

    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func closeRichWorkspaceWebView() {
        reloadDataSourceNetwork()
    }

    @objc func deleteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        self.queryDB(isForced: true)
        self.collectionView?.reloadData()

        if error != .success {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        deleteFile(notification)
    }

    @objc func copyFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error != .success {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func renameFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        reloadDataSourceNetwork(isForced: true)
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

        reloadDataSource()

        if withPush, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            pushMetadata(metadata)
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {

        if self is NCFavorite {
            return reloadDataSource()
        }

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl
        else { return }

        dataSource.reloadMetadata(ocId: ocId) {
            self.collectionView?.reloadData()
        }
    }

    @objc func downloadStartFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let account = userInfo["account"] as? String,
              account == appDelegate.account,
              let ocId = userInfo["ocId"] as? String
        else { return }

        dataSource.reloadMetadata(ocId: ocId) {
            self.collectionView?.reloadData()
        }
    }

    @objc func downloadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let account = userInfo["account"] as? String,
              account == appDelegate.account,
              let ocId = userInfo["ocId"] as? String
        else { return }

        dataSource.reloadMetadata(ocId: ocId) {
            self.collectionView?.reloadData()
        }
    }

    @objc func downloadCancelFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        dataSource.reloadMetadata(ocId: ocId) {
            self.collectionView?.reloadData()
        }
    }

    @objc func uploadStartFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        guard !isSearchingMode, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }

        // Header view trasfer
        if metadata.isTransferInForeground {
            NCNetworking.shared.transferInForegorund = NCNetworking.TransferInForegorund(ocId: ocId, progress: 0)
            self.collectionView?.reloadData()
        }

        if serverUrl == self.serverUrl, account == appDelegate.account {
            reloadDataSource()
        }
    }

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocIdTemp = userInfo["ocIdTemp"] as? String,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if ocIdTemp == NCNetworking.shared.transferInForegorund?.ocId {
            NCNetworking.shared.transferInForegorund = nil
            self.collectionView?.reloadData()
        }

        if account == appDelegate.account, serverUrl == self.serverUrl {
            dataSource.reloadMetadata(ocId: ocId, ocIdTemp: ocIdTemp) {
                self.collectionView?.reloadData()
            }
        }
    }

    @objc func uploadedLivePhoto(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        self.reloadDataSource()
    }

    @objc func uploadCancelFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if ocId == NCNetworking.shared.transferInForegorund?.ocId {
            NCNetworking.shared.transferInForegorund = nil
            self.collectionView?.reloadData()
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

        DispatchQueue.global().async {
            let chunk: Int = userInfo["chunk"] as? Int ?? 0
            let e2eEncrypted: Bool = userInfo["e2eEncrypted"] as? Bool ?? false

            // Header Transfer
            if self.headerMenuTransferView && (chunk > 0 || e2eEncrypted) {
                if NCNetworking.shared.transferInForegorund?.ocId == ocId {
                    NCNetworking.shared.transferInForegorund?.progress = progressNumber.floatValue
                } else {
                    NCNetworking.shared.transferInForegorund = NCNetworking.TransferInForegorund(ocId: ocId, progress: progressNumber.floatValue)
                    DispatchQueue.main.async { self.collectionView.reloadData() }
                }
                self.headerMenu?.progressTransfer.progress = progressNumber.floatValue
            }

            let status = userInfo["status"] as? Int ?? NCGlobal.shared.metadataStatusNormal
            guard let indexPath = self.dataSource.getIndexPathMetadata(ocId: ocId).indexPath else { return }

            DispatchQueue.main.async {
                guard let cell = self.collectionView?.cellForItem(at: indexPath),
                      let cell = cell as? NCCellProtocol else { return }

                if progressNumber.floatValue == 1 && !(cell is NCTransferCell) {
                    cell.fileProgressView?.isHidden = true
                    cell.fileProgressView?.progress = .zero
                    cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCImageCache.images.buttonMore)
                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                        cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
                    } else {
                        cell.fileInfoLabel?.text = ""
                    }
                } else {
                    cell.fileProgressView?.isHidden = false
                    cell.fileProgressView?.progress = progressNumber.floatValue
                    cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCImageCache.images.buttonStop)
                    if status == NCGlobal.shared.metadataStatusInDownload {
                        cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected) + " - ↓ " + self.utilityFileSystem.transformedSize(totalBytes)
                    } else if status == NCGlobal.shared.metadataStatusInUpload {
                        if totalBytes > 0 {
                            cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected) + " - ↑ " + self.utilityFileSystem.transformedSize(totalBytes)
                        } else {
                            cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected) + " - ↑ …"
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tip

    func showTip() {

        if self is NCFiles, self.view.window != nil, !NCBrandOptions.shared.disable_multiaccount, !NCBrandOptions.shared.disable_manage_account, self.serverUrl == utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId), let view = self.navigationItem.leftBarButtonItem?.customView {
            if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest), !NCManageDatabase.shared.getAllAccountOrderAlias().isEmpty {
                self.tipView?.show(forView: view)
            }
        }
    }

    // MARK: - Layout

    func setNavigationItem() {

        self.setNavigationRightItems()
        navigationItem.title = titleCurrentFolder

        guard layoutKey == NCGlobal.shared.layoutViewFiles else { return }

        // PROFILE BUTTON

        let activeAccount = NCManageDatabase.shared.getActiveAccount()

        let image = utility.loadUserImage(
            for: appDelegate.user,
               displayName: activeAccount?.displayName,
               userBaseUrl: appDelegate)

        let button = UIButton(type: .custom)
        button.setImage(image, for: .normal)

        if serverUrl == utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) {

            var titleButton = "  "

            if getNavigationTitle() == activeAccount?.alias {
                titleButton = ""
            } else {
                titleButton += activeAccount?.displayName ?? ""
            }

            button.setTitle(titleButton, for: .normal)
            button.setTitleColor(.systemBlue, for: .normal)
        }

        button.semanticContentAttribute = .forceLeftToRight
        button.sizeToFit()
        button.action(for: .touchUpInside) { _ in

            let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
            if !accounts.isEmpty, !NCBrandOptions.shared.disable_multiaccount, !NCBrandOptions.shared.disable_manage_account {

                if let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {

                    vcAccountRequest.activeAccount = NCManageDatabase.shared.getActiveAccount()
                    vcAccountRequest.accounts = accounts
                    vcAccountRequest.enableTimerProgress = false
                    vcAccountRequest.enableAddAccount = true
                    vcAccountRequest.delegate = self
                    vcAccountRequest.dismissDidEnterBackground = true

                    let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
                    let numberCell = accounts.count + 1
                    let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)

                    let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height)

                    self.present(popup, animated: true)
                }

                // TIP
                self.dismissTip()
            }
        }
        navigationItem.setLeftBarButton(UIBarButtonItem(customView: button), animated: true)
        navigationItem.leftItemsSupplementBackButton = true
        if titlePreviusFolder == nil {
            navigationController?.navigationBar.topItem?.title = getNavigationTitle()
        } else {
            navigationController?.navigationBar.topItem?.title = titlePreviusFolder
        }
        navigationItem.title = titleCurrentFolder
    }

    func getNavigationTitle() -> String {

        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        guard let userAlias = activeAccount?.alias, !userAlias.isEmpty else {
            return NCBrandOptions.shared.brand
        }
        return userAlias
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        self.emptyDataSet?.setOffset(getHeaderHeight())
        if isSearchingMode {
            view.emptyImage.image = UIImage(named: "search")?.image(color: .gray, size: UIScreen.main.bounds.width)
            if isReloadDataSourceNetworkInProgress {
                view.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
            } else {
                view.emptyTitle.text = NSLocalizedString("_search_no_record_found_", comment: "")
            }
            view.emptyDescription.text = NSLocalizedString("_search_instruction_", comment: "")
        } else if isReloadDataSourceNetworkInProgress {
            view.emptyImage.image = UIImage(named: "networkInProgress")?.image(color: .gray, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
            view.emptyDescription.text = ""
        } else {
            if serverUrl.isEmpty {
                view.emptyImage.image = emptyImage
                view.emptyTitle.text = NSLocalizedString(emptyTitle, comment: "")
                view.emptyDescription.text = NSLocalizedString(emptyDescription, comment: "")
            } else {
                view.emptyImage.image = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
                view.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
                view.emptyDescription.text = NSLocalizedString("_no_file_pull_down_", comment: "")
            }
        }
    }

    // MARK: - SEARCH

    func updateSearchResults(for searchController: UISearchController) {
        self.literalSearch = searchController.searchBar.text
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {

        isSearchingMode = true
        self.providers?.removeAll()
        self.dataSource.clearDataSource()
        self.collectionView.reloadData()

        // TIP
        self.tipView?.dismiss()
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

    func accountRequestChangeAccount(account: String) {

        appDelegate.changeAccount(account, userProfile: nil)
    }

    func accountRequestAddAccount() {
        appDelegate.openLogin(viewController: self, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
    }

    func tapButtonSwitch(_ sender: Any) {

        guard isTransitioning == false else { return }
        isTransitioning = true

        if layoutForView?.layout == NCGlobal.shared.layoutGrid {

            // list layout
            headerMenu?.buttonSwitch.accessibilityLabel = NSLocalizedString("_grid_view_", comment: "")
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
            self.groupByField = "name"
            if self.dataSource.groupByField != self.groupByField {
                self.dataSource.changeGroupByField(self.groupByField)
            }

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.listLayout, animated: true) {_ in self.isTransitioning = false }
        } else {

            // grid layout
            headerMenu?.buttonSwitch.accessibilityLabel = NSLocalizedString("_list_view_", comment: "")
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
            if isSearchingMode {
                self.groupByField = "name"
            } else {
                self.groupByField = "classFile"
            }
            if self.dataSource.groupByField != self.groupByField {
                self.dataSource.changeGroupByField(self.groupByField)
            }

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true) {_ in self.isTransitioning = false }
        }
    }

    func tapButtonOrder(_ sender: Any) {

        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, account: appDelegate.account, key: layoutKey, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }

    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
        tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, image: image, indexPath: indexPath, sender: sender)
    }

    func tapShareListItem(with objectId: String, indexPath: IndexPath, sender: Any) {

        if isEditMode { return }
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        NCActionCenter.shared.openShare(viewController: self, metadata: metadata, page: .sharing)
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {

        if isEditMode { return }

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        if namedButtonMore == NCGlobal.shared.buttonMoreMore || namedButtonMore == NCGlobal.shared.buttonMoreLock {
            toggleMenu(metadata: metadata, indexPath: indexPath, imageIcon: image)
        } else if namedButtonMore == NCGlobal.shared.buttonMoreStop {
            Task {
                await NCNetworking.shared.cancel(metadata: metadata)
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
                await NCNetworking.shared.cancel(metadata: metadata)
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
        }
        return false
    }

    @objc func pasteFilesMenu() {
        NCActionCenter.shared.pastePasteboard(serverUrl: serverUrl)
    }

    // MARK: - DataSource + NC Endpoint

    func queryDB(isForced: Bool) { }

    @objc func reloadDataSource(isForced: Bool = true) {
        guard !appDelegate.account.isEmpty else { return }

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
    }

    @objc func reloadDataSourceNetwork(isForced: Bool = false) { }

    @objc func networkSearch() {
        guard !appDelegate.account.isEmpty, let literalSearch = literalSearch, !literalSearch.isEmpty
        else {
            self.refreshControl.endRefreshing()
            return
        }

        isReloadDataSourceNetworkInProgress = true
        self.dataSource.clearDataSource()
        self.refreshControl.beginRefreshing()
        self.collectionView.reloadData()

        if NCGlobal.shared.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion20 {
            NCNetworking.shared.unifiedSearchFiles(userBaseUrl: appDelegate, literal: literalSearch) { _, searchProviders in
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
                NCNetworking.shared.unifiedSearchQueue.addOperation(NCOperationUnifiedSearch(collectionViewCommon: self, metadatas: metadatas, searchResult: searchResult))
            } completion: { _, _ in
                self.refreshControl.endRefreshing()
                self.isReloadDataSourceNetworkInProgress = false
                self.collectionView.reloadData()
            }
        } else {
            NCNetworking.shared.searchFiles(urlBase: appDelegate, literal: literalSearch) { metadatas, error in
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
                self.isReloadDataSourceNetworkInProgress = false
            }
        }
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) {

        guard let metadataForSection = metadataForSection, let lastSearchResult = metadataForSection.lastSearchResult, let cursor = lastSearchResult.cursor, let term = literalSearch else { return }

        metadataForSection.unifiedSearchInProgress = true
        self.collectionView?.reloadData()

        NCNetworking.shared.unifiedSearchFilesProvider(userBaseUrl: appDelegate, id: lastSearchResult.id, term: term, limit: 5, cursor: cursor) { _, searchResult, metadatas, error in
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

    @objc func networkReadFolder(isForced: Bool, completion: @escaping(_ tableDirectory: tableDirectory?, _ metadatas: [tableMetadata]?, _ metadatasChangedCount: Int, _ metadatasChanged: Bool, _ error: NKError) -> Void) {

        var tableDirectory: tableDirectory?

        NCNetworking.shared.readFile(serverUrlFileName: serverUrl) { account, metadataFolder, error in
            guard error == .success else {
                completion(nil, nil, 0, false, error)
                return
            }

            if let metadataFolder = metadataFolder {
                tableDirectory = NCManageDatabase.shared.setDirectory(serverUrl: self.serverUrl, richWorkspace: metadataFolder.richWorkspace, account: account)
            }

            if isForced || tableDirectory?.etag != metadataFolder?.etag || metadataFolder?.e2eEncrypted ?? true {
                NCNetworking.shared.readFolder(serverUrl: self.serverUrl, account: self.appDelegate.account) { _, metadataFolder, metadatas, metadatasChangedCount, metadatasChanged, error in
                    guard error == .success else {
                        completion(tableDirectory, nil, 0, false, error)
                        return
                    }
                    self.metadataFolder = metadataFolder
                    // E2EE
                    if let metadataFolder = metadataFolder,
                       metadataFolder.e2eEncrypted,
                       NCKeychain().isEndToEndEnabled(account: self.appDelegate.account),
                       !NCNetworkingE2EE().isInUpload(account: self.appDelegate.account, serverUrl: self.serverUrl) {
                        let lock = NCManageDatabase.shared.getE2ETokenLock(account: self.appDelegate.account, serverUrl: self.serverUrl)
                        NextcloudKit.shared.getE2EEMetadata(fileId: metadataFolder.ocId, e2eToken: lock?.e2eToken) { _, e2eMetadata, signature, _, error in
                            if error == .success, let e2eMetadata = e2eMetadata {
                                let error = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: signature, serverUrl: self.serverUrl, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                                if error == .success {
                                    self.reloadDataSource()
                                } else {
                                    NCContentPresenter().showError(error: error)
                                }
                            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                                // no metadata found, send a new metadata
                                Task {
                                    let serverUrl = metadataFolder.serverUrl + "/" + metadataFolder.fileName
                                    let error = await NCNetworkingE2EE().uploadMetadata(account: metadataFolder.account, serverUrl: serverUrl, userId: metadataFolder.userId)
                                    if error != .success {
                                        NCContentPresenter().showError(error: error)
                                    }
                                }
                            } else {
                                NCContentPresenter().showError(error: NKError(errorCode: NCGlobal.shared.errorE2EEKeyDecodeMetadata, errorDescription: "_e2e_error_"))
                            }
                            completion(tableDirectory, metadatas, metadatasChangedCount, metadatasChanged, error)
                        }
                    } else {
                        completion(tableDirectory, metadatas, metadatasChangedCount, metadatasChanged, error)
                    }
                }
            } else {
                completion(tableDirectory, nil, 0, false, NKError())
            }
        }
    }

    // MARK: - Push metadata

    func pushMetadata(_ metadata: tableMetadata) {

        let serverUrlPush = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
        appDelegate.activeMetadata = metadata

        if let viewController = appDelegate.listFilesVC[serverUrlPush], viewController.isViewLoaded {
            pushViewController(viewController: viewController)
        } else {
            if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {
                viewController.isRoot = false
                viewController.serverUrl = serverUrlPush
                viewController.titlePreviusFolder = navigationItem.title
                viewController.titleCurrentFolder = metadata.fileNameView
                appDelegate.listFilesVC[serverUrlPush] = viewController
                pushViewController(viewController: viewController)
            }
        }
    }
}

// MARK: - E2EE

extension NCCollectionViewCommon: NCEndToEndInitializeDelegate {

    func endToEndInitializeSuccess() {
        if let metadata = appDelegate.activeMetadata {
            pushMetadata(metadata)
        }
    }
}

// MARK: - Collection View

extension NCCollectionViewCommon: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
        appDelegate.activeMetadata = metadata
        let metadataSourceForAllSections = dataSource.getMetadataSourceForAllSections()

        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
                selectIndexPath.removeAll(where: { $0 == indexPath })
            } else {
                selectOcId.append(metadata.ocId)
                selectIndexPath.append(indexPath)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }

        if metadata.e2eEncrypted {
            if NCGlobal.shared.capabilityE2EEEnabled {
                if !NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
                    let e2ee = NCEndToEndInitialize()
                    e2ee.delegate = self
                    e2ee.initEndToEndEncryption()
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
                for metadata in metadataSourceForAllSections {
                    if metadata.isImage || metadata.isAudioOrVideo {
                        metadatas.append(metadata)
                    }
                }
                NCViewer().view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: imageIcon)
                return
            }

            if utilityFileSystem.fileProviderStorageExists(metadata) {
                NCViewer().view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
            } else if NextcloudKit.shared.isNetworkReachable() {
                NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileView) { _, _ in }
            } else {
                let error = NKError(errorCode: NCGlobal.shared.errorOffline, errorDescription: "_go_online_")
                NCContentPresenter().showInfo(error: error)
            }
        }
    }

    func pushViewController(viewController: UIViewController) {
        if pushed { return }

        pushed = true
        navigationController?.pushViewController(viewController, animated: true)
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

extension NCCollectionViewCommon: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }

        // Thumbnail
        if !metadata.directory {
            if metadata.name == NCGlobal.shared.appName {
                    if let image = utility.createFilePreviewImage(ocId: metadata.ocId, etag: metadata.etag, fileNameView: metadata.fileNameView, classFile: metadata.classFile, status: metadata.status, createPreviewMedia: !metadata.hasPreview) {
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = image
                } else {
                    if metadata.iconName.isEmpty {
                        (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.file
                    } else {
                        (cell as? NCCellProtocol)?.filePreviewImageView?.image = UIImage(named: metadata.iconName)
                    }
                    if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && (!utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)) {
                        for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId { return }
                        NCNetworking.shared.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, cell: (cell as? NCCellProtocol), collectionView: collectionView))
                    }
                }
            } else {
                // Unified search
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconContacts
                case let str where str.contains("conversation"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconTalk
                case let str where str.contains("calendar"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconCalendar
                case let str where str.contains("deck"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconDeck
                case let str where str.contains("mail"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconMail
                case let str where str.contains("talk"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconTalk
                case let str where str.contains("confirm"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconConfirm
                case let str where str.contains("pages"):
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.iconPages
                default:
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.file
                }

                if !metadata.iconUrl.isEmpty {
                    if let ownerId = getAvatarFromIconUrl(metadata: metadata), let cell = cell as? NCCellProtocol {
                        let fileName = metadata.userBaseUrl + "-" + ownerId + ".png"
                        NCNetworking.shared.downloadAvatar(user: ownerId, dispalyName: nil, fileName: fileName, cell: cell, view: collectionView, cellImageView: cell.filePreviewImageView)
                    }
                }
            }
        }

        // Avatar
        if !metadata.ownerId.isEmpty,
           metadata.ownerId != appDelegate.userId,
           appDelegate.account == metadata.account,
           let cell = cell as? NCCellProtocol {
            let fileName = metadata.userBaseUrl + "-" + metadata.ownerId + ".png"
            NCNetworking.shared.downloadAvatar(user: metadata.ownerId, dispalyName: metadata.ownerDisplayName, fileName: fileName, cell: cell, view: collectionView, cellImageView: cell.fileAvatarImageView)
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

        let numberItems = dataSource.numberOfItemsInSection(section)
        emptyDataSet?.numberOfItemsInSection(numberItems, section: section)
        return numberItems
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        var cell: NCCellProtocol & UICollectionViewCell

        // LAYOUT LIST
        if layoutForView?.layout == NCGlobal.shared.layoutList {
            guard let listCell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell else { return UICollectionViewCell() }
            listCell.delegate = self
            cell = listCell
        } else {
        // LAYOUT GRID
            guard let gridCell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell else { return UICollectionViewCell() }
            gridCell.delegate = self
            cell = gridCell
        }

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return cell }

        defer {
            if appDelegate.disableSharesView || !metadata.isSharable() {
                cell.hideButtonShare(true)
            }
        }

        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder!.permissions.contains(NCGlobal.shared.permissionShared)
            isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder!.permissions.contains(NCGlobal.shared.permissionMounted)
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
        } else {
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
            a11yValues.append(NSLocalizedString("_favorite_", comment: ""))
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
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_download_", comment: "")
        case NCGlobal.shared.metadataStatusInDownload:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_download_", comment: "")
        case NCGlobal.shared.metadataStatusDownloading:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size) + " - ↓ …"
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_upload_", comment: "")
            cell.fileLocalImage?.image = nil
        case NCGlobal.shared.metadataStatusInUpload:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_upload_", comment: "")
            cell.fileLocalImage?.image = nil
        case NCGlobal.shared.metadataStatusUploading:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size) + " - ↑ …"
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
        cell.setAccessibility(label: metadata.fileNameView + ", " + (cell.fileInfoLabel?.text ?? ""), value: a11yValues.joined(separator: ", "))

        // Color string find in search
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

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            if indexPath.section == 0 {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as? NCSectionHeaderMenu else { return UICollectionReusableView() }
                let (_, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: indexPath.section)

                self.headerMenu = header

                if layoutForView?.layout == NCGlobal.shared.layoutGrid {
                    header.setImageSwitchList()
                    header.buttonSwitch.accessibilityLabel = NSLocalizedString("_list_view_", comment: "")
                } else {
                    header.setImageSwitchGrid()
                    header.buttonSwitch.accessibilityLabel = NSLocalizedString("_grid_view_", comment: "")
                }

                header.delegate = self

                if !isSearchingMode, headerMenuTransferView, let ocId = NCNetworking.shared.transferInForegorund?.ocId {
                    let text = String(format: NSLocalizedString("_upload_foreground_msg_", comment: ""), NCBrandOptions.shared.brand)
                    header.setViewTransfer(isHidden: false, ocId: ocId, text: text, progress: NCNetworking.shared.transferInForegorund?.progress)
                } else {
                    header.setViewTransfer(isHidden: true)
                }

                if headerMenuButtonsView {
                    header.setStatusButtonsView(enable: !dataSource.getMetadataSourceForAllSections().isEmpty)
                    header.setButtonsView(height: NCGlobal.shared.heightButtonsView)
                    header.setSortedTitle(layoutForView?.titleButtonHeader ?? "")
                } else {
                    header.setButtonsView(height: 0)
                }

                header.setRichWorkspaceHeight(heightHeaderRichWorkspace)
                header.setRichWorkspaceText(richWorkspaceText)

                header.setSectionHeight(heightHeaderSection)
                if heightHeaderSection == 0 {
                    header.labelSection.text = ""
                } else {
                    header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                }
                header.labelSection.textColor = .label

                return header

            } else {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as? NCSectionHeader else { return UICollectionReusableView() }

                header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                header.labelSection.textColor = .label

                return header
            }

        } else {

            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return UICollectionReusableView() }
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

    func getHeaderHeight() -> CGFloat {

        var size: CGFloat = 0

        // transfer in progress
        if headerMenuTransferView,
           let metadata = NCManageDatabase.shared.getMetadataFromOcId(NCNetworking.shared.transferInForegorund?.ocId),
            metadata.isTransferInForeground {
            if !isSearchingMode {
                size += NCGlobal.shared.heightHeaderTransfer
            }
        } else {
            NCNetworking.shared.transferInForegorund = nil
        }

        if headerMenuButtonsView {
            size += NCGlobal.shared.heightButtonsView
        }

        return size
    }

    func getHeaderHeight(section: Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {

        var headerRichWorkspace: CGFloat = 0

        if let richWorkspaceText = richWorkspaceText, !headerRichWorkspaceDisable {
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

        let (heightHeaderCommands, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: section)
        let heightHeader = heightHeaderCommands + heightHeaderRichWorkspace + heightHeaderSection

        return CGSize(width: collectionView.frame.width, height: heightHeader)
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

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest)
        self.tipView?.dismiss()
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
}

// MARK: -

class NCOperationUnifiedSearch: ConcurrentOperation {

    var collectionViewCommon: NCCollectionViewCommon
    var metadatas: [tableMetadata]
    var searchResult: NKSearchResult

    init(collectionViewCommon: NCCollectionViewCommon, metadatas: [tableMetadata], searchResult: NKSearchResult) {
        self.collectionViewCommon = collectionViewCommon
        self.metadatas = metadatas
        self.searchResult = searchResult
    }

    func reloadDataThenPerform(_ closure: @escaping (() -> Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            CATransaction.begin()
            CATransaction.setCompletionBlock(closure)
            self.collectionViewCommon.collectionView.reloadData()
            CATransaction.commit()
        }
    }

    override func start() {

        guard !isCancelled else { return self.finish() }

        self.collectionViewCommon.dataSource.addSection(metadatas: metadatas, searchResult: searchResult)
        self.collectionViewCommon.searchResults?.append(self.searchResult)
        reloadDataThenPerform {
            self.finish()
        }
    }
}

class NCCollectionViewDownloadThumbnail: ConcurrentOperation {

    var metadata: tableMetadata
    var cell: NCCellProtocol?
    var collectionView: UICollectionView?
    var fileNamePath: String
    var fileNamePreviewLocalPath: String
    var fileNameIconLocalPath: String
    let utilityFileSystem = NCUtilityFileSystem()

    init(metadata: tableMetadata, cell: NCCellProtocol?, collectionView: UICollectionView?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.cell = cell
        self.collectionView = collectionView
        self.fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
        self.fileNamePreviewLocalPath = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        self.fileNameIconLocalPath = utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
    }

    override func start() {

        guard !isCancelled else { return self.finish() }

        var etagResource: String?
        if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            etagResource = metadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileNamePathOrFileId: fileNamePath,
                                            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                            widthPreview: NCGlobal.shared.sizePreview,
                                            heightPreview: NCGlobal.shared.sizePreview,
                                            fileNameIconLocalPath: fileNameIconLocalPath,
                                            sizeIcon: NCGlobal.shared.sizeIcon,
                                            etag: etagResource,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, _, imageIcon, _, etag, error in

            if error == .success, let image = imageIcon {
                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                DispatchQueue.main.async {
                    if self.metadata.ocId == self.cell?.fileObjectId, let filePreviewImageView = self.cell?.filePreviewImageView {
                        UIView.transition(with: filePreviewImageView,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { filePreviewImageView.image = image },
                                          completion: nil)
                    } else {
                        self.collectionView?.reloadData()
                    }
                }
            }
            self.finish()
        }
    }
}
