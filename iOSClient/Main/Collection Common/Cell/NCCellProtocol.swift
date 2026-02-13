// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

protocol NCCellProtocol {
    var metadata: tableMetadata? {get set }
    var avatarImage: UIImageView? { get }
    var previewImage: UIImageView? { get set }
    var imageLocal: UIImageView? { get set }
}

extension NCCellProtocol {
    var metadata: tableMetadata? {
        get { return nil }
        set {}
    }
    var avatarImage: UIImageView? {
        get { return nil }
        set {}
    }
    var previewImage: UIImageView? {
        get { return nil }
        set {}
    }
    var imageLocal: UIImageView? {
        get { return nil }
        set {}
    }
}

#if !EXTENSION
extension NCCollectionViewCommon {
    func setCellDirectory(cell: NCCellProtocol, metadata: tableMetadata, isShare: Bool, isMounted: Bool) {
        let tblDirectory = database.getTableDirectory(ocId: metadata.ocId)

        if metadata.e2eEncrypted {
            cell.previewImage?.image = imageCache.getFolderEncrypted(account: metadata.account)
        } else if isShare {
            cell.previewImage?.image = imageCache.getFolderSharedWithMe(account: metadata.account)
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
            (cell.previewImage?.image = imageCache.getFolderPublic(account: metadata.account)) :
            (cell.previewImage?.image = imageCache.getFolderSharedWithMe(account: metadata.account))
        } else if !metadata.shareType.isEmpty && metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) {
            cell.previewImage?.image = imageCache.getFolderPublic(account: metadata.account)
        } else if metadata.mountType == "group" {
            cell.previewImage?.image = imageCache.getFolderGroup(account: metadata.account)
        } else if isMounted {
            cell.previewImage?.image = imageCache.getFolderExternal(account: metadata.account)
        } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
            cell.previewImage?.image = imageCache.getFolderAutomaticUpload(account: metadata.account)
        } else {
            cell.previewImage?.image = imageCache.getFolder(account: metadata.account)
        }

        // Local image: offline
        metadata.isOffline = tblDirectory?.offline ?? false

        if metadata.isOffline {
            cell.imageLocal?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
        }

        // color folder
        cell.previewImage?.image = cell.previewImage?.image?.colorizeFolder(metadata: metadata, tblDirectory: tblDirectory)
    }

    func setCellFile(cell: NCCellProtocol, metadata: tableMetadata,) {
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let tableLocalFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

        if metadata.hasPreviewBorder {
            cell.previewImage?.layer.borderWidth = 0.2
            cell.previewImage?.layer.borderColor = UIColor.lightGray.cgColor
        }

        if metadata.name == global.appName {
            if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                cell.previewImage?.image = image
            } else if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase) {
                cell.previewImage?.image = image
            }

            if cell.previewImage?.image == nil {
                if metadata.iconName.isEmpty {
                    cell.previewImage?.image = NCImageCache.shared.getImageFile()
                } else {
                    cell.previewImage?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                }
            }
        } else {
            // APP NAME - UNIFIED SEARCH
            switch metadata.iconName {
            case let str where str.contains("contacts"):
                cell.previewImage?.image = utility.loadImage(named: "person.crop.rectangle.stack", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("conversation"):
                cell.previewImage?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
            case let str where str.contains("calendar"):
                cell.previewImage?.image = utility.loadImage(named: "calendar", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("deck"):
                cell.previewImage?.image = utility.loadImage(named: "square.stack.fill", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("mail"):
                cell.previewImage?.image = utility.loadImage(named: "mail", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("talk"):
                cell.previewImage?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
            case let str where str.contains("confirm"):
                cell.previewImage?.image = utility.loadImage(named: "arrow.right", colors: [NCBrandColor.shared.iconImageColor])
            case let str where str.contains("pages"):
                cell.previewImage?.image = utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])
            default:
                cell.previewImage?.image = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])
            }
            if !metadata.iconUrl.isEmpty {
                if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                    let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: ownerId)
                    if let image = NCImageCache.shared.getImageCache(key: fileName) {
                        cell.previewImage?.image = image
                    } else {
                        self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                            if let image {
                                cell.previewImage?.image = image
                                NCImageCache.shared.addImageCache(image: image, key: fileName)
                            } else {
                                cell.previewImage?.image = self.utility.loadUserImage(for: ownerId, displayName: nil, urlBase: metadata.urlBase)
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
            //a11yValues.append(NSLocalizedString("_offline_", comment: ""))
            cell.imageLocal?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
        } else if utilityFileSystem.fileProviderStorageExists(metadata) {
            cell.imageLocal?.image = imageCache.getImageLocal(colors: [.systemBackground, .systemGreen])
        }
    }

}
#endif
