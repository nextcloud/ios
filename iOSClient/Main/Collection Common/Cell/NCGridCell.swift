// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

protocol NCGridCellDelegate: AnyObject {
    func onMenuIntent(with metadata: tableMetadata?)
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any)
}

class NCGridCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var labelSubinfo: UILabel!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!
    @IBOutlet weak var iconsStackView: UIStackView!

    weak var delegate: NCGridCellDelegate?

    var metadata: tableMetadata? {
        didSet {
            delegate?.openContextMenu(with: metadata, button: buttonMore, sender: self) /* preconfigure UIMenu with each metadata */
        }
    }
    var previewImageView: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let tapObserver = UITapGestureRecognizer(target: self, action: #selector(handleTapObserver(_:)))
        tapObserver.cancelsTouchesInView = false
        tapObserver.delegate = self
        contentView.addGestureRecognizer(tapObserver)

        initCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initCell()
    }

    func initCell() {
        accessibilityHint = nil
        accessibilityLabel = nil
        accessibilityValue = nil
        isAccessibilityElement = true

        imageItem.image = nil
        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true
        imageSelect.isHidden = true
        imageSelect.image = NCImageCache.shared.getImageCheckedYes()
        imageStatus.image = nil
        imageFavorite.image = nil
        imageLocal.image = nil
        labelTitle.text = ""
        labelInfo.text = ""
        labelSubinfo.text = ""
        imageVisualEffect.layer.cornerRadius = 6
        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5

        iconsStackView.addBlurBackground(style: .systemMaterial)
        iconsStackView.layer.cornerRadius = 8
        iconsStackView.clipsToBounds = true

        buttonMore.menu = nil
        buttonMore.showsMenuAsPrimaryAction = true

        contentView.bringSubviewToFront(buttonMore)
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    @objc private func handleTapObserver(_ g: UITapGestureRecognizer) {
        let location = g.location(in: contentView)

        if buttonMore.frame.contains(location) {
            delegate?.onMenuIntent(with: metadata)
        }
    }

    func setButtonMore(image: UIImage) {
        buttonMore.setImage(image, for: .normal)
    }

    func hideImageItem(_ status: Bool) {
        imageItem.isHidden = status
    }

    func hideImageFavorite(_ status: Bool) {
        imageFavorite.isHidden = status
    }

    func hideImageStatus(_ status: Bool) {
        imageStatus.isHidden = status
    }

    func hideImageLocal(_ status: Bool) {
        imageLocal.isHidden = status
    }

    func hideLabelInfo(_ status: Bool) {
        labelInfo.isHidden = status
    }

    func hideLabelSubinfo(_ status: Bool) {
        labelSubinfo.isHidden = status
    }

    func hideButtonMore(_ status: Bool) {
        buttonMore.isHidden = status
    }

    func selected(_ status: Bool, isEditMode: Bool) {
        if isEditMode {
            buttonMore.isHidden = true
            accessibilityCustomActions = nil
        } else {
            buttonMore.isHidden = false
        }
        if status {
            imageSelect.isHidden = false
            imageSelect.image = NCImageCache.shared.getImageCheckedYes()
            imageVisualEffect.isHidden = false
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }

    func writeInfoDateSize(date: NSDate, size: Int64) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale.current

        labelInfo.text = dateFormatter.string(from: date as Date)
        labelSubinfo.text = NCUtilityFileSystem().transformedSize(size)
    }

    func setAccessibility(label: String, value: String) {
        accessibilityLabel = label
        accessibilityValue = value
    }

    func setIconOutlines() {}
}

// MARK: - Grid Layout

class NCGridLayout: UICollectionViewFlowLayout {
    var heightLabelPlusButton: CGFloat = 60
    var marginLeftRight: CGFloat = 10
    var column: CGFloat = 3
    var itemWidthDefault: CGFloat = 140

    override init() {
        super.init()

        sectionHeadersPinToVisibleBounds = false

        minimumInteritemSpacing = 1
        minimumLineSpacing = marginLeftRight

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: marginLeftRight, bottom: 0, right: marginLeftRight)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                if collectionView.frame.width < 400 {
                    column = 3
                } else {
                    column = collectionView.frame.width / itemWidthDefault
                }
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (column - 1)) / column
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
                return CGSize(width: itemWidth, height: itemHeight)
            }
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

extension NCCollectionViewCommon {
    func gridCell(cell: NCGridCell, indexPath: IndexPath, metadata: tableMetadata) -> NCGridCell {
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)

        // CONTENT MODE
        cell.previewImageView?.layer.borderWidth = 0

        if existsImagePreview && layoutForView?.layout != global.layoutPhotoRatio {
            cell.previewImageView?.contentMode = .scaleAspectFill
        } else {
            cell.previewImageView?.contentMode = .scaleAspectFit
        }

        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionShared)
            isMounted = metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionMounted)
        }

        if !metadata.sessionError.isEmpty, metadata.status != global.metadataStatusNormal {
            cell.labelSubinfo.isHidden = false
            cell.labelInfo.text = metadata.sessionError
        } else {
            cell.labelSubinfo.isHidden = false
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        cell.labelTitle.text = metadata.fileNameView

        // Accessibility [shared] if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
        if metadata.ownerId != metadata.userId {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
            let tblDirectory = database.getTableDirectory(ocId: metadata.ocId)

            if metadata.e2eEncrypted {
                cell.previewImageView?.image = imageCache.getFolderEncrypted(account: metadata.account)
            } else if isShare {
                cell.previewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account)
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
                (cell.previewImageView?.image = imageCache.getFolderPublic(account: metadata.account)) :
                (cell.previewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account))
            } else if !metadata.shareType.isEmpty && metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) {
                cell.previewImageView?.image = imageCache.getFolderPublic(account: metadata.account)
            } else if metadata.mountType == "group" {
                cell.previewImageView?.image = imageCache.getFolderGroup(account: metadata.account)
            } else if isMounted {
                cell.previewImageView?.image = imageCache.getFolderExternal(account: metadata.account)
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.previewImageView?.image = imageCache.getFolderAutomaticUpload(account: metadata.account)
            } else {
                cell.previewImageView?.image = imageCache.getFolder(account: metadata.account)
            }

            // Local image: offline
            metadata.isOffline = tblDirectory?.offline ?? false

            if metadata.isOffline {
                cell.imageLocal.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
            }

            // color folder
            cell.previewImageView?.image = cell.previewImageView?.image?.colorizeFolder(metadata: metadata, tblDirectory: tblDirectory)

        } else {
            let tableLocalFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

            if metadata.hasPreviewBorder {
                cell.previewImageView?.layer.borderWidth = 0.2
                cell.previewImageView?.layer.borderColor = UIColor.lightGray.cgColor
            }

            if metadata.name == global.appName {
                if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                    cell.previewImageView?.image = image
                } else if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase) {
                    cell.previewImageView?.image = image
                }

                if cell.previewImageView?.image == nil {
                    if metadata.iconName.isEmpty {
                        cell.previewImageView?.image = NCImageCache.shared.getImageFile()
                    } else {
                        cell.previewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                    }
                }
            } else {
                // APP NAME - UNIFIED SEARCH
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    cell.previewImageView?.image = utility.loadImage(named: "person.crop.rectangle.stack", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("conversation"):
                    cell.previewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("calendar"):
                    cell.previewImageView?.image = utility.loadImage(named: "calendar", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("deck"):
                    cell.previewImageView?.image = utility.loadImage(named: "square.stack.fill", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("mail"):
                    cell.previewImageView?.image = utility.loadImage(named: "mail", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("talk"):
                    cell.previewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("confirm"):
                    cell.previewImageView?.image = utility.loadImage(named: "arrow.right", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("pages"):
                    cell.previewImageView?.image = utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])
                default:
                    cell.previewImageView?.image = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])
                }
                if !metadata.iconUrl.isEmpty {
                    if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                        let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: ownerId)
                        if let image = NCImageCache.shared.getImageCache(key: fileName) {
                            cell.previewImageView?.image = image
                        } else {
                            self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                                if let image {
                                    cell.previewImageView?.image = image
                                    NCImageCache.shared.addImageCache(image: image, key: fileName)
                                } else {
                                    cell.previewImageView?.image = self.utility.loadUserImage(for: ownerId, displayName: nil, urlBase: metadata.urlBase)
                                }

                                if !(tblAvatar?.loaded ?? false),
                                   self.networking.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                                    self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: ownerId, fileName: fileName, account: metadata.account, view: self.collectionView, isPreviewImageView: true))
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
                cell.imageLocal?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.imageLocal?.image = imageCache.getImageLocal(colors: [.systemBackground, .systemGreen])
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.imageFavorite?.image = imageCache.getImageFavorite()
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Button More
        if metadata.lock == true {
            cell.setButtonMore(image: imageCache.getImageButtonMoreLock())
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(image: imageCache.getImageButtonMore())
        }

        // Status
        if metadata.isLivePhoto {
            cell.imageStatus?.image = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        } else if metadata.isVideo {
            cell.imageStatus?.image = utility.loadImage(named: "play.circle.fill", colors: [.systemBackgroundInverted, .systemGray5])
        }

        switch metadata.status {
        case global.metadataStatusWaitCreateFolder:
            cell.imageStatus?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelInfo?.text = NSLocalizedString("_status_wait_create_folder_", comment: "")
        case global.metadataStatusWaitFavorite:
            cell.imageStatus?.image = utility.loadImage(named: "star.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelInfo?.text = NSLocalizedString("_status_wait_favorite_", comment: "")
        case global.metadataStatusWaitCopy:
            cell.imageStatus?.image = utility.loadImage(named: "c.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelInfo?.text = NSLocalizedString("_status_wait_copy_", comment: "")
        case global.metadataStatusWaitMove:
            cell.imageStatus?.image = utility.loadImage(named: "m.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelInfo?.text = NSLocalizedString("_status_wait_move_", comment: "")
        case global.metadataStatusWaitRename:
            cell.imageStatus?.image = utility.loadImage(named: "a.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelInfo?.text = NSLocalizedString("_status_wait_rename_", comment: "")
        case global.metadataStatusWaitDownload:
            cell.imageStatus?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloading:
            cell.imageStatus?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloadError, global.metadataStatusUploadError:
            cell.imageStatus?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        default:
            break
        }

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue {
            cell.imageLocal?.image = nil
            cell.hideButtonMore(true)
        }

        // Edit mode
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
            a11yValues.append(NSLocalizedString("_selected_", comment: ""))
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        // Accessibility
        cell.setAccessibility(label: metadata.fileNameView + ", " + (cell.labelInfo?.text ?? "") + (cell.labelSubinfo?.text ?? ""), value: a11yValues.joined(separator: ", "))

        // Color string find in search
        cell.labelTitle?.textColor = NCBrandColor.shared.textColor
        cell.labelTitle?.font = .systemFont(ofSize: 15)

        // Hide buttons
        if metadata.name != global.appName {
            cell.hideButtonMore(true)
        }

        cell.setIconOutlines()

        // Obligatory here, at the end !!
        cell.metadata = metadata

        return cell
    }
}
