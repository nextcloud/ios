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
import JGProgressHUD

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCPhotoCellDelegate, NCSectionFirstHeaderDelegate, NCSectionFooterDelegate, NCSectionFirstHeaderEmptyDataDelegate, UIAdaptivePresentationControllerDelegate, UIContextMenuInteractionDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var headerTop: NSLayoutConstraint?
	@IBOutlet weak var collectionViewTop: NSLayoutConstraint?
	@IBOutlet weak var fileActionsHeader: FileActionsHeader?
    
    var accountButtonFactory: AccountButtonFactory!

    var autoUploadFileName = ""
    var autoUploadDirectory = ""
    var isTransitioning: Bool = false
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
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
    var selectOcId: [String] = []
    var metadataFolder: tableMetadata?
    var dataSource = NCDataSource()
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
    var commonSelectToolbar: NCCollectionViewCommonSelectToolbar!
    var timerNotificationCenter: Timer?
    var notificationReloadDataSource: Int = 0
    var notificationReloadDataSourceNetwork: Int = 0
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    let maxImageGrid: CGFloat = 7

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

    var showDescription: Bool {
        !headerRichWorkspaceDisable && NCKeychain().showDescription
    }

    var infoLabelsSeparator: String {
        layoutForView?.layout == NCGlobal.shared.layoutList ? " - " : ""
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        commonSelectToolbar = NCCollectionViewCommonSelectToolbar(delegate: self)
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
        
		isEditMode = false
		setNavigationBarLogoIfNeeded()
        setNavigationLeftItems()
        setNavigationRightItems()
		setViewLayout()
		updateHeadersView()
		
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
                if sceneIdentifier == self.sceneIdentifier {
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
                self.sectionFirstHeader?.progressTransfer.progress = progressNumber.floatValue
                self.sectionFirstHeaderEmptyData?.progressTransfer.progress = progressNumber.floatValue
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
        let isTabBarSelectHidden = commonSelectToolbar.isHidden()

        if isEditMode {
            commonSelectToolbar.update(selectOcId: selectOcId, metadatas: getSelectedMetadatas(), userId: appDelegate.userId)
            commonSelectToolbar.show()
        } else {
            commonSelectToolbar.hide()
			navigationItem.rightBarButtonItems = isCurrentScreenInMainTabBar() ? [createAccountButton()] : []
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
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        guard let userAlias = activeAccount?.alias, !userAlias.isEmpty else {
            return NCBrandOptions.shared.brand
        }
        return userAlias
    }
    
    private func isCurrentScreenInMainTabBar() -> Bool {
        return self.tabBarController is NCMainTabBarController
    }
	
	private func setViewLayout() {
		layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl)
		if layoutForView?.layout == NCGlobal.shared.layoutList {
			collectionView?.collectionViewLayout = listLayout
			self.layoutType = NCGlobal.shared.layoutList
		} else if layoutForView?.layout == NCGlobal.shared.layoutGrid {
			collectionView?.collectionViewLayout = gridLayout
			self.layoutType = NCGlobal.shared.layoutGrid
		} else if layoutForView?.layout == NCGlobal.shared.layoutPhotoRatio {
			collectionView?.collectionViewLayout = mediaLayout
			self.layoutType = NCGlobal.shared.layoutPhotoRatio
		} else if layoutForView?.layout == NCGlobal.shared.layoutPhotoSquare {
			collectionView?.collectionViewLayout = mediaLayout
			self.layoutType = NCGlobal.shared.layoutPhotoSquare
		}
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
        } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundExtension {
            session = NCNetworking.shared.sessionManagerUploadBackgroundExtension
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
        NCActionCenter.shared.pastePasteboard(serverUrl: serverUrl, account: appDelegate.account, hudView: mainTabBarController?.currentViewController()?.view)
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
                self.dataSource = NCDataSource(metadatas: [], account: self.appDelegate.account, layoutForView: self.layoutForView, providers: self.providers, searchResults: self.searchResults)
            } update: { _, _, searchResult, metadatas in
                guard let metadatas, !metadatas.isEmpty, self.isSearchingMode, let searchResult else { return }
                NCNetworking.shared.unifiedSearchQueue.addOperation(NCCollectionViewUnifiedSearch(collectionViewCommon: self, metadatas: metadatas, searchResult: searchResult))
            } completion: { _, _ in
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
        } else {
            NCNetworking.shared.searchFiles(urlBase: appDelegate, literal: literalSearch, account: appDelegate.account) { task in
                self.dataSourceTask = task
                self.collectionView.reloadData()
            } completion: { metadatas, error in
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.collectionView.reloadData()
                }
                guard let metadatas = metadatas, error == .success, self.isSearchingMode else { return }
                self.dataSource = NCDataSource(metadatas: metadatas, account: self.appDelegate.account, layoutForView: self.layoutForView, providers: self.providers, searchResults: self.searchResults)
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
        guard let navigationCollectionViewCommon = mainTabBarController?.navigationCollectionViewCommon else { return }
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

    func isHeaderMenuTransferViewEnabled() -> Bool {
        if headerMenuTransferView {
            return NCManageDatabase.shared.getResultMetadataFromOcId(NCNetworking.shared.transferInForegorund?.ocId)?.isTransferInForeground ?? false
        }
        return false
    }

    func getHeaderHeight(section: Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {
        var headerRichWorkspace: CGFloat = 0

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

        if let richWorkspaceText = richWorkspaceText, showDescription {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !isSearchingMode {
                headerRichWorkspace = UIScreen.main.bounds.size.height / 6
            }
        }

        if isSearchingMode || layoutForView?.groupBy != "none" || dataSource.numberOfSections() > 1 {
            if section == 0 {
                return (getHeaderHeight(), headerRichWorkspace, NCGlobal.shared.heightSection)
            } else {
                return (0, 0, NCGlobal.shared.heightSection)
            }
        } else {
            return (getHeaderHeight(), headerRichWorkspace, 0)
        }
    }

    func sizeForHeaderInSection(section: Int) -> CGSize {
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

    // MARK: - Footer size

    func sizeForFooterInSection(section: Int) -> CGSize {
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

// MARK: -

extension NCCollectionViewCommon {
	// MARK: - Headers view
	
	private var sortTitle: String? {
		guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return nil }
		
		switch layoutForView.sort {
		case "fileName": return NSLocalizedString("_name_", comment: "")
		case "date": return NSLocalizedString("_date_", comment: "")
		case "size": return NSLocalizedString("_size_", comment: "")
		default: return nil
		}
	}
	private var sortDirectionImage: UIImage? {
		guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return nil }
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
	
	private func setNavigationBarLogoIfNeeded() {
		if  isCurrentScreenInMainTabBar() && self.navigationController?.viewControllers.count == 1 {
			setNavigationBarLogo()
		}
	}
	
	private func createSortMenuActions() -> [UIMenuElement] {
		guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return [] }
		   
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
		guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

		let listImage = UIImage(named: "FileSelection/view_mode_list")?.templateRendered()
		let gridImage = UIImage(named: "FileSelection/view_mode_grid")?.templateRendered()

		let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: listImage, state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
			layoutForView.layout = NCGlobal.shared.layoutList
			self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
			self.layoutType = NCGlobal.shared.layoutList

			self.collectionView.reloadData()
			self.collectionView.collectionViewLayout.invalidateLayout()
			self.collectionView.setCollectionViewLayout(self.listLayout, animated: true) {_ in self.isTransitioning = false }

			self.setNavigationRightItems()
		}

		let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
			layoutForView.layout = NCGlobal.shared.layoutGrid
			self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
			self.layoutType = NCGlobal.shared.layoutGrid

			self.collectionView.reloadData()
			self.collectionView.collectionViewLayout.invalidateLayout()
			self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true) {_ in self.isTransitioning = false }

			self.setNavigationRightItems()
		}

		let menuPhoto = UIMenu(title: "", options: .displayInline, children: [
			UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutPhotoSquare ? .on : .off) { _ in
				layoutForView.layout = NCGlobal.shared.layoutPhotoSquare
				self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
				self.layoutType = NCGlobal.shared.layoutPhotoSquare

				self.collectionView.reloadData()
				self.collectionView.collectionViewLayout.invalidateLayout()
				self.collectionView.setCollectionViewLayout(self.mediaLayout, animated: true) {_ in self.isTransitioning = false }

				self.reloadDataSource()
				self.setNavigationRightItems()
			},
			UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutPhotoRatio ? .on : .off) { _ in
				layoutForView.layout = NCGlobal.shared.layoutPhotoRatio
				self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
				self.layoutType = NCGlobal.shared.layoutPhotoRatio

				self.collectionView.reloadData()
				self.collectionView.collectionViewLayout.invalidateLayout()
				self.collectionView.setCollectionViewLayout(self.mediaLayout, animated: true) {_ in self.isTransitioning = false }

				self.reloadDataSource()
				self.setNavigationRightItems()
			}
		])

		return [list, grid, UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [menuPhoto])]
	}
}
