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

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {

    @IBOutlet weak var collectionView: UICollectionView!

    internal let refreshControl = UIRefreshControl()
    internal var searchController: UISearchController?
    
    @objc var serverUrl: String?
        
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
       
    internal var isEditMode = false
    internal var selectOcId: [String] = []
    internal var metadatasSource: [tableMetadata] = []
    internal var metadataFolder: tableMetadata?
    internal var metadataPush: tableMetadata?
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
        }
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib.init(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brandElement
        refreshControl.addTarget(self, action: #selector(reloadDataSourceNetwork), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self
        self.collectionView.emptyDataSetSource = self
        
        // 3D Touch peek and pop
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: k_notificationCenter_reloadDataSource), object: nil)
        
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

        self.navigationItem.title = titleCurrentFolder
                
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)
        
        (layout, _, _, groupBy, _, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey)
        gridLayout.itemForLine = CGFloat(itemForLine)
        
        if layout == k_layout_list {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }
        
        if serverUrl == nil {
            appDelegate.activeServerUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        } else {
            appDelegate.activeServerUrl = self.serverUrl
        }
        
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
    
    // MARK: - Utility
    
    @objc func minCharTextFieldDidChange(sender: UITextField) {
        guard let alertController = self.presentedViewController as? UIAlertController else { return }
        guard let password = alertController.textFields?.first else { return }
        guard let ok = alertController.actions.last else { return }
        ok.isEnabled =  password.text?.count ?? 0 >= 8
    }
    
    // MARK: - NotificationCenter

    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.collectionView?.reloadData()
                            }
                        })
                    }
                }
            }
        }
    }
   
    @objc func moveFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let _ = userInfo["metadataNew"] as? tableMetadata {
                
                if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.performBatchUpdates({
                        collectionView?.deleteItems(at: [indexPath])
                    }, completion: { (_) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.collectionView?.reloadData()
                        }
                    })
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.collectionView?.reloadData()
                            }
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
                let progressNumber = userInfo["progress"] as? NSNumber ?? 0
                let progress = progressNumber.floatValue
                
                if let index = dataSource?.getIndexMetadata(ocId: ocId) {
                    if let cell = collectionView?.cellForItem(at: IndexPath(row: index, section: 0)) {
                        if cell is NCListCell {
                            let cell = cell as! NCListCell
                            if progress > 0 {
                                cell.progressView?.isHidden = false
                                cell.progressView?.progress = progress
                                cell.setButtonMore(named: "stop")
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
        
    // MARK: DZNEmpty
    
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
        
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
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
    
    // MARK: SEARCH
    
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
    
    // MARK: TAP EVENT
    
    @objc func tapSelect(sender: Any) {
        
        isEditMode = !isEditMode
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
    
    func tapMoreHeader(sender: Any) {

    }
    
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
            NCMainCommon.shared.cancelTransferMetadata(metadata, uploadStatusForcedStart: false)
        }
    }
    
    func tapRichWorkspace(sender: Any) {
        
        if let navigationController = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateInitialViewController() as? UINavigationController {
            if let viewerRichWorkspace = navigationController.topViewController as? NCViewerRichWorkspace {
                viewerRichWorkspace.richWorkspaceText = richWorkspaceText ?? ""
                viewerRichWorkspace.serverUrl = appDelegate.activeServerUrl
                
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: SEGUE
    
    @objc func segue(metadata: tableMetadata) {
        self.metadataPush = metadata
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
                segueViewController.metadata = metadataPush
            }
        }
    }
    
    // MARK: - NC API & Algorithm
    
    @objc func reloadDataSource() {
        let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, appDelegate.activeServerUrl))
        richWorkspaceText = directory?.richWorkspace
    }
    @objc func reloadDataSourceNetwork() { }
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { }
}

extension NCCollectionViewCommon: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            if isEditMode {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "navigationMore"), style: .plain, target: self, action:#selector(tapSelectMenu(sender:)))
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, target: self, action: #selector(tapSelect(sender:)))
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_select_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(tapSelect(sender:)))
                self.navigationItem.leftBarButtonItem = nil
            }
            
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
            
            if collectionView.collectionViewLayout == gridLayout {
                header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            } else {
                header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
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
        return dataSource?.numberOfItemsInSection(section: section) ?? 1
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
        
        NCCollectionCommon.shared.cellForItemAt(indexPath: indexPath, collectionView: collectionView, cell: cell, metadata: metadata, metadataFolder: metadataFolder, serverUrl: metadata.serverUrl, isEditMode: isEditMode, selectocId: selectOcId, autoUploadFileName: autoUploadFileName, autoUploadDirectory: autoUploadDirectory, hideButtonMore: false, downloadThumbnail: true, shares: shares, source: self, dataSource: dataSource)
        
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
