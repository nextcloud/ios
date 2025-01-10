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
        case favorite = "star.filled"
        case addToFavorite = "star.hollow"
        case livePhoto = "livephoto"
        case details = "details"
        case share = "menu.share"
        case unshare = "unshare"
        case trash = "trash_icon"
		case delete = "delete"
        case rename = "rename"
        case viewInFolder = "viewInFolder"
        case moveOrCopy = "moveOrCopy"
        case addToOffline = "offline"
        case availableOffline = "synced"
        case goToPage = "goToPage"
        case modifyWithQuickLook = "modifyWithQuickLook"
        case search = "menu.search"
        case lock = "item.lock"
        case lockOpen = "item.lock.open"
        case readOnly = "readOnly"
        case edit = "allowEdit"
        case add = "menu.add"
        case selectAll = "checkmark.circle.fill"
        case close = "xmark"
        case photoOrVideo = "photoOrVideo"
        case uploadFile = "uploadFile"
        case scan = "scan"
        case document = "document"
        case spreadsheet = "spreadsheet"
        case presentation = "presentation"
        case createFolder = "createFolder"
        case restore = "restore"
		
		case mediaForward = "MediaPlayer/Forward"
		case mediaFullscreen = "MediaPlayer/Fullscreen"
		case mediaCloseFullscreen = "MediaPlayer/CloseFullscreen"
		case mediaMessage = "MediaPlayer/Message"
		case mediaPause = "MediaPlayer/Pause"
		case mediaPlay = "MediaPlayer/Play"
		case mediaRewind = "MediaPlayer/Rewind"
		case mediaSound = "MediaPlayer/Sound"
    }
    
    private static let utility = NCUtility()
    
    static var shareHeaderFavorite: UIImage {
        utility.loadImage(
            named: ImageName.favorite.rawValue,
            colors: [NCBrandColor.shared.brandElement],
            size: 20)
    }
    
    static var trash: UIImage {
        UIImage(resource: .deleted).withRenderingMode(.alwaysTemplate)
    }
    
	// menu
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
	
	static var menuIconDelete: UIImage {
		menuIcon(ImageName.delete)
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
        utility.loadImage(named: ImageName.availableOffline.rawValue)
    }
    
    static var menuIconDownloadFullResolutionImage: UIImage {
        menuIcon(ImageName.photoOrVideo)
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
        menuIcon(ImageName.scan)
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
    
    static var menuIconClose: UIImage {
        menuIcon(ImageName.close)
    }
    
    static var menuIconUploadPhotosVideos: UIImage {
        menuIcon(ImageName.photoOrVideo)
    }
    
    static var menuIconUploadFile: UIImage {
        menuIcon(ImageName.uploadFile)
    }
    
    static var menuIconScan: UIImage {
        menuIcon(ImageName.scan)
    }
    
    static var menuIconCreateFolder: UIImage {
        menuIcon(ImageName.createFolder)
    }
    
    static var menuIconCreateDocument: UIImage {
        menuIcon(ImageName.document)
    }
    
    static var menuIconCreateSpreadsheet: UIImage {
        menuIcon(ImageName.spreadsheet)
    }
    
    static var menuIconCreatePresentation: UIImage {
        menuIcon(ImageName.presentation)
    }
    
    static var menuRestore: UIImage {
        menuIcon(ImageName.restore)
    }
    
    private static func menuIcon(_ imageName: ImageName) -> UIImage {
        utility.loadImage(
            named: imageName.rawValue,
            colors: [.menuIconTint])
    }
	
	// media player
	static let mediaBigIconSize: CGFloat = 48
	static let mediaMediumIconSize: CGFloat = 24
	
	static var mediaIconForward: UIImage {
		mediaIcon(ImageName.mediaForward, size: mediaBigIconSize)
	}

	static var mediaIconFullscreen: UIImage {
		mediaIcon(ImageName.mediaFullscreen)
	}

	static var mediaIconCloseFullscreen: UIImage {
		mediaIcon(ImageName.mediaCloseFullscreen)
	}
	
	static var mediaIconMessage: UIImage {
		mediaIcon(ImageName.mediaMessage)
	}

	static var mediaIconPause: UIImage {
		mediaIcon(ImageName.mediaPause, size: mediaBigIconSize)
	}

	static var mediaIconPlay: UIImage {
		mediaIcon(ImageName.mediaPlay, size: mediaBigIconSize)
	}

	static var mediaIconRewind: UIImage {
		mediaIcon(ImageName.mediaRewind, size: mediaBigIconSize)
	}

	static var mediaIconSound: UIImage {
		mediaIcon(ImageName.mediaSound)
	}

	private static func mediaIcon(_ imageName: ImageName, size: CGFloat = mediaMediumIconSize) -> UIImage {
		let color = UIColor(named: "MediaPlayer/IconTint") ?? .white
		return UIImage(named: imageName.rawValue)?.image(color: color, size: size) ??  utility.loadImage(named: imageName.rawValue, size: size)
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
