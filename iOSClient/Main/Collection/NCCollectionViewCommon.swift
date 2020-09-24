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

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {

    @IBOutlet weak var collectionView: UICollectionView!

    internal let refreshControl = UIRefreshControl()
    internal var searchController: UISearchController?
    
    @objc var serverUrl: String = ""
        
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
       
    internal var isEncryptedFolder = false
    internal var isEditMode = false
    internal var selectOcId: [String] = []
    internal var metadatasSource: [tableMetadata] = []
    internal var metadataFolder: tableMetadata?
    internal var metadataTouch: tableMetadata?
    internal var dataSource: NCDataSource?
    internal var richWorkspaceText: String?
        
    internal var layout = ""
    internal var groupBy = ""
    internal var titleButton = ""
    internal var itemForLine = 0

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
        
    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
            
    private let headerHeight: CGFloat = 50
    private var headerRichWorkspaceHeight: CGFloat = 0
    private let footerHeight: CGFloat = 50
    
    private var timerInputSearch: Timer?
    internal var literalSearch: String?
    internal var isSearching: Bool = false
    
    internal var isReloadDataSourceNetworkInProgress: Bool = false
    
    // DECLARE
    internal var layoutKey = ""
    internal var titleCurrentFolder = ""
    internal var enableSearchBar: Bool = false
    internal var DZNimage: UIImage?
    internal var DZNtitle: String = ""
    internal var DZNdescription: String = ""
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        if enableSearchBar {
            searchController = UISearchController(searchResultsController: nil)
            searchController?.searchResultsUpdater = self
            self.navigationItem.searchController = searchController
            searchController?.dimsBackgroundDuringPresentation = false
            searchController?.delegate = self
            searchController?.searchBar.delegate = self
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brandElement
        refreshControl.addTarget(self, action: #selector(reloadDataSourceNetworkRefreshControl), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self
        self.collectionView.emptyDataSetSource = self
        
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
        NotificationCenter.default.addObserver(self, selector: #selector(changeStatusFolderE2EE(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_changeStatusFolderE2EE), object: nil)

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
        
        self.navigationItem.title = titleCurrentFolder
                
        (layout, _, _, groupBy, _, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey)
        gridLayout.itemForLine = CGFloat(itemForLine)
        
        if layout == k_layout_list {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }
        
        setNavigationItem()
        reloadDataSource()
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadDataSourceNetwork()
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
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "navigationMore"), style: .plain, target: self, action:#selector(tapSelectMenu(sender:)))
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, target: self, action: #selector(tapSelect(sender:)))
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_select_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(tapSelect(sender:)))
            self.navigationItem.leftBarButtonItem = nil
        }
    }
    
    // MARK: - NotificationCenter

    @objc func initializeMain() {
        self.navigationController?.popToRootViewController(animated: false)
        appDelegate.listFavoriteVC.removeAllObjects()
        appDelegate.listOfflineVC.removeAllObjects()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
    }
    
    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        reloadDataSource()
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let onlyLocal = userInfo["onlyLocal"] as? Bool {
                
                if onlyLocal {
                    if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.reloadItems(at: [indexPath])
                    }
                } else {
                    if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
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
                    if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.deleteItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    }
                } else if metadataNew.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    if let row = dataSource?.addMetadata(metadataNew) {
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
                    self.reloadDataSource()
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                
                if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.performBatchUpdates({
                        collectionView?.reloadItems(at: [indexPath])
                    }, completion: { (_) in
                        self.collectionView?.reloadData()
                    })
                }
            }
        }
    }
    
    @objc func createFolder(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    if let row = dataSource?.addMetadata(metadata) {
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
            self.reloadDataSourceNetwork()
        }
    }
    
    @objc func favoriteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if dataSource?.getIndexMetadata(ocId: metadata.ocId) != nil {
                    self.reloadDataSource()
                }
            }
        }
    }
    
    @objc func downloadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                
                if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
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
                
               if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
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
               
                if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
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
                    
                    if let row = dataSource?.addMetadata(metadata) {
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
                   
                    dataSource?.reloadMetadata(ocId: metadata.ocId, ocIdTemp: ocIdTemp)
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
                    
                    if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
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
                
                if let index = dataSource?.getIndexMetadata(ocId: ocId) {
                    if let cell = collectionView?.cellForItem(at: IndexPath(row: index, section: 0)) {
                        if cell is NCListCell {
                            let cell = cell as! NCListCell
                            if progress > 0 {
                                cell.progressView?.isHidden = false
                                cell.progressView?.progress = progress
                                cell.setButtonMore(named: "stop")
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
                                cell.setButtonMore(named: "stop")
                            }
                        }
                    }
                }
            }
        }
    }
        
    // MARK: - DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        
        if searchController?.isActive ?? false {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "search"), width: 300, height: 300, color: NCBrandColor.sharedInstance.yellowFavorite)
        }
        
        return DZNimage
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        
        var text = "\n"+NSLocalizedString(DZNtitle, comment: "")
        
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
        
        var text = "\n"+NSLocalizedString(DZNdescription, comment: "")
        
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
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            layout = k_layout_list
            NCUtility.shared.setLayoutForView(key: layoutKey, layout: layout)
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            layout = k_layout_grid
            NCUtility.shared.setLayoutForView(key: layoutKey, layout: layout)
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
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) else { return }
        NCMainCommon.shared.openShare(ViewController: self, metadata: metadata, indexPage: 2)
    }
        
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, sender: Any) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) else { return }
        guard let tabBarController = self.tabBarController else { return }

        if namedButtonMore == "more" {
            toggleMoreMenu(viewController: tabBarController, metadata: metadata)
        } else if namedButtonMore == "stop" {
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
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) {
            metadataTouch = metadata
            longPressCollecationView(gestureRecognizer)
        }
    }
    
    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) {
            metadataTouch = metadata
            longPressCollecationView(gestureRecognizer)
        }
    }
    
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    @objc func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }
        if serverUrl == "" { return }
        
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
        
        for metadata in (dataSource?.metadatas ?? [tableMetadata]()) {
            if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video {
                photoDataSource.add(metadata)
            }
        }
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? NCDetailViewController {
                segueViewController.metadata = metadataTouch
            }
        }
    }
    
    // MARK: - DataSource + NC Endpoint
    
    @objc func reloadDataSource() {
        let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace
        
        // E2EE
        isEncryptedFolder = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: metadataFolder?.e2eEncrypted ?? false, account: appDelegate.account, urlBase: appDelegate.urlBase)

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)
    }
    @objc func reloadDataSource(_ notification: NSNotification) { }
    @objc func reloadDataSourceNetwork(forced: Bool = false) { }
    @objc func reloadDataSourceNetworkRefreshControl() {
        reloadDataSourceNetwork(forced: true)
    }
    @objc func networkSearch() {
        if literalSearch?.count ?? 0 > 1 {
        
            isReloadDataSourceNetworkInProgress = true
            collectionView?.reloadData()
            
            NCNetworking.shared.searchFiles(urlBase: appDelegate.urlBase, user: appDelegate.user, literal: literalSearch!) { (account, metadatas, errorCode, errorDescription) in
                if self.searchController?.isActive ?? false && errorCode == 0 {
                    self.metadatasSource = metadatas!
                }
                self.isReloadDataSourceNetworkInProgress = false
                self.reloadDataSource()
            }
        }
    }
    
    @objc func networkReadFolder(forced: Bool, completion: @escaping(_ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        NCNetworking.shared.readFile(serverUrlFileName: serverUrl, account: appDelegate.account) { (account, metadata, errorCode, errorDescription) in
            if errorCode == 0 {
                let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
                if forced || directory?.etag != metadata?.etag {
                    NCNetworking.shared.readFolder(serverUrl: self.serverUrl, account: self.appDelegate.account) { (account, metadataFolder, metadatas, metadatasUpdate, metadatasLocalUpdate, errorCode, errorDescription) in
                        if errorCode == 0 {
                            self.metadataFolder = metadataFolder
                        }
                        completion(metadatas, errorCode, errorDescription)
                    }
                } else {
                    completion(nil, 0, "")
                }
            } else {
               completion(nil, errorCode, errorDescription)
            }
        }
    }
}

// MARK: - 3D Touch peek and pop

extension NCCollectionViewCommon: UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let point = collectionView?.convert(location, from: collectionView?.superview) else { return nil }
        guard let indexPath = collectionView?.indexPathForItem(at: point) else { return nil }
        guard let metadata = dataSource?.cellForItemAt(indexPath: indexPath) else { return nil }
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
        
        guard let metadata = dataSource?.cellForItemAt(indexPath: indexPath) else { return }
        metadataTouch = metadata
        
        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }
        
        if metadata.e2eEncrypted && !CCUtility.isEnd(toEndEnabled: appDelegate.account) {
            NCContentPresenter.shared.messageNotification("_info_", description: "_e2e_goto_settings_for_enable_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorE2EENotEnabled), forced: true)
            return
        }
        
        if metadata.directory {
            
            guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadataTouch!.serverUrl, addFileName: metadataTouch!.fileName) else { return }
            
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
            
        } else {
            
            if metadata.typeFile == k_metadataTypeFile_document && NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType) != nil {
                if NCCommunication.shared.isNetworkReachable() {
                    performSegue(withIdentifier: "segueDetail", sender: self)
                } else {
                    NCContentPresenter.shared.messageNotification("_info_", description: "_go_online_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorOffline), forced: true)
                }
                return
            }
            
            if metadata.typeFile == k_metadataTypeFile_document && NCUtility.shared.isRichDocument(metadata) {
                if NCCommunication.shared.isNetworkReachable() {
                    performSegue(withIdentifier: "segueDetail", sender: self)
                } else {
                    NCContentPresenter.shared.messageNotification("_info_", description: "_go_online_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorOffline), forced: true)
                }
                return
            }
            
            if CCUtility.fileProviderStorageExists(metadataTouch?.ocId, fileNameView: metadataTouch?.fileNameView) {
                performSegue(withIdentifier: "segueDetail", sender: self)
            } else {
                NCNetworking.shared.download(metadata: metadataTouch!, selector: selectorLoadFileView) { (_) in }
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
            header.setStatusButton(count: dataSource?.metadatas.count ?? 0)
            header.setTitleSorted(datasourceTitleButton: titleButton)
            header.viewRichWorkspaceHeightConstraint.constant = headerRichWorkspaceHeight
            header.setRichWorkspaceText(richWorkspaceText: richWorkspaceText)

            return header
            
        } else {
            
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
            
            let info = dataSource?.getFilesInformation()
            footer.setTitleLabel(directories: info?.directories ?? 0, files: info?.files ?? 0, size: info?.size ?? 0)
            
            return footer
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource?.numberOfItems() ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell: UICollectionViewCell
        
        guard let metadata = dataSource?.cellForItemAt(indexPath: indexPath) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        if layout == k_layout_grid {
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
           
        } else {
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        let shares = NCManageDatabase.sharedInstance.getTableShares(account: metadata.account, serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        
        NCCollectionCommon.shared.cellForItemAt(indexPath: indexPath, collectionView: collectionView, cell: cell, metadata: metadata, metadataFolder: metadataFolder, serverUrl: metadata.serverUrl, isEditMode: isEditMode, isEncryptedFolder: isEncryptedFolder, selectocId: selectOcId, autoUploadFileName: autoUploadFileName, autoUploadDirectory: autoUploadDirectory, hideButtonMore: false, downloadThumbnail: true, shares: shares, source: self, dataSource: dataSource)
        
        return cell
    }
}

extension NCCollectionViewCommon: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        if richWorkspaceText?.count ?? 0 == 0 {
            headerRichWorkspaceHeight = 0
        } else {
            headerRichWorkspaceHeight = UIScreen.main.bounds.size.height / 4
        }
        
        return CGSize(width: collectionView.frame.width, height: headerHeight + headerRichWorkspaceHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: footerHeight)
    }
}
