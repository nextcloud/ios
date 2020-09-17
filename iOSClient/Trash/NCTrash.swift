//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

class NCTrash: UIViewController, UIGestureRecognizerDelegate, NCTrashListCellDelegate, NCGridCellDelegate, NCTrashSectionHeaderMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
    
    @IBOutlet weak var collectionView: UICollectionView!

    var trashPath = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var blinkocId: String?
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var isEditMode = false
    private var selectocId: [String] = []
    
    private var datasource: [tableTrash] = []
    
    private var layout = ""
    private var groupBy = "none"
    private var titleButton = ""
    private var itemForLine = 0

    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
    
    private let highHeader: CGFloat = 50
    
    private let refreshControl = UIRefreshControl()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeTrash = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.prefersLargeTitles = true

        // Cell
        collectionView.register(UINib.init(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header - Footer
        collectionView.register(UINib.init(nibName: "NCTrashSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib.init(nibName: "NCTrashSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brandElement
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self;
        self.collectionView.emptyDataSetSource = self;
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
       
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = titleCurrentFolder

        (layout, _, _, groupBy, _, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: k_layout_view_trash)
        gridLayout.itemForLine = CGFloat(itemForLine)
        
        if layout == k_layout_list {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
                
        if trashPath == "" {
            guard let userID = (appDelegate.userID as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed) else { return }
            trashPath = appDelegate.urlBase + "/" + NCUtility.shared.getDAV() + "/trashbin/" + userID + "/trash/"
        }
        reloadDataSource()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadListingTrash()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
        
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brandElement
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 300, height: 300, color: .gray)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_trash_no_trash_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.gray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_trash_no_trash_description_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: TAP EVENT
    
    func tapSwitchHeaderMenu(sender: Any) {
        
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
            NCUtility.shared.setLayoutForView(key: k_layout_view_trash, layout: layout)
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
            NCUtility.shared.setLayoutForView(key: k_layout_view_trash, layout: layout)
        }
    }
    
    func tapOrderHeaderMenu(sender: Any) {
        
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: k_layout_view_trash, sortButton: sender as? UIButton, serverUrl: nil, hideDirectoryOnTop: true)
    }
    
    func tapMoreHeaderMenu(sender: Any) {
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        
        var actions: [NCMenuAction] = []
                
        if isEditMode {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_trash_delete_selected_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                    action: { menuAction in
                        let alert = UIAlertController(title: NSLocalizedString("_trash_delete_selected_", comment: ""), message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .destructive, handler: { _ in
                            for ocId in self.selectocId {
                                self.deleteItem(with: ocId)
                            }
                            self.isEditMode = false
                            self.selectocId.removeAll()
                            self.collectionView.reloadData()
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                )
            )
        } else {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_trash_delete_all_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                    action: { menuAction in
                        let alert = UIAlertController(title: NSLocalizedString("_trash_delete_all_", comment: ""), message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .destructive, handler: { _ in
                            self.emptyTrash()
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                )
            )
        }
        
        mainMenuViewController.actions = actions
        
        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
    
    func tapRestoreListItem(with ocId: String, sender: Any) {
        
        if !isEditMode {
            restoreItem(with: ocId)
        } else {
            let buttonPosition:CGPoint = (sender as! UIButton).convert(CGPoint.zero, to:collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }
    
    func tapMoreListItem(with objectId: String, sender: Any) {
        if !isEditMode {
            let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController

            var actions: [NCMenuAction] = []

            guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: objectId, account: appDelegate.account) else {
                return
            }

            var iconHeader: UIImage!
            if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
                iconHeader = icon
            } else {
                if(tableTrash.directory) {
                    iconHeader = CCGraphics.changeThemingColorImage(UIImage(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
                } else {
                    iconHeader = UIImage(named: tableTrash.iconName)
                }
            }

            actions.append(
                NCMenuAction(
                    title: tableTrash.trashbinFileName,
                    icon: iconHeader,
                    action: nil
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_delete_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                    action: { menuAction in
                        self.deleteItem(with: objectId)
                    }
                )
            )

            mainMenuViewController.actions = actions

            let menuPanelController = NCMenuPanelController()
            menuPanelController.parentPresenter = self
            menuPanelController.delegate = mainMenuViewController
            menuPanelController.set(contentViewController: mainMenuViewController)
            menuPanelController.track(scrollView: mainMenuViewController.tableView)

            self.present(menuPanelController, animated: true, completion: nil)
        } else {
            let buttonPosition: CGPoint = (sender as! UIButton).convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }
    
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, sender: Any) {
        if !isEditMode {
            let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController

            var actions: [NCMenuAction] = []

            guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: objectId, account: appDelegate.account) else {
                return
            }

            var iconHeader: UIImage!
            if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
                iconHeader = icon
            } else {
                if(tableTrash.directory) {
                    iconHeader = CCGraphics.changeThemingColorImage(UIImage(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
                } else {
                    iconHeader = UIImage(named: tableTrash.iconName)
                }
            }

            actions.append(
                NCMenuAction(
                    title: tableTrash.trashbinFileName,
                    icon: iconHeader,
                    action: nil
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_restore_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "restore"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.restoreItem(with: objectId)
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_delete_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                    action: { menuAction in
                        self.deleteItem(with: objectId)
                    }
                )
            )

            mainMenuViewController.actions = actions

            let menuPanelController = NCMenuPanelController()
            menuPanelController.parentPresenter = self
            menuPanelController.delegate = mainMenuViewController
            menuPanelController.set(contentViewController: mainMenuViewController)
            menuPanelController.track(scrollView: mainMenuViewController.tableView)

            self.present(menuPanelController, animated: true, completion: nil)

        } else {
            let buttonPosition: CGPoint = (sender as! UIButton).convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }

    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
    
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
    }
}

// MARK: - Collection View

extension NCTrash: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let tableTrash = datasource[indexPath.item]
        
        if isEditMode {
            if let index = selectocId.firstIndex(of: tableTrash.fileId) {
                selectocId.remove(at: index)
            } else {
                selectocId.append(tableTrash.fileId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }
        
        if tableTrash.directory {
            
            let ncTrash:NCTrash = UIStoryboard(name: "NCTrash", bundle: nil).instantiateInitialViewController() as! NCTrash
            
            ncTrash.trashPath = tableTrash.filePath + tableTrash.fileName
            ncTrash.titleCurrentFolder = tableTrash.trashbinFileName
            
            self.navigationController?.pushViewController(ncTrash, animated: true)
        }
    }
}

extension NCTrash: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let trashHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCTrashSectionHeaderMenu
            
            if collectionView.collectionViewLayout == gridLayout {
                trashHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            } else {
                trashHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            }
            
            trashHeader.delegate = self
            trashHeader.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            trashHeader.separator.backgroundColor = NCBrandColor.sharedInstance.separator
            trashHeader.setStatusButton(datasource: datasource)
            trashHeader.setTitleSorted(datasourceTitleButton: titleButton)
            
            return trashHeader
            
        } else {
            
            let trashFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCTrashSectionFooter
            
            trashFooter.setTitleLabelFooter(datasource: datasource)
            
            return trashFooter
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datasource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let tableTrash = datasource[indexPath.item]
        var image: UIImage?
        
        if tableTrash.iconName.count > 0 {
            image = UIImage.init(named: tableTrash.iconName)
        } else {
            image = UIImage.init(named: "file")
        }
        
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName))
        } else {
            if tableTrash.hasPreview && !CCUtility.fileProviderStoragePreviewIconExists(tableTrash.fileId, etag: tableTrash.fileName) {
                downloadThumbnail(with: tableTrash, indexPath: indexPath)
            }
        }
        
        if collectionView.collectionViewLayout == listLayout {
            
            // LIST
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCTrashListCell
            cell.delegate = self
            
            cell.objectId = tableTrash.fileId
            cell.indexPath = indexPath
            cell.labelTitle.text = tableTrash.trashbinFileName
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            cell.separator.backgroundColor = NCBrandColor.sharedInstance.separator

            if tableTrash.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date)
            } else {
                cell.imageItem.image = image
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date) + ", " + CCUtility.transformedSize(tableTrash.size)
            }
            
            if isEditMode {
                cell.imageItemLeftConstraint.constant = 45
                cell.imageSelect.isHidden = false
                
                if selectocId.contains(tableTrash.fileId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.shared.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedNo"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = nil
                }
            } else {
                cell.imageItemLeftConstraint.constant = 10
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            
            return cell
            
        } else {
            
            // GRID
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self
            
            cell.objectId = tableTrash.fileId
            cell.indexPath = indexPath
            cell.labelTitle.text = tableTrash.trashbinFileName
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            
            if tableTrash.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
            } else {
                cell.imageItem.image = image
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectocId.contains(tableTrash.fileId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.shared.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.isHidden = true
                    cell.backgroundView = nil
                }
            } else {
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            return cell
        }
    }
}

extension NCTrash: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }
}

// MARK: - NC API & Algorithm

extension NCTrash {

    @objc func reloadDataSource() {
        
        var sort: String
        var ascending: Bool
        
        (layout, sort, ascending, groupBy, _, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: k_layout_view_trash)
        
        datasource.removeAll()
        
        guard let tashItems = NCManageDatabase.sharedInstance.getTrash(filePath: trashPath, sort: sort, ascending: ascending, account: appDelegate.account) else {
            return
        }
        
        datasource = tashItems
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // GoTo ocId
            if self.blinkocId != nil {
                for item in 0...self.datasource.count-1 {
                    if self.datasource[item].fileId.contains(self.blinkocId!) {
                        let indexPath = IndexPath(item: item, section: 0)
                        self.collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.blinkocId = nil
                            NCUtility.shared.blink(cell: self.collectionView.cellForItem(at: indexPath))
                        }
                    }
                }
            }
        }
        collectionView.reloadData()
        CATransaction.commit()
    }
    
    @objc func loadListingTrash() {
        
        NCCommunication.shared.listingTrash(showHiddenFiles: false) { (account, items, errorCode, errorDescription) in
            self.refreshControl.endRefreshing()
         
            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.sharedInstance.deleteTrash(filePath: self.trashPath, account: self.appDelegate.account)
                NCManageDatabase.sharedInstance.addTrash(account: account, items: items)
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
            
            self.reloadDataSource()
        }
    }
    
    func restoreItem(with fileId: String) {
        
        guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: fileId, account: appDelegate.account) else {
            return
        }
        
        let fileNameFrom = tableTrash.filePath + tableTrash.fileName
        let fileNameTo = appDelegate.urlBase + "/" + NCUtility.shared.getDAV() + "/trashbin/" + appDelegate.userID + "/restore/" + tableTrash.fileName
        
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true) { (account, errorCode, errorDescription) in
            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.sharedInstance.deleteTrash(fileId: fileId, account: account)
                self.reloadDataSource()
            }  else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }
    
    func emptyTrash() {
        
        let serverUrlFileName = appDelegate.urlBase + "/" + NCUtility.shared.getDAV() + "/trashbin/" + appDelegate.userID + "/trash"

        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName) { (account, errorCode, errorDescription) in
            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.sharedInstance.deleteTrash(fileId: nil, account: self.appDelegate.account)
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
            self.reloadDataSource()
        }
    }
    
    func deleteItem(with fileId: String) {
        
        guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: fileId, account: appDelegate.account) else {
            return
        }
        
        let serverUrlFileName = tableTrash.filePath + tableTrash.fileName
        
        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName) { (account, errorCode, errorDescription) in
            if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.sharedInstance.deleteTrash(fileId: fileId, account: account)
                self.reloadDataSource()
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }
    
    func downloadThumbnail(with tableTrash: tableTrash, indexPath: IndexPath) {
        
        let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(tableTrash.fileId, etag: tableTrash.fileName)!
        let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)!
        
        NCCommunication.shared.downloadPreview(fileNamePathOrFileId: tableTrash.fileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: Int(k_sizePreview), heightPreview: Int(k_sizePreview), fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: Int(k_sizeIcon), endpointTrashbin: true) { (account, imagePreview, imageIcon, errorCode, errorDescription) in
            
            if errorCode == 0 && imageIcon != nil && account == self.appDelegate.account {
                if let cell = self.collectionView.cellForItem(at: indexPath) {
                    if cell is NCTrashListCell {
                        (cell as! NCTrashListCell).imageItem.image = imageIcon
                    } else if cell is NCGridCell {
                        (cell as! NCGridCell).imageItem.image = imageIcon
                    }
                }
            }
        }
    }
}
