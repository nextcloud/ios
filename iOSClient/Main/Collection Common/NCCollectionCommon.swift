//
//  NCCollectionCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/09/2020.
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

class NCCollectionCommon: NSObject, NCSelectDelegate {
    @objc static let shared: NCCollectionCommon = {
        let instance = NCCollectionCommon()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // MARK: - NCSelect + Delegate
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], buttonType: String, overwrite: Bool) {
        if (serverUrl != nil && items.count > 0) {
            var move = true
            if buttonType == "done1" { move = false }
            
            for metadata in items as! [tableMetadata] {
                NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: move)
            }
        }
    }

    func openSelectView(items: [Any], viewController: UIViewController) {
        
        let navigationController = UIStoryboard.init(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let topViewController = navigationController.topViewController as! NCSelect
        var listViewController = [NCSelect]()
        
        var copyItems: [Any] = []
        for item in items {
            copyItems.append(item)
        }
        
        let homeUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        var serverUrl = (copyItems[0] as! Nextcloud.tableMetadata).serverUrl
        
        // Setup view controllers such that the current view is of the same directory the items to be copied are in
        while true {
            // If not in the topmost directory, create a new view controller and set correct title.
            // If in the topmost directory, use the default view controller as the base.
            var viewController: NCSelect?
            if serverUrl != homeUrl {
                viewController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect
                if viewController == nil {
                    return
                }
                viewController!.titleCurrentFolder = (serverUrl as NSString).lastPathComponent
            } else {
                viewController = topViewController
            }
            guard let vc = viewController else { return }

            vc.delegate = self
            vc.hideButtonCreateFolder = false
            vc.selectFile = false
            vc.includeDirectoryE2EEncryption = false
            vc.includeImages = false
            vc.type = ""
            vc.titleButtonDone = NSLocalizedString("_move_", comment: "")
            vc.titleButtonDone1 = NSLocalizedString("_copy_",comment: "")
            vc.isButtonDone1Hide = false
            vc.isOverwriteHide = false
            vc.items = copyItems
            vc.serverUrl = serverUrl
            
            vc.navigationItem.backButtonTitle = vc.titleCurrentFolder
            listViewController.insert(vc, at: 0)
            
            if serverUrl != homeUrl {
                serverUrl = NCUtilityFileSystem.shared.deletingLastPathComponent(serverUrl: serverUrl, urlBase: appDelegate.urlBase, account: appDelegate.account)
            } else {
                break
            }
        }
        
        navigationController.setViewControllers(listViewController, animated: false)
        navigationController.modalPresentationStyle = .formSheet
        
        viewController.present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: - Context Menu Configuration
    
    @available(iOS 13.0, *)
    func contextMenuConfiguration(metadata: tableMetadata, viewController: UIViewController, enableDeleteLocal: Bool, enableViewInFolder: Bool) -> UIMenu {
        
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }
        var titleSave: String = NSLocalizedString("_save_selected_files_", comment: "")
        let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        if metadataMOV != nil {
            titleSave = NSLocalizedString("_livephoto_save_", comment: "")
        }
        
        let copy = UIAction(title: NSLocalizedString("_copy_file_", comment: ""), image: UIImage(systemName: "doc.on.doc") ) { action in
            self.appDelegate.pasteboardOcIds = [metadata.ocId]
            NCFunctionCenter.shared.copyPasteboard()
        }
        
        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""), image: UIImage(systemName: "info") ) { action in
            NCFunctionCenter.shared.openShare(ViewController: viewController, metadata: metadata, indexPage: 0)
        }
        
        let save = UIAction(title: titleSave, image: UIImage(systemName: "square.and.arrow.down")) { action in
            if metadataMOV != nil {
                NCFunctionCenter.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV!)
            } else {
                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    NCFunctionCenter.shared.saveAlbum(metadata: metadata)
                } else {
                    NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                }
            }
        }
        
        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""), image: UIImage(systemName: "arrow.forward.square")) { action in
            NCFunctionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        }
        
        let openIn = UIAction(title: NSLocalizedString("_open_in_", comment: ""), image: UIImage(systemName: "square.and.arrow.up") ) { action in
            NCFunctionCenter.shared.downloadOpen(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn)
        }
        
        let openQuickLook = UIAction(title: NSLocalizedString("_open_quicklook_", comment: ""), image: UIImage(systemName: "eye")) { action in
            NCFunctionCenter.shared.downloadOpen(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
        }
        
        let open = UIMenu(title: NSLocalizedString("_open_", comment: ""), image: UIImage(systemName: "square.and.arrow.up"), children: [openIn, openQuickLook])
        
        let moveCopy = UIAction(title: NSLocalizedString("_move_or_copy_", comment: ""), image: UIImage(systemName: "arrow.up.right.square")) { action in
            NCCollectionCommon.shared.openSelectView(items: [metadata], viewController: viewController)
        }
        
        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile, image: UIImage(systemName: "trash"), attributes: .destructive) { action in
            NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: false) { (errorCode, errorDescription) in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
        
        let deleteConfirmLocal = UIAction(title: NSLocalizedString("_remove_local_file_", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { action in
            NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: true) { (errorCode, errorDescription) in
            }
        }
        
        var delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmLocal, deleteConfirmFile])
        
        if !enableDeleteLocal {
            delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }
        
        if metadata.directory {
            delete = UIMenu(title: NSLocalizedString("_delete_folder_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }
        
        // ------ MENU -----
        
        if metadata.directory {
             return UIMenu(title: "", children: [detail, moveCopy, delete])
        }
        
        var children: [UIMenuElement] = [detail, open, moveCopy, copy, delete]

        if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage || metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo {
            children.insert(save, at: 2)
        }
        
        if enableViewInFolder {
            children.insert(viewInFolder, at: 5)
        }
        
        return UIMenu(title: "", image: nil, identifier: nil, children: children)
    }
}


// MARK: - List Layout

class NCListLayout: UICollectionViewFlowLayout {
    
    var itemHeight: CGFloat = 60
    
    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 0
        minimumLineSpacing = 1
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                let itemWidth: CGFloat = collectionView.frame.width
                return CGSize(width: itemWidth, height: self.itemHeight)
            }
            
            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}

// MARK: - Grid Layout

class NCGridLayout: UICollectionViewFlowLayout {
    
    var heightLabelPlusButton: CGFloat = 45
    var marginLeftRight: CGFloat = 6
    var itemForLine: CGFloat = 3
    var itemWidthDefault: CGFloat = 120

    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 1
        minimumLineSpacing = marginLeftRight
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: marginLeftRight, bottom: 0, right:  marginLeftRight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                
                if collectionView.frame.width < 400 {
                    itemForLine = 3
                } else {
                    itemForLine = collectionView.frame.width / itemWidthDefault
                }
                
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
                
                return CGSize(width: itemWidth, height: itemHeight)
            }
            
            // Default fallback
            return CGSize(width: itemWidthDefault, height: itemWidthDefault)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
