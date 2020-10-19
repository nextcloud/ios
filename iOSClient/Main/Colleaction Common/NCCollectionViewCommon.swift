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

import Foundation
import NCCommunication

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, UIAdaptivePresentationControllerDelegate  {

    @IBOutlet weak var collectionView: UICollectionView!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    internal let refreshControl = UIRefreshControl()
    internal var searchController: UISearchController?
    internal var emptyDataSet: NCEmptyDataSet?
    
    internal var serverUrl: String = ""
    internal var isEncryptedFolder = false
    internal var isEditMode = false
    internal var selectOcId: [String] = []
    internal var metadatasSource: [tableMetadata] = []
    internal var metadataFolder: tableMetadata?
    internal var metadataTouch: tableMetadata?
    internal var dataSource = NCDataSource()
    internal var richWorkspaceText: String?
        
    internal var layout = ""
    internal var sort: String = ""
    internal var ascending: Bool = true
    internal var directoryOnTop: Bool = true
    internal var groupBy = ""
    internal var titleButton = ""
    internal var itemForLine = 0

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
        
    internal var listLayout: NCListLayout!
    internal var gridLayout: NCGridLayout!
            
    private let headerHeight: CGFloat = 50
    private var headerRichWorkspaceHeight: CGFloat = 0
    private let footerHeight: CGFloat = 100
    
    private var timerInputSearch: Timer?
    internal var literalSearch: String?
    internal var isSearching: Bool = false
    
    internal var isReloadDataSourceNetworkInProgress: Bool = false
    
    // DECLARE
    internal var layoutKey = ""
    internal var titleCurrentFolder = ""
    internal var enableSearchBar: Bool = false
    internal var emptyImage: UIImage?
    internal var emptyTitle: String = ""
    internal var emptyDescription: String = ""
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if enableSearchBar {
            searchController = UISearchController(searchResultsController: nil)
            searchController?.searchResultsUpdater = self
            searchController?.dimsBackgroundDuringPresentation = false
            searchController?.delegate = self
            searchController?.searchBar.delegate = self
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.register(UINib.init(nibName: "NCTransferCell", bundle: nil), forCellWithReuseIdentifier: "transferCell")

        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = .gray
        refreshControl.addTarget(self, action: #selector(reloadDataSourceNetworkRefreshControl), for: .valueChanged)
        
        // Empty
        emptyDataSet = NCEmptyDataSet.init(collectionView: collectionView, image: emptyImage, title: emptyTitle, description: emptyDescription)
        //collectionView.emptyDataSetDelegate = self
        //collectionView.emptyDataSetSource = self
        
        // 3D Touch peek and pop
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }
        
        // Long Press on CollectionView
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressCollecationView(_:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)
        
        // Notification
        
        NotificationCenter.default.addObserver(self, selector: #selector(initializeMain), name: NSNotification.Name(rawValue: k_notificationCenter_initializeMain), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_reloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSourceNetworkForced(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_reloadDataSourceNetworkForced), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeStatusFolderE2EE(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_changeStatusFolderE2EE), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeRichWorkspaceWebView), name: NSNotification.Name(rawValue: k_notificationCenter_closeRichWorkspaceWebView), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_copyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_createFolder), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_favoriteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadCancelFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancelFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_progressTask), object:nil)

        changeTheming()
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        if serverUrl == "" {
            appDelegate.activeServerUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        } else {
            appDelegate.activeServerUrl = serverUrl
        }
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(itemForLine)
        
        if layout == k_layout_list {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(false, animated: false)
        setNavigationItem()
        
        reloadDataSource()
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadDataSourceNetwork()
    }
        
    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        let viewController = presentationController.presentedViewController
        if viewController is NCViewerRichWorkspaceWebView {
            closeRichWorkspaceWebView()
        } else if viewController is UINavigationController {
            if (viewController as! UINavigationController).topViewController is NCFileViewInFolder {
                appDelegate.activeFileViewInFolder = nil
            }
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
    
    func setNavigationItem() {
        
        if isEditMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "navigationMore"), style: .plain, target: self, action:#selector(tapSelectMenu(sender:)))
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, target: self, action: #selector(tapSelect(sender:)))
            navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatas.count)"
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_select_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(tapSelect(sender:)))
            navigationItem.leftBarButtonItem = nil
            navigationItem.title = titleCurrentFolder
        }
    }
    
    // MARK: - NotificationCenter

    @objc func initializeMain() {
        if appDelegate.account.count == 0 { return }
        
        if searchController?.isActive ?? false {
            searchController?.isActive = false
        }
        
        // set active serverUrl
        if self.view?.window != nil {
            if serverUrl == "" {
                appDelegate.activeServerUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
            } else {
                appDelegate.activeServerUrl = serverUrl
            }
        }
        
        self.navigationController?.popToRootViewController(animated: false)
        
        appDelegate.listFilesVC.removeAllObjects()
        appDelegate.listFavoriteVC.removeAllObjects()
        appDelegate.listOfflineVC.removeAllObjects()
        
        reloadDataSource()
    }
    
    @objc func changeTheming() {
        view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        collectionView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        collectionView.reloadData()
    }
    
    @objc func reloadDataSource(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        reloadDataSource()
    }
    
    @objc func reloadDataSourceNetworkForced(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        if let userInfo = notification.userInfo as NSDictionary? {
            if let serverUrl = userInfo["serverUrl"] as? String {
                if serverUrl == self.serverUrl {
                    reloadDataSourceNetwork(forced: true)
                }
            }
        } else {
            reloadDataSourceNetwork(forced: true)
        }
    }
    
    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        reloadDataSource()
    }
    
    @objc func closeRichWorkspaceWebView() {
        if self.view?.window == nil { return }
        
        reloadDataSourceNetwork()
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let onlyLocal = userInfo["onlyLocal"] as? Bool {
                
                if onlyLocal {
                    reloadDataSource()
                } else if metadata.fileNameView.lowercased() == k_fileNameRichWorkspace.lowercased() {
                    reloadDataSourceNetwork(forced: true)
                } else {
                    if let row = dataSource.deleteMetadata(ocId: metadata.ocId) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.deleteItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    }
                }
            }
        }
    }
   
    @objc func moveFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata {
                
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    if let row = dataSource.deleteMetadata(ocId: metadata.ocId) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.deleteItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    }
                } else if metadataNew.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    if let row = dataSource.addMetadata(metadataNew) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.insertItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    }
                }
            }
        }
    }
    
    @objc func copyFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let serverUrlTo = userInfo["serverUrlTo"] as? String {
                if serverUrlTo == self.serverUrl {
                    reloadDataSource()
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        reloadDataSource()
    }
    
    @objc func createFolder(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    if let row = dataSource.addMetadata(metadata) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.insertItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    }
                }
            }
        } else {
            reloadDataSourceNetwork()
        }
    }
    
    @objc func favoriteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if dataSource.getIndexMetadata(ocId: metadata.ocId) != nil {
                    reloadDataSource()
                }
            }
        }
    }
    
    @objc func downloadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                
                if let row = dataSource.reloadMetadata(ocId: metadata.ocId) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.reloadItems(at: [indexPath])
                }
            }
        }
    }
    
    @objc func downloadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let _ = userInfo["errorCode"] as? Int {
                
               if let row = dataSource.reloadMetadata(ocId: metadata.ocId) {
                   let indexPath = IndexPath(row: row, section: 0)
                   collectionView?.reloadItems(at: [indexPath])
               }
            }
        }
    }
        
    @objc func downloadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
               
                if let row = dataSource.reloadMetadata(ocId: metadata.ocId) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.reloadItems(at: [indexPath])
                }
            }
        }
    }
    
    @objc func uploadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    
                    if let row = dataSource.addMetadata(metadata) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.insertItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    }
                }
            }
        }
    }
        
    @objc func uploadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let ocIdTemp = userInfo["ocIdTemp"] as? String, let _ = userInfo["errorCode"] as? Int {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                   
                    dataSource.reloadMetadata(ocId: metadata.ocId, ocIdTemp: ocIdTemp)
                    collectionView?.reloadData()
                }
            }
        }
    }
    
    @objc func uploadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    
                    if let row = dataSource.deleteMetadata(ocId: metadata.ocId) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.deleteItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    } else {
                        self.reloadDataSource()
                    }
                }
            }
        }
    }
        
    @objc func triggerProgressTask(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String {
                
                let _ = userInfo["account"] as? String ?? ""
                let _ = userInfo["serverUrl"] as? String ?? ""
                let progressNumber = userInfo["progress"] as? NSNumber ?? 0
                let progress = progressNumber.floatValue
                let status = userInfo["status"] as? Int ?? Int(k_metadataStatusNormal)
                let totalBytes = userInfo["totalBytes"] as? Double ?? 0
                let totalBytesExpected = userInfo["totalBytesExpected"] as? Double ?? 0
                
                appDelegate.listProgressMetadata.setObject([progress as NSNumber, totalBytes as NSNumber, totalBytesExpected as NSNumber], forKey: userInfo["ocId"] as? NSString ?? "")
                
                if let index = dataSource.getIndexMetadata(ocId: ocId) {
                    if let cell = collectionView?.cellForItem(at: IndexPath(row: index, section: 0)) {
                        if cell is NCListCell {
                            let cell = cell as! NCListCell
                            if progress > 0 {
                                cell.progressView?.isHidden = false
                                cell.progressView?.progress = progress
                                cell.setButtonMore(named: k_buttonMoreStop, image: NCCollectionCommon.images.cellButtonStop)
                                if status == k_metadataStatusInDownload {
                                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↓ " + CCUtility.transformedSize(totalBytes)
                                } else if status == k_metadataStatusInUpload {
                                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↑ " + CCUtility.transformedSize(totalBytes)
                                }
                            }
                        } else if cell is NCTransferCell {
                            let cell = cell as! NCTransferCell
                            if progress > 0 {
                                cell.progressView?.isHidden = false
                                cell.progressView?.progress = progress
                                cell.setButtonMore(named: k_buttonMoreStop, image: NCCollectionCommon.images.cellButtonStop)
                                if status == k_metadataStatusInDownload {
                                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↓ " + CCUtility.transformedSize(totalBytes)
                                } else if status == k_metadataStatusInUpload {
                                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↑ " + CCUtility.transformedSize(totalBytes)
                                }
                            }
                        } else if cell is NCGridCell {
                            let cell = cell as! NCGridCell
                            if progress > 0 {
                                cell.progressView.isHidden = false
                                cell.progressView.progress = progress
                                cell.setButtonMore(named: k_buttonMoreStop, image: NCCollectionCommon.images.cellButtonStop)
                            }
                        }
                    }
                }
            }
        }
    }
        
    // MARK: - Empty
    
    
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        
        if searchController?.isActive ?? false {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "search"), width: 300, height: 300, color: .gray)
        }
        
        if isReloadDataSourceNetworkInProgress {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "networkInProgress"), width: 300, height: 300, color: .gray)
        }
        
        return emptyImage
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        
        var text = "\n"+NSLocalizedString(emptyTitle, comment: "")
        
        if isReloadDataSourceNetworkInProgress {
            text = "\n"+NSLocalizedString("_request_in_progress_", comment: "")
        }
        
        if searchController?.isActive ?? false {
            if isReloadDataSourceNetworkInProgress {
                text = "\n"+NSLocalizedString("_search_in_progress_", comment: "")
            } else {
                text = "\n"+NSLocalizedString("_search_no_record_found_", comment: "")
            }
        }
        
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.gray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        
        var text = "\n"+NSLocalizedString(emptyDescription, comment: "")
        
        if isReloadDataSourceNetworkInProgress {
            text = ""
        }
        
        if searchController?.isActive ?? false {
            text = "\n"+NSLocalizedString("_search_instruction_", comment: "")
        }
        
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: - SEARCH
    
    func updateSearchResults(for searchController: UISearchController) {

        timerInputSearch?.invalidate()
        timerInputSearch = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(reloadDataSourceNetwork), userInfo: nil, repeats: false)
        literalSearch = searchController.searchBar.text
        collectionView?.reloadData()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        isSearching = true
        metadatasSource.removeAll()
        reloadDataSource()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        
        isSearching = false
        literalSearch = ""
        reloadDataSource()
    }
    
    // MARK: - TAP EVENT
    
    @objc func tapSelect(sender: Any) {
        
        isEditMode = !isEditMode
        
        selectOcId.removeAll()
        setNavigationItem()
        
        self.collectionView.reloadData()
    }
    
    func tapSwitchHeader(sender: Any) {
        
        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                })
            })
            layout = k_layout_list
            NCUtility.shared.setLayoutForView(key: layoutKey, serverUrl: serverUrl, layout: layout)
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                })
            })
            layout = k_layout_grid
            NCUtility.shared.setLayoutForView(key: layoutKey, serverUrl: serverUrl, layout: layout)
        }
    }
    
    func tapOrderHeader(sender: Any) {
        
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: layoutKey, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }
    
    @objc func tapSelectMenu(sender: Any) {
        
        guard let tabBarController = self.tabBarController else { return }
        toggleMoreSelect(viewController: tabBarController, selectOcId: selectOcId)
    }
    
    func tapMoreHeader(sender: Any) { }
    
    func tapMoreListItem(with objectId: String, namedButtonMore: String, sender: Any) {
        
        tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, sender: sender)
    }
    
    func tapShareListItem(with objectId: String, sender: Any) {
        
        if isEditMode { return }
        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) else { return }
        
        NCNetworkingNotificationCenter.shared.openShare(ViewController: self, metadata: metadata, indexPage: 2)
    }
        
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, sender: Any) {
        
        if isEditMode { return }

        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) else { return }

        if namedButtonMore == k_buttonMoreMore {
            toggleMoreMenu(viewController: self, metadata: metadata)
        } else if namedButtonMore == k_buttonMoreStop {
            NCNetworking.shared.cancelTransferMetadata(metadata) { }
        }
    }
    
    func tapRichWorkspace(sender: Any) {
        
        if let navigationController = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateInitialViewController() as? UINavigationController {
            if let viewerRichWorkspace = navigationController.topViewController as? NCViewerRichWorkspace {
                viewerRichWorkspace.richWorkspaceText = richWorkspaceText ?? ""
                viewerRichWorkspace.serverUrl = serverUrl
                
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true, completion: nil)
            }
        }
    }
    
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
        openMenuItems(with: objectId, gestureRecognizer: gestureRecognizer)
    }
    
    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
        openMenuItems(with: objectId, gestureRecognizer: gestureRecognizer)
    }
    
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    @objc func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        openMenuItems(with: nil, gestureRecognizer: gestureRecognizer)
    }
    
    func openMenuItems(with objectId: String?, gestureRecognizer: UILongPressGestureRecognizer) {
        
        if gestureRecognizer.state != .began { return }
        if serverUrl == "" { return }
        
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) {
            metadataTouch = metadata
        } else {
            metadataTouch = nil
        }
        
        var listMenuItems: [UIMenuItem] = []
        let touchPoint = gestureRecognizer.location(in: collectionView)
        
        becomeFirstResponder()
                
        if metadataTouch != nil {
            listMenuItems.append(UIMenuItem.init(title: NSLocalizedString("_copy_file_", comment: ""), action: #selector(copyFileMenu(_:))))
        }
        
        listMenuItems.append(UIMenuItem.init(title: NSLocalizedString("_paste_file_", comment: ""), action: #selector(pasteFilesMenu(_:))))
        
        if metadataTouch != nil {
            listMenuItems.append(UIMenuItem.init(title: NSLocalizedString("_open_quicklook_", comment: ""), action: #selector(openQuickLookMenu(_:))))
            if !NCBrandOptions.sharedInstance.disable_openin_file {
                listMenuItems.append(UIMenuItem.init(title: NSLocalizedString("_open_in_", comment: ""), action: #selector(openInMenu(_:))))
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
        
        if (#selector(pasteFilesMenu(_:)) == action) {
            if UIPasteboard.general.items.count > 0 {
                return true
            }
        }
        
        if (#selector(openQuickLookMenu(_:)) == action || #selector(openInMenu(_:)) == action || #selector(copyFileMenu(_:)) == action) {
            guard let metadata = metadataTouch else { return false }
            if !metadata.directory && metadata.status == k_metadataStatusNormal {
                return true
            }
        }

        return false
    }
    
    @objc func copyFileMenu(_ notification: Any) {
        var metadatas: [tableMetadata] = []
        var items = [[String : Any]]()

        if isEditMode {
            for ocId in selectOcId {
                if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                    metadatas.append(metadata)
                }
            }
        } else {
            guard let metadata = metadataTouch else { return }
            metadatas.append(metadata)
        }
                
        for metadata in metadatas {
            
            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                do {
                    let etagPasteboard = try NSKeyedArchiver.archivedData(withRootObject: metadata.ocId, requiringSecureCoding: false)
                    items.append([k_metadataKeyedUnarchiver:etagPasteboard])
                } catch {
                    print("error")
                }
            } else {
                NCNetworking.shared.download(metadata: metadata, selector: selectorLoadCopy, setFavorite: false) { (_) in }
            }
        }
        
        UIPasteboard.general.setItems(items, options: [:])
        
        if isEditMode {
            tapSelect(sender: self)
        }
    }
    
    @objc func pasteFilesMenu(_ notification: Any) {
        
        var listData: [String] = []
        
        for item in UIPasteboard.general.items {
            for object in item {
                let contentType = object.key
                let data = object.value
                if contentType == k_metadataKeyedUnarchiver {
                    do {
                        if let ocId = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data as! Data) as? String{
                            uploadPasteOcId(ocId)
                        }
                    } catch {
                        print("error")
                    }
                    continue
                }
                if data is String {
                    if listData.contains(data as! String) {
                        continue
                    } else {
                        listData.append(data as! String)
                    }
                }
                let type = NCCommunicationCommon.shared.convertUTItoResultType(fileUTI: contentType as CFString)
                if type.resultTypeFile != NCCommunicationCommon.typeFile.unknow.rawValue && type.resultExtension != "" {
                    uploadPasteFile(fileName: type.resultFilename, ext: type.resultExtension, contentType: contentType, data: data)
                }
            }
        }
    }
    
    private func uploadPasteFile(fileName: String, ext: String, contentType: String, data: Any) {
        do {
            let fileNameView = fileName + "_" + CCUtility.getIncrementalNumber() + "." + ext
            let ocId = UUID().uuidString
            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)!
            
            if data is UIImage {
                try (data as? UIImage)?.jpegData(compressionQuality: 1)?.write(to: URL(fileURLWithPath: filePath))
            } else if data is Data {
                try (data as? Data)?.write(to: URL(fileURLWithPath: filePath))
            } else if data is String {
                try (data as? String)?.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
            } else {
                return
            }
            
            let metadataForUpload = NCManageDatabase.sharedInstance.createMetadata(account: appDelegate.account, fileName: fileNameView, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: contentType, livePhoto: false)
            
            metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
            metadataForUpload.sessionSelector = selectorUploadFile
            metadataForUpload.size = Double(NCUtilityFileSystem.shared.getFileSize(filePath: filePath))
            metadataForUpload.status = Int(k_metadataStatusWaitUpload)
            
            NCManageDatabase.sharedInstance.addMetadata(metadataForUpload)
            
        } catch { }
    }
    
    private func uploadPasteOcId(_ ocId: String) {
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                let fileNameView = NCUtility.shared.createFileName(metadata.fileNameView, serverUrl: serverUrl, account: appDelegate.account)
                let ocId = NSUUID().uuidString
                
                CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView))
                let metadataForUpload = NCManageDatabase.sharedInstance.createMetadata(account: appDelegate.account, fileName: fileNameView, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: "", livePhoto: false)
                
                metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
                metadataForUpload.sessionSelector = selectorUploadFile
                metadataForUpload.size = metadata.size
                metadataForUpload.status = Int(k_metadataStatusWaitUpload)
                
                NCManageDatabase.sharedInstance.addMetadata(metadataForUpload)
            }
        }
    }
    
    @objc func openQuickLookMenu(_ notification: Any) {
        guard let metadata = metadataTouch else { return }
                
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_downloadedFile, userInfo: ["metadata": metadata, "selector": selectorLoadFileQuickLook, "errorCode": 0, "errorDescription": "" ])
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: selectorLoadFileQuickLook) { (_) in }
        }
    }
    
    @objc func openInMenu(_ notification: Any) {
        guard let metadata = metadataTouch else { return }
                
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_downloadedFile, userInfo: ["metadata": metadata, "selector": selectorOpenIn, "errorCode": 0, "errorDescription": "" ])
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: selectorOpenIn) { (_) in }
        }
    }
    
    // MARK: - SEGUE
    
    @objc func segue(metadata: tableMetadata) {
        self.metadataTouch = metadata
        performSegue(withIdentifier: "segueDetail", sender: self)
    }
        
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let photoDataSource: NSMutableArray = []
        
        for metadata in (dataSource.metadatas) {
            if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video {
                photoDataSource.add(metadata)
            }
        }
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? NCDetailViewController {
                segueViewController.metadata = metadataTouch
                segueViewController.layoutKey = layoutKey
            }
        } else if let segueViewController = segue.destination as? NCDetailViewController {
            segueViewController.metadata = metadataTouch
            segueViewController.layoutKey = layoutKey
        }
    }
    
    // MARK: - DataSource + NC Endpoint
    
    @objc func reloadDataSource() {
        if appDelegate.account.count == 0 { return }
        
        // Get richWorkspace Text
        let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace
        
        // E2EE
        isEncryptedFolder = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: metadataFolder?.e2eEncrypted ?? false, account: appDelegate.account, urlBase: appDelegate.urlBase)

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)
        
        // get layout for view
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
    }
    @objc func reloadDataSourceNetwork(forced: Bool = false) { }
    @objc func reloadDataSourceNetworkRefreshControl() {
        reloadDataSourceNetwork(forced: true)
    }
    @objc func networkSearch() {
        if appDelegate.account.count == 0 { return }
        
        if literalSearch?.count ?? 0 > 1 {
        
            isReloadDataSourceNetworkInProgress = true
            collectionView?.reloadData()
            
            NCNetworking.shared.searchFiles(urlBase: appDelegate.urlBase, user: appDelegate.user, literal: literalSearch!) { (account, metadatas, errorCode, errorDescription) in
                if self.searchController?.isActive ?? false && errorCode == 0 {
                    self.metadatasSource = metadatas!
                }
                
                self.refreshControl.endRefreshing()
                self.isReloadDataSourceNetworkInProgress = false
                self.reloadDataSource()
            }
        } else {
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc func networkReadFolder(forced: Bool, completion: @escaping(_ metadatas: [tableMetadata]?, _ metadatasUpdate: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCNetworking.shared.readFile(serverUrlFileName: serverUrl, account: appDelegate.account) { (account, metadata, errorCode, errorDescription) in
            
            if errorCode == 0 {
                
                let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
                
                if forced || directory?.etag != metadata?.etag || directory?.e2eEncrypted ?? false {
                    
                    NCNetworking.shared.readFolder(serverUrl: self.serverUrl, account: self.appDelegate.account) { (account, metadataFolder, metadatas, metadatasUpdate, metadatasLocalUpdate, errorCode, errorDescription) in
                        
                        if errorCode == 0 {
                            self.metadataFolder = metadataFolder
                            
                            // E2EE
                            if let metadataFolder = metadataFolder {
                                if metadataFolder.e2eEncrypted && CCUtility.isEnd(toEndEnabled: self.appDelegate.account) {
                                    
                                    NCCommunication.shared.getE2EEMetadata(fileId: metadataFolder.ocId, e2eToken: nil) { (account, e2eMetadata, errorCode, errorDescription) in
                                        if errorCode == 0 && e2eMetadata != nil {
                                            
                                            if !NCEndToEndMetadata.sharedInstance.decoderMetadata(e2eMetadata!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: self.serverUrl, account: account, urlBase: self.appDelegate.urlBase) {
                                                
                                                NCContentPresenter.shared.messageNotification("_error_e2ee_", description: "_e2e_error_decode_metadata_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorDecodeMetadata), forced: true)
                                            } else {
                                                self.reloadDataSource()
                                            }
                                            
                                        } else if errorCode != k_CCErrorResourceNotFound {
                                            
                                            NCContentPresenter.shared.messageNotification("_error_e2ee_", description: "_e2e_error_decode_metadata_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorDecodeMetadata), forced: true)
                                        }
                                        
                                        completion(metadatas, metadatasUpdate, errorCode, errorDescription)
                                    }
                                } else {
                                    completion(metadatas, metadatasUpdate, errorCode, errorDescription)
                                }
                            } else {
                                completion(metadatas, metadatasUpdate, errorCode, errorDescription)
                            }
                        } else {
                            completion(nil, nil, errorCode, errorDescription)
                        }
                    }
                } else {
                    completion(nil, nil, 0, "")
                }
            } else {
               completion(nil, nil, errorCode, errorDescription)
            }
        }
    }
}

// MARK: - 3D Touch peek and pop

extension NCCollectionViewCommon: UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let point = collectionView?.convert(location, from: collectionView?.superview) else { return nil }
        guard let indexPath = collectionView?.indexPathForItem(at: point) else { return nil }
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return nil }
        guard let viewController = UIStoryboard(name: "CCPeekPop", bundle: nil).instantiateViewController(withIdentifier: "PeekPopImagePreview") as? CCPeekPop else { return nil }

        viewController.metadata = metadata

        if layout == k_layout_grid {
            guard let cell = collectionView?.cellForItem(at: indexPath) as? NCGridCell else { return nil }
            previewingContext.sourceRect = cell.frame
            viewController.imageFile = cell.imageItem.image
        } else {
            guard let cell = collectionView?.cellForItem(at: indexPath) as? NCListCell else { return nil }
            previewingContext.sourceRect = cell.frame
            viewController.imageFile = cell.imageItem.image
        }
        
        viewController.showOpenIn = true
        viewController.showOpenQuickLook = NCUtility.shared.isQuickLookDisplayable(metadata: metadata)
        viewController.showShare = false
        
        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        
        guard let indexPath = collectionView?.indexPathForItem(at: previewingContext.sourceRect.origin) else { return }
        
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

// MARK: - Collection View

extension NCCollectionViewCommon: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
        metadataTouch = metadata
        
        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            self.navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatas.count)"
            return
        }
        
        if metadata.e2eEncrypted && !CCUtility.isEnd(toEndEnabled: appDelegate.account) {
            NCContentPresenter.shared.messageNotification("_info_", description: "_e2e_goto_settings_for_enable_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorE2EENotEnabled), forced: true)
            return
        }
        
        if metadata.directory {
            
            guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadataTouch!.serverUrl, addFileName: metadataTouch!.fileName) else { return }
            
            // FILES
            if layoutKey == k_layout_view_files {
                
                if let viewController = appDelegate.listFilesVC.value(forKey: serverUrlPush) {
                    guard let vcFiles = (viewController as? NCFiles) else { return }
                    
                    if vcFiles.isViewLoaded {
                        self.navigationController?.pushViewController(vcFiles, animated: true)
                    }
                    
                } else {
                    
                    let vcFiles:NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as! NCFiles
                    
                    vcFiles.isRoot = false
                    vcFiles.serverUrl = serverUrlPush
                    vcFiles.titleCurrentFolder = metadataTouch!.fileNameView
                    
                    appDelegate.listFilesVC.setValue(vcFiles, forKey: serverUrlPush)
                    
                    self.navigationController?.pushViewController(vcFiles, animated: true)
                }
            }
            
            // FAVORITE
            if layoutKey == k_layout_view_favorite {
            
                if let viewController = appDelegate.listFavoriteVC.value(forKey: serverUrlPush) {
                    guard let vcFavorite = (viewController as? NCFavorite) else { return }
                    
                    if vcFavorite.isViewLoaded {
                        self.navigationController?.pushViewController(vcFavorite, animated: true)
                    }

                } else {
                                        
                    let vcFavorite:NCFavorite = UIStoryboard(name: "NCFavorite", bundle: nil).instantiateInitialViewController() as! NCFavorite
                
                    vcFavorite.serverUrl = serverUrlPush
                    vcFavorite.titleCurrentFolder = metadataTouch!.fileNameView
                
                    appDelegate.listFavoriteVC.setValue(vcFavorite, forKey: serverUrlPush)
                    
                    self.navigationController?.pushViewController(vcFavorite, animated: true)
                }
            }
            
            // OFFLINE
            if layoutKey == k_layout_view_offline {
                
                if let viewController = appDelegate.listOfflineVC.value(forKey: serverUrlPush) {
                    guard let vcOffline = (viewController as? NCOffline) else { return }
                    
                    if vcOffline.isViewLoaded {
                        self.navigationController?.pushViewController(vcOffline, animated: true)
                    }
                    
                } else {
                    
                    let vcOffline:NCOffline = UIStoryboard(name: "NCOffline", bundle: nil).instantiateInitialViewController() as! NCOffline
                    
                    vcOffline.serverUrl = serverUrlPush
                    vcOffline.titleCurrentFolder = metadataTouch!.fileNameView
                    
                    appDelegate.listOfflineVC.setValue(vcOffline, forKey: serverUrlPush)
                    
                    self.navigationController?.pushViewController(vcOffline, animated: true)
                }
            }
            
            // RECENT ( for push use Files ... he he he )
            if layoutKey == k_layout_view_recent {
                
                if let viewController = appDelegate.listFilesVC.value(forKey: serverUrlPush) {
                    guard let vcFiles = (viewController as? NCFiles) else { return }
                    
                    if vcFiles.isViewLoaded {
                        self.navigationController?.pushViewController(vcFiles, animated: true)
                    }
                    
                } else {
                    
                    let vcFiles:NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as! NCFiles
                    
                    vcFiles.isRoot = false
                    vcFiles.serverUrl = serverUrlPush
                    vcFiles.titleCurrentFolder = metadataTouch!.fileNameView
                    
                    appDelegate.listFilesVC.setValue(vcFiles, forKey: serverUrlPush)
                    
                    self.navigationController?.pushViewController(vcFiles, animated: true)
                }
            }
            
            if layoutKey == k_layout_view_viewInFolder {
                
                let vcFileViewInFolder:NCFileViewInFolder = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as! NCFileViewInFolder
                
                vcFileViewInFolder.serverUrl = serverUrlPush
                vcFileViewInFolder.titleCurrentFolder = metadataTouch!.fileNameView
                                
                self.navigationController?.pushViewController(vcFileViewInFolder, animated: true)
            }
            
        } else {
            
            guard let metadataTouch = metadataTouch else { return }
            
            if metadata.typeFile == k_metadataTypeFile_document && NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType) != nil {
                if NCCommunication.shared.isNetworkReachable() {
                    NCViewer.shared.view(viewController: self, metadata: metadataTouch)
                } else {
                    NCContentPresenter.shared.messageNotification("_info_", description: "_go_online_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorOffline), forced: true)
                }
                return
            }
            
            if metadata.typeFile == k_metadataTypeFile_document && NCUtility.shared.isRichDocument(metadata) {
                if NCCommunication.shared.isNetworkReachable() {
                    NCViewer.shared.view(viewController: self, metadata: metadataTouch)
                } else {
                    NCContentPresenter.shared.messageNotification("_info_", description: "_go_online_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorOffline), forced: true)
                }
                return
            }
            
            if metadata.typeFile == k_metadataTypeFile_video {
                NCViewer.shared.view(viewController: self, metadata: metadataTouch)
                return
            }
            
            if CCUtility.fileProviderStorageExists(metadataTouch.ocId, fileNameView: metadataTouch.fileNameView) {
                NCViewer.shared.view(viewController: self, metadata: metadataTouch)
            } else {
                NCNetworking.shared.download(metadata: metadataTouch, selector: selectorLoadFileView) { (_) in }
            }
        }
    }
    
    func collectionViewSelectAll() {
        selectOcId.removeAll()
        for metadata in metadatasSource {
            selectOcId.append(metadata.ocId)
        }
        collectionView.reloadData()
    }
}

extension NCCollectionViewCommon: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
        NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: appDelegate.urlBase, view: collectionView, indexPath: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }        
        NCOperationQueue.shared.cancelDownloadThumbnail(metadata: metadata)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
                        
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
            
            if collectionView.collectionViewLayout == gridLayout {
                header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), width: 100, height: 100, color: NCBrandColor.sharedInstance.icon), for: .normal)
            } else {
                header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), width: 100, height: 100, color: NCBrandColor.sharedInstance.icon), for: .normal)
            }
            
            header.delegate = self
            header.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            header.separator.backgroundColor = NCBrandColor.sharedInstance.separator
            header.setStatusButton(count: dataSource.metadatas.count)
            header.setTitleSorted(datasourceTitleButton: titleButton)
            header.viewRichWorkspaceHeightConstraint.constant = headerRichWorkspaceHeight
            header.setRichWorkspaceText(richWorkspaceText: richWorkspaceText)

            return header
            
        } else {
            
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
            
            let info = dataSource.getFilesInformation()
            footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size )
            
            return footer
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberItems = dataSource.numberOfItems()
        emptyDataSet?.numberOfItemsInSection(numberItems)
        return numberItems
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else {
            return UICollectionViewCell()
        }
        
        var tableShare: tableShare?
        var isShare = false
        var isMounted = false
                
        if metadataFolder != nil {
            isShare = metadata.permissions.contains(k_permission_shared) && !metadataFolder!.permissions.contains(k_permission_shared)
            isMounted = metadata.permissions.contains(k_permission_mounted) && !metadataFolder!.permissions.contains(k_permission_mounted)
        }
        
        if dataSource.metadataShare[metadata.ocId] != nil {
            tableShare = dataSource.metadataShare[metadata.ocId]
        }
        
        //
        // LAYOUT LIST
        //
        if layout == k_layout_list {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            cell.delegate = self
            
            cell.objectId = metadata.ocId
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            cell.separator.backgroundColor = NCBrandColor.sharedInstance.separator
            
            cell.imageSelect.image = nil
            cell.imageStatus.image = nil
            cell.imageLocal.image = nil
            cell.imageFavorite.image = nil
            cell.imageShared.image = nil
            cell.imageMore.image = nil
            
            cell.imageItem.image = nil
            cell.imageItem.backgroundColor = nil
            
            cell.progressView.progress = 0.0
            
            if metadata.directory {
                
                if metadata.e2eEncrypted {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderEncryptedImage
                } else if isShare {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare?.shareType != 3) {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare?.shareType == 3) {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderPublicImage
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderGroupImage
                } else if isMounted {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderExternalImage
                } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderAutomaticUploadImage
                } else {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderImage
                }
                
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date)
                
                let lockServerUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl))
                
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.imageLocal.image = NCCollectionCommon.images.cellOfflineFlag
                }
                
            } else {
                
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                    cell.imageItem.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                } else {
                    if metadata.hasPreview {
                        cell.imageItem.backgroundColor = .lightGray
                    } else {
                        if metadata.iconName.count > 0 {
                            cell.imageItem.image = UIImage.init(named: metadata.iconName)
                        } else {
                            cell.imageItem.image = NCCollectionCommon.images.cellFileImage
                        }
                    }
                }
                
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
                                
                // image local
                if dataSource.metadataOffLine.contains(metadata.ocId) {
                    cell.imageLocal.image = NCCollectionCommon.images.cellOfflineFlag
                } else if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    cell.imageLocal.image = NCCollectionCommon.images.cellLocal
                }
            }
            
            // image Favorite
            if metadata.favorite {
                cell.imageFavorite.image = NCCollectionCommon.images.cellFavouriteImage
            }
            
            // Share image
            if (isShare) {
                cell.imageShared.image = NCCollectionCommon.images.cellSharedImage
            } else if (tableShare != nil && tableShare?.shareType == 3) {
                cell.imageShared.image = NCCollectionCommon.images.cellShareByLinkImage
            } else if (tableShare != nil && tableShare?.shareType != 3) {
                cell.imageShared.image = NCCollectionCommon.images.cellSharedImage
            } else {
                cell.imageShared.image = NCCollectionCommon.images.cellCanShareImage
            }
            if metadata.ownerId.count > 0 && metadata.ownerId != appDelegate.userID {
                // Load avatar
                let fileNameSource = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + metadata.ownerId + ".png"
                let fileNameSourceAvatar = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-avatar-" + metadata.ownerId + ".png"
                if FileManager.default.fileExists(atPath: fileNameSourceAvatar) {
                    cell.imageShared.image = UIImage(contentsOfFile: fileNameSourceAvatar)
                } else if FileManager.default.fileExists(atPath: fileNameSource) {
                    cell.imageShared.image = NCUtility.shared.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                } else {
                    NCCommunication.shared.downloadAvatar(userID: metadata.ownerId, fileNameLocalPath: fileNameSource, size: Int(k_avatar_size)) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 && account == self.appDelegate.account {
                            cell.imageShared.image = NCUtility.shared.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                        }
                    }
                }
            }
            
            // Transfer
            var progress: Float = 0.0
            var totalBytes: Double = 0.0
            let progressArray = appDelegate.listProgressMetadata.object(forKey: metadata.ocId) as? NSArray
            if progressArray != nil && progressArray?.count == 3 {
                progress = progressArray?.object(at: 0) as? Float ?? 0
                totalBytes = progressArray?.object(at: 1) as? Double ?? 0
            }
            if metadata.status == k_metadataStatusInDownload || metadata.status == k_metadataStatusDownloading ||  metadata.status >= k_metadataStatusTypeUpload {
                cell.progressView.isHidden = false
                cell.setButtonMore(named: k_buttonMoreStop, image: NCCollectionCommon.images.cellButtonStop)
            } else {
                cell.progressView.isHidden = true
                cell.progressView.progress = progress
                cell.setButtonMore(named: k_buttonMoreMore, image: NCCollectionCommon.images.cellButtonMore)
            }
            // Write status on Label Info
            switch metadata.status {
            case Int(k_metadataStatusWaitDownload):
                cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_download_", comment: "")
                break
            case Int(k_metadataStatusInDownload):
                cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_download_", comment: "")
                break
            case Int(k_metadataStatusDownloading):
                cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↓ " + CCUtility.transformedSize(totalBytes)
                break
            case Int(k_metadataStatusWaitUpload):
                cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_upload_", comment: "")
                break
            case Int(k_metadataStatusInUpload):
                cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_upload_", comment: "")
                break
            case Int(k_metadataStatusUploading):
                cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↑ " + CCUtility.transformedSize(totalBytes)
                break
            default:
                break
            }
            
            // Live Photo
            if metadata.livePhoto {
                cell.imageStatus.image = NCCollectionCommon.images.cellLivePhotoImage
            }
            
            // E2EE
            if metadata.e2eEncrypted || isEncryptedFolder {
                cell.hideButtonShare(true)
            } else {
                cell.hideButtonShare(false)
            }
            
            // Remove last separator
            if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
                cell.separator.isHidden = true
            } else {
                cell.separator.isHidden = false
            }
            
            // Edit mode
            if isEditMode {
                cell.selectMode(true)
                if selectOcId.contains(metadata.ocId) {
                    cell.selected(true)
                } else {
                    cell.selected(false)
                }
            } else {
                cell.selectMode(false)
            }
            
            return cell
        }
        
        //
        // LAYOUT GRID
        //
        if layout == k_layout_grid {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self
            
            cell.objectId = metadata.ocId
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            
            cell.imageSelect.image = nil
            cell.imageStatus.image = nil
            cell.imageLocal.image = nil
            cell.imageFavorite.image = nil
            
            cell.imageItem.image = nil
            cell.imageItem.backgroundColor = nil
            
            cell.progressView.progress = 0.0

            if metadata.directory {
                
                if metadata.e2eEncrypted {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderEncryptedImage
                } else if isShare {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType != 3) {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType == 3) {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderPublicImage
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderGroupImage
                } else if isMounted {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderExternalImage
                } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderAutomaticUploadImage
                } else {
                    cell.imageItem.image = NCCollectionCommon.images.cellFolderImage
                }
    
                let lockServerUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl))
                                
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.imageLocal.image = NCCollectionCommon.images.cellOfflineFlag
                }
                
            } else {
                
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                    cell.imageItem.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                } else {
                    if metadata.hasPreview {
                        cell.imageItem.backgroundColor = .lightGray
                    } else {
                        if metadata.iconName.count > 0 {
                            cell.imageItem.image = UIImage.init(named: metadata.iconName)
                        } else {
                            cell.imageItem.image = NCCollectionCommon.images.cellFileImage
                        }
                    }
                }
                
                // image Local
                if dataSource.metadataOffLine.contains(metadata.ocId) {
                    cell.imageLocal.image = NCCollectionCommon.images.cellOfflineFlag
                } else if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    cell.imageLocal.image = NCCollectionCommon.images.cellLocal
                }
            }
            
            // image Favorite
            if metadata.favorite {
                cell.imageFavorite.image = NCCollectionCommon.images.cellFavouriteImage
            }
            
            // Transfer
            if metadata.status == k_metadataStatusInDownload || metadata.status == k_metadataStatusDownloading ||  metadata.status >= k_metadataStatusTypeUpload {
                cell.progressView.isHidden = false
                cell.setButtonMore(named: k_buttonMoreStop, image: NCCollectionCommon.images.cellButtonStop)
            } else {
                cell.progressView.isHidden = true
                cell.progressView.progress = 0.0
                cell.setButtonMore(named: k_buttonMoreMore, image: NCCollectionCommon.images.cellButtonMore)
            }
            
            // Live Photo
            if metadata.livePhoto {
                cell.imageStatus.image = NCCollectionCommon.images.cellLivePhotoImage
            }
            
            // Edit mode
            if isEditMode {
                cell.selectMode(true)
                if selectOcId.contains(metadata.ocId) {
                    cell.selected(true)
                } else {
                    cell.selected(false)
                }
            } else {
                cell.selectMode(false)
            }
            
            return cell
        }
        
        return UICollectionViewCell()
    }
}

extension NCCollectionViewCommon: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        headerRichWorkspaceHeight = 0
        
        if let richWorkspaceText = richWorkspaceText {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 0 && !isSearching {
                headerRichWorkspaceHeight = UIScreen.main.bounds.size.height / 4
            }
        } 
        
        return CGSize(width: collectionView.frame.width, height: headerHeight + headerRichWorkspaceHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: footerHeight)
    }
}
