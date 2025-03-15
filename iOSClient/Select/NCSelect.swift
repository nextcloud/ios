//
//  NCSelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import UIKit
import SwiftUI
import NextcloudKit

protocol NCSelectDelegate: AnyObject {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session)
}

class NCSelect: UIViewController, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate, NCListCellDelegate, NCSectionFirstHeaderDelegate {

    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var buttonCancel: UIBarButtonItem!
    @IBOutlet private var bottomContraint: NSLayoutConstraint?

    private var selectCommandViewSelect: NCSelectCommandView?
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared

    enum selectType: Int {
        case select
        case selectCreateFolder
        case copyMove
        case nothing
    }

    // ------ external settings ------------------------------------
    var delegate: NCSelectDelegate?
    var typeOfCommandView: selectType = .select

    var includeDirectoryE2EEncryption = false
    var includeImages = false
    var enableSelectFile = false
    var type = ""
    var items: [tableMetadata] = []

    var titleCurrentFolder = NCBrandOptions.shared.brand
    var serverUrl = ""
    var session: NCSession.Session!
    // -------------------------------------------------------------

    private var dataSourceTask: URLSessionTask?
    private var serverUrlPush = ""
    private var metadataFolder = tableMetadata()
    private var overwrite = true
    private var dataSource = NCCollectionViewDataSource()
    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    private var backgroundImageView = UIImageView()

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.setNavigationBarAppearance()
        navigationController?.navigationBar.prefersLargeTitles = true

        view.backgroundColor = .systemBackground
        collectionView.backgroundColor = .systemBackground

        selectCommandViewSelect?.separatorView.backgroundColor = .separator

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.collectionViewLayout = NCListLayout()

        // Header
        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCSectionFirstHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeader")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .systemBackground

        buttonCancel.title = NSLocalizedString("_cancel_", comment: "")
        bottomContraint?.constant = UIApplication.shared.firstWindow?.rootViewController?.view.safeAreaInsets.bottom ?? 0

        // Type of command view
        if typeOfCommandView == .select || typeOfCommandView == .selectCreateFolder {
            if typeOfCommandView == .select {
                selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewSelect", owner: self, options: nil)?.first as? NCSelectCommandView
            } else {
                selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewSelect+CreateFolder", owner: self, options: nil)?.first as? NCSelectCommandView
            }
            self.view.addSubview(selectCommandViewSelect!)

            selectCommandViewSelect?.setColor(account: session.account)
            selectCommandViewSelect?.selectView = self
            selectCommandViewSelect?.translatesAutoresizingMaskIntoConstraints = false

            selectCommandViewSelect?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.heightAnchor.constraint(equalToConstant: 80).isActive = true

            bottomContraint?.constant = 80
        }

        if typeOfCommandView == .copyMove {
            selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewCopyMove", owner: self, options: nil)?.first as? NCSelectCommandView
            self.view.addSubview(selectCommandViewSelect!)

            selectCommandViewSelect?.setColor(account: session.account)
            selectCommandViewSelect?.selectView = self
            selectCommandViewSelect?.translatesAutoresizingMaskIntoConstraints = false
            if items.contains(where: { $0.lock }) {
                selectCommandViewSelect?.moveButton?.isEnabled = false
                selectCommandViewSelect?.moveButton?.titleLabel?.isEnabled = false
            }
            selectCommandViewSelect?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
            selectCommandViewSelect?.heightAnchor.constraint(equalToConstant: 150).isActive = true

            bottomContraint?.constant = 150
        }

        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let folderPath = utilityFileSystem.getFileNamePath("", serverUrl: serverUrl, session: session)

        if serverUrl.isEmpty || !FileNameValidator.checkFolderPath(folderPath, account: session.account) {
            serverUrl = utilityFileSystem.getHomeServer(session: session)
            titleCurrentFolder = NCBrandOptions.shared.brand
        }

        autoUploadFileName = self.database.getAccountAutoUploadFileName()
        autoUploadDirectory = self.database.getAccountAutoUploadDirectory(session: session)

        self.navigationItem.title = titleCurrentFolder

        reloadDataSource()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut) {
                self.collectionView?.collectionViewLayout.invalidateLayout()
            }
            animator.startAnimation()
        })
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        // Dismission
    }

    // MARK: - NotificationCenter

    @objc func createFolder(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let withPush = userInfo["withPush"] as? Bool,
              serverUrl == self.serverUrl,
              let metadata = self.database.getMetadataFromOcId(ocId)
        else { return }

        if withPush {
            pushMetadata(metadata)
        }
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    func selectButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: false, move: false, session: session)
        self.dismiss(animated: true, completion: nil)
    }

    func copyButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: true, move: false, session: session)
        self.dismiss(animated: true, completion: nil)
    }

    func moveButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: false, move: true, session: session)
        self.dismiss(animated: true, completion: nil)
    }

    func createFolderButtonPressed(_ sender: UIButton) {
        let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session)
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func valueChangedSwitchOverwrite(_ sender: UISwitch) {
        overwrite = sender.isOn
    }

    func tapShareListItem(with ocId: String, ocIdTransfer: String, sender: Any) { }

    func tapMoreListItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any) { }

    func longPressListItem(with odId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    func tapRichWorkspace(_ sender: Any) { }

    func tapRecommendationsButtonMenu(with metadata: tableMetadata, image: UIImage?) { }

    func tapRecommendations(with metadata: tableMetadata) { }

    // MARK: - Push metadata

    func pushMetadata(_ metadata: tableMetadata) {

        let serverUrlPush = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
        guard let viewController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect else { return }

        self.serverUrlPush = serverUrlPush

        viewController.delegate = delegate
        viewController.typeOfCommandView = typeOfCommandView
        viewController.includeDirectoryE2EEncryption = includeDirectoryE2EEncryption
        viewController.includeImages = includeImages
        viewController.enableSelectFile = enableSelectFile
        viewController.type = type
        viewController.overwrite = overwrite
        viewController.items = items
        viewController.titleCurrentFolder = metadata.fileNameView
        viewController.serverUrl = serverUrlPush
        viewController.session = session

        if let fileNameError = FileNameValidator.checkFileName(metadata.fileNameView, account: session.account) {
            present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)
        } else {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

// MARK: - Collection View

extension NCSelect: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return }

        if metadata.directory {
            pushMetadata(metadata)
        } else {
            delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadata, type: type, items: items, overwrite: overwrite, copy: false, move: false, session: session)
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension NCSelect: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return }

        // Thumbnail
        if !metadata.directory {
            if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512) {
                (cell as? NCCellProtocol)?.filePreviewImageView?.image = image
            } else {
                if metadata.iconName.isEmpty {
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.shared.getImageFile()
                } else {
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                }
                if metadata.hasPreview,
                   metadata.status == NCGlobal.shared.metadataStatusNormal {
                    for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId { return }
                    NCNetworking.shared.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, collectionView: collectionView, ext: NCGlobal.shared.previewExt256))
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell)!
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return cell }

        var isShare = false
        var isMounted = false
        let permissions = NCPermissions()

        isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder.permissions.contains(permissions.permissionShared)
        isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder.permissions.contains(permissions.permissionMounted)

        cell.listCellDelegate = self

        cell.fileOcId = metadata.ocId
        cell.fileOcIdTransfer = metadata.ocIdTransfer
        cell.fileUser = metadata.ownerId
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = NCBrandColor.shared.textColor

        cell.imageSelect.image = nil
        cell.imageStatus.image = nil
        cell.imageLocal.image = nil
        cell.imageFavorite.image = nil
        cell.imageShared.image = nil
        cell.imageMore.image = nil

        cell.imageItem.image = nil
        cell.imageItem.backgroundColor = nil

        if metadata.directory {
            if metadata.e2eEncrypted {
                cell.imageItem.image = NCImageCache.shared.getFolderEncrypted(account: metadata.account)
            } else if isShare {
                cell.imageItem.image = NCImageCache.shared.getFolderSharedWithMe(account: metadata.account)
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(3) ?
                (cell.imageItem.image = NCImageCache.shared.getFolderPublic(account: metadata.account)) :
                (cell.imageItem.image = NCImageCache.shared.getFolderSharedWithMe(account: metadata.account))
            } else if metadata.mountType == "group" {
                cell.imageItem.image = NCImageCache.shared.getFolderGroup(account: metadata.account)
            } else if isMounted {
                cell.imageItem.image = NCImageCache.shared.getFolderExternal(account: metadata.account)
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.imageItem.image = NCImageCache.shared.getFolderAutomaticUpload(account: metadata.account)
            } else {
                cell.imageItem.image = NCImageCache.shared.getFolder(account: metadata.account)
            }
            cell.imageItem.image = cell.imageItem.image?.colorizeFolder(metadata: metadata)

            cell.labelInfo.text = utility.getRelativeDateTitle(metadata.date as Date)

        } else {

            cell.labelInfo.text = utility.getRelativeDateTitle(metadata.date as Date) + " · " + utilityFileSystem.transformedSize(metadata.size)

            // image local
            if self.database.getTableLocalFile(ocId: metadata.ocId) != nil {
                cell.imageLocal.image = NCImageCache.shared.getImageOfflineFlag()
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.imageLocal.image = NCImageCache.shared.getImageLocal()
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = NCImageCache.shared.getImageFavorite()
        }

        cell.imageSelect.isHidden = true
        cell.backgroundView = nil
        cell.hideButtonMore(true)
        cell.hideButtonShare(true)
        cell.selected(false, isEditMode: false)

        // Live Photo
        if metadata.isLivePhoto {
            cell.imageStatus.image = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor2])
        }

        // Remove last separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
            cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }

        // Add TAGS
        cell.setTags(tags: Array(metadata.tags))

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {
            if self.dataSource.isEmpty() {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }
                if self.dataSourceTask?.state == .running {
                    header.emptyImage.image = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.getElement(account: session.account)])
                    header.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
                    header.emptyDescription.text = ""
                } else {
                    header.emptyImage.image = NCImageCache.shared.getFolder(account: session.account)
                    if includeImages {
                        header.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
                    } else {
                        header.emptyTitle.text = NSLocalizedString("_files_no_folders_", comment: "")
                    }
                    header.emptyDescription.text = ""
                }
                return header
            } else {
                return UICollectionReusableView()
            }
        } else {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return NCSectionFooter() }
            let sections = self.dataSource.numberOfSections()
            let section = indexPath.section

            footer.setTitleLabel("")
            footer.separatorIsHidden(true)

            if sections == 1 || section == sections - 1 {
                let info = self.dataSource.getFooterInformation()
                footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size)
            } else {
                footer.separatorIsHidden(false)
            }

            return footer
        }
    }
}

extension NCSelect: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height: CGFloat = 0
        if self.dataSource.isEmpty() {
            height = utility.getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: -20)
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = self.dataSource.numberOfSections()
        if section == sections - 1 {
            return CGSize(width: collectionView.frame.width, height: 85)
        } else {
            return CGSize(width: collectionView.frame.width, height: 1)
        }
    }
}

// MARK: -

extension NCSelect {
    func reloadDataSource() {
        var predicate = NSPredicate()

        if includeDirectoryE2EEncryption {
            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND (directory == true OR classFile == 'image') AND NOT (status IN %@)", session.account, serverUrl, NCGlobal.shared.metadataStatusHideInView)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true AND NOT (status IN %@)", session.account, serverUrl, NCGlobal.shared.metadataStatusHideInView)
            }
        } else {
            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND (directory == true OR classFile == 'image') AND NOT (status IN %@)", session.account, serverUrl, NCGlobal.shared.metadataStatusHideInView)
            } else if enableSelectFile {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND NOT (status IN %@)", session.account, serverUrl, NCGlobal.shared.metadataStatusHideInView)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND directory == true AND NOT (status IN %@)", session.account, serverUrl, NCGlobal.shared.metadataStatusHideInView)
            }
        }

        NCNetworking.shared.readFolder(serverUrl: serverUrl,
                                       account: session.account,
                                       checkResponseDataChanged: false,
                                       queue: .main) { task in
            self.dataSourceTask = task
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        } completion: { _, _, _, _, _ in
            let metadatas = self.database.getResultsMetadatasPredicate(predicate, layoutForView: NCDBLayoutForView())

            self.dataSource = NCCollectionViewDataSource(metadatas: metadatas)
            self.collectionView.reloadData()

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": self.serverUrl])
        }
    }
}

// MARK: -

class NCSelectCommandView: UIView {
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var createFolderButton: UIButton?
    @IBOutlet weak var selectButton: UIButton?
    @IBOutlet weak var copyButton: UIButton?
    @IBOutlet weak var moveButton: UIButton?
    @IBOutlet weak var overwriteSwitch: UISwitch?
    @IBOutlet weak var overwriteLabel: UILabel?
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!

    var selectView: NCSelect?
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        separatorHeightConstraint.constant = 0.5
        separatorView.backgroundColor = .separator

        overwriteLabel?.text = NSLocalizedString("_overwrite_", comment: "")

        selectButton?.layer.cornerRadius = 15
        selectButton?.layer.masksToBounds = true
        selectButton?.setTitle(NSLocalizedString("_select_", comment: ""), for: .normal)

        createFolderButton?.layer.cornerRadius = 15
        createFolderButton?.layer.masksToBounds = true
        createFolderButton?.setTitle(NSLocalizedString("_create_folder_", comment: ""), for: .normal)

        copyButton?.layer.cornerRadius = 15
        copyButton?.layer.masksToBounds = true
        copyButton?.setTitle(NSLocalizedString("_copy_", comment: ""), for: .normal)

        moveButton?.layer.cornerRadius = 15
        moveButton?.layer.masksToBounds = true
        moveButton?.setTitle(NSLocalizedString("_move_", comment: ""), for: .normal)
    }

    func setColor(account: String) {
        overwriteSwitch?.onTintColor = NCBrandColor.shared.getElement(account: account)

        selectButton?.backgroundColor = NCBrandColor.shared.getElement(account: account)
        selectButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        selectButton?.setTitleColor(.white, for: .normal)

        createFolderButton?.backgroundColor = NCBrandColor.shared.getElement(account: account)
        createFolderButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        createFolderButton?.setTitleColor(NCBrandColor.shared.getText(account: account), for: .normal)

        copyButton?.backgroundColor = NCBrandColor.shared.getElement(account: account)
        copyButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        copyButton?.setTitleColor(NCBrandColor.shared.getText(account: account), for: .normal)

        moveButton?.backgroundColor = NCBrandColor.shared.getElement(account: account)
        moveButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        moveButton?.setTitleColor(NCBrandColor.shared.getText(account: account), for: .normal)
    }

    @IBAction func createFolderButtonPressed(_ sender: UIButton) {
        selectView?.createFolderButtonPressed(sender)
    }

    @IBAction func selectButtonPressed(_ sender: UIButton) {
        selectView?.selectButtonPressed(sender)
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        selectView?.copyButtonPressed(sender)
    }

    @IBAction func moveButtonPressed(_ sender: UIButton) {
        selectView?.moveButtonPressed(sender)
    }

    @IBAction func valueChangedSwitchOverwrite(_ sender: UISwitch) {
        selectView?.valueChangedSwitchOverwrite(sender)
    }
}

// MARK: - UIViewControllerRepresentable

struct NCSelectViewControllerRepresentable: UIViewControllerRepresentable {
    typealias UIViewControllerType = UINavigationController
    var delegate: NCSelectDelegate
    var session: NCSession.Session!

    func makeUIViewController(context: Context) -> UINavigationController {

        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController?.topViewController as? NCSelect

        viewController?.delegate = delegate
        viewController?.typeOfCommandView = .selectCreateFolder
        viewController?.includeDirectoryE2EEncryption = true
        viewController?.session = session

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }
}

struct SelectView: UIViewControllerRepresentable {
    @Binding var serverUrl: String
    var session: NCSession.Session!

    class Coordinator: NSObject, NCSelectDelegate {
        var parent: SelectView

        init(_ parent: SelectView) {
            self.parent = parent
        }

        func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
            if let serverUrl = serverUrl {
                self.parent.serverUrl = serverUrl
            }
        }
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController?.topViewController as? NCSelect

        viewController?.delegate = context.coordinator
        viewController?.typeOfCommandView = .selectCreateFolder
        viewController?.includeDirectoryE2EEncryption = true
        viewController?.session = session

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
