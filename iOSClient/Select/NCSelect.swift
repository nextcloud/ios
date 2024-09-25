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

@objc protocol NCSelectDelegate {
    @objc func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool)
}

class NCSelect: UIViewController, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate, NCListCellDelegate, NCSectionFirstHeaderDelegate {

    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var buttonCancel: UIBarButtonItem!
    @IBOutlet private var bottomContraint: NSLayoutConstraint?

    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private var selectCommandViewSelect: NCSelectCommandView?
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    enum selectType: Int {
        case select
        case selectCreateFolder
        case copyMove
        case nothing
    }

    // ------ external settings ------------------------------------
    weak var delegate: NCSelectDelegate?
    var typeOfCommandView: selectType = .select

    var includeDirectoryE2EEncryption = false
    var includeImages = false
    var enableSelectFile = false
    var type = ""
    var items: [tableMetadata] = []

    var titleCurrentFolder = NCBrandOptions.shared.brand
    var serverUrl = ""
    // -------------------------------------------------------------

    private var dataSourceTask: URLSessionTask?
    private var serverUrlPush = ""
    private var metadataFolder = tableMetadata()
    private var overwrite = true
    private var dataSource = NCDataSource()
    internal var richWorkspaceText: String?
    internal var headerMenu: NCSectionFirstHeader?
    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    private var backgroundImageView = UIImageView()
    private var activeAccount: tableAccount!
    private let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.presentationController?.delegate = self
        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor

        view.backgroundColor = .systemBackground
        selectCommandViewSelect?.separatorView.backgroundColor = .separator

        activeAccount = NCManageDatabase.shared.getActiveAccount()

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
        bottomContraint?.constant = window?.rootViewController?.view.safeAreaInsets.bottom ?? 0

        // Type of command view
        if typeOfCommandView == .select || typeOfCommandView == .selectCreateFolder {
            if typeOfCommandView == .select {
                selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewSelect", owner: self, options: nil)?.first as? NCSelectCommandView
            } else {
                selectCommandViewSelect = Bundle.main.loadNibNamed("NCSelectCommandViewSelect+CreateFolder", owner: self, options: nil)?.first as? NCSelectCommandView
            }
            self.view.addSubview(selectCommandViewSelect!)
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

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let folderPath = utilityFileSystem.getFileNamePath("", serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

        if serverUrl.isEmpty || !FileNameValidator.shared.checkFolderPath(folderPath: folderPath) {
            serverUrl = utilityFileSystem.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId)
            titleCurrentFolder = NCBrandOptions.shared.brand
        }

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, userId: activeAccount.userId, account: activeAccount.account)

        loadDatasource(withLoadFolder: true)

        self.navigationItem.title = titleCurrentFolder
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        // Dismission
    }

    // MARK: - NotificationCenter

    @objc func createFolder(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        pushMetadata(metadata)
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    func selectButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: false, move: false)
        self.dismiss(animated: true, completion: nil)
    }

    func copyButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: true, move: false)
        self.dismiss(animated: true, completion: nil)
    }

    func moveButtonPressed(_ sender: UIButton) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadataFolder, type: type, items: items, overwrite: overwrite, copy: false, move: true)
        self.dismiss(animated: true, completion: nil)
    }

    func createFolderButtonPressed(_ sender: UIButton) {
        let alertController = UIAlertController.createFolder(serverUrl: serverUrl, userBaseUrl: activeAccount)
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func valueChangedSwitchOverwrite(_ sender: UISwitch) {
        overwrite = sender.isOn
    }

    func tapShareListItem(with objectId: String, indexPath: IndexPath, sender: Any) {
    }

    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
    }

    func longPressListItem(with objectId: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) {
    }

    func tapButtonTransfer(_ sender: Any) {
    }

    func tapRichWorkspace(_ sender: Any) {
    }

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

        if let fileNameError = FileNameValidator.shared.checkFileName(metadata.fileNameView) {
            present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)
        } else {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

// MARK: - Collection View

extension NCSelect: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }

        if metadata.directory {
            pushMetadata(metadata)
        } else {
            delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadata, type: type, items: items, overwrite: overwrite, copy: false, move: false)
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension NCSelect: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }

        // Thumbnail
        if !metadata.directory {
            if FileManager().fileExists(atPath: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                (cell as? NCCellProtocol)?.filePreviewImageView?.image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            } else {
                if metadata.iconName.isEmpty {
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = NCImageCache.images.file
                } else {
                    (cell as? NCCellProtocol)?.filePreviewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true)
                }
                if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && (!utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)) {
                    for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId { return }
                    NCNetworking.shared.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, cell: (cell as? NCCellProtocol), collectionView: collectionView))
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell,
              let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return UICollectionViewCell() }
        var isShare = false
        var isMounted = false
        let permissions = NCPermissions()

        isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder.permissions.contains(permissions.permissionShared)
        isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder.permissions.contains(permissions.permissionMounted)

        cell.listCellDelegate = self

        cell.fileObjectId = metadata.ocId
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

        cell.progressView.progress = 0.0

        if metadata.directory {

            if metadata.e2eEncrypted {
                cell.imageItem.image = NCImageCache.images.folderEncrypted
            } else if isShare {
                cell.imageItem.image = NCImageCache.images.folderSharedWithMe
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(3) ?
                (cell.imageItem.image = NCImageCache.images.folderPublic) :
                (cell.imageItem.image = NCImageCache.images.folderSharedWithMe)
            } else if metadata.mountType == "group" {
                cell.imageItem.image = NCImageCache.images.folderGroup
            } else if isMounted {
                cell.imageItem.image = NCImageCache.images.folderExternal
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.imageItem.image = NCImageCache.images.folderAutomaticUpload
            } else {
                cell.imageItem.image = NCImageCache.images.folder
            }
            cell.imageItem.image = cell.imageItem.image?.colorizeFolder(metadata: metadata)

            cell.labelInfo.text = utility.dateDiff(metadata.date as Date)

        } else {

            cell.labelInfo.text = utility.dateDiff(metadata.date as Date) + " · " + utilityFileSystem.transformedSize(metadata.size)

            // image local
            if NCManageDatabase.shared.getTableLocalFile(ocId: metadata.ocId) != nil {
                cell.imageLocal.image = NCImageCache.images.offlineFlag
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.imageLocal.image = NCImageCache.images.local
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = NCImageCache.images.favorite
        }

        cell.imageSelect.isHidden = true
        cell.backgroundView = nil
        cell.hideButtonMore(true)
        cell.hideButtonShare(true)
        cell.selected(false, isEditMode: false)

        // Live Photo
        if metadata.isLivePhoto {
            cell.imageStatus.image = NCImageCache.images.livePhoto
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

            if dataSource.getMetadataSourceForAllSections().isEmpty {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }
                if self.dataSourceTask?.state == .running {
                    header.emptyImage.image = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.brandElement])
                    header.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
                    header.emptyDescription.text = ""
                } else {
                    header.emptyImage.image = NCImageCache.images.folder
                    if includeImages {
                        header.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
                    } else {
                        header.emptyTitle.text = NSLocalizedString("_files_no_folders_", comment: "")
                    }
                    header.emptyDescription.text = ""
                }
                return header

            } else {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeader", for: indexPath) as? NCSectionFirstHeader else { return NCSectionFirstHeader() }
                let (_, heightHeaderRichWorkspace, _) = getHeaderHeight(section: indexPath.section)

                self.headerMenu = header

                header.delegate = self
                header.setRichWorkspaceHeight(heightHeaderRichWorkspace)
                header.setRichWorkspaceText(richWorkspaceText)
                header.setViewTransfer(isHidden: true)
                return header
            }

        } else {

            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return NCSectionFooter() }
            let sections = dataSource.numberOfSections()
            let section = indexPath.section

            footer.setTitleLabel("")
            footer.separatorIsHidden(true)

            if sections == 1 || section == sections - 1 {
                let info = dataSource.getFooterInformationAllMetadatas()
                footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size)
            } else {
                footer.separatorIsHidden(false)
            }

            return footer
        }
    }
}

extension NCSelect: UICollectionViewDelegateFlowLayout {

    func getHeaderHeight(section: Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {

        var headerRichWorkspace: CGFloat = 0

        if let richWorkspaceText = richWorkspaceText {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 0 {
                headerRichWorkspace = UIScreen.main.bounds.size.height / 6
            }
        }

        return (0, headerRichWorkspace, 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height: CGFloat = 0
        if dataSource.getMetadataSourceForAllSections().isEmpty {
            height = NCGlobal.shared.getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: -20)
        } else {
            let (heightHeaderCommands, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: section)
            height = heightHeaderCommands + heightHeaderRichWorkspace + heightHeaderSection
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = dataSource.numberOfSections()
        if section == sections - 1 {
            return CGSize(width: collectionView.frame.width, height: NCGlobal.shared.endHeightFooter)
        } else {
            return CGSize(width: collectionView.frame.width, height: NCGlobal.shared.heightFooter)
        }
    }
}

// MARK: -

extension NCSelect {

    @objc func reloadDataSource() {
        loadDatasource(withLoadFolder: false)
    }

    @objc func loadDatasource(withLoadFolder: Bool) {

        var predicate: NSPredicate?

        if includeDirectoryE2EEncryption {

            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND (directory == true OR classFile == 'image')", activeAccount.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", activeAccount.account, serverUrl)
            }

        } else {

            if includeImages {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND (directory == true OR classFile == 'image')", activeAccount.account, serverUrl)
            } else if enableSelectFile {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false", activeAccount.account, serverUrl)
            } else {
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND directory == true", activeAccount.account, serverUrl)
            }
        }

        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: predicate!)
        self.dataSource = NCDataSource(metadatas: metadatas, account: activeAccount.account, layoutForView: nil)
                                     
        if withLoadFolder {
            loadFolder()
        }

        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace

        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    func loadFolder() {

        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: activeAccount.account) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { _, _, _, _, _, error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
            self.loadDatasource(withLoadFolder: false)
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

        overwriteSwitch?.onTintColor = NCBrandColor.shared.brandElement
        overwriteLabel?.text = NSLocalizedString("_overwrite_", comment: "")

        selectButton?.layer.cornerRadius = 15
        selectButton?.layer.masksToBounds = true
        selectButton?.setTitle(NSLocalizedString("_select_", comment: ""), for: .normal)
        selectButton?.backgroundColor = NCBrandColor.shared.brandElement
        selectButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        selectButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        createFolderButton?.layer.cornerRadius = 15
        createFolderButton?.layer.masksToBounds = true
        createFolderButton?.setTitle(NSLocalizedString("_create_folder_", comment: ""), for: .normal)
        createFolderButton?.backgroundColor = NCBrandColor.shared.brandElement
        createFolderButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        createFolderButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        copyButton?.layer.cornerRadius = 15
        copyButton?.layer.masksToBounds = true
        copyButton?.setTitle(NSLocalizedString("_copy_", comment: ""), for: .normal)
        copyButton?.backgroundColor = NCBrandColor.shared.brandElement
        copyButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        copyButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        moveButton?.layer.cornerRadius = 15
        moveButton?.layer.masksToBounds = true
        moveButton?.setTitle(NSLocalizedString("_move_", comment: ""), for: .normal)
        moveButton?.backgroundColor = NCBrandColor.shared.brandElement
        moveButton?.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .highlighted)
        moveButton?.setTitleColor(NCBrandColor.shared.brandText, for: .normal)
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

    func makeUIViewController(context: Context) -> UINavigationController {

        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController?.topViewController as? NCSelect

        viewController?.delegate = delegate
        viewController?.typeOfCommandView = .selectCreateFolder
        viewController?.includeDirectoryE2EEncryption = true

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }
}

struct SelectView: UIViewControllerRepresentable {
    @Binding var serverUrl: String

    class Coordinator: NSObject, NCSelectDelegate {
        var parent: SelectView

        init(_ parent: SelectView) {
            self.parent = parent
        }

        func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
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

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
