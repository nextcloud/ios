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
    
    private enum ImageName: String {
        case favorite = "star.fill"
        case addToFavorite = "star.hollow"
        case livePhoto = "livephoto"
        case details = "details"
        case share = "menu.share"
        case unshare = "person.2.slash"
        case trash = "trash_icon"
        case rename = "rename"
        case viewInFolder = "questionmark.folder"
        case moveOrCopy = "moveOrCopy"
        case addToOffline = "offline"
        case availableOffline = "synced"
        case downloadFullResolutionImage = "media"
        case goToPage = "book.pages"
        case modifyWithQuickLook = "pencil.tip.crop.circle"
        case search = "magnifyingglass"
        case saveAsScan = "doc.viewfinder"
        case lock = "item.lock"
        case lockOpen = "item.lock.open"
        case readOnly = "eye"
        case edit = "pencil"
        case add = "plus"
        case selectAll = "checkmark.circle.fill"
        case cancel = "xmark"
        case uploadPhotosVideos = "upload_photos_or_videos"
        case uploadFile = "uploadFile"
        case scan = "scan"
        case document = "doc.text"
        case richDocument = "doc.richtext"
        case spreadsheet = "tablecells"
        case presentation = "play.rectangle"
    }
    
    private static let utility = NCUtility()
    
    static var favorite: UIImage {
        utility.loadImage(
            named: ImageName.favorite.rawValue,
            colors: [NCBrandColor.shared.brandElement])
    }
    
    static var shareHeaderFavorite: UIImage {
        utility.loadImage(
            named: ImageName.favorite.rawValue,
            colors: [NCBrandColor.shared.brandElement],
            size: 20)
    }
    
    static var livePhoto: UIImage {
        utility.loadImage(
            named: ImageName.livePhoto.rawValue,
            colors: [NCBrandColor.shared.iconImageColor])
    }
    
    static var menuIconRemoveFromFavorite: UIImage {
        menuIcon(ImageName.favorite)
    }
    
    static var menuIconAddToFavorite: UIImage {
        menuIcon(ImageName.addToFavorite)
    }
    
    static var menuIconDetails: UIImage {
        menuIcon(ImageName.details)
    }
    
    static var menuIconShare: UIImage {
        menuIcon(ImageName.share)
    }
    
    static var menuIconTrash: UIImage {
        menuIcon(ImageName.trash)
    }
    
    static var menuIconRename: UIImage {
        menuIcon(ImageName.rename)
    }
    
    static var menuIconViewInFolder: UIImage {
        menuIcon(ImageName.viewInFolder)
    }
    
    static var menuIconMoveOrCopy: UIImage {
        menuIcon(ImageName.moveOrCopy)
    }
    
    static var menuIconAddToOffline: UIImage {
        menuIcon(ImageName.addToOffline)
    }
    
    static var menuIconAvailableOffline: UIImage {
        menuIcon(ImageName.availableOffline)
    }
    
    static var menuIconDownloadFullResolutionImage: UIImage {
        menuIcon(ImageName.downloadFullResolutionImage)
    }
    
    static var menuIconGoToPage: UIImage {
        menuIcon(ImageName.goToPage)
    }
    
    static var menuIconModifyWithQuickLook: UIImage {
        menuIcon(ImageName.modifyWithQuickLook)
    }
    
    static var menuIconSearch: UIImage {
        menuIcon(ImageName.search)
    }
    
    static var menuIconLivePhoto: UIImage {
        menuIcon(ImageName.livePhoto)
    }
    
    static var menuIconSaveAsScan: UIImage {
        menuIcon(ImageName.saveAsScan)
    }

    static var menuIconLock: UIImage {
        menuIcon(ImageName.lock)
    }
    
    static var menuIconLockOpen: UIImage {
        menuIcon(ImageName.lockOpen)
    }
    
    static var menuIconUnshare: UIImage {
        menuIcon(ImageName.unshare)
    }
    
    static var menuIconReadOnly: UIImage {
        menuIcon(ImageName.readOnly)
    }
    
    static var menuIconEdit: UIImage {
        menuIcon(ImageName.edit)
    }
    
    static var menuIconAdd: UIImage {
        menuIcon(ImageName.add)
    }
    
    static var menuIconSelectAll: UIImage {
        menuIcon(ImageName.selectAll)
    }
    
    static var menuIconCancel: UIImage {
        menuIcon(ImageName.cancel)
    }
    
    static var menuIconUploadPhotosVideos: UIImage {
        menuIcon(ImageName.uploadPhotosVideos)
    }
    
    static var menuIconUploadUploadFile: UIImage {
        menuIcon(ImageName.uploadFile)
    }
    
    static var menuIconScan: UIImage {
        menuIcon(ImageName.scan)
    }
    
    static var menuIconCreateNewDocument: UIImage {
        menuIcon(ImageName.document)
    }
    
    static var menuIconCreateNewSpreadsheet: UIImage {
        menuIcon(ImageName.spreadsheet)
    }
    
    static var menuIconCreateNewPresentation: UIImage {
        menuIcon(ImageName.presentation)
    }
    
    static var menuIconCreateNewRichDocument: UIImage {
        menuIcon(ImageName.richDocument)
    }
    
    private static func menuIcon(_ imageName: ImageName) -> UIImage {
        utility.loadImage(
            named: imageName.rawValue,
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
