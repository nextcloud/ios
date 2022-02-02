//
//  NCShareExtension.swift
//  Share
//
//  Created by Marino Faggiana on 20/04/2021.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import NCCommunication
import JGProgressHUD

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

    var emptyDataSet: NCEmptyDataSet?
    let keyLayout = NCGlobal.shared.layoutViewShareExtension
    var metadataFolder: tableMetadata?
    var networkInProgress = false
    var dataSource = NCDataSource()
    var layoutForView: NCGlobal.layoutForViewType?
    let heightRowTableView: CGFloat = 50
    let heightCommandView: CGFloat = 170
    var autoUploadFileName = ""
    var autoUploadDirectory = ""
    let refreshControl = UIRefreshControl()
    var activeAccount: tableAccount!
    let chunckSize = CCUtility.getChunkSize() * 1000000
    var progress: CGFloat = 0
    var counterUploaded: Int = 0
    var uploadErrors: [tableMetadata] = []
    var uploadMetadata: [tableMetadata] = []
    var uploadStarted = false
    let hud = JGProgressHUD()

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.prefersLargeTitles = false

        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.collectionViewLayout = NCListLayout()

        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.shared.brandText
        refreshControl.backgroundColor = NCBrandColor.shared.systemBackground
        refreshControl.addTarget(self, action: #selector(reloadDatasource), for: .valueChanged)

        commandView.backgroundColor = NCBrandColor.shared.secondarySystemBackground
        separatorView.backgroundColor = NCBrandColor.shared.separator
        separatorHeightConstraint.constant = 0.5

        tableView.separatorColor = NCBrandColor.shared.separator
        tableView.layer.cornerRadius = 10
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 0, height: 1)))
        commandViewHeightConstraint.constant = heightCommandView

        createFolderView.layer.cornerRadius = 10
        createFolderImage.image = NCUtility.shared.loadImage(named: "folder.badge.plus", color: NCBrandColor.shared.label)
        createFolderLabel.text = NSLocalizedString("_create_folder_", comment: "")
        let createFolderGesture = UITapGestureRecognizer(target: self, action: #selector(actionCreateFolder))
        createFolderView.addGestureRecognizer(createFolderGesture)

        uploadView.layer.cornerRadius = 10
        
        // uploadImage.image = NCUtility.shared.loadImage(named: "square.and.arrow.up", color: NCBrandColor.shared.label)
        uploadLabel.text = NSLocalizedString("_upload_", comment: "")
        uploadLabel.textColor = .systemBlue
        let uploadGesture = UITapGestureRecognizer(target: self, action: #selector(actionUpload))
        uploadView.addGestureRecognizer(uploadGesture)

        // LOG
        let levelLog = CCUtility.getLogLevel()
        let isSimulatorOrTestFlight = NCUtility.shared.isSimulatorOrTestFlight()
        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility.shared.getVersionApp())

        NCCommunicationCommon.shared.levelLog = levelLog
        if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
            NCCommunicationCommon.shared.pathLog = pathDirectoryGroup
        }
        if isSimulatorOrTestFlight {
            NCCommunicationCommon.shared.writeLog("Start session with level \(levelLog) " + versionNextcloudiOS + " (Simulator / TestFlight)")
        } else {
            NCCommunicationCommon.shared.writeLog("Start session with level \(levelLog) " + versionNextcloudiOS)
        }

        hud.indicatorView = JGProgressHUDRingIndicatorView()
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
            indicatorView.ringWidth = 1.5
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard serverUrl.isEmpty else { return }

        guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else {
            return showAlert(description: "_no_active_account_") {
                self.cancel(with: .noAccount)
            }
        }

        accountRequestChangeAccount(account: activeAccount.account)
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            cancel(with: .noFiles)
            return
        }
        NCFilesExtensionHandler(items: inputItems) { fileNames in
            self.filesName = fileNames
            DispatchQueue.main.async { self.setCommandView() }
        }
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
        let alertController = UIAlertController(title: NSLocalizedString(title, comment: ""), message: NSLocalizedString(description, comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
            onDismiss?()
        }))
        self.present(alertController, animated: true)
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {
        guard let progress = notification.userInfo?["progress"] as? Float else { return }
        hud.progress = progress
    }
    
    func setNavigationBar(navigationTitle: String) {

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

                self.reloadDatasource(withLoadFolder: true)

                var navigationTitle = (self.serverUrl as NSString).lastPathComponent
                if NCUtilityFileSystem.shared.getHomeServer(account: self.activeAccount.account) == self.serverUrl {
                    navigationTitle = NCBrandOptions.shared.brand
                }
                self.setNavigationBar(navigationTitle: navigationTitle)
            }
        }

        let image = NCUtility.shared.loadUserImage(
            for: activeAccount.user,
               displayName: activeAccount.displayName,
               userBaseUrl: activeAccount)
        let profileButton = UIButton(type: .custom)
        profileButton.setImage(image, for: .normal)

        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(account: activeAccount.account) {

            var title = "  "
            if let userAlias = activeAccount?.alias, !userAlias.isEmpty {
                title += userAlias
            } else {
                title += activeAccount?.displayName ?? ""
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
        if serverUrl != NCUtilityFileSystem.shared.getHomeServer(account: activeAccount.account) {
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
        // Label upload button
        uploadLabel.text = NSLocalizedString("_upload_", comment: "") + " \(filesName.count) " + NSLocalizedString("_files_", comment: "")
        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: -50 * counter, delegate: self)
        self.tableView.reloadData()
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        cancel(with: .cancel)
    }

    @objc func actionCreateFolder() {

        let alertController = UIAlertController(title: NSLocalizedString("_create_folder_", comment: ""), message: "", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.autocapitalizationType = UITextAutocapitalizationType.words
        }

        let actionSave = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default) { _ in
            if let fileName = alertController.textFields?.first?.text {
                self.createFolder(with: fileName)
            }
        }

        let actionCancel = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel)

        alertController.addAction(actionSave)
        alertController.addAction(actionCancel)

        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: - Upload
extension NCShareExtension {
    @objc func actionUpload() {
        guard !uploadStarted else { return }
        guard !filesName.isEmpty else { return showAlert(description: "_files_no_files_") }

        counterUploaded = 0
        uploadStarted = true
        uploadErrors = []

        var conflicts: [tableMetadata] = []
        for fileName in filesName {
            let ocId = NSUUID().uuidString
            let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
            guard NCUtilityFileSystem.shared.copyFile(atPath: (NSTemporaryDirectory() + fileName), toPath: toPath) else { continue }
            let metadata = NCManageDatabase.shared.createMetadata(
                account: activeAccount.account, user: activeAccount.user, userId: activeAccount.userId,
                fileName: fileName, fileNameView: fileName,
                ocId: ocId,
                serverUrl: serverUrl, urlBase: activeAccount.urlBase, url: "",
                contentType: "",
                livePhoto: false)
            metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
            metadata.sessionSelector = NCGlobal.shared.selectorUploadFileShareExtension
            metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: toPath)
            metadata.status = NCGlobal.shared.metadataStatusWaitUpload
            if NCManageDatabase.shared.getMetadataConflict(account: activeAccount.account, serverUrl: serverUrl, fileName: fileName) != nil {
                conflicts.append(metadata)
            } else {
                uploadMetadata.append(metadata)
            }
        }

        if !conflicts.isEmpty {
            guard let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict
            else { return }
            conflict.serverUrl = self.serverUrl
            conflict.metadatasUploadInConflict = conflicts
            conflict.delegate = self
            self.present(conflict, animated: true, completion: nil)
        } else {
            upload()
        }
    }

    func upload() {
        guard uploadStarted else { return }
        guard uploadMetadata.count > counterUploaded else { return finishedUploading() }
        let metadata = uploadMetadata[counterUploaded]

        // E2EE
        metadata.e2eEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        // CHUNCK
        metadata.chunk = chunckSize != 0 && metadata.size > chunckSize

        hud.textLabel.text = NSLocalizedString("_upload_file_", comment: "") + " \(counterUploaded + 1) " + NSLocalizedString("_of_", comment: "") + " \(filesName.count)"
        hud.progress = 0
        hud.show(in: self.view)
        
        NCNetworking.shared.upload(metadata: metadata) { } completion: { errorCode, _ in
            if errorCode == 0 {
                self.counterUploaded += 1
                self.upload()
            } else {
                let path = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)!
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: metadata.ocId)
                NCUtilityFileSystem.shared.deleteFile(filePath: path)
                self.uploadErrors.append(metadata)
            }
        }
    }

    func finishedUploading() {
        uploadStarted = false
        if !uploadErrors.isEmpty {
            let fileList = "- " + uploadErrors.map({ $0.fileName }).joined(separator: "\n  - ")
            showAlert(title: "_error_files_upload_", description: fileList) {
                self.extensionContext?.cancelRequest(withError: NCShareExtensionError.fileUpload)
            }
        } else {
            hud.indicatorView = JGProgressHUDSuccessIndicatorView()
            hud.textLabel.text = NSLocalizedString("_success_", comment: "")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
            }
        }
    }
}
