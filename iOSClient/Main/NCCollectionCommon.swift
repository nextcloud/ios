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
        
        images.cellSharedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 50, height: 50, color: NCBrandColor.sharedInstance.graySoft)
        images.cellCanShareImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 50, height: 50, color: NCBrandColor.sharedInstance.graySoft)
        images.cellShareByLinkImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), width: 50, height: 50, color: NCBrandColor.sharedInstance.graySoft)
        
        images.cellFavouriteImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite)
        images.cellCommentImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "comment"), width: 50, height: 50, color: NCBrandColor.sharedInstance.graySoft)
        images.cellLivePhotoImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView)
        images.cellOfflineFlag = UIImage.init(named: "offlineFlag")!
        images.cellLocal = UIImage.init(named: "local")!
            
        images.cellFolderEncryptedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderEncrypted"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        images.cellFolderSharedWithMeImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        images.cellFolderPublicImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_public"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        images.cellFolderGroupImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_group"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        images.cellFolderExternalImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_external"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        images.cellFolderAutomaticUploadImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderAutomaticUpload"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        images.cellFolderImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        
        images.cellCheckedYes = CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedYes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement)
        images.cellCheckedNo = CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedNo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.graySoft)
        
        images.cellButtonMore = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.graySoft)
        images.cellButtonStop = CCGraphics.changeThemingColorImage(UIImage.init(named: "stop"), width: 50, height: 50, color: NCBrandColor.sharedInstance.graySoft)
    }
    
    // MARK: - NCSelect + Delegate
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, array: [Any], buttonType: String, overwrite: Bool) {
        if (serverUrl != nil && array.count > 0) {
            var move = true
            if buttonType == "done1" { move = false }
            
            for metadata in array as! [tableMetadata] {
                NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: move)
            }
        }
    }

    func openSelectView(viewController: UIViewController, array: [Any]) {
        
        let navigationController = UIStoryboard.init(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let vc = navigationController.topViewController as! NCSelect
        
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
        vc.array = array
        
        navigationController.modalPresentationStyle = .fullScreen
        viewController.present(navigationController, animated: true, completion: nil)
    }
    
    @objc func openFileViewInFolder(serverUrl: String, fileName: String) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        let viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as! NCFileViewInFolder
        let navigationController = UINavigationController.init(rootViewController: viewController)

        viewController.serverUrl = serverUrl
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
    }
}

// MARK: - List Layout

class NCListLayout: UICollectionViewFlowLayout {
    
    let itemHeight: CGFloat = 60
    
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
                
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
                
                return CGSize(width: itemWidth, height: itemHeight)
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
