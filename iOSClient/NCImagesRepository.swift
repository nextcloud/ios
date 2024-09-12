//
//  NCImagesRepository.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 11.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation
import UIKit

class NCImagesRepository: NSObject {
    private static let utility = NCUtility()
    
    static var favorite: UIImage {
        utility.loadImage(
            named: "star.fill",
            colors: [NCBrandColor.shared.brandElement])
    }
    
    static var shareHeaderFavorite: UIImage {
        utility.loadImage(
            named: "star.fill",
            colors: [NCBrandColor.shared.brandElement],
            size: 20)
    }
    
    static var livePhoto: UIImage {
        utility.loadImage(
            named: "livephoto",
            colors: [NCBrandColor.shared.iconImageColor])
    }
    
    static var menuIconRemoveFromFavorite: UIImage {
        favorite.image(color: .menuIconTint)
    }
    
    static var menuIconAddToFavorite: UIImage {
        utility.loadImage(
            named: "star.hollow",
            colors: [.menuIconTint])
    }
    
    static var menuIconDetails: UIImage {
        utility.loadImage(
            named: "details",
            colors: [.menuIconTint])
    }
    
    static var menuIconShare: UIImage {
        utility.loadImage(
            named: "menu.share",
            colors: [.menuIconTint])
    }
    
    static var menuIconTrash: UIImage {
        utility.loadImage(
            named: "trash_icon",
            colors: [.menuIconTint])
    }
    
    static var menuIconRename: UIImage {
        utility.loadImage(
            named: "rename",
            colors: [.menuIconTint])
    }
    
    static var menuIconViewInFolder: UIImage {
        utility.loadImage(
            named: "questionmark.folder",
            colors: [.menuIconTint])
    }
    
    static var menuIconMoveOrCopy: UIImage {
        utility.loadImage(
            named: "moveOrCopy",
            colors: [.menuIconTint])
    }
    
    static var menuIconAddToOffline: UIImage {
        utility.loadImage(
            named: "offline",
            colors: [.menuIconTint])
    }
    
    static var menuIconAvailableOffline: UIImage {
        utility.loadImage(
            named: "synced")
    }
    
    static var menuIconDownloadFullResolutionImage: UIImage {
        utility.loadImage(
            named: "media",
            colors: [.menuIconTint])
    }
    
    static var menuIconGoToPage: UIImage {
        utility.loadImage(
            named: "book.pages",
            colors: [.menuIconTint])
    }
    
    static var menuIconModifyWithQuickLook: UIImage {
        utility.loadImage(
            named: "pencil.tip.crop.circle",
            colors: [.menuIconTint])
    }
    
    static var menuIconSearch: UIImage {
        utility.loadImage(
            named: "magnifyingglass",
            colors: [.menuIconTint])
    }
    
    static var menuIconLivePhoto: UIImage {
        livePhoto.image(color: .menuIconTint)
    }
    
    static var menuIconSaveAsScan: UIImage {
        utility.loadImage(
            named: "doc.viewfinder",
            colors: [.menuIconTint])
    }

    static var menuIconLock: UIImage {
        utility.loadImage(
            named: "item.lock",
            colors: [.menuIconTint])
    }
    
    static var menuIconLockOpen: UIImage {
        utility.loadImage(
            named: "item.lock.open",
            colors: [.menuIconTint])
    }
    
    static var menuIconUnshare: UIImage {
        utility.loadImage(
            named: "person.2.slash",
            colors: [.menuIconTint])
    }
    
    static var menuIconReadOnly: UIImage {
        utility.loadImage(
            named: "eye",
            colors: [.menuIconTint])
    }
    
    static var menuIconEdit: UIImage {
        utility.loadImage(
            named: "pencil",
            colors: [.menuIconTint])
    }
    
    static var menuIconAdd: UIImage {
        utility.loadImage(
            named: "plus",
            colors: [.menuIconTint])
    }
    
    static var menuIconSelectAll: UIImage {
        utility.loadImage(
            named: "checkmark.circle.fill",
            colors: [.menuIconTint])
    }
    
    static var menuIconCancel: UIImage {
        utility.loadImage(
            named: "xmark",
            colors: [.menuIconTint])
    }
    
    static var menuIconUploadPhotosVideos: UIImage {
        utility.loadImage(
            named: "upload_photos_or_videos",
            colors: [.menuIconTint])
    }
    
    static var menuIconUploadUploadFile: UIImage {
        utility.loadImage(
            named: "uploadFile",
            colors: [.menuIconTint])
    }
    
    static var menuIconScan: UIImage {
        utility.loadImage(
            named: "scan",
            colors: [.menuIconTint])
    }
    
    static var menuIconCreateNewDocument: UIImage {
        utility.loadImage(
            named: "doc.text",
            colors: [.menuIconTint])
    }
    
    static var menuIconCreateNewSpreadsheet: UIImage {
        utility.loadImage(
            named: "tablecells",
            colors: [.menuIconTint])
    }
    
    static var menuIconCreateNewPresentation: UIImage {
        utility.loadImage(
            named: "play.rectangle",
            colors: [.menuIconTint])
    }
    
    static var menuIconCreateNewRichDocument: UIImage {
        utility.loadImage(
            named: "doc.richtext",
            colors: [.menuIconTint])
    }
}

extension UIColor {
    static var menuIconTint: UIColor {
        NCBrandColor.shared.menuIconColor
    }
    
    static var menuFolderIconTint: UIColor {
        NCBrandColor.shared.menuFolderIconColor
    }
}
