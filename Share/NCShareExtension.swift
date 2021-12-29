//
//  NCShareExtension.swift
//  Nextcloud
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
import IHProgressHUD

enum NCShareExtensionError: Error {
    case cancel, fileUpload, noAccount, noFiles
}

class NCShareExtension: UIViewController, NCListCellDelegate, NCEmptyDataSetDelegate, NCAccountRequestDelegate {

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
    // is this still needed?
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

    var heightRowTableView: CGFloat = 50
    private var heightCommandView: CGFloat = 170

    var autoUploadFileName = ""
    var autoUploadDirectory = ""

    let refreshControl = UIRefreshControl()
    var activeAccount: tableAccount!
    private let chunckSize = CCUtility.getChunkSize() * 1000000

    private var numberFilesName: Int = 0
    private var counterUpload: Int = 0
    private var uploadDispatchGroup: DispatchGroup?
    private var uploadErrors: [tableMetadata] = []
    private var uploadStarted = false

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.prefersLargeTitles = false

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.collectionViewLayout = NCListLayout()

        // Add Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.shared.brandText
        refreshControl.backgroundColor = NCBrandColor.shared.systemBackground
        refreshControl.addTarget(self, action: #selector(reloadDatasource), for: .valueChanged)

        // Command view
        commandView.backgroundColor = NCBrandColor.shared.secondarySystemBackground
        separatorView.backgroundColor = NCBrandColor.shared.separator
        separatorHeightConstraint.constant = 0.5

        // Table view
        tableView.separatorColor = NCBrandColor.shared.separator
        tableView.layer.cornerRadius = 10
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 0, height: 1)))
        commandViewHeightConstraint.constant = heightCommandView

        // Create folder
        createFolderView.layer.cornerRadius = 10
        createFolderImage.image = NCUtility.shared.loadImage(named: "folder.badge.plus", color: NCBrandColor.shared.label)
        createFolderLabel.text = NSLocalizedString("_create_folder_", comment: "")
        let createFolderGesture = UITapGestureRecognizer(target: self, action: #selector(actionCreateFolder))
        createFolderView.addGestureRecognizer(createFolderGesture)

        // Upload
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

        // HUD
        IHProgressHUD.set(viewForExtension: self.view)
        IHProgressHUD.set(defaultMaskType: .clear)
        IHProgressHUD.set(minimumDismiss: 0)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if serverUrl == "" {

            if let activeAccount = NCManageDatabase.shared.getActiveAccount() {

                setAccount(account: activeAccount.account)
                getFilesExtensionContext { filesName in

                    self.filesName = filesName
                    DispatchQueue.main.async {

                        var saveHtml: [String] = []
                        var saveOther: [String] = []

                        for fileName in self.filesName {
                            if (fileName as NSString).pathExtension.lowercased() == "html" {
                                saveHtml.append(fileName)
                            } else {
                                saveOther.append(fileName)
                            }
                        }

                        if saveOther.count > 0 && saveHtml.count > 0 {
                            for file in saveHtml {
                                self.filesName = self.filesName.filter {$0 != file}
                            }
                        }

                        self.setCommandView()
                    }
                }

            } else {
                showAlert(description: "_no_active_account_") {
                    self.extensionContext?.cancelRequest(withError: NCShareExtensionError.noAccount)
                }
            }
        }
    }
    
    func showAlert(title: String = "_error_", description: String, onDismiss: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: NSLocalizedString(title, comment: ""), message: NSLocalizedString(description, comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
            onDismiss?()
        }))
        self.present(alertController, animated: true)
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

    @objc func triggerProgressTask(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary?, let progressNumber = userInfo["progress"] as? NSNumber {

            let progress = CGFloat(progressNumber.floatValue)
            let status = NSLocalizedString("_upload_file_", comment: "") + " \(self.counterUpload) " + NSLocalizedString("_of_", comment: "") + " \(self.numberFilesName)"
            IHProgressHUD.show(progress: progress, status: status)
        }
    }

    // MARK: -

    func setAccount(account: String) {

        guard let activeAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else {
            extensionContext?.cancelRequest(withError: NCShareExtensionError.noAccount)
            return
        }
        self.activeAccount = activeAccount

        // NETWORKING
        NCCommunicationCommon.shared.setup(
            account: activeAccount.account,
            user: activeAccount.user,
            userId: activeAccount.userId,
            password: CCUtility.getPassword(activeAccount.account),
            urlBase: activeAccount.urlBase,
            userAgent: CCUtility.getUserAgent(),
            webDav: NCUtilityFileSystem.shared.getWebDAV(account: activeAccount.account),
            nextcloudVersion: 0,
            delegate: NCNetworking.shared)

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, account: activeAccount.account)

        serverUrl = NCUtilityFileSystem.shared.getHomeServer(account: activeAccount.account)

        layoutForView = NCUtility.shared.getLayoutForView(key: keyLayout, serverUrl: serverUrl)

        reloadDatasource(withLoadFolder: true)
        setNavigationBar(navigationTitle: NCBrandOptions.shared.brand)
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

            while self.serverUrl.last != "/" {
                self.serverUrl.removeLast()
            }
            self.serverUrl.removeLast()

            self.reloadDatasource(withLoadFolder: true)

            var navigationTitle = (self.serverUrl as NSString).lastPathComponent
            if NCUtilityFileSystem.shared.getHomeServer(account: self.activeAccount.account) == self.serverUrl {
                navigationTitle = NCBrandOptions.shared.brand
            }
            self.setNavigationBar(navigationTitle: navigationTitle)
        }

        // PROFILE BUTTON

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

            let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
            if accounts.count > 1 {

                if let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {

                    // Only here change the active account
                    for account in accounts {
                        if account.account == self.activeAccount.account {
                            account.active = true
                        } else {
                            account.active = false
                        }
                    }

                    vcAccountRequest.activeAccount = self.activeAccount
                    vcAccountRequest.accounts = accounts.sorted { sorg, dest -> Bool in
                        return sorg.active && !dest.active
                    }
                    vcAccountRequest.enableTimerProgress = false
                    vcAccountRequest.enableAddAccount = false
                    vcAccountRequest.delegate = self
                    vcAccountRequest.dismissDidEnterBackground = true

                    let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
                    let numberCell = accounts.count
                    let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)

                    let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height + 20)

                    self.present(popup, animated: true)
                }
            }
        }

        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(account: activeAccount.account) {

            navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: profileButton)], animated: true)

        } else {

            let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            space.width = 20

            navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: backButton), space, UIBarButtonItem(customView: profileButton)], animated: true)
        }
    }

    func setCommandView() {

        var counter: CGFloat = 0

        if filesName.isEmpty {
            self.extensionContext?.cancelRequest(withError: NCShareExtensionError.noFiles)
            return
        } else {
            if filesName.count < 3 {
                counter = CGFloat(filesName.count)
                self.commandViewHeightConstraint.constant = heightCommandView + (self.heightRowTableView * counter)
            } else {
                counter = 3
                self.commandViewHeightConstraint.constant = heightCommandView + (self.heightRowTableView * counter)
            }
            if filesName.count <= 3 {
                self.tableView.isScrollEnabled = false
            }
            // Label upload button
            numberFilesName = filesName.count
            uploadLabel.text = NSLocalizedString("_upload_", comment: "") + " \(numberFilesName) " + NSLocalizedString("_files_", comment: "")
            // Empty
            emptyDataSet = NCEmptyDataSet(view: collectionView, offset: -50 * counter, delegate: self)
            self.tableView.reloadData()
        }
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        if networkInProgress {
            view.emptyImage.image = UIImage(named: "networkInProgress")?.image(color: .gray, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
            view.emptyDescription.text = ""
        } else {
            view.emptyImage.image = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_files_no_folders_", comment: "")
            view.emptyDescription.text = ""
        }
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        extensionContext?.cancelRequest(withError: NCShareExtensionError.cancel)
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

    @objc func actionUpload() {
        guard !uploadStarted else { return }
        guard !filesName.isEmpty else { return showAlert(description: "_files_no_files_") }

        uploadStarted = true
        uploadErrors = []
        uploadDispatchGroup = DispatchGroup()
        uploadDispatchGroup?.enter()
        uploadDispatchGroup?.notify(queue: .main, execute: finishedUploading)

        var conflicts: [tableMetadata] = []
        for fileName in filesName {
            let ocId = NSUUID().uuidString
            let atPath = (NSTemporaryDirectory() + fileName)
            let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
            guard NCUtilityFileSystem.shared.copyFile(atPath: atPath, toPath: toPath) else { continue }
            let metadata = NCManageDatabase.shared.createMetadata(
                account: activeAccount.account,
                user: activeAccount.user,
                userId: activeAccount.userId,
                fileName: fileName,
                fileNameView: fileName,
                ocId: ocId,
                serverUrl: serverUrl,
                urlBase: activeAccount.urlBase,
                url: "",
                contentType: "",
                livePhoto: false)
            metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
            metadata.sessionSelector = NCGlobal.shared.selectorUploadFile
            metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: toPath)
            metadata.status = NCGlobal.shared.metadataStatusWaitUpload
            if NCManageDatabase.shared.getMetadataConflict(account: activeAccount.account, serverUrl: serverUrl, fileName: fileName) != nil {
                conflicts.append(metadata)
            } else {
                upload(metadata)
            }
        }

        if !conflicts.isEmpty {
            uploadDispatchGroup?.enter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict {

                    conflict.serverUrl = self.serverUrl
                    conflict.metadatasUploadInConflict = conflicts
                    conflict.delegate = self

                    self.present(conflict, animated: true, completion: nil)
                }
            }
        }
        uploadDispatchGroup?.leave()
    }

    func upload(_ metadata: tableMetadata) {
        uploadDispatchGroup?.enter()
        // E2EE
        if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase) {
            metadata.e2eEncrypted = true
        }

        // CHUNCK
        if chunckSize != 0 && metadata.size > chunckSize {
            metadata.chunk = true
        }

        NCNetworking.shared.upload(metadata: metadata) {

        } completion: { errorCode, _ in
            defer { self.uploadDispatchGroup?.leave() }
            if errorCode != 0 {
                self.counterUpload += 1
            } else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteChunks(account: self.activeAccount.account, ocId: metadata.ocId)
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
            IHProgressHUD.showSuccesswithStatus(NSLocalizedString("_success_", comment: ""))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.extensionContext?.completeRequest(returningItems: self.extensionContext?.inputItems, completionHandler: nil)
            }
        }
    }

    func accountRequestChangeAccount(account: String) {
        setAccount(account: account)
    }
}

extension NCShareExtension: NCShareCellDelegate, NCRenameFileDelegate {
    func removeFile(named fileName: String) {
        guard let index = self.filesName.firstIndex(of: fileName) else {
            return showAlert(title: "_file_not_found_", description: fileName)
        }
        self.filesName.remove(at: index)
        if self.filesName.isEmpty {
            self.extensionContext?.cancelRequest(withError: NCShareExtensionError.noFiles)
        } else {
            self.setCommandView()
        }
    }

    func rename(fileName: String, fileNameNew: String) {
        guard let fileIx = self.filesName.firstIndex(of: fileName),
              !self.filesName.contains(fileNameNew),
              NCUtilityFileSystem.shared.moveFile(atPath: (NSTemporaryDirectory() + fileName), toPath: (NSTemporaryDirectory() + fileNameNew)) else {
                  return showAlert(title: "_single_file_conflict_title_", description: "'\(fileName)' -> '\(fileNameNew)'")
              }

        filesName[fileIx] = fileNameNew
        tableView.reloadData()
    }
}

extension NCShareExtension: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        metadatas?.forEach { self.upload($0) }
        uploadDispatchGroup?.leave()
    }
}
