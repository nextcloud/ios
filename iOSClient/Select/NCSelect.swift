//
//  NCSelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/2018.
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

@objc protocol NCSelectDelegate {
    @objc func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, buttonType: String, overwrite: Bool)
}

class NCSelect: UIViewController, UIGestureRecognizerDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var toolbar: UIView!
    @IBOutlet fileprivate weak var overwriteView: UIView!

    @IBOutlet fileprivate weak var buttonCancel: UIBarButtonItem!
    @IBOutlet fileprivate weak var buttonCreateFolder: UIButton!
    @IBOutlet fileprivate weak var buttonDone: UIButton!
    @IBOutlet fileprivate weak var buttonDone1: UIButton!
    
    @IBOutlet fileprivate weak var overwriteSwitch: UISwitch!
    @IBOutlet fileprivate weak var overwriteLabel: UILabel!
    
    @IBOutlet fileprivate weak var toolBarTop: NSLayoutConstraint!

    // ------ external settings ------------------------------------
    @objc var delegate: NCSelectDelegate?
    
    @objc var hideButtonCreateFolder = false
    @objc var selectFile = false
    @objc var includeDirectoryE2EEncryption = false
    @objc var includeImages = false
    @objc var type = ""
    @objc var titleButtonDone = NSLocalizedString("_move_", comment: "")
    @objc var titleButtonDone1 = NSLocalizedString("_copy_", comment: "")
    @objc var isButtonDone1Hide = true
    @objc var isOverwriteHide = true
    @objc var keyLayout = k_layout_view_move
    @objc var heightToolBarTop: CGFloat = 100
    
    var titleCurrentFolder = NCBrandOptions.sharedInstance.brand
    var serverUrl = ""
    // -------------------------------------------------------------
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var serverUrlPush = ""
    private var metadataPush: tableMetadata?
    private var metadataFolder = tableMetadata()
    
    private var isEditMode = false
    private var networkInProgress = false
    private var selectocId: [String] = []
    private var overwrite = false
    private var sectionDatasource = CCSectionDataSourceMetadata()
    
    private var layout = ""
    private var groupBy = ""
    private var titleButton = ""
    private var itemForLine = 0

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    
    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
        
    private let headerMenuHeight: CGFloat = 50
    private let sectionHeaderHeight: CGFloat = 20
    private let footerHeight: CGFloat = 50
    
    private var shares: [tableShare]?
    
    private let refreshControl = UIRefreshControl()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib.init(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        
        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        
        // Configure Refresh Control
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandElement
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        refreshControl.addTarget(self, action: #selector(loadDatasource), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self;
        self.collectionView.emptyDataSetSource = self;
        
        // title button
        buttonCancel.title = NSLocalizedString("_cancel_", comment: "")
        buttonCreateFolder.setTitle(NSLocalizedString("_create_folder_", comment: ""), for: .normal)
        overwriteLabel.text = NSLocalizedString("_overwrite_", comment: "")
        
        // button
        buttonCreateFolder.layer.cornerRadius = 15
        buttonCreateFolder.layer.masksToBounds = true
        buttonCreateFolder.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.5).cgColor
        buttonCreateFolder.setTitleColor(.black, for: .normal)

        buttonDone.layer.cornerRadius = 15
        buttonDone.layer.masksToBounds = true
        buttonDone.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.5).cgColor
        buttonDone.setTitleColor(.black, for: .normal)
        
        buttonDone1.layer.cornerRadius = 15
        buttonDone1.layer.masksToBounds = true
        buttonDone1.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.5).cgColor
        buttonDone1.setTitleColor(.black, for: .normal)
                
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: k_notificationCenter_reloadDataSource), object: nil)

        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = titleCurrentFolder
        
        toolBarTop.constant = -heightToolBarTop
        
        buttonDone.setTitle(titleButtonDone, for: .normal)
        buttonDone1.setTitle(titleButtonDone1, for: .normal)
        buttonDone1.isHidden = isButtonDone1Hide
        overwriteSwitch.isOn = overwrite
        overwriteView.isHidden = isOverwriteHide
        
        if selectFile {
            buttonDone.isHidden = true
        }
        
        if hideButtonCreateFolder {
            buttonCreateFolder.isHidden = true
        }
                
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)
        
        (layout, _, _, groupBy, _, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: keyLayout)
        
        if layout == k_layout_list {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
        
        loadDatasource(withLoadFolder: true)

        shares = NCManageDatabase.sharedInstance.getTableShares(account: appDelegate.account, serverUrl: serverUrl)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        toolbar.backgroundColor = NCBrandColor.sharedInstance.tabBar
        //toolbar.tintColor = .gray
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        if networkInProgress {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "networkInProgress"), width: 300, height: 300, color: UIColor.lightGray)
        } else {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
        }
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        
        if networkInProgress {
            return NSAttributedString.init(string: "\n"+NSLocalizedString("_request_in_progress_", comment: ""), attributes: attributes)
        } else if includeImages {
            return NSAttributedString.init(string: "\n"+NSLocalizedString("_files_no_files_", comment: ""), attributes: attributes)
        } else {
            return NSAttributedString.init(string: "\n"+NSLocalizedString("_files_no_folders_", comment: ""), attributes: attributes)
        }
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: ACTION
    
    @IBAction func actionCancel(_ sender: Any) {
        delegate?.dismissSelect(serverUrl: nil, metadata: nil, type: type, buttonType: "cancel", overwrite: overwrite)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func actionDone(_ sender: Any) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, buttonType: "done", overwrite: overwrite)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func actionDone1(_ sender: Any) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, buttonType: "done1", overwrite: overwrite)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func actionCreateFolder(_ sender: Any) {
        
        let alertController = UIAlertController(title: NSLocalizedString("_create_folder_", comment: ""), message:"", preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.autocapitalizationType = UITextAutocapitalizationType.words
        }
        
        let actionSave = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default) { (action:UIAlertAction) in
            if let fileName = alertController.textFields?.first?.text  {
                self.createFolder(with: fileName)
            }
        }
        
        let actionCancel = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (action:UIAlertAction) in
            print("You've pressed cancel button")
        }
        
        alertController.addAction(actionSave)
        alertController.addAction(actionCancel)
        
        self.present(alertController, animated: true, completion:nil)
    }
    
    @IBAction func valueChangedSwitchOverwrite(_ sender: Any) {
        if let viewControllers = self.navigationController?.viewControllers {
            for viewController in viewControllers {
                if viewController is NCSelect {
                    (viewController as! NCSelect).overwrite = overwriteSwitch.isOn
                }
            }
        }
    }
    
    // MARK: TAP EVENT
    
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
            NCUtility.shared.setLayoutForView(key: keyLayout, layout: layout)
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
            NCUtility.shared.setLayoutForView(key: keyLayout, layout: layout)
        }
    }
    
    func tapOrderHeader(sender: Any) {
        
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: keyLayout, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }
    
    func tapMoreHeader(sender: Any) {
    }
    
    func tapMoreListItem(with objectId: String, sender: Any) {
    }
    
    func tapMoreGridItem(with objectId: String, sender: Any) {
    }
    
    func tapShareListItem(with objectId: String, sender: Any) {
    }
}

// MARK: - Collection View

extension NCSelect: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return
        }
        
        if isEditMode {
            if let index = selectocId.firstIndex(of: metadata.ocId) {
                selectocId.remove(at: index)
            } else {
                selectocId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }
        
        if metadata.directory {
            
            guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName) else { return }
            guard let visualController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect else { return }

            self.serverUrlPush = serverUrlPush
            self.metadataPush = metadata
            
            visualController.delegate = delegate
            visualController.hideButtonCreateFolder = hideButtonCreateFolder
            visualController.selectFile = selectFile
            visualController.includeDirectoryE2EEncryption = includeDirectoryE2EEncryption
            visualController.includeImages = includeImages
            visualController.type = type
            visualController.titleButtonDone = titleButtonDone
            visualController.titleButtonDone1 = titleButtonDone1
            visualController.keyLayout = keyLayout
            visualController.isButtonDone1Hide = isButtonDone1Hide
            visualController.isOverwriteHide = isOverwriteHide
            visualController.overwrite = overwrite
            visualController.heightToolBarTop = heightToolBarTop
                
            visualController.titleCurrentFolder = metadataPush!.fileNameView
            visualController.serverUrl = serverUrlPush
                   
            self.navigationController?.pushViewController(visualController, animated: true)
            
        } else {
            
            delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadata, type: type, buttonType: "select", overwrite: overwrite)
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension NCSelect: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if (indexPath.section == 0) {
            
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
                
                if collectionView.collectionViewLayout == gridLayout {
                    header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
                } else {
                    header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
                }
                
                header.delegate = self
                
                header.setStatusButton(count: sectionDatasource.allOcId.count)
                header.setTitleSorted(datasourceTitleButton: titleButton)
                
                if groupBy == "none" {
                    header.labelSection.isHidden = true
                    header.labelSectionHeightConstraint.constant = 0
                } else {
                    header.labelSection.isHidden = false
                    header.setTitleLabel(sectionDatasource: sectionDatasource, section: indexPath.section)
                    header.labelSectionHeightConstraint.constant = sectionHeaderHeight
                }
                
                return header
                
            } else {
                
                let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
                
                footer.setTitleLabel(sectionDatasource: sectionDatasource)
                
                return footer
            }
            
        } else {
            
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionHeader
                
                header.setTitleLabel(sectionDatasource: sectionDatasource, section: indexPath.section)
                
                return header
                
            } else {
                
                let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
                
                footer.setTitleLabel(sectionDatasource: sectionDatasource)
                
                return footer
            }
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        return sections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let key = sectionDatasource.sections.object(at: section)
        let datasource = sectionDatasource.sectionArrayRow.object(forKey: key) as! [tableMetadata]
        return datasource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell: UICollectionViewCell
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        if layout == k_layout_grid {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
        } else {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        NCMainCommon.sharedInstance.collectionViewCellForItemAt(indexPath, collectionView: collectionView, cell: cell, metadata: metadata, metadataFolder: metadataFolder, serverUrl: serverUrl, isEditMode: isEditMode, selectocId: selectocId, autoUploadFileName: autoUploadFileName, autoUploadDirectory: autoUploadDirectory ,hideButtonMore: true, downloadThumbnail: true, shares: shares, source: self)
        
        if layout == k_layout_grid {
            let cell = cell as! NCGridCell
            cell.buttonMore.isHidden = true
            
            return cell
        } else {
            let cell = cell as! NCListCell
            cell.imageMore.isHidden = true
            cell.sharedLeftConstraint.constant = 15
            
            return cell
        }
    }
}

extension NCSelect: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            if groupBy == "none" {
                return CGSize(width: collectionView.frame.width, height: headerMenuHeight)
            } else {
                return CGSize(width: collectionView.frame.width, height: headerMenuHeight + sectionHeaderHeight)
            }
        } else {
            return CGSize(width: collectionView.frame.width, height: sectionHeaderHeight)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        if (section == sections - 1) {
            return CGSize(width: collectionView.frame.width, height: footerHeight)
        } else {
            return CGSize(width: collectionView.frame.width, height: 0)
        }
    }
}

// MARK: - NC API & Algorithm

extension NCSelect {

    @objc func reloadDataSource() {
        loadDatasource(withLoadFolder: false)
    }
    
    @objc func loadDatasource(withLoadFolder: Bool) {
        
        var predicate: NSPredicate?
        var sort: String
        var ascending: Bool
        var directoryOnTop: Bool
        
        sectionDatasource = CCSectionDataSourceMetadata()
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: keyLayout)
        
        if serverUrl == "" {
            
            serverUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        }
        
        if includeDirectoryE2EEncryption {
            
            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND (directory == true OR typeFile == 'image')", appDelegate.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", appDelegate.account, serverUrl)
            }
            
        } else {
            
            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND (directory == true OR typeFile == 'image')", appDelegate.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND directory == true", appDelegate.account, serverUrl)
            }
        }
        
        let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: predicate!)
        sectionDatasource = CCSectionMetadata.creataDataSourseSectionMetadata(metadatas, listProgressMetadata: nil, groupBy: groupBy, filterTypeFileImage: false, filterTypeFileVideo: false, filterLivePhoto: false, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, account: appDelegate.account)
        
        if withLoadFolder {
            loadFolder()
        } else {
            self.refreshControl.endRefreshing()
        }
        
        collectionView.reloadData()
    }
    
    func createFolder(with fileName: String) {
        
        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: appDelegate.account, urlBase: appDelegate.urlBase) { (errorCode, errorDescription) in
            
            if errorCode == 0 {
                self.loadDatasource(withLoadFolder: true)
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    func loadFolder() {
        
        networkInProgress = true
        collectionView.reloadData()
        
        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: appDelegate.account) { (_, _, _, _, _, _, _) in
            
            self.networkInProgress = false
            self.loadDatasource(withLoadFolder: false)
        }
    }
}
