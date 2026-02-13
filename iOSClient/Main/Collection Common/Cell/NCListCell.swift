// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

protocol NCListCellDelegate: AnyObject {
    func onMenuIntent(with metadata: tableMetadata?)
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any)
    func tapShareListItem(with metadata: tableMetadata?, button: UIButton, sender: Any)
}

class NCListCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var labelInfoSeparator: UILabel!
    @IBOutlet weak var labelSubinfo: UILabel!
    @IBOutlet weak var imageShared: UIImageView!
    @IBOutlet weak var buttonShared: UIButton!
    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var tag0: UILabel!
    @IBOutlet weak var tag1: UILabel!

    @IBOutlet weak var imageItemLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleTrailingConstraint: NSLayoutConstraint!

    weak var delegate: NCListCellDelegate?

    // Cell Protocol
    var metadata: tableMetadata? {
        didSet {
            delegate?.openContextMenu(with: metadata, button: buttonMore, sender: self) /* preconfigure UIMenu with each metadata */
        }
    }
    var avatarImage: UIImageView? {
        return imageShared
    }
    var previewImage: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
    }

    override var accessibilityIdentifier: String? {
        get {
            super.accessibilityIdentifier
        }
        set {
            super.accessibilityIdentifier = newValue

            if let newValue {
                buttonShared.accessibilityIdentifier = "\(newValue)/shareButton"
            }
        }
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
        imageStatus.image = nil
        imageFavorite.image = nil
        imageLocal.image = nil
        labelTitle.text = ""
        labelInfo.text = ""
        labelSubinfo.text = ""
        imageShared.image = nil
        imageMore.image = nil
        separatorHeightConstraint.constant = 0.5
        tag0.text = ""
        tag1.text = ""
        titleTrailingConstraint.constant = 90

        contentView.bringSubviewToFront(buttonMore)
        buttonMore.menu = nil
        buttonMore.showsMenuAsPrimaryAction = true
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    @IBAction func touchUpInsideShare(_ sender: Any) {
        delegate?.tapShareListItem(with: metadata, button: buttonShared, sender: sender)
    }

    @objc private func handleTapObserver(_ g: UITapGestureRecognizer) {
        let location = g.location(in: contentView)

        if buttonMore.frame.contains(location) {
            delegate?.onMenuIntent(with: metadata)
        }
    }

    // Allow the button to receive taps even with the long press gesture
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: contentView)
        return buttonMore.frame.contains(location)
    }

    func titleInfoTrailingFull() {
        titleTrailingConstraint.constant = 10
    }

    func setButtonMore(image: UIImage) {
        imageMore.image = image
    }

    func hideButtonMore(_ status: Bool) {
        imageMore.isHidden = status
        buttonMore.isHidden = status
    }

    func hideButtonShare(_ status: Bool) {
        imageShared.isHidden = status
        buttonShared.isHidden = status
    }

    func selected(_ status: Bool, isEditMode: Bool) {
        if isEditMode {
            imageItemLeftConstraint.constant = 45
            imageSelect.isHidden = false
            imageShared.isHidden = true
            imageMore.isHidden = true
            buttonShared.isHidden = true
            buttonMore.isHidden = true
            accessibilityCustomActions = nil
        } else {
            imageItemLeftConstraint.constant = 10
            imageSelect.isHidden = true
            imageShared.isHidden = false
            imageMore.isHidden = false
            buttonShared.isHidden = false
            buttonMore.isHidden = false
            backgroundView = nil
        }
        if status {
            var blurEffectView: UIView?
            blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            blurEffectView?.backgroundColor = .lightGray
            blurEffectView?.frame = self.bounds
            blurEffectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageSelect.image = NCImageCache.shared.getImageCheckedYes()
            backgroundView = blurEffectView
            separator.isHidden = true
        } else {
            imageSelect.image = NCImageCache.shared.getImageCheckedNo()
            backgroundView = nil
            separator.isHidden = false
        }

    }

    func writeInfoDateSize(date: NSDate, size: Int64) {
        labelInfo.text = NCUtility().getRelativeDateTitle(date as Date)
        labelSubinfo.text = NCUtilityFileSystem().transformedSize(size)
    }

    func setAccessibility(label: String, value: String) {
        accessibilityLabel = label
        accessibilityValue = value
    }

    func setTags(tags: [String]) {
        if tags.isEmpty {
            tag0.isHidden = true
            tag1.isHidden = true
            labelInfo.isHidden = false
            labelSubinfo.isHidden = false
            labelInfoSeparator.isHidden = false
        } else {
            tag0.isHidden = false
            tag1.isHidden = true
            labelInfo.isHidden = true
            labelSubinfo.isHidden = true
            labelInfoSeparator.isHidden = true

            if let tag = tags.first {
                tag0.text = tag
                if tags.count > 1 {
                    tag1.isHidden = false
                    tag1.text = "+\(tags.count - 1)"
                }
            }
        }
    }

    func setIconOutlines() {
        [imageStatus, imageLocal].forEach { imageView in
            imageView.makeCircularBackground(withColor: imageView.image != nil ? .systemBackground : .clear)
        }

        if imageFavorite.image != nil {
            let outlineView = UIImageView()
            outlineView.translatesAutoresizingMaskIntoConstraints = false
            outlineView.image = UIImage(systemName: "star")
            outlineView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .thin)
            outlineView.tintColor = .systemBackground

            imageFavorite.addSubview(outlineView)
            NSLayoutConstraint.activate([
                outlineView.leadingAnchor.constraint(equalTo: imageFavorite.leadingAnchor, constant: -1),
                outlineView.trailingAnchor.constraint(equalTo: imageFavorite.trailingAnchor, constant: 1),
                outlineView.topAnchor.constraint(equalTo: imageFavorite.topAnchor, constant: -1),
                outlineView.bottomAnchor.constraint(equalTo: imageFavorite.bottomAnchor, constant: 1)
            ])
            imageFavorite.sendSubviewToBack(outlineView)
        } else {
            imageFavorite.subviews.forEach { view in
                view.removeFromSuperview()
            }
        }

    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep the shadow path in sync with current bounds
        imageStatus.layer.shadowPath = UIBezierPath(ovalIn: imageStatus.bounds).cgPath

        // Ensure the circular background remains correct after Auto Layout
        if imageStatus.layer.cornerRadius != imageStatus.bounds.width / 2 {
            imageStatus.layer.cornerRadius = imageStatus.bounds.width / 2
        }
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

class BidiFilenameLabel: UILabel {
    var fullFilename: String = ""

    var isFolder: Bool = false

    var isRTL: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateText()
    }

    private func updateText() {
        guard !fullFilename.isEmpty else {
            self.text = ""
            return
        }

        let availableWidth = bounds.width
        guard availableWidth > 0 else { return }

        let isRTL = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        let sanitizedFilename = fullFilename.sanitizeForBidiCharacters(isFolder: isFolder, isRTL: isRTL)

        let nsFilename = sanitizedFilename as NSString
        let ext = nsFilename.pathExtension
        let base = nsFilename.deletingPathExtension

        let dotExt = ext.isEmpty ? "" : "." + ext
        let truncatedBase = truncateBase(base: base, dotExt: dotExt, maxWidth: availableWidth, font: font ?? UIFont.systemFont(ofSize: 17))

        self.text = sanitizedFilename.replacingOccurrences(of: base, with: truncatedBase)
    }

    private func truncateBase(base: String, dotExt: String, maxWidth: CGFloat, font: UIFont) -> String {
        let extWidth = (dotExt as NSString).size(withAttributes: [.font: font]).width

        if (base as NSString).size(withAttributes: [.font: font]).width + extWidth <= maxWidth {
            return base
        }

        let characters = Array(base)
        var low = 0
        var high = characters.count
        var result = ""

        while low <= high {
            let mid = (low + high) / 2
            let prefixCount = mid / 2
            let suffixCount = mid - prefixCount
            let finalString = String(characters.prefix(prefixCount)) + "…" + String(characters.suffix(suffixCount))
            let finalStringWidth = (finalString as NSString).size(withAttributes: [.font: font]).width + extWidth

            if finalStringWidth <= maxWidth {
                result = finalString
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }
}

#if !EXTENSION
extension NCCollectionViewCommon {
    func listCell(cell: NCListCell, indexPath: IndexPath, metadata: tableMetadata) -> NCListCell {
        defer {
            let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
            if !metadata.isSharable() || (!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
                cell.hideButtonShare(true)
            }
        }
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)

        // CONTENT MODE
        cell.avatarImage?.contentMode = .center
        cell.previewImage?.layer.borderWidth = 0

        if existsImagePreview && layoutForView?.layout != global.layoutPhotoRatio {
            cell.previewImage?.contentMode = .scaleAspectFill
        } else {
            cell.previewImage?.contentMode = .scaleAspectFit
        }

        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionShared)
            isMounted = metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionMounted)
        }

        if isSearchingMode {
            if metadata.name == global.appName {
                cell.labelInfo?.text = NSLocalizedString("_in_", comment: "") + " " + utilityFileSystem.getPath(path: metadata.path, user: metadata.user)
            } else {
                cell.labelInfo?.text = metadata.subline
            }
            cell.labelSubinfo?.isHidden = true
        } else if !metadata.sessionError.isEmpty, metadata.status != global.metadataStatusNormal {
            cell.labelSubinfo?.isHidden = false
            cell.labelInfo?.text = metadata.sessionError
        } else {
            cell.labelSubinfo?.isHidden = false
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        cell.labelTitle?.text = metadata.fileNameView

        // Accessibility [shared] if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
        if metadata.ownerId != metadata.userId {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
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

        } else {
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

        // Share image
        if isShare {
            cell.imageShared?.image = imageCache.getImageShared()
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
            (cell.imageShared?.image = imageCache.getImageShareByLink()) :
            (cell.imageShared?.image = imageCache.getImageShared())
        } else {
            cell.imageShared?.image = imageCache.getImageCanShare()
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

        // AVATAR
        if !metadata.ownerId.isEmpty, metadata.ownerId != metadata.userId {
            let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: metadata.ownerId)
            if let image = NCImageCache.shared.getImageCache(key: fileName) {
                cell.avatarImage?.contentMode = .scaleAspectFill
                cell.avatarImage?.image = image
            } else {
                self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                    if let image {
                        cell.avatarImage?.contentMode = .scaleAspectFill
                        cell.avatarImage?.image = image
                        NCImageCache.shared.addImageCache(image: image, key: fileName)
                    } else {
                        cell.avatarImage?.contentMode = .scaleAspectFill
                        cell.avatarImage?.image = self.utility.loadUserImage(for: metadata.ownerId, displayName: metadata.ownerDisplayName, urlBase: metadata.urlBase)
                    }

                    if !(tblAvatar?.loaded ?? false),
                       self.networking.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                        self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: metadata.ownerId, fileName: fileName, account: metadata.account, view: self.collectionView))
                    }
                }
            }
        }

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue {
            cell.imageLocal?.image = nil
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        // Separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 || isSearchingMode {
            cell.separator?.isHidden = true
        } else {
            cell.separator?.isHidden = false
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

        if isSearchingMode,
           let searchResultStore,
           let title = cell.labelTitle?.text {
            let longestWordRange = (title.lowercased() as NSString).range(of: searchResultStore)
            let attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            attributedString.setAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 15), NSAttributedString.Key.foregroundColor: UIColor.systemBlue], range: longestWordRange)
            cell.labelTitle?.attributedText = attributedString
        }

        // TAGS
        cell.setTags(tags: Array(metadata.tags))

        // SearchingMode - TAG Separator Hidden
        if isSearchingMode {
            cell.labelInfoSeparator.isHidden = true
        }

        // Hide buttons
        if metadata.name != global.appName {
            cell.titleInfoTrailingFull()
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        cell.setIconOutlines()

        // Obligatory here, at the end !!
        cell.metadata = metadata

        return cell
    }
}
#endif
