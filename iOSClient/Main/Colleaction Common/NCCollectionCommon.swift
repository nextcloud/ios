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
        instance.createImagesThemingColor()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    struct images {
        static var cellFileImage = UIImage()

        static var cellSharedImage = UIImage()
        static var cellCanShareImage = UIImage()
        static var cellShareByLinkImage = UIImage()
        
        static var cellFavouriteImage = UIImage()
        static var cellCommentImage = UIImage()
        static var cellLivePhotoImage = UIImage()
        static var cellOfflineFlag = UIImage()
        static var cellLocal = UIImage()

        static var cellFolderEncryptedImage = UIImage()
        static var cellFolderSharedWithMeImage = UIImage()
        static var cellFolderPublicImage = UIImage()
        static var cellFolderGroupImage = UIImage()
        static var cellFolderExternalImage = UIImage()
        static var cellFolderAutomaticUploadImage = UIImage()
        static var cellFolderImage = UIImage()
        
        static var cellCheckedYes = UIImage()
        static var cellCheckedNo = UIImage()
        
        static var cellButtonMore = UIImage()
        static var cellButtonStop = UIImage()
    }
    
    // MARK: -
    
    @objc func createImagesThemingColor() {
        
        images.cellFileImage = UIImage.init(named: "file")!
        
        images.cellSharedImage = UIImage(named: "share")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellCanShareImage = UIImage(named: "share")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellShareByLinkImage = UIImage(named: "sharebylink")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        
        images.cellFavouriteImage = UIImage(named: "favorite")!.image(color: NCBrandColor.shared.yellowFavorite, size: 50)
        images.cellCommentImage = UIImage(named: "comment")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellLivePhotoImage = UIImage(named: "livePhoto")!.image(color: NCBrandColor.shared.textView, size: 50)
        images.cellOfflineFlag = UIImage.init(named: "offlineFlag")!
        images.cellLocal = UIImage.init(named: "local")!
            
        let folderWidth: CGFloat = UIScreen.main.bounds.width / 3
        images.cellFolderEncryptedImage = UIImage(named: "folderEncrypted")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderSharedWithMeImage = UIImage(named: "folder_shared_with_me")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderPublicImage = UIImage(named: "folder_public")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderGroupImage = UIImage(named: "folder_group")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderExternalImage = UIImage(named: "folder_external")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderAutomaticUploadImage = UIImage(named: "folderAutomaticUpload")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderImage =  UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        
        images.cellCheckedYes = UIImage(named: "checkedYes")!.image(color: .darkGray, size: 50)
        images.cellCheckedNo = UIImage(named: "checkedNo")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        
        images.cellButtonMore = UIImage(named: "more")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellButtonStop = UIImage(named: "stop")!.image(color: NCBrandColor.shared.graySoft, size: 50)
    }
    
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

    func openSelectView(items: [Any]) {
        
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
        
        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
    }
    
    @objc func openFileViewInFolder(serverUrl: String, fileName: String) {
        
        let viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as! NCFileViewInFolder
        let navigationController = UINavigationController.init(rootViewController: viewController)

        let topViewController = viewController
        var listViewController = [NCFileViewInFolder]()
        var serverUrl = serverUrl
        let homeUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        
        while true {
            
            var viewController: NCFileViewInFolder?
            if serverUrl != homeUrl {
                viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as? NCFileViewInFolder
                if viewController == nil {
                    return
                }
                viewController!.titleCurrentFolder = (serverUrl as NSString).lastPathComponent
            } else {
                viewController = topViewController
            }
            guard let vc = viewController else { return }
            
            vc.serverUrl = serverUrl
            vc.fileName = fileName
            
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
        
        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
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
