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
import NCCommunication

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, NCSectionFooterDelegate, UIAdaptivePresentationControllerDelegate, NCEmptyDataSetDelegate, UIContextMenuInteractionDelegate, NCAccountRequestDelegate, NCBackgroundImageColorDelegate, NCSelectableNavigationView {

    @IBOutlet weak var collectionView: UICollectionView!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    internal let refreshControl = UIRefreshControl()
    internal var searchController: UISearchController?
    internal var emptyDataSet: NCEmptyDataSet?
    internal var backgroundImageView = UIImageView()
    internal var serverUrl: String = ""
    internal var isEncryptedFolder = false
    internal var isEditMode = false
    internal var selectOcId: [String] = []
    internal var metadatasSource: [tableMetadata] = []
    internal var metadataFolder: tableMetadata?
    internal var dataSource = NCDataSource()
    internal var richWorkspaceText: String?
    internal var headerMenu: NCSectionHeaderMenu?

    internal var layoutForView: NCGlobal.layoutForViewType?
    internal var selectableDataSource: [RealmSwiftObject] { dataSource.metadatasSource }

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""

    internal var groupByField = "name"
    internal var providers: [NCCSearchProvider]?
    internal var searchResults: [NCCSearchResult]?

    internal var listLayout: NCListLayout!
    internal var gridLayout: NCGridLayout!

    internal var literalSearch: String?
    internal var isSearching: Bool = false

    internal var isReloadDataSourceNetworkInProgress: Bool = false

    private var pushed: Bool = false

    // DECLARE
    internal var layoutKey = ""
    internal var titleCurrentFolder = ""
    internal var enableSearchBar: Bool = false
    internal var headerMenuButtonsCommand: Bool = true
    internal var headerMenuButtonsView: Bool = true
    internal var headerRichWorkspaceDisable:Bool = false
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

        collectionView.alwaysBounceVertical = true

        if enableSearchBar {
            searchController = UISearchController(searchResultsController: nil)
            searchController?.searchResultsUpdater = self
            searchController?.obscuresBackgroundDuringPresentation = false
            searchController?.delegate = self
            searchController?.searchBar.delegate = self
            searchController?.searchBar.autocapitalizationType = .none
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
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

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.action(for: .valueChanged) { _ in
            self.reloadDataSourceNetwork(forced: true)
        }

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: getHeaderHeight(), delegate: self)

        // Long Press on CollectionView
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressCollecationView(_:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)

        // Notification

        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)

        changeTheming()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // ACTIVE
        appDelegate.activeViewController = self

        //
        NotificationCenter.default.addObserver(self, selector: #selector(closeRichWorkspaceWebView), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeStatusFolderE2EE(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setNavigationItem), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
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
        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancelFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        if serverUrl == "" {
            appDelegate.activeServerUrl = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)
        } else {
            appDelegate.activeServerUrl = serverUrl
        }

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        setNavigationItem()

        changeTheming()
        reloadDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !isSearching {
            reloadDataSourceNetwork()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
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
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        pushed = false

        // REQUEST
        NCNetworking.shared.cancelUnifiedSearchFiles()
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        let viewController = presentationController.presentedViewController
        if viewController is NCViewerRichWorkspaceWebView {
            closeRichWorkspaceWebView()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        changeTheming()
    }

    // MARK: - NotificationCenter

    @objc func initialize() {

        if appDelegate.account == "" { return }

        // Search
        if searchController?.isActive ?? false {
            searchController?.isActive = false
        }

        // Select
        if isEditMode {
            isEditMode = !isEditMode
            selectOcId.removeAll()
        }

        if self.view?.window != nil {
            if serverUrl == "" {
                appDelegate.activeServerUrl = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)
            } else {
                appDelegate.activeServerUrl = serverUrl
            }

            appDelegate.listFilesVC.removeAll()
            appDelegate.listFavoriteVC.removeAll()
            appDelegate.listOfflineVC.removeAll()
        }

        if serverUrl != "" {
            self.navigationController?.popToRootViewController(animated: false)
        }

        setNavigationItem()
        reloadDataSource()
        changeTheming()
    }

    @objc func changeTheming() {

        view.backgroundColor = NCBrandColor.shared.systemBackground
        collectionView.backgroundColor = NCBrandColor.shared.systemBackground
        refreshControl.tintColor = .gray

        layoutForView = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }

        // IMAGE BACKGROUND
        if layoutForView?.imageBackgroud != "" {
            let imagePath = CCUtility.getDirectoryGroup().appendingPathComponent(NCGlobal.shared.appBackground).path + "/" + layoutForView!.imageBackgroud
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: imagePath))
                if let image = UIImage(data: data) {
                    backgroundImageView.image = image
                    backgroundImageView.contentMode = .scaleToFill
                    collectionView.backgroundView = backgroundImageView
                }
            } catch { }
        } else {
            backgroundImageView.image = nil
            collectionView.backgroundView = nil
        }

        // COLOR BACKGROUND
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        if traitCollection.userInterfaceStyle == .dark {
            if activeAccount?.darkColorBackground != "" {
                collectionView.backgroundColor = UIColor(hex: activeAccount?.darkColorBackground ?? "")
            } else {
                collectionView.backgroundColor = NCBrandColor.shared.systemBackground
            }
        } else {
           if activeAccount?.lightColorBackground != "" {
                collectionView.backgroundColor = UIColor(hex: activeAccount?.lightColorBackground ?? "")
            } else {
                collectionView.backgroundColor = NCBrandColor.shared.systemBackground
            }
        }

        collectionView.reloadData()
    }

    @objc func reloadDataSource(_ notification: NSNotification) {

        reloadDataSource()
    }

    @objc func reloadDataSourceNetworkForced(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl
        else {
            return
        }

        reloadDataSourceNetwork(forced: true)
    }

    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func closeRichWorkspaceWebView() {
        reloadDataSourceNetwork()
    }

    @objc func deleteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let fileNameView = userInfo["fileNameView"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String,
              let onlyLocalCache = userInfo["onlyLocalCache"] as? Bool,
              (serverUrl == serverUrl && account == appDelegate.account)
        else {
            return
        }
        if fileNameView.lowercased() == NCGlobal.shared.fileNameRichWorkspace.lowercased() {
            reloadDataSourceNetwork(forced: true)
        } else if onlyLocalCache {
            self.collectionView?.reloadData()
        } else {
            let (indexPath, sameSections) = dataSource.deleteMetadata(ocId: ocId)
            if let indexPath = indexPath {
                if sameSections && (indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section)) {
                    collectionView?.performBatchUpdates({
                        collectionView?.deleteItems(at: [indexPath])
                    }, completion: { _ in
                        self.collectionView?.reloadData()
                    })
                } else {
                    self.collectionView?.reloadData()
                }
            } else {
                reloadDataSource()
            }
        }
    }

    @objc func moveFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrlFrom = userInfo["serverUrlFrom"] as? String,
              serverUrlFrom == self.serverUrl
        else {
            return
        }
        let (indexPath, sameSections) = dataSource.deleteMetadata(ocId: ocId)
        if let indexPath = indexPath {
            if sameSections && (indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section)) {
                collectionView?.performBatchUpdates({
                    collectionView?.deleteItems(at: [indexPath])
                }, completion: { _ in
                    self.collectionView?.reloadData()
                })
            } else {
                self.collectionView?.reloadData()
            }
        } else {
            reloadDataSource()
        }
    }

    @objc func copyFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrlTo = userInfo["serverUrlTo"] as? String,
              serverUrlTo == self.serverUrl
        else {
            return
        }
        reloadDataSource()
    }

    @objc func renameFile(_ notification: NSNotification) {

        reloadDataSource()
    }

    @objc func createFolder(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), (metadata.serverUrl == serverUrl && metadata.account == appDelegate.account ) {
            pushMetadata(metadata)
        } else {
            reloadDataSourceNetwork()
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else {
            reloadDataSource()
            return
        }
        dataSource.reloadMetadata(ocId: ocId)
        collectionView?.reloadData()
    }

    @objc func downloadStartFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else {
            reloadDataSource()
            return
        }
        let (indexPath, sameSections) = dataSource.reloadMetadata(ocId: ocId)
        if let indexPath = indexPath {
            if sameSections && (indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section)) {
                collectionView?.reloadItems(at: [indexPath])
            } else {
                self.collectionView?.reloadData()
            }
        } else {
            reloadDataSource()
        }
    }

    @objc func downloadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else {
            reloadDataSource()
            return
        }
        let (indexPath, sameSections) = dataSource.reloadMetadata(ocId: ocId)
        if let indexPath = indexPath {
            if sameSections && (indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section)) {
                collectionView?.reloadItems(at: [indexPath])
            } else {
                self.collectionView?.reloadData()
            }
        } else {
            reloadDataSource()
        }
    }

    @objc func downloadCancelFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else {
            reloadDataSource()
            return
        }
        let (indexPath, sameSections) = dataSource.reloadMetadata(ocId: ocId)
        if let indexPath = indexPath {
            if sameSections && (indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section)) {
                collectionView?.reloadItems(at: [indexPath])
            } else {
                self.collectionView?.reloadData()
            }
        } else {
            reloadDataSource()
        }
    }

    @objc func uploadStartFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              (metadata.serverUrl == serverUrl && metadata.account == appDelegate.account)
        else {
            return
        }
        dataSource.addMetadata(metadata)
        self.collectionView?.reloadData()
    }

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let ocIdTemp = userInfo["ocIdTemp"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              (metadata.serverUrl == serverUrl && metadata.account == appDelegate.account)
        else {
            return
        }
        let (indexPath, sameSections) = dataSource.reloadMetadata(ocId: metadata.ocId, ocIdTemp: ocIdTemp)
        if let indexPath = indexPath {
            if sameSections && (indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section)) {
                collectionView?.performBatchUpdates({
                    collectionView?.reloadItems(at: [indexPath])
                }, completion: { _ in
                    self.collectionView?.reloadData()
                })
            } else {
                self.collectionView?.reloadData()
            }
        } else {
            reloadDataSource()
        }
    }

    @objc func uploadCancelFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String,
              (serverUrl == self.serverUrl && account == appDelegate.account)
        else {
            return
        }
        let (indexPath, sameSections) = dataSource.deleteMetadata(ocId: ocId)
        if let indexPath = indexPath {
            if sameSections && (indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section)) {
                collectionView?.performBatchUpdates({
                    collectionView?.deleteItems(at: [indexPath])
                }, completion: { _ in
                    self.collectionView?.reloadData()
                })
            } else {
                self.collectionView?.reloadData()
            }
        } else {
            reloadDataSource()
        }
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let progressNumber = userInfo["progress"] as? NSNumber,
              let totalBytes = userInfo["totalBytes"] as? Int64,
              let totalBytesExpected = userInfo["totalBytesExpected"] as? Int64,
              let ocId = userInfo["ocId"] as? String,
              let (indexPath, _) = self.dataSource.getIndexPathMetadata(ocId: ocId) as? (IndexPath, NCMetadataForSection?)
        else {
            return
        }
        let status = userInfo["status"] as? Int ?? NCGlobal.shared.metadataStatusNormal

        if let cell = collectionView?.cellForItem(at: indexPath) {
            if let cell = cell as? NCCellProtocol {
                if progressNumber.floatValue == 1 {
                    cell.fileProgressView?.isHidden = true
                    cell.fileProgressView?.progress = .zero
                    cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                        cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
                    } else {
                        cell.fileInfoLabel?.text = ""
                    }
                } else {
                    cell.fileProgressView?.isHidden = false
                    cell.fileProgressView?.progress = progressNumber.floatValue
                    cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCBrandColor.cacheImages.buttonStop)
                    if status == NCGlobal.shared.metadataStatusInDownload {
                        cell.fileInfoLabel?.text = CCUtility.transformedSize(totalBytesExpected) + " - ↓ " + CCUtility.transformedSize(totalBytes)
                    } else if status == NCGlobal.shared.metadataStatusInUpload {
                        cell.fileInfoLabel?.text = CCUtility.transformedSize(totalBytesExpected) + " - ↑ " + CCUtility.transformedSize(totalBytes)
                    }
                }
            }
        }
    }

    // MARK: - Layout

    @objc func setNavigationItem() {
        self.setNavigationHeader()
        guard !isEditMode, layoutKey == NCGlobal.shared.layoutViewFiles else { return }
        
        // PROFILE BUTTON
        
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        
        let image = NCUtility.shared.loadUserImage(
            for: appDelegate.user,
               displayName: activeAccount?.displayName,
               userBaseUrl: appDelegate)
        
        let button = UIButton(type: .custom)
        button.setImage(image, for: .normal)
        
        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account) {
            
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
            if accounts.count > 0 && !NCBrandOptions.shared.disable_multiaccount && !NCBrandOptions.shared.disable_manage_account {
                
                if let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {
                    
                    vcAccountRequest.activeAccount = NCManageDatabase.shared.getActiveAccount()
                    vcAccountRequest.accounts = accounts
                    vcAccountRequest.enableTimerProgress = false
                    vcAccountRequest.enableAddAccount = true
                    vcAccountRequest.delegate = self
                    vcAccountRequest.dismissDidEnterBackground = true
                    
                    let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height/5)
                    let numberCell = accounts.count + 1
                    let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)
                    
                    let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height)
                    
                    UIApplication.shared.keyWindow?.rootViewController?.present(popup, animated: true)
                }
            }
        }
        navigationItem.setLeftBarButton(UIBarButtonItem(customView: button), animated: true)
        navigationItem.leftItemsSupplementBackButton = true
    }

    func getNavigationTitle() -> String {
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        guard let userAlias = activeAccount?.alias, !userAlias.isEmpty else {
            return NCBrandOptions.shared.brand
        }
        return userAlias
    }

    // MARK: - BackgroundImageColor Delegate

    func colorPickerCancel() {
        changeTheming()
    }

    func colorPickerWillChange(color: UIColor) {
        collectionView.backgroundColor = color
    }

    func colorPickerDidChange(lightColor: String, darkColor: String) {

        NCManageDatabase.shared.setAccountColorFiles(lightColorBackground: lightColor, darkColorBackground: darkColor)

        changeTheming()
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        self.emptyDataSet?.setOffset(getHeaderHeight())
        if isSearching {
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
            if serverUrl == "" {
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

        self.isSearching = true

        self.providers?.removeAll()
        self.searchResults?.removeAll()
        self.metadatasSource.removeAll()
        self.dataSource.clearDataSource()

        self.collectionView.reloadData()

    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {

        if self.isSearching && self.literalSearch?.count ?? 0 >= 2 {
            reloadDataSourceNetwork()
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {

        DispatchQueue.global().async {
            NCNetworking.shared.cancelUnifiedSearchFiles()

            self.isSearching = false
            self.literalSearch = ""
            self.providers?.removeAll()
            self.searchResults?.removeAll()
            self.dataSource.clearDataSource()

            self.reloadDataSource()
        }
    }

    // MARK: - TAP EVENT

    func accountRequestChangeAccount(account: String) {
        NCManageDatabase.shared.setAccountActive(account)
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {

            NCOperationQueue.shared.cancelAllQueue()
            NCNetworking.shared.cancelAllTask()

            appDelegate.settingAccount(activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account))

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitialize)
        }
    }

    func accountRequestAddAccount() {
        appDelegate.openLogin(viewController: self, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
    }

    func tapButtonSwitch(_ sender: Any) {

        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            headerMenu?.buttonSwitch.accessibilityLabel = NSLocalizedString("_grid_view_", comment: "")
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCUtility.shared.setLayoutForView(key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
        } else {
            // grid layout
            headerMenu?.buttonSwitch.accessibilityLabel = NSLocalizedString("_list_view_", comment: "")
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCUtility.shared.setLayoutForView(key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
        }
        reloadDataSource()
    }

    func tapButtonOrder(_ sender: Any) {

        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: layoutKey, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }

    func tapButton1(_ sender: Any) {
        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: self) { hasPermission in
            if hasPermission {
                NCPhotosPickerViewController.init(viewController: self, maxSelectedAssets: 0, singleSelectedMode: false)
            }
        }
    }

    func tapButton2(_ sender: Any) {
        guard !appDelegate.activeServerUrl.isEmpty else { return }
        let alertController = UIAlertController.createFolder(serverUrl: appDelegate.activeServerUrl, urlBase: appDelegate)
        appDelegate.window?.rootViewController?.present(alertController, animated: true, completion: nil)
    }

    func tapButton3(_ sender: Any) {
        if #available(iOS 13.0, *) {
            if let viewController = appDelegate.window?.rootViewController {
                NCCreateScanDocument.shared.openScannerDocument(viewController: viewController)
            }
        }
    }

    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {

        tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, image: image, sender: sender)
    }

    func tapShareListItem(with objectId: String, sender: Any) {

        if isEditMode { return }
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        NCFunctionCenter.shared.openShare(viewController: self, metadata: metadata, indexPage: .sharing)
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {

        if isEditMode { return }

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        if namedButtonMore == NCGlobal.shared.buttonMoreMore || namedButtonMore == NCGlobal.shared.buttonMoreLock {
            toggleMenu(metadata: metadata, imageIcon: image)
        } else if namedButtonMore == NCGlobal.shared.buttonMoreStop {
            NCNetworking.shared.cancelTransferMetadata(metadata) { }
        }
    }

    func tapRichWorkspace(_ sender: Any) {

        if let navigationController = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateInitialViewController() as? UINavigationController {
            if let viewerRichWorkspace = navigationController.topViewController as? NCViewerRichWorkspace {
                viewerRichWorkspace.richWorkspaceText = richWorkspaceText ?? ""
                viewerRichWorkspace.serverUrl = serverUrl

                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true, completion: nil)
            }
        }
    }

    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?) {

        if let metadataForSection = metadataForSection, let searchResult = metadataForSection.searchResult, let cursor = searchResult.cursor, let term = literalSearch {

            metadataForSection.unifiedSearchInProgress = true
            self.collectionView?.reloadData()

            NCNetworking.shared.unifiedSearchFilesProvider(urlBase: appDelegate, id: searchResult.id, term: term, limit: 5, cursor: cursor) { searchResult, metadatas, errorCode, ErrorDescription in

                metadataForSection.unifiedSearchInProgress = false
                guard let searchResult = searchResult, let metadatas = metadatas else { return }
                metadataForSection.searchResult = searchResult
                var indexPaths: [IndexPath] = []
                for metadata in metadatas {
                    self.metadatasSource.append(metadata)
                    let (indexPath, sameSections) = self.dataSource.addMetadata(metadata)
                    if let indexPath = indexPath, sameSections {
                        indexPaths.append(indexPath)
                    }
                }
                DispatchQueue.main.async {
                    self.collectionView?.performBatchUpdates({
                        self.collectionView?.insertItems(at: indexPaths)
                    }, completion: { _ in
                        self.collectionView?.reloadData()
                    })
                }
            }
        }
    }

    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    @objc func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) {

        openMenuItems(with: nil, gestureRecognizer: gestureRecognizer)
        /*
        if #available(iOS 13.0, *) {
            
            let interaction = UIContextMenuInteraction(delegate: self)
            self.view.addInteraction(interaction)
        }
        */
    }

    @available(iOS 13.0, *)
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {

            return nil

        }, actionProvider: { _ in

            // let share = UIAction(title: "Share Pupper", image: UIImage(systemName: "square.and.arrow.up")) { action in
            // }
            // return UIMenu(title: "Main Menu", children: [share])
            return nil
        })
    }

    func openMenuItems(with objectId: String?, gestureRecognizer: UILongPressGestureRecognizer) {

        if gestureRecognizer.state != .began { return }

        var listMenuItems: [UIMenuItem] = []
        let touchPoint = gestureRecognizer.location(in: collectionView)

        becomeFirstResponder()

        if serverUrl != "" {
            listMenuItems.append(UIMenuItem(title: NSLocalizedString("_paste_file_", comment: ""), action: #selector(pasteFilesMenu)))
        }
        if #available(iOS 13.0, *) {
            if !NCBrandOptions.shared.disable_background_color {
                listMenuItems.append(UIMenuItem(title: NSLocalizedString("_background_", comment: ""), action: #selector(backgroundFilesMenu)))
            }
        }

        if listMenuItems.count > 0 {
            UIMenuController.shared.menuItems = listMenuItems
            UIMenuController.shared.setTargetRect(CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0), in: collectionView)
            UIMenuController.shared.setMenuVisible(true, animated: true)
        }
    }

    // MARK: - Menu Item

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if #selector(pasteFilesMenu) == action {
            if UIPasteboard.general.items.count > 0 {
                return true
            }
        }

        if #selector(backgroundFilesMenu) == action {
            return true
        }

        return false
    }

    @objc func pasteFilesMenu() {
        NCFunctionCenter.shared.pastePasteboard(serverUrl: serverUrl)
    }

    @objc func backgroundFilesMenu() {

        if let vcBackgroundImageColor = UIStoryboard(name: "NCBackgroundImageColor", bundle: nil).instantiateInitialViewController() as? NCBackgroundImageColor {

            vcBackgroundImageColor.delegate = self
            vcBackgroundImageColor.setupColor = collectionView.backgroundColor
            if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
                vcBackgroundImageColor.lightColor = activeAccount.lightColorBackground
                vcBackgroundImageColor.darkColor = activeAccount.darkColorBackground
            }

            let popup = NCPopupViewController(contentController: vcBackgroundImageColor, popupWidth: vcBackgroundImageColor.width, popupHeight: vcBackgroundImageColor.height)
            popup.backgroundAlpha = 0

            self.present(popup, animated: true)
        }
    }

    // MARK: - DataSource + NC Endpoint

    func reloadDataThenPerform(_ closure: @escaping (() -> Void)) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(closure)
        self.collectionView?.reloadData()
        CATransaction.commit()
    }

    @objc func reloadDataSource() {

        if appDelegate.account == "" { return }

        // Get richWorkspace Text
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace

        // E2EE
        isEncryptedFolder = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: metadataFolder?.e2eEncrypted ?? false, account: appDelegate.account, urlBase: appDelegate.urlBase)

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)

        // get layout for view
        layoutForView = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)

        // set GroupField for Grid
        if !self.isSearching && layoutForView?.layout == NCGlobal.shared.layoutGrid {
            groupByField = "classFile"
        } else {
            groupByField = "name"
        }
    }

    @objc func reloadDataSourceNetwork(forced: Bool = false) { }

    @objc func networkSearch() {
        guard !appDelegate.account.isEmpty, let literalSearch = literalSearch, !literalSearch.isEmpty
        else {
            self.refreshControl.endRefreshing()
            return
        }

        isReloadDataSourceNetworkInProgress = true
        self.metadatasSource.removeAll()
        self.dataSource.clearDataSource()
        self.refreshControl.beginRefreshing()
        self.collectionView.reloadData()

        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        if serverVersionMajor >= NCGlobal.shared.nextcloudVersion20 {

            let semaphore = DispatchSemaphore(value: 1)
            
            NCNetworking.shared.unifiedSearchFiles(urlBase: appDelegate, literal: literalSearch) { allProviders in
                self.providers = allProviders
            } update: { searchResults, metadatas in
                guard let metadatas = metadatas, metadatas.count > 0 else { return }

                if self.isSearching {
                    semaphore.wait()

                    self.searchResults = searchResults
                    self.metadatasSource = metadatas
                    self.dataSource = NCDataSource(metadatasSource: self.metadatasSource,
                                                   account: self.appDelegate.account,
                                                   sort: self.layoutForView?.sort,
                                                   ascending: self.layoutForView?.ascending,
                                                   directoryOnTop: self.layoutForView?.directoryOnTop,
                                                   favoriteOnTop: true,
                                                   filterLivePhoto: true,
                                                   providers: self.providers,
                                                   searchResults: self.searchResults)

                    DispatchQueue.main.sync {
                        self.reloadDataThenPerform {
                            semaphore.signal()
                        }
                    }
                }
            } completion: { searchResults, metadatas, errorCode, errorDescription in

                DispatchQueue.global().async {
                    if self.isSearching, errorCode == 0, let metadatas = metadatas {
                        self.searchResults = searchResults
                        self.metadatasSource = metadatas
                    }
                    self.isReloadDataSourceNetworkInProgress = false
                    self.reloadDataSource()
                }
            }

        } else {

            NCNetworking.shared.searchFiles(urlBase: appDelegate, literal: literalSearch) { metadatas, errorCode, errorDescription in

                DispatchQueue.main.async { self.refreshControl.endRefreshing() }
                if  self.isSearching, errorCode == 0, let metadatas = metadatas {
                    self.searchResults = nil
                    self.metadatasSource = metadatas
                }
                self.isReloadDataSourceNetworkInProgress = false
                self.reloadDataSource()
            }
        }
    }

    @objc func networkReadFolder(forced: Bool, completion: @escaping(_ tableDirectory: tableDirectory?, _ metadatas: [tableMetadata]?, _ metadatasUpdate: [tableMetadata]?, _ metadatasDelete: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String) -> Void) {

        var tableDirectory: tableDirectory?

        NCNetworking.shared.readFile(serverUrlFileName: serverUrl) { (account, metadataFolder, errorCode, errorDescription) in

            if errorCode == 0 {

                if let metadataFolder = metadataFolder {
                    tableDirectory = NCManageDatabase.shared.setDirectory(richWorkspace: metadataFolder.richWorkspace, serverUrl: self.serverUrl, account: account)
                }

                if forced || tableDirectory?.etag != metadataFolder?.etag || metadataFolder?.e2eEncrypted ?? false {

                    NCNetworking.shared.readFolder(serverUrl: self.serverUrl, account: self.appDelegate.account) { account, metadataFolder, metadatas, metadatasUpdate, _, metadatasDelete, errorCode, errorDescription in

                        if errorCode == 0 {
                            self.metadataFolder = metadataFolder

                            // E2EE
                            if let metadataFolder = metadataFolder {
                                if metadataFolder.e2eEncrypted && CCUtility.isEnd(toEndEnabled: self.appDelegate.account) {

                                    NCCommunication.shared.getE2EEMetadata(fileId: metadataFolder.ocId, e2eToken: nil) { account, e2eMetadata, errorCode, errorDescription in

                                        if errorCode == 0 && e2eMetadata != nil {

                                            if !NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: self.serverUrl, account: account, urlBase: self.appDelegate.urlBase) {

                                                NCContentPresenter.shared.messageNotification("_error_e2ee_", description: "_e2e_error_decode_metadata_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorDecodeMetadata)
                                            } else {
                                                self.reloadDataSource()
                                            }

                                        } else if errorCode != NCGlobal.shared.errorResourceNotFound {

                                            NCContentPresenter.shared.messageNotification("_error_e2ee_", description: "_e2e_error_decode_metadata_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorDecodeMetadata)
                                        }

                                        completion(tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, errorDescription)
                                    }
                                } else {
                                    completion(tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, errorDescription)
                                }
                            } else {
                                completion(tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, errorDescription)
                            }
                        } else {
                            completion(tableDirectory, nil, nil, nil, errorCode, errorDescription)
                        }
                    }
                } else {
                    completion(tableDirectory, nil, nil, nil, 0, "")
                }
            } else {
               completion(nil, nil, nil, nil, errorCode, errorDescription)
            }
        }
    }

    // MARK: - Push metadata

    func pushMetadata(_ metadata: tableMetadata) {

        guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName) else { return }
        appDelegate.activeMetadata = metadata

        // FILES
        if layoutKey == NCGlobal.shared.layoutViewFiles && !pushed {

            if let viewController = appDelegate.listFilesVC[serverUrlPush] {

                if viewController.isViewLoaded {
                    pushViewController(viewController: viewController)
                }

            } else {

                if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {

                    viewController.isRoot = false
                    viewController.serverUrl = serverUrlPush
                    viewController.titleCurrentFolder = metadata.fileNameView

                    appDelegate.listFilesVC[serverUrlPush] = viewController

                    pushViewController(viewController: viewController)
                }
            }
        }

        // FAVORITE
        if layoutKey == NCGlobal.shared.layoutViewFavorite && !pushed {

            if let viewController = appDelegate.listFavoriteVC[serverUrlPush] {

                if viewController.isViewLoaded {
                    pushViewController(viewController: viewController)
                }

            } else {

                if let viewController: NCFavorite = UIStoryboard(name: "NCFavorite", bundle: nil).instantiateInitialViewController() as? NCFavorite {

                    viewController.serverUrl = serverUrlPush
                    viewController.titleCurrentFolder = metadata.fileNameView

                    appDelegate.listFavoriteVC[serverUrlPush] = viewController

                    pushViewController(viewController: viewController)
                }
            }
        }

        // OFFLINE
        if layoutKey == NCGlobal.shared.layoutViewOffline && !pushed {

            if let viewController = appDelegate.listOfflineVC[serverUrlPush] {

                if viewController.isViewLoaded {
                    pushViewController(viewController: viewController)
                }

            } else {

                if let viewController: NCOffline = UIStoryboard(name: "NCOffline", bundle: nil).instantiateInitialViewController() as? NCOffline {

                    viewController.serverUrl = serverUrlPush
                    viewController.titleCurrentFolder = metadata.fileNameView

                    appDelegate.listOfflineVC[serverUrlPush] = viewController

                    pushViewController(viewController: viewController)
                }
            }
        }

        // RECENT ( for push use Files ... he he he )
        if layoutKey == NCGlobal.shared.layoutViewRecent && !pushed {

            if let viewController = appDelegate.listFilesVC[serverUrlPush] {

                if viewController.isViewLoaded {
                    pushViewController(viewController: viewController)
                }

            } else {

                if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {

                    viewController.isRoot = false
                    viewController.serverUrl = serverUrlPush
                    viewController.titleCurrentFolder = metadata.fileNameView

                    appDelegate.listFilesVC[serverUrlPush] = viewController

                    pushViewController(viewController: viewController)
                }
            }
        }

        // VIEW IN FOLDER
        if layoutKey == NCGlobal.shared.layoutViewViewInFolder && !pushed {

            if let viewController: NCFileViewInFolder = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as? NCFileViewInFolder {

                viewController.serverUrl = serverUrlPush
                viewController.titleCurrentFolder = metadata.fileNameView

                pushViewController(viewController: viewController)
            }
        }

        // SHARES ( for push use Files ... he he he )
        if layoutKey == NCGlobal.shared.layoutViewShares && !pushed {

            if let viewController = appDelegate.listFilesVC[serverUrlPush] {

                if viewController.isViewLoaded {
                    pushViewController(viewController: viewController)
                }

            } else {

                if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {

                    viewController.isRoot = false
                    viewController.serverUrl = serverUrlPush
                    viewController.titleCurrentFolder = metadata.fileNameView

                    appDelegate.listFilesVC[serverUrlPush] = viewController

                    pushViewController(viewController: viewController)
                }
            }
        }
    }
}

// MARK: - Collection View

extension NCCollectionViewCommon: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
        appDelegate.activeMetadata = metadata

        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            self.navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatasSource.count)"
            return
        }

        if metadata.e2eEncrypted && !CCUtility.isEnd(toEndEnabled: appDelegate.account) {
            NCContentPresenter.shared.messageNotification("_info_", description: "_e2e_goto_settings_for_enable_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorE2EENotEnabled)
            return
        }

        if metadata.directory {

            pushMetadata(metadata)
            
        } else if !(self is NCFileViewInFolder) {
            
            let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))

            if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
                var metadatas: [tableMetadata] = []
                for metadata in dataSource.metadatasSource {
                    if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
                        metadatas.append(metadata)
                    }
                }
                NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: imageIcon)
                return
            }

            if CCUtility.fileProviderStorageExists(metadata) {
                NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
            } else if NCCommunication.shared.isNetworkReachable() {
                NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileView) { _ in }
            } else {
                NCContentPresenter.shared.messageNotification("_info_", description: "_go_online_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorOffline)
            }
        }
    }

    func pushViewController(viewController: UIViewController) {
        if pushed { return }

        pushed = true
        navigationController?.pushViewController(viewController, animated: true)
    }

    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return nil }
        if isEditMode || metadata.classFile == NCCommunicationCommon.typeClassFile.url.rawValue { return nil }

        let identifier = indexPath as NSCopying
        var image: UIImage?
        let cell = collectionView.cellForItem(at: indexPath)
        if cell is NCListCell {
            image = (cell as! NCListCell).imageItem.image
        } else if cell is NCGridCell {
            image = (cell as! NCGridCell).imageItem.image
        }

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {

            return NCViewerProviderContextMenu(metadata: metadata, image: image)

        }, actionProvider: { _ in

            return NCFunctionCenter.shared.contextMenuConfiguration(ocId: metadata.ocId, viewController: self, enableDeleteLocal: true, enableViewInFolder: false, image: image)
        })
    }

    @available(iOS 13.0, *)
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
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                    (cell as! NCCellProtocol).filePreviewImageView?.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                } else {
                    NCOperationQueue.shared.downloadThumbnail(metadata: metadata, placeholder: true, cell: cell, view: collectionView)
                }
            } else {
                // Unified search
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconContacts
                case let str where str.contains("conversation"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconTalk
                case let str where str.contains("calendar"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconCalendar
                case let str where str.contains("deck"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconDeck
                case let str where str.contains("mail"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconMail
                case let str where str.contains("talk"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconTalk
                case let str where str.contains("confirm"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconConfirm
                case let str where str.contains("pages"):
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.iconPages
                default:
                    (cell as! NCCellProtocol).filePreviewImageView?.image = NCBrandColor.cacheImages.file
                }

                //var urlString: String = ""
                if !metadata.iconUrl.isEmpty {
                    if let ownerId = NCUtility.shared.getAvatarFromIconUrl(metadata: metadata), let cell = cell as? NCCellProtocol {
                        let fileName = metadata.userBaseUrl + "-" + ownerId + ".png"
                        NCOperationQueue.shared.downloadAvatar(user: ownerId, dispalyName: nil, fileName: fileName, cell: cell, view: collectionView, cellImageView: cell.filePreviewImageView)
                    }

                    /*
                    if metadata.iconUrl.starts(with: "/apps") {
                        //urlString = metadata.urlBase + metadata.iconUrl
                    } else if metadata.iconUrl.contains("http") && metadata.iconUrl.contains("avatar") {
                        let splitIconUrl = metadata.iconUrl.components(separatedBy: "/")
                        var found:Bool = false
                        var ownerId: String = ""
                        for item in splitIconUrl {
                            if found {
                                ownerId = item
                                break
                            }
                            if item == "avatar" { found = true}
                        }
                        let fileName = metadata.userBaseUrl + "-" + ownerId + ".png"
                        if let cell = cell as? NCCellProtocol {
                            NCOperationQueue.shared.downloadAvatar(user: ownerId, dispalyName: nil, fileName: fileName, cell: cell, view: collectionView, cellImageView: cell.filePreviewImageView)
                        }
                    }
//                    NCCommunication.shared.downloadContent(serverUrl: urlString) { _, data, errorCode, _ in
//                        if errorCode == 0, let data = data, let image = UIImage(data: data) {
//                            (cell as! NCCellProtocol).filePreviewImageView?.image = image
//                        }
//                    }
                     */
                }
            }
        }

        // Avatar
        if metadata.ownerId.count > 0,
           metadata.ownerId != appDelegate.userId,
           appDelegate.account == metadata.account,
           let cell = cell as? NCCellProtocol {
            let fileName = metadata.userBaseUrl + "-" + metadata.ownerId + ".png"
            NCOperationQueue.shared.downloadAvatar(user: metadata.ownerId, dispalyName: metadata.ownerDisplayName, fileName: fileName, cell: cell, view: collectionView, cellImageView: cell.fileAvatarImageView)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

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

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return UICollectionViewCell() }

        let tableShare = dataSource.metadatasForSection[indexPath.section].metadataShare[metadata.ocId]
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
        cell.fileUser = metadata.ownerId
        cell.fileProgressView?.isHidden = true
        cell.fileProgressView?.progress = 0.0
        cell.hideButtonShare(false)
        cell.hideButtonMore(false)
        cell.titleInfoTrailingDefault()

        if isSearching {
            cell.fileTitleLabel?.text = metadata.fileName
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingTail
            if metadata.name == NCGlobal.shared.appName {
                cell.fileInfoLabel?.text = NSLocalizedString("_in_", comment: "") + " " + NCUtilityFileSystem.shared.getPath(metadata: metadata, withFileName: false)
            } else {
                cell.fileInfoLabel?.text = metadata.subline
                cell.titleInfoTrailingFull()
            }
            if let literalSearch = self.literalSearch {
                let longestWordRange = (metadata.fileName.lowercased() as NSString).range(of: literalSearch)
                let attributedString = NSMutableAttributedString(string: metadata.fileName, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 15)])
                attributedString.setAttributes([NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 15), NSAttributedString.Key.foregroundColor : NCBrandColor.shared.annotationColor], range: longestWordRange)
                cell.fileTitleLabel?.attributedText = attributedString
            }
        } else {
            cell.fileTitleLabel?.text = metadata.fileNameView
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingMiddle
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        // Progress
        var progress: Float = 0.0
        var totalBytes: Int64 = 0
        if let progressType = appDelegate.listProgress[metadata.ocId] {
            progress = progressType.progress
            totalBytes = progressType.totalBytes
        }
        if metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusUploading {
            cell.fileProgressView?.isHidden = false
            cell.fileProgressView?.progress = progress
        }

        // Accessibility [shared]
        if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {

            if metadata.e2eEncrypted {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folderEncrypted
            } else if isShare {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if tableShare != nil && tableShare?.shareType != 3 {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if tableShare != nil && tableShare?.shareType == 3 {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folderPublic
            } else if metadata.mountType == "group" {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folderGroup
            } else if isMounted {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folderExternal
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folderAutomaticUpload
                if cell is NCListCell {
                    cell.fileTitleLabel?.text = (cell.fileTitleLabel?.text ?? "") + " - " + NSLocalizedString("_auto_upload_folder_", comment: "")
                }
            } else {
                cell.filePreviewImageView?.image = NCBrandColor.cacheImages.folder
            }

            let lockServerUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
            let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl))

            // Local image: offline
            if tableDirectory != nil && tableDirectory!.offline {
                cell.fileLocalImage?.image = NCBrandColor.cacheImages.offlineFlag
            }

        } else {

            // image local
            if dataSource.metadatasForSection[indexPath.section].metadataOffLine.contains(metadata.ocId) {
                a11yValues.append(NSLocalizedString("_offline_", comment: ""))
                cell.fileLocalImage?.image = NCBrandColor.cacheImages.offlineFlag
            } else if CCUtility.fileProviderStorageExists(metadata) {
                cell.fileLocalImage?.image = NCBrandColor.cacheImages.local
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.fileFavoriteImage?.image = NCBrandColor.cacheImages.favorite
            a11yValues.append(NSLocalizedString("_favorite_", comment: ""))
        }

        // Share image
        if isShare {
            cell.fileSharedImage?.image = NCBrandColor.cacheImages.shared
        } else if tableShare != nil && tableShare?.shareType == 3 {
            cell.fileSharedImage?.image = NCBrandColor.cacheImages.shareByLink
        } else if tableShare != nil && tableShare?.shareType != 3 {
            cell.fileSharedImage?.image = NCBrandColor.cacheImages.shared
        } else {
            cell.fileSharedImage?.image = NCBrandColor.cacheImages.canShare
        }
        if appDelegate.account != metadata.account {
            cell.fileSharedImage?.image = NCBrandColor.cacheImages.shared
        }

        // Button More
        if metadata.status == NCGlobal.shared.metadataStatusInDownload || metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusInUpload || metadata.status == NCGlobal.shared.metadataStatusUploading {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCBrandColor.cacheImages.buttonStop)
        } else if metadata.lock == true {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreLock, image: NCBrandColor.cacheImages.buttonMoreLock)
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
        }

        // Write status on Label Info
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.fileInfoLabel?.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_download_", comment: "")
            break
        case NCGlobal.shared.metadataStatusInDownload:
            cell.fileInfoLabel?.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_download_", comment: "")
            break
        case NCGlobal.shared.metadataStatusDownloading:
            cell.fileInfoLabel?.text = CCUtility.transformedSize(metadata.size) + " - ↓ " + CCUtility.transformedSize(totalBytes)
            break
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.fileInfoLabel?.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_upload_", comment: "")
            break
        case NCGlobal.shared.metadataStatusInUpload:
            cell.fileInfoLabel?.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_upload_", comment: "")
            break
        case NCGlobal.shared.metadataStatusUploading:
            cell.fileInfoLabel?.text = CCUtility.transformedSize(metadata.size) + " - ↑ " + CCUtility.transformedSize(totalBytes)
            break
        case NCGlobal.shared.metadataStatusUploadError:
            if metadata.sessionError != "" {
                cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_upload_", comment: "") + " " + metadata.sessionError
            } else {
                cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_upload_", comment: "")
            }
            break
        default:
            break
        }

        // Live Photo
        if metadata.livePhoto {
            cell.fileStatusImage?.image = NCBrandColor.cacheImages.livePhoto
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        }

        // E2EE
        if metadata.e2eEncrypted || isEncryptedFolder {
            cell.hideButtonShare(true)
        }

        // URL
        if metadata.classFile == NCCommunicationCommon.typeClassFile.url.rawValue {
            cell.fileLocalImage?.image = nil
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
            if let ownerId = NCUtility.shared.getAvatarFromIconUrl(metadata: metadata) {
                cell.fileUser = ownerId
            }
        }

        // Disable Share Button
        if appDelegate.disableSharesView {
            cell.hideButtonShare(true)
        }

        // Separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 || isSearching {
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

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            if indexPath.section == 0 {

                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
                let (_, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: indexPath.section)

                self.headerMenu = header

                if collectionView.collectionViewLayout == gridLayout {
                    header.setImageSwitchList()
                    header.buttonSwitch.accessibilityLabel = NSLocalizedString("_list_view_", comment: "")
                } else {
                    header.setImageSwitchGrid()
                    header.buttonSwitch.accessibilityLabel = NSLocalizedString("_grid_view_", comment: "")
                }

                header.delegate = self
                if headerMenuButtonsCommand && !isSearching {
                    header.setButtonsCommand(heigt: NCGlobal.shared.heightButtonsCommand, imageButton1: UIImage(named: "buttonAddImage"), titleButton1: NSLocalizedString("_upload_", comment: ""), imageButton2: UIImage(named: "buttonAddFolder"), titleButton2: NSLocalizedString("_folder_", comment: ""), imageButton3: UIImage(named: "buttonAddScan"), titleButton3: NSLocalizedString("_scan_", comment: ""))
                } else {
                    header.setButtonsCommand(heigt: 0)
                }
                if headerMenuButtonsView {
                    header.setStatusButtonsView(enable: !dataSource.metadatasSource.isEmpty)
                    header.setButtonsView(heigt: NCGlobal.shared.heightButtonsView)
                    header.setSortedTitle(layoutForView?.titleButtonHeader ?? "")
                } else {
                    header.setButtonsView(heigt: 0)
                }

                header.setRichWorkspaceHeight(heightHeaderRichWorkspace)
                header.setRichWorkspaceText(richWorkspaceText)

                header.setSectionHeight(heightHeaderSection)
                header.labelSection.text = self.dataSource.getSectionValue(indexPath: indexPath)
                header.labelSection.textColor = NCBrandColor.shared.label

                return header

            } else {

                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionHeader

                header.labelSection.text = self.dataSource.getSectionValue(indexPath: indexPath)
                header.labelSection.textColor = NCBrandColor.shared.label

                return header
            }

        } else {

            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
            let sections = dataSource.numberOfSections()
            let section = indexPath.section
            let metadataForSection = self.dataSource.getMetadataForSection(indexPath.section)
            let isPaginated = metadataForSection?.searchResult?.isPaginated ?? false
            let entriesCount: Int = metadataForSection?.searchResult?.entries.count ?? 0
            let unifiedSearchInProgress = metadataForSection?.unifiedSearchInProgress ?? false

            footer.delegate = self
            footer.metadataForSection = metadataForSection

            footer.setTitleLabel("")
            footer.setButtonText(NSLocalizedString("_show_more_results_", comment: ""))
            footer.separatorIsHidden(true)
            footer.buttonIsHidden(true)
            footer.hideActivityIndicatorSection()

            if isSearching {
                if sections > 1 && section != sections - 1 {
                    footer.separatorIsHidden(false)
                }
                if isSearching && isPaginated && entriesCount > 0 {
                    footer.buttonIsHidden(false)
                }
                if unifiedSearchInProgress {
                    footer.showActivityIndicatorSection()
                }
            } else {
                if sections == 1 || section == sections - 1 {
                    let info = dataSource.getFooterInformation()
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

        if headerMenuButtonsCommand && !isSearching {
            size += NCGlobal.shared.heightButtonsCommand
        }
        if headerMenuButtonsView {
            size += NCGlobal.shared.heightButtonsView
        }

        return size
    }

    func getHeaderHeight(section:Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {

        var headerRichWorkspace: CGFloat = 0

        if let richWorkspaceText = richWorkspaceText, !headerRichWorkspaceDisable {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 0 && !isSearching {
                headerRichWorkspace = UIScreen.main.bounds.size.height / 6
            }
        }

        if section == 0 && dataSource.numberOfSections() > 1 {
            return (getHeaderHeight(), headerRichWorkspace, NCGlobal.shared.heightSection)
        } else if section == 0 && dataSource.numberOfSections() == 1 {
            if collectionView.collectionViewLayout == gridLayout {
                return (getHeaderHeight(), headerRichWorkspace, NCGlobal.shared.heightSection)
            } else {
                return (getHeaderHeight(), headerRichWorkspace, 0)
            }
        } else if section > 0 && dataSource.numberOfSections() > 1 {
            return (0, 0, NCGlobal.shared.heightSection)
        } else {
            return (0, 0, 0)
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
        let isPaginated = metadataForSection?.searchResult?.isPaginated ?? false
        let entriesCount: Int = metadataForSection?.searchResult?.entries.count ?? 0
        var size = CGSize(width: collectionView.frame.width, height: 0)

        if section == sections - 1 {
            size.height += NCGlobal.shared.endHeightFooter
        } else {
            size.height += NCGlobal.shared.heightFooter
        }

        if isSearching && isPaginated && entriesCount > 0 {
            size.height += NCGlobal.shared.heightFooterButton
        }

        return size
    }
}
