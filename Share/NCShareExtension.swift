// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-FileCopyrightText: 2021 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

enum NCShareExtensionError: Error {
    case cancel, fileUpload, noAccount, noFiles
}

class NCShareExtension: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var commandView: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var commandViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var createFolderView: UIView!
    @IBOutlet weak var createFolderImage: UIImageView!
    @IBOutlet weak var createFolderLabel: UILabel!
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var uploadImage: UIImageView!
    @IBOutlet weak var uploadLabel: UILabel!

    // -------------------------------------------------------------
    var serverUrl = ""
    var filesName: [String] = []
    // -------------------------------------------------------------

    let keyLayout = NCGlobal.shared.layoutViewShareExtension
    var metadataFolder: tableMetadata?
    var dataSourceTask: URLSessionTask?
    var dataSource = NCCollectionViewDataSource()
    let heightRowTableView: CGFloat = 50
    let heightCommandView: CGFloat = 170
    var autoUploadFileName = ""
    var autoUploadDirectory = ""
    var progress: CGFloat = 0
    var counterUploaded: Int = 0
    var uploadErrors: [tableMetadata] = []
    var uploadMetadata: [tableMetadata] = []
    var uploadStarted = false
    let hud = NCHud()
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared
    let extensionData = NCShareExtensionData.shared

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.prefersLargeTitles = false

        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.collectionViewLayout = NCListLayout()

        commandView.backgroundColor = .secondarySystemBackground
        separatorView.backgroundColor = .separator
        separatorHeightConstraint.constant = 0.5

        tableView.separatorColor = .separator
        tableView.layer.cornerRadius = 10
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 0, height: 1)))
        commandViewHeightConstraint.constant = heightCommandView

        createFolderView.layer.cornerRadius = 10
        createFolderImage.image = utility.loadImage(named: "folder.badge.plus", colors: [NCBrandColor.shared.iconImageColor])
        createFolderLabel.text = NSLocalizedString("_create_folder_", comment: "")
        let createFolderGesture = UITapGestureRecognizer(target: self, action: #selector(actionCreateFolder(_:)))
        createFolderView.addGestureRecognizer(createFolderGesture)

        uploadView.layer.cornerRadius = 10

        uploadLabel.text = NSLocalizedString("_upload_", comment: "")
        uploadLabel.textColor = .systemBlue
        let uploadGesture = UITapGestureRecognizer(target: self, action: #selector(actionUpload(_:)))
        uploadView.addGestureRecognizer(uploadGesture)

        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionApp())
        NextcloudKit.configureLogger(logLevel: (NCBrandOptions.shared.disable_log ? .disabled : NCKeychain().log))

        nkLog(start: "Start Share session " + versionNextcloudiOS)

        NCBrandColor.shared.createUserColors()

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            if NCKeychain().presentPasscode {
                NCPasscode.shared.presentPasscode(viewController: self, delegate: self) {
                    NCPasscode.shared.enableTouchFaceID()
                }
            }
        }

        if let account = extensionData.getTblAccoun()?.account {
            accountRequestChangeAccount(account: account, controller: nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard extensionData.getTblAccoun() != nil,
                  !NCPasscode.shared.isPasscodeReset else {
            return showAlert(description: "_no_active_account_") {
                self.cancel(with: .noAccount)
            }
        }

        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            cancel(with: .noFiles)
            return
        }

        NCFilesExtensionHandler(items: inputItems) { fileNames in
            self.filesName = fileNames
            DispatchQueue.main.async {
                self.setCommandView()
            }
        }

        if NCKeychain().presentPasscode {
            NCPasscode.shared.presentPasscode(viewController: self, delegate: self) {
                NCPasscode.shared.enableTouchFaceID()
            }
        }

        self.collectionView.reloadData()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        collectionView.reloadData()
        tableView.reloadData()
    }

    // MARK: -

    func cancel(with error: NCShareExtensionError) {
        // make sure no uploads are continued
        uploadStarted = false
        extensionContext?.cancelRequest(withError: error)
    }

    func showAlert(title: String = "_error_", description: String, onDismiss: (() -> Void)? = nil) {
        let description = description.replacingOccurrences(of: "\t", with: "\n")
        let alertController = UIAlertController(title: NSLocalizedString(title, comment: ""), message: NSLocalizedString(description, comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
            onDismiss?()
        }))
        self.present(alertController, animated: true)
    }

    func setNavigationBar(navigationTitle: String) {
        guard let tblAccount = self.extensionData.getTblAccoun() else {
            return
        }
        let session = self.extensionData.getSession()

        navigationItem.title = navigationTitle
        cancelButton.title = NSLocalizedString("_cancel_", comment: "")

        // BACK BUTTON
        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "back"), for: .normal)
        backButton.tintColor = .systemBlue
        backButton.semanticContentAttribute = .forceLeftToRight
        backButton.setTitle(" " + NSLocalizedString("_back_", comment: ""), for: .normal)
        backButton.setTitleColor(.systemBlue, for: .normal)
        backButton.action(for: .touchUpInside) { _ in
            if !self.uploadStarted {
                while self.serverUrl.last != "/" { self.serverUrl.removeLast() }
                self.serverUrl.removeLast()
                Task {
                    await self.reloadData()
                }
                var navigationTitle = (self.serverUrl as NSString).lastPathComponent
                if self.utilityFileSystem.getHomeServer(session: session) == self.serverUrl {
                    navigationTitle = NCBrandOptions.shared.brand
                }
                self.setNavigationBar(navigationTitle: navigationTitle)
            }
        }

        let image = utility.loadUserImage(for: tblAccount.user, displayName: tblAccount.displayName, urlBase: tblAccount.urlBase)
        let profileButton = UIButton(type: .custom)
        profileButton.setImage(image, for: .normal)

        if serverUrl == utilityFileSystem.getHomeServer(session: session) {
            var title = "  "
            if !tblAccount.alias.isEmpty {
                title += tblAccount.alias
            } else {
                title += tblAccount.displayName
            }

            profileButton.setTitle(title, for: .normal)
            profileButton.setTitleColor(.systemBlue, for: .normal)
        }

        profileButton.semanticContentAttribute = .forceLeftToRight
        profileButton.sizeToFit()
        profileButton.action(for: .touchUpInside) { _ in
            if !self.uploadStarted {
                self.showAccountPicker()
            }
        }
        var navItems = [UIBarButtonItem(customView: profileButton)]
        if serverUrl != utilityFileSystem.getHomeServer(session: session) {
            let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            space.width = 20
            navItems.append(contentsOf: [UIBarButtonItem(customView: backButton), space])
        }
        navigationItem.setLeftBarButtonItems(navItems, animated: true)
    }

    func setCommandView() {
        guard !filesName.isEmpty else {
            cancel(with: .noFiles)
            return
        }
        let counter = min(CGFloat(filesName.count), 3)
        self.commandViewHeightConstraint.constant = heightCommandView + (self.heightRowTableView * counter)

        if filesName.count <= 3 {
            self.tableView.isScrollEnabled = false
        }
        uploadLabel.text = NSLocalizedString("_upload_", comment: "") + " \(filesName.count) " + NSLocalizedString("_files_", comment: "")
        self.tableView.reloadData()
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        cancel(with: .cancel)
    }

    @objc func actionCreateFolder(_ sender: Any?) {
        let session = self.extensionData.getSession()
        guard let capabilities = NCNetworking.shared.capabilities[session.account] else {
            return
        }
        let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, capabilities: capabilities) { error in
            if error == .success {
                Task {
                    await self.loadFolder()
                }
            } else {
                self.showAlert(title: "_error_createsubfolders_upload_", description: error.errorDescription)
            }
        }
        self.present(alertController, animated: true)
    }
}

// MARK: - Upload
extension NCShareExtension {
    @objc func actionUpload(_ sender: Any?) {
        Task { @MainActor in
            guard let tblAccount = self.extensionData.getTblAccoun(),
                  let capabilities = NCNetworking.shared.capabilities[tblAccount.account] else {
                return
            }
            guard !uploadStarted else { return }
            guard !filesName.isEmpty else { return showAlert(description: "_files_no_files_") }
            let session = self.extensionData.getSession()

            counterUploaded = 0
            uploadErrors = []
            var dismissAfterUpload = true

            var conflicts: [tableMetadata] = []
            var invalidNameIndexes: [Int] = []

            for (index, fileName) in filesName.enumerated() {
                let newFileName = FileAutoRenamer.rename(fileName, capabilities: capabilities)

                if let fileNameError = FileNameValidator.checkFileName(newFileName, account: tblAccount.account, capabilities: capabilities) {
                    if filesName.count == 1 {
                        showRenameFileDialog(named: fileName, account: tblAccount.account)
                        return
                    } else {
                        let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                        await UIAlertController.warningAsync(message: message, presenter: self)

                        invalidNameIndexes.append(index)
                        dismissAfterUpload = false
                        continue
                    }

                }
            }

            for index in invalidNameIndexes.reversed() {
                filesName.remove(at: index)
            }

            for fileName in filesName {
                let ocId = NSUUID().uuidString
                let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName, userId: session.userId, urlBase: session.urlBase)
                guard utilityFileSystem.copyFile(atPath: (NSTemporaryDirectory() + fileName), toPath: toPath) else {
                    continue
                }
                let metadataForUpload = await self.database.createMetadataAsync(fileName: fileName,
                                                                           ocId: ocId,
                                                                           serverUrl: serverUrl,
                                                                     session: session,
                                                                     sceneIdentifier: nil)

                metadataForUpload.session = NCNetworking.shared.sessionUpload
                metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFileShareExtension
                metadataForUpload.size = utilityFileSystem.getFileSize(filePath: toPath)
                metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                metadataForUpload.sessionDate = Date()
                if self.database.getMetadataConflict(account: session.account, serverUrl: serverUrl, fileNameView: fileName, nativeFormat: metadataForUpload.nativeFormat) != nil {
                    conflicts.append(metadataForUpload)
                } else {
                    uploadMetadata.append(metadataForUpload)
                }
            }

            tableView.reloadData()

            if !conflicts.isEmpty {
                guard let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict
                else { return }

                conflict.account = session.account
                conflict.serverUrl = self.serverUrl
                conflict.metadatasUploadInConflict = conflicts
                conflict.delegate = self
                self.present(conflict, animated: true, completion: nil)
            } else {
                uploadStarted = true
                upload(dismissAfterUpload: dismissAfterUpload)
            }
        }
    }

    func upload(dismissAfterUpload: Bool = true) {
        Task { @MainActor in
            guard uploadStarted else { return }
            guard uploadMetadata.count > counterUploaded else {
                return DispatchQueue.main.async {
                    self.finishedUploading(dismissAfterUpload: dismissAfterUpload)
                }
            }
            let session = self.extensionData.getSession()

            let metadata = uploadMetadata[counterUploaded]
            let results = await NKTypeIdentifiers.shared.getInternalType(fileName: metadata.fileNameView, mimeType: metadata.contentType, directory: false, account: session.account)
            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.classFile = results.classFile
            metadata.typeIdentifier = results.typeIdentifier
            metadata.serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName

            // CHUNK
            var chunkSize = NCGlobal.shared.chunkSizeMBCellular
            if NCNetworking.shared.networkReachability == NKTypeReachability.reachableEthernetOrWiFi {
                chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
            }
            if metadata.size > chunkSize {
                metadata.chunk = chunkSize
            } else {
                metadata.chunk = 0
            }
            // E2EE
            metadata.e2eEncrypted = metadata.isDirectoryE2EE

            hud.initHudRing(view: self.view,
                            text: NSLocalizedString("_upload_file_", comment: "") + " \(self.counterUploaded + 1) " + NSLocalizedString("_of_", comment: "") + " \(self.filesName.count)")

            NCNetworking.shared.uploadHub(metadata: metadata, uploadE2EEDelegate: self, controller: self) {
                self.hud.progress(0)
            } progressHandler: { _, _, fractionCompleted in
                self.hud.progress(fractionCompleted)
            } completion: {error in
                if error != .success {
                    self.database.deleteMetadataOcId(metadata.ocId)
                    self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    self.uploadErrors.append(metadata)
                }
                self.counterUploaded += 1
                self.upload()
            }
        }
    }

    func finishedUploading(dismissAfterUpload: Bool = true) {
        uploadStarted = false
        if !uploadErrors.isEmpty {
            let fileList = "- " + uploadErrors.map({ $0.fileName }).joined(separator: "\n  - ")
            showAlert(title: "_error_files_upload_", description: fileList) {
                self.extensionContext?.cancelRequest(withError: NCShareExtensionError.fileUpload)
            }
        } else {
            hud.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
            }
        }
    }
}

extension NCShareExtension: uploadE2EEDelegate {
    func start() {
        self.hud.progress(0)
    }

    func uploadE2EEProgress(_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) {
        self.hud.progress(fractionCompleted)
    }
}

extension NCShareExtension: NCPasscodeDelegate {
    func passcodeReset(_ passcodeViewController: TOPasscodeViewController) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            passcodeViewController.dismiss(animated: false)
            self.cancel(with: .noAccount)
        }
    }

    func evaluatePolicy(_ passcodeViewController: TOPasscodeViewController, isCorrectCode: Bool) {
        if !isCorrectCode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                passcodeViewController.dismiss(animated: false)
                self.cancel(with: .noAccount)
            }
        }
    }
}
