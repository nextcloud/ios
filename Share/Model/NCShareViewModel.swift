// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
import LucidBanner
import Network
@preconcurrency import QuickLookThumbnailing
import UniformTypeIdentifiers

@MainActor
final class NCShareViewModel: NSObject, ObservableObject {
    @Published var folders: [NCShareFolderItem] = []
    @Published var recentFolders: [NCShareFolderItem] = []
    @Published var selectedFolder: NCShareFolderItem?
    @Published var isRecentFolderSelected = false
    @Published var folderChildren: [String: [NCShareFolderItem]] = [:]
    @Published var expandedFolderURLs: Set<String> = []
    @Published var loadingFolderURLs: Set<String> = []
    @Published var loadedFolderURLs: Set<String> = []
    @Published var folderLoadErrors: [String: String] = [:]
    var folderTasks: [String: Task<Void, Never>] = [:]
    var folderRequests: [String: URLSessionTask] = [:]
    var folderSelectionTask: Task<Void, Never>?
    var folderBrowserID = UUID()
    lazy var recentFoldersStore = NCShareRecentFoldersStore(
        defaults: UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) ?? .standard)
    @Published var fileNames: [String] = []
    @Published var fileThumbnails: [String: UIImage] = [:]
    private var thumbnailRequests: [String: QLThumbnailGenerator.Request] = [:]
    private var failedThumbnails: Set<String> = []
    @Published var isLoading = false
    @Published private(set) var isOffline = false
    private var connectionMonitor: NWPathMonitor?
    @Published var isAvailable = false
    @Published var isPreparingUpload = false
    @Published var uploadConfirmation: NCShareUploadConfirmation?
    var pendingUploadConfirmation: NCShareUploadConfirmation?
    var uploadChoice: NCShareUploadChoice?
    var uploadTask: Task<Void, Never>?
    var replacementETags: [String: String] = [:]
    var isClosing = false
    @Published var isPreparingInput = false
    @Published var isShowingInputError = false
    @Published var inputErrorMessage = ""
    @Published var navigationTitle = NCBrandOptions.shared.brand
    @Published var accountName = ""
    @Published var accounts: [NCShareAccountItem] = []
    @Published var accountAvatars: [String: UIImage] = [:]
    @Published var isLoadingAccounts = false
    @Published var isSwitchingAccount = false
    @Published var serverCapabilities: NKCapabilities.Capabilities?
    @Published var isLoadingCapabilities = false
    @Published var capabilitiesErrorMessage = ""
    var isAccountReady: Bool { serverCapabilities != nil && !isSwitchingAccount && !isOffline }

    var capabilitiesTask: Task<Void, Never>?
    var capabilitiesRequest: URLSessionTask?
    var accountsTask: Task<Void, Never>?
    var accountChangeTask: Task<Void, Never>?
    var accountChangeID = UUID()
    @Published private(set) var isAuthenticated = false

    weak var presenter: UIViewController?
    var requestContext: NSExtensionContext?
    lazy var sessionStore = NCShareSessionStore()
    var serverUrl = ""
    var filesName: [String] {
        get { fileNames }
        set { fileNames = newValue }
    }
    let inputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("NextcloudShare-" + UUID().uuidString, isDirectory: true)
    private var inputTask: Task<Void, Never>?
    private var hasStarted = false
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    let keyLayout = NCGlobal.shared.layoutViewShareExtension
    var metadataFolder: tableMetadata?
    var dataSourceTask: URLSessionTask?
    var autoUploadFileName = ""
    var autoUploadDirectory = ""
    var progress: CGFloat = 0
    var counterUploaded: Int = 0
    var uploadMetadata: [tableMetadata] = []
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let global = NCGlobal.shared
    var maintenanceMode: Bool = false
    var token: Int?
    var banner: LucidBanner?
    var sceneIdentifier: String = UUID().uuidString
    private var isPresentingNoAccountAlert = false
    private var isPresentingPasscode = false
    private var isPasscodeAuthenticated = false

    func start(context: NSExtensionContext?, presenter: UIViewController) {
        guard !hasStarted else { return }
        hasStarted = true
        monitorConnection()
        self.requestContext = context
        self.presenter = presenter
        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionBuild())
        NextcloudKit.configureLogger(
            logLevel: NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log,
            logDirectory: NCPreferences.sharedLogDirectory
        )

        nkLog(start: "Start Share session " + versionNextcloudiOS)

        NCBrandColor.shared.createUserColors()

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.cancelAccountLoading() }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isClosing else { return }
                self.cancelAccountLoading()
                guard !self.maintenanceMode, self.validateAccount() else { return }
                self.resolveUploadConfirmation(nil)
                self.isPasscodeAuthenticated = false
                self.requestPasscodeIfNeeded()
            }
        }
        // Verify version
        let versionApp = NCUtility().getVersionMaintenance()
        if let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) {
            let lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion)
            if lastVersion != versionApp {
                maintenanceMode = true
                appear()
                return
            }
        }

        if let account = sessionStore.getTblAccoun()?.account {
            changeAccount(account)
        }

        NCNetworking.shared.setupScene(sceneIdentifier: sceneIdentifier, controller: presenter)

        if let windowScene = presenter.view.window?.windowScene {
            banner = LucidBannerRegistry.shared.banner(for: windowScene)
        }
        appear()
    }

    private func appear() {
        guard !maintenanceMode else {
            return showAlert(description: "_version_mismatch_error_") {
                self.cancel(with: .versionMismatch)
            }
        }
        guard validateAccount() else { return }
        requestPasscodeIfNeeded()
        guard let items = requestContext?.inputItems as? [NSExtensionItem] else {
            cancel(with: .noFiles)
            return
        }
        isPreparingInput = true
        let directory = inputDirectory
        inputTask = Task { [weak self] in
            defer {
                if Task.isCancelled { try? FileManager.default.removeItem(at: directory) }
            }
            do {
                let output = try await NCShareLoaderItemProvider.load(items: items, directory: directory)
                guard let self, !Task.isCancelled else { return }
                self.filesName = output.fileNames
                self.isPreparingInput = false
                if !output.failures.isEmpty || output.fileNames.isEmpty {
                    let key = output.fileNames.isEmpty ? "_share_import_no_files_" : "_share_import_failed_"
                    self.inputErrorMessage = ([NSLocalizedString(key, comment: "")] + output.failures).joined(separator: "\n\n")
                    self.showInputErrorIfNeeded()
                }
            } catch is CancellationError {
                // The loader removes its own request directory on cancellation.
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.isPreparingInput = false
                self.inputErrorMessage = NSLocalizedString("_share_import_no_files_", comment: "") + "\n\n" + error.localizedDescription
                self.showInputErrorIfNeeded()
            }
        }
    }

    private func monitorConnection() {
        let monitor = NWPathMonitor()
        connectionMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor [weak self] in
                guard let self, !self.isClosing else { return }
                let wasOffline = self.isOffline
                self.isOffline = offline
                if wasOffline && !offline { self.retryConnection() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.nextcloud.share.connection"))
    }

    func retryConnection() {
        guard !isOffline, isAuthenticated, !isClosing, !isSwitchingAccount, !isPreparingUpload else { return }
        if serverCapabilities == nil {
            retryCapabilities()
        } else {
            for row in visibleFolderRows where expandedFolderURLs.contains(row.folder.serverUrl) {
                requestFolderChildren(row.folder, refresh: true)
            }
        }
    }

    func loadThumbnail(named fileName: String) {
        guard !isClosing, fileThumbnails[fileName] == nil, thumbnailRequests[fileName] == nil,
              !failedThumbnails.contains(fileName), fileNames.contains(fileName) else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: inputFileURL(named: fileName), size: CGSize(width: 36, height: 36),
            scale: presenter?.view.window?.screen.scale ?? 2, representationTypes: .all)
        thumbnailRequests[fileName] = request
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            let image = representation?.uiImage
            Task { @MainActor [weak self] in
                guard let self, !self.isClosing, self.thumbnailRequests[fileName] === request else { return }
                self.thumbnailRequests[fileName] = nil
                guard self.fileNames.contains(fileName) else { return }
                if let image {
                    // Keep extension memory bounded even when sharing many files.
                    if self.fileThumbnails.count >= 64, let oldest = self.fileThumbnails.keys.first {
                        self.fileThumbnails[oldest] = nil
                    }
                    self.fileThumbnails[fileName] = image
                } else {
                    self.failedThumbnails.insert(fileName)
                }
            }
        }
    }

    func fileIcon(named fileName: String) -> String {
        guard let type = UTType(filenameExtension: (fileName as NSString).pathExtension) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .audio) { return "music.note" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }

    private func discardThumbnail(named fileName: String) {
        if let request = thumbnailRequests.removeValue(forKey: fileName) {
            QLThumbnailGenerator.shared.cancel(request)
        }
        fileThumbnails[fileName] = nil
        failedThumbnails.remove(fileName)
    }

    func inputFileURL(named fileName: String) -> URL {
        inputDirectory.appendingPathComponent(fileName)
    }

    func showInputErrorIfNeeded() {
        // Do not present import errors over the passcode screen.
        if isAuthenticated && !isLoadingAccounts && !inputErrorMessage.isEmpty {
            isShowingInputError = true
        }
    }

    func acknowledgeInputError() {
        inputErrorMessage = ""
        if filesName.isEmpty { cancel(with: .noFiles) }
    }

    isolated deinit {
        connectionMonitor?.cancel()
        for request in thumbnailRequests.values { QLThumbnailGenerator.shared.cancel(request) }
        inputTask?.cancel()
        uploadTask?.cancel()
        accountsTask?.cancel()
        accountChangeTask?.cancel()
        capabilitiesTask?.cancel()
        capabilitiesRequest?.cancel()
        dataSourceTask?.cancel()
        folderSelectionTask?.cancel()
        for task in folderTasks.values { task.cancel() }
        for request in folderRequests.values { request.cancel() }
        if !isPreparingInput { try? FileManager.default.removeItem(at: inputDirectory) }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    private func validateAccount() -> Bool {
        guard !NCPasscodeModel.isPasscodeReset else {
            return showNoAccountAlert()
        }

        if let account = sessionStore.getTblAccoun()?.account,
           NCManageDatabase.shared.getTableAccount(account: account) != nil {
            return true
        }

        guard let activeAccount = NCManageDatabase.shared.getActiveTableAccount() else {
            return showNoAccountAlert()
        }

        clearAccountView()
        changeAccount(activeAccount.account)
        return true
    }

    private func showNoAccountAlert() -> Bool {
        clearAccountView()
        if !isPresentingNoAccountAlert {
            isPresentingNoAccountAlert = true
            showAlert(description: "_no_active_account_") {
                self.cancel(with: .noAccount)
            }
        }
        return false
    }

    func clearAccountView() {
        capabilitiesTask?.cancel()
        capabilitiesRequest?.cancel()
        serverCapabilities = nil
        isLoadingCapabilities = false
        capabilitiesErrorMessage = ""
        dataSourceTask?.cancel()
        dataSourceTask = nil
        metadataFolder = nil
        isAvailable = false
        resetFolderBrowser()
        accountName = ""
        navigationTitle = NCBrandOptions.shared.brand
    }

    func showAccountView() {
        isAvailable = true
    }

    func cancel(with error: NCShareRequestError? = nil) {
        isClosing = true
        connectionMonitor?.cancel()
        cancelAccountLoading()
        uploadConfirmation = nil
        pendingUploadConfirmation = nil
        uploadChoice = nil
        inputTask?.cancel()
        uploadTask?.cancel()
        accountsTask?.cancel()
        accountChangeTask?.cancel()
        capabilitiesTask?.cancel()
        capabilitiesRequest?.cancel()
        dataSourceTask?.cancel()
        folderSelectionTask?.cancel()
        for task in folderTasks.values { task.cancel() }
        for request in folderRequests.values { request.cancel() }
        if !isPreparingInput { try? FileManager.default.removeItem(at: inputDirectory) }
        if let error {
            requestContext?.cancelRequest(withError: error)
        } else {
            requestContext?.completeRequest(returningItems: requestContext?.inputItems, completionHandler: nil)
        }
    }

    func showAlert(title: String = "_error_", description: String, onDismiss: (() -> Void)? = nil) {
        let description = description.replacingOccurrences(of: "\t", with: "\n")
        let alertController = UIAlertController(title: NSLocalizedString(title, comment: ""), message: NSLocalizedString(description, comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
            onDismiss?()
        }))
        presenter?.present(alertController, animated: true)
    }

    func setNavigationBar(navigationTitle: String) {
        self.navigationTitle = navigationTitle
        guard let account = sessionStore.getTblAccoun() else { return }
        let name = account.displayName.isEmpty ? account.user : account.displayName
        accountName = account.alias.isEmpty ? name : name + " - " + account.alias
    }

    func setCommandView() {
        if filesName.isEmpty { cancel(with: .noFiles) }
    }

    func createFolder() {
        let session = sessionStore.getSession()
        guard isAccountReady, let folder = selectedFolder, !loadingFolderURLs.contains(folder.serverUrl) else { return }
        guard let capabilities = serverCapabilities else { return }
        let alert = UIAlertController.createFolderWith(serverUrl: folder.serverUrl, session: session, capabilities: capabilities) { [weak self] error in
            guard let self else { return }
            guard !self.isClosing, self.sessionStore.getSession().account == session.account else { return }
            if error == .success {
                self.expandedFolderURLs.insert(folder.serverUrl)
                self.requestFolderChildren(folder, refresh: true)
            } else {
                self.showAlert(title: "_error_createsubfolders_upload_", description: error.errorDescription)
            }
        }
        presenter?.present(alert, animated: true)
    }

    func showRenameFileDialog(named fileName: String, account: String) {
        guard let capabilities = serverCapabilities else { return }
        let alert = UIAlertController.renameFile(fileName: fileName, capabilities: capabilities, account: account) { [self] newFileName in
            renameFile(oldName: fileName, newName: newFileName, account: account)
        }

        presenter?.present(alert, animated: true)
    }

    func renameFile(oldName: String, newName: String, account: String) {
        guard let fileIx = self.filesName.firstIndex(of: oldName),
              !self.filesName.contains(newName),
              newName == (newName as NSString).lastPathComponent,
              newName != ".", newName != "..",
              utilityFileSystem.moveFile(atPath: inputFileURL(named: oldName).path, toPath: inputFileURL(named: newName).path) else {
            return showAlert(title: "_single_file_conflict_title_", description: "'\(oldName)' -> '\(newName)'")
        }

        discardThumbnail(named: oldName)
        filesName[fileIx] = newName

    }

    func removeFile(named fileName: String) {
        guard let index = self.filesName.firstIndex(of: fileName) else {
            return showAlert(title: "_file_not_found_", description: fileName)
        }
        discardThumbnail(named: fileName)
        try? FileManager.default.removeItem(at: inputFileURL(named: fileName))
        self.filesName.remove(at: index)
        if self.filesName.isEmpty {
            cancel(with: NCShareRequestError.noFiles)
        } else {
            self.setCommandView()
        }
    }

    func rename(_ fileName: String) {
        showRenameFileDialog(named: fileName, account: sessionStore.getSession().account)
    }

    func remove(_ fileName: String) {
        removeFile(named: fileName)
    }

    func upload() {
        guard isAccountReady, isAuthenticated, !isPreparingInput, inputErrorMessage.isEmpty, !isPreparingUpload,
              !isSwitchingAccount, !isLoadingAccounts, !isLoading, !fileNames.isEmpty else { return }
        guard let capabilities = serverCapabilities else { return }
        isPreparingUpload = true
        actionUpload(capabilities: capabilities)
    }
}

extension NCShareViewModel {
    /// Require authentication once per foreground session without reopening after dismissal.
    private func requestPasscodeIfNeeded() {
        if !NCPreferences().presentPasscode {
            isAuthenticated = true
            showInputErrorIfNeeded()
            return
        }
        isAuthenticated = false
        isShowingInputError = false
        guard NCPreferences().presentPasscode,
              !isPasscodeAuthenticated,
              !isPresentingPasscode,
              let presenter else { return }
        isPresentingPasscode = true
        // Embed in the content controller; the helper hides the outer navigation bar.
        NCPasscodeView.embed(in: presenter) { [weak self] result in
            guard let self else { return }
            self.isPresentingPasscode = false
            switch result {
            case .authenticated:
                self.isPasscodeAuthenticated = true
                if self.validateAccount() {
                    self.isAuthenticated = true
                    self.showInputErrorIfNeeded()
                }
            case .cancelled, .reset, .configured, .disabled:
                self.cancel(with: .noAccount)
            }
        }
    }
}

/// A UI snapshot, so SwiftUI does not retain live Realm objects.
struct NCShareFolderItem: Identifiable {
    var id: String { serverUrl }
    let ocId: String
    let name: String
    let serverUrl: String
    let path: String
    let image: UIImage?
    let isEncrypted: Bool
}

struct NCShareFolderRow: Identifiable {
    var id: String { folder.id }
    let folder: NCShareFolderItem
    let depth: Int
}

enum NCShareRequestError: Error {
    case cancel, fileUpload, noAccount, noFiles, versionMismatch
}

struct NCShareUploadItem: Sendable {
    let sourceName: String
    let fileName: String
}

struct NCShareUploadConfirmation: Identifiable, Sendable {
    let id = UUID()
    let account: String
    let serverUrl: String
    let items: [NCShareUploadItem]
    let replacementFileName: String?
    let replacementETag: String?
    let requiresConfirmation: Bool

    var isBatch: Bool { items.count > 1 }
    var renamedItems: [NCShareUploadItem] { items.filter { $0.sourceName != $0.fileName } }
}

enum NCShareUploadChoice: Equatable, Sendable {
    case replace, keepBoth
}

/// Account picker data contains no live Realm objects or mutable account flags.
struct NCShareAccountItem: Identifiable, Sendable {
    let id: String
    let name: String
    let user: String
    let serverUrl: String
    let isSelected: Bool
}

#if DEBUG && SHARE_PREVIEWS
extension NCShareViewModel {
    /// Static preview state. The entry controller never starts a share request.
    /// Session storage stays lazy so constructing this model does not read accounts.
    static func preview() -> NCShareViewModel {
        let model = NCShareViewModel()
        model.isAvailable = true
        model.serverCapabilities = NKCapabilities.Capabilities()
        model.isAuthenticated = true
        model.accountName = "Personal"
        let home = "https://cloud.example.com/remote.php/dav/files/marino"
        let root = NCShareFolderItem(ocId: "root", name: "My files", serverUrl: home, path: "/", image: UIImage(systemName: "folder.fill"), isEncrypted: false)
        let documents = NCShareFolderItem(ocId: "documents", name: "Documents", serverUrl: home + "/Documents", path: "/Documents", image: UIImage(systemName: "folder.fill"), isEncrypted: false)
        let photos = NCShareFolderItem(ocId: "photos", name: "Photos", serverUrl: home + "/Photos", path: "/Photos", image: UIImage(systemName: "folder.fill"), isEncrypted: false)
        let work = NCShareFolderItem(ocId: "work", name: "Work", serverUrl: home + "/Documents/Work", path: "/Documents/Work", image: UIImage(systemName: "folder.fill"), isEncrypted: false)
        model.serverUrl = documents.serverUrl
        model.selectedFolder = documents
        model.folders = [root]
        model.folderChildren = [home: [documents, photos], documents.serverUrl: [work]]
        model.expandedFolderURLs = [home, documents.serverUrl]
        model.loadedFolderURLs = [home, documents.serverUrl]
        model.recentFolders = [documents, photos]
        model.fileNames = ["Report.pdf", "Photo.jpg", "Notes.txt"]
        model.accounts = [
            NCShareAccountItem(id: "personal", name: "Personal", user: "marino", serverUrl: "https://cloud.example.com", isSelected: true),
            NCShareAccountItem(id: "work", name: "Work", user: "marino.work", serverUrl: "https://team.example.com", isSelected: false)
        ]
        return model
    }
}
#endif
