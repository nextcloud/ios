// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

protocol NCCellMainProtocol {
    var metadata: tableMetadata? {get set }
    var avatarImg: UIImageView? { get }
    var previewImg: UIImageView? { get set }
    var localImg: UIImageView? { get set }
    var statusImg: UIImageView? { get set }
    var infoLbl: UILabel? { get set }

}

extension NCCellMainProtocol {
    var metadata: tableMetadata? {
        get { return nil }
        set {}
    }
    var avatarImg: UIImageView? {
        get { return nil }
        set {}
    }
    var previewImg: UIImageView? {
        get { return nil }
        set {}
    }
    var localImg: UIImageView? {
        get { return nil }
        set {}
    }
    var statusImg: UIImageView? {
        get { return nil }
        set {}
    }
    var infoLbl: UILabel? {
        get { return nil }
        set {}
    }
}

#if !EXTENSION
extension NCCollectionViewCommon {
    func cellMainStatus(cell: NCCellMainProtocol,
                        metadata: tableMetadata,
                        a11yValues: inout [String]) {
        if metadata.isLivePhoto {
            cell.statusImg?.image = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        } else if metadata.isVideo {
            cell.statusImg?.image = utility.loadImage(named: "play.circle.fill", colors: [.systemBackgroundInverted, .systemGray5])
        }

        switch metadata.status {
        case global.metadataStatusWaitCreateFolder:
            cell.statusImg?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.infoLbl?.text = NSLocalizedString("_status_wait_create_folder_", comment: "")
        case global.metadataStatusWaitFavorite:
            cell.statusImg?.image = utility.loadImage(named: "star.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.infoLbl?.text = NSLocalizedString("_status_wait_favorite_", comment: "")
        case global.metadataStatusWaitCopy:
            cell.statusImg?.image = utility.loadImage(named: "c.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.infoLbl?.text = NSLocalizedString("_status_wait_copy_", comment: "")
        case global.metadataStatusWaitMove:
            cell.statusImg?.image = utility.loadImage(named: "m.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.infoLbl?.text = NSLocalizedString("_status_wait_move_", comment: "")
        case global.metadataStatusWaitRename:
            cell.statusImg?.image = utility.loadImage(named: "a.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.infoLbl?.text = NSLocalizedString("_status_wait_rename_", comment: "")
        case global.metadataStatusWaitDownload:
            cell.statusImg?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloading:
            cell.statusImg?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloadError, global.metadataStatusUploadError:
            cell.statusImg?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        default:
            break
        }

    }
    func cellMainDirectory(cell: NCCellMainProtocol,
                           metadata: tableMetadata,
                           isShare: Bool,
                           isMounted: Bool) {
        let tblDirectory = database.getTableDirectory(ocId: metadata.ocId)

        if metadata.e2eEncrypted {
            cell.previewImg?.image = imageCache.getFolderEncrypted(account: metadata.account)
        } else if isShare {
            cell.previewImg?.image = imageCache.getFolderSharedWithMe(account: metadata.account)
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
            (cell.previewImg?.image = imageCache.getFolderPublic(account: metadata.account)) :
            (cell.previewImg?.image = imageCache.getFolderSharedWithMe(account: metadata.account))
        } else if !metadata.shareType.isEmpty && metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) {
            cell.previewImg?.image = imageCache.getFolderPublic(account: metadata.account)
        } else if metadata.mountType == "group" {
            cell.previewImg?.image = imageCache.getFolderGroup(account: metadata.account)
        } else if isMounted {
            cell.previewImg?.image = imageCache.getFolderExternal(account: metadata.account)
        } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
            cell.previewImg?.image = imageCache.getFolderAutomaticUpload(account: metadata.account)
        } else {
            cell.previewImg?.image = imageCache.getFolder(account: metadata.account)
        }

        // Local image: offline
        metadata.isOffline = tblDirectory?.offline ?? false

        if metadata.isOffline {
            cell.localImg?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
        }

        // color folder
        cell.previewImg?.image = cell.previewImg?.image?.colorizeFolder(metadata: metadata, tblDirectory: tblDirectory)
    }

    func cellMainFile(cell: NCCellMainProtocol,
                      metadata: tableMetadata,
                      a11yValues: inout [String]) {
        let tableLocalFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

        if metadata.hasPreviewBorder {
            cell.previewImg?.layer.borderWidth = 0.2
            cell.previewImg?.layer.borderColor = UIColor.lightGray.cgColor
        }

        if metadata.name == global.appName {
            let ext = global.getSizeExtension(column: self.numberOfColumns)
            if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                cell.previewImg?.image = image
            } else if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase) {
                cell.previewImg?.image = image
            }

            if cell.previewImg?.image == nil {
                if metadata.iconName.isEmpty {
                    cell.previewImg?.image = NCImageCache.shared.getImageFile()
                } else {
                    cell.previewImg?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                }
            }
        } else {
            // APP NAME - UNIFIED SEARCH
            switch metadata.iconName {
            case let str where str.contains("contacts"):
                cell.previewImg?.image = utility.loadImage(named: "person.crop.rectangle.stack", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("conversation"):
                cell.previewImg?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
            case let str where str.contains("calendar"):
                cell.previewImg?.image = utility.loadImage(named: "calendar", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("deck"):
                cell.previewImg?.image = utility.loadImage(named: "square.stack.fill", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("mail"):
                cell.previewImg?.image = utility.loadImage(named: "mail", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("talk"):
                cell.previewImg?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
            case let str where str.contains("confirm"):
                cell.previewImg?.image = utility.loadImage(named: "arrow.right", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("pages"):
                cell.previewImg?.image = utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])
            default:
                cell.previewImg?.image = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])
            }
            if !metadata.iconUrl.isEmpty {
                if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                    let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: ownerId)
                    if let image = NCImageCache.shared.getImageCache(key: fileName) {
                        cell.previewImg?.image = image
                    } else {
                        self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                            if let image {
                                cell.previewImg?.image = image
                                NCImageCache.shared.addImageCache(image: image, key: fileName)
                            } else {
                                cell.previewImg?.image = self.utility.loadUserImage(for: ownerId, displayName: nil, urlBase: metadata.urlBase)
                            }

                            if !(tblAvatar?.loaded ?? false),
                               self.networking.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                                self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: ownerId, fileName: fileName, account: metadata.account, view: self.collectionView, isPreviewImage: true))
                            }
                        }
                    }
                }
            }
        }

        // Local image: offline
        metadata.isOffline = tableLocalFile?.offline ?? false

        if metadata.isOffline {
            a11yValues.append(NSLocalizedString("_offline_", comment: ""))
            cell.localImg?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
        } else if utilityFileSystem.fileProviderStorageExists(metadata) {
            cell.localImg?.image = imageCache.getImageLocal(colors: [.systemBackground, .systemGreen])
        }
    }

}
#endif
