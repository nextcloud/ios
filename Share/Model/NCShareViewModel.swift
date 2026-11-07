// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
import LucidBanner
import Network
@preconcurrency import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Owns one share request. Accounts, folder browsing and uploads are implemented
/// in the corresponding extensions; input files remain local until upload staging.
@MainActor
final class NCShareViewModel: NSObject, ObservableObject {
    @Published var folders: [NCShareFolderItem] = []
    @Published var recentFolders: [NCShareFolderItem] = []
    @Published var selectedFolder: NCShareFolderItem?
    @Published var isRecentFolderSelected = false
    @Published var folderScrollTarget: String?
    @Published var folderChildren: [String: [NCShareFolderItem]] = [:]
    @Published var expandedFolderURLs: Set<String> = []
    @Published var loadingFolderURLs: Set<String> = []
    @Published var loadedFolderURLs: Set<String> = []
    @Published var folderLoadErrors: [String: String] = [:]
    var folderTasks: [String: Task<Void, Never>] = [:]
    var folderRequests: [String: URLSessionTask] = [:]
    var folderSelectionTask: Task<Void, Never>?
    // Invalidates asynchronous folder results when the account/browser is reset.
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
    // Local account/browser state is ready. Authentication and upload readiness
    // are separate: cached folders may be displayed before capabilities arrive.
    @Published var isAvailable = false
    @Published var isPreparingUpload = false
    @Published var uploadConfirmation: NCShareUploadConfirmation?
    // Keep the plan after SwiftUI clears the sheet binding, until onDismiss runs.
    var pendingUploadConfirmation: NCShareUploadConfirmation?
    var uploadChoice: NCShareUploadChoice?
    var uploadTask: Task<Void, Never>?
    var replacementETags: [String: String] = [:]
    var isClosing = false
    @Published var isPreparingInput = false
    @Published var inputErrorMessage = ""
    @Published var alertMessage = ""
    private var alertDismissAction: (() -> Void)?
    @Published var accountName = ""
    @Published var accounts: [NCShareAccountItem] = []
    @Published var accountAvatars: [String: UIImage] = [:]
    @Published var isLoadingAccounts = false
    @Published var isSwitchingAccount = false
    @Published var serverCapabilities: NKCapabilities.Capabilities?
    @Published var isLoadingCapabilities = false
    @Published var capabilitiesErrorMessage = ""
    var isAccountReady: Bool { serverCapabilities != nil && !isSwitchingAccount && !isOffline }

    var isUploadDestinationReady: Bool {
        guard let selectedFolder else { return false }
        return isAccountReady && alertMessage.isEmpty && !loadingFolderURLs.contains(selectedFolder.serverUrl) &&
            folderLoadErrors[selectedFolder.serverUrl] == nil
    }

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
    let inputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("NextcloudShare-" + UUID().uuidString, isDirectory: true)
    private var inputTask: Task<Void, Never>?
    private var hasStarted = false
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    let keyLayout = NCGlobal.shared.layoutViewShareExtension
    var autoUploadFileName = ""
    var autoUploadDirectory = ""
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

    /// Starts account setup and attachment import independently, once per request.
    /// Protected content remains hidden until passcode authentication succeeds.
    func start(context: NSExtensionContext?, presenter: UIViewController) {
        guard !hasStarted else { return }
        hasStarted = true
        let monitor = NWPathMonitor()
        connectionMonitor = monitor
        // A usable network path does not guarantee that the server is reachable.
        // Request failures are still reported separately by the networking calls.
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
            Task { @MainActor [weak self] in self?.accountsTask?.cancel() }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isClosing else { return }
                self.accountsTask?.cancel()
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
                return
            }
        }

        if let account = sessionStore.account?.account {
            isAuthenticated = !NCPreferences().presentPasscode
            changeAccount(account)
        }
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
                self.fileNames = output.fileNames
                self.isPreparingInput = false
                if !output.failures.isEmpty || output.fileNames.isEmpty {
                    let key = output.fileNames.isEmpty ? "_share_import_no_files_" : "_share_import_failed_"
                    self.inputErrorMessage = ([NSLocalizedString(key, comment: "")] + output.failures).joined(separator: "\n\n")
                }
            } catch is CancellationError {
                // The loader removes its own request directory on cancellation.
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.isPreparingInput = false
                self.inputErrorMessage = NSLocalizedString("_share_import_no_files_", comment: "") + "\n\n" + error.localizedDescription
            }
        }
    }

    func validateAccountAndRequestPasscode() {
        guard !isClosing else { return }
        guard !maintenanceMode else {
            return showAlert(description: "_version_mismatch_error_") { [weak self] in
                self?.cancel(with: .versionMismatch)
            }
        }
        guard validateAccount() else { return }
        requestPasscodeIfNeeded()
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

    func acknowledgeInputError() {
        inputErrorMessage = ""
        if fileNames.isEmpty { cancel(with: .noFiles) }
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

        if let account = sessionStore.account?.account,
           NCManageDatabase.shared.getTableAccount(account: account) != nil {
            return true
        }

        guard let activeAccount = NCManageDatabase.shared.getActiveTableAccount() else {
            return showNoAccountAlert()
        }

        changeAccount(activeAccount.account)
        return true
    }

    private func showNoAccountAlert() -> Bool {
        clearAccountView()
        if !isPresentingNoAccountAlert {
            isPresentingNoAccountAlert = true
            showAlert(description: "_no_active_account_") { [weak self] in
                self?.cancel(with: .noAccount)
            }
        }
        return false
    }

    func clearAccountView(preservingContent: Bool = false) {
        capabilitiesTask?.cancel()
        capabilitiesRequest?.cancel()
        serverCapabilities = nil
        isLoadingCapabilities = false
        capabilitiesErrorMessage = ""
        resetFolderBrowser(preservingContent: preservingContent)
        if !preservingContent {
            isAvailable = false
            accountName = ""
        }
    }

    /// Completes or cancels the extension request once and stops its pending work.
    /// An in-flight importer cleans up its directory after observing cancellation.
    func cancel(with error: NCShareRequestError? = nil) {
        guard !isClosing else { return }
        isClosing = true
        alertDismissAction = nil
        connectionMonitor?.cancel()
        for request in thumbnailRequests.values { QLThumbnailGenerator.shared.cancel(request) }
        thumbnailRequests.removeAll()
        fileThumbnails.removeAll()
        uploadConfirmation = nil
        pendingUploadConfirmation = nil
        uploadChoice = nil
        inputTask?.cancel()
        uploadTask?.cancel()
        accountsTask?.cancel()
        accountChangeTask?.cancel()
        capabilitiesTask?.cancel()
        capabilitiesRequest?.cancel()
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

    func showAlert(description: String, onDismiss: (() -> Void)? = nil) {
        alertMessage = NSLocalizedString(description.replacingOccurrences(of: "\t", with: "\n"), comment: "")
        alertDismissAction = onDismiss
    }

    func acknowledgeAlert() {
        let action = alertDismissAction
        alertMessage = ""
        alertDismissAction = nil
        action?()
    }

    func createFolder() {
        let session = sessionStore.getSession()
        guard canUseFolderBrowser, isUploadDestinationReady, !isPreparingInput, inputErrorMessage.isEmpty,
              let folder = selectedFolder else { return }
        guard let capabilities = serverCapabilities,
              let presenter, presenter.viewIfLoaded?.window != nil,
              presenter.presentedViewController == nil,
              !presenter.isBeingDismissed else { return }
        let browserID = folderBrowserID
        let alert = UIAlertController.createFolderWith(
            serverUrl: folder.serverUrl, session: session,
            onCreated: { [weak self] name in
                guard let self, !self.isClosing, self.folderBrowserID == browserID else { return }
                self.isLoading = true
                self.folderSelectionTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    defer { if self.folderBrowserID == browserID { self.isLoading = false } }
                    // Recents can point into a collapsed, not-yet-loaded branch.
                    // Load and expand its ancestors before scrolling to the new row.
                    guard var branch = self.folders.first else { return }
                    while true {
                        guard !Task.isCancelled, !self.isClosing, self.folderBrowserID == browserID else { return }
                        self.expandedFolderURLs.insert(branch.serverUrl)
                        if let task = self.folderTasks[branch.serverUrl] { await task.value }
                        guard !Task.isCancelled, !self.isClosing, self.folderBrowserID == browserID else { return }
                        self.requestFolderChildren(branch, refresh: branch.serverUrl == folder.serverUrl)
                        if let task = self.folderTasks[branch.serverUrl] { await task.value }
                        guard !Task.isCancelled, !self.isClosing, self.folderBrowserID == browserID,
                              self.folderLoadErrors[branch.serverUrl] == nil else { return }
                        if branch.serverUrl == folder.serverUrl { break }
                        guard let child = self.folderChildren[branch.serverUrl]?.first(where: {
                            folder.serverUrl == $0.serverUrl || folder.serverUrl.hasPrefix($0.serverUrl + "/")
                        }) else { return }
                        branch = child
                    }
                    guard let created = self.folderChildren[folder.serverUrl]?.first(where: { $0.name == name }),
                          self.isAuthenticated else { return }
                    self.selectedFolder = created
                    self.serverUrl = created.serverUrl
                    self.isRecentFolderSelected = false
                    self.expandedFolderURLs.insert(created.serverUrl)
                    self.requestFolderChildren(created)
                    self.folderScrollTarget = created.serverUrl
                }
            }, capabilities: capabilities, completion: { [weak self] error in
                guard let self, !self.isClosing, self.folderBrowserID == browserID else { return }
                if error != .success { self.showAlert(description: error.errorDescription) }
            })
        presenter.present(alert, animated: true)
    }

    func showRenameFileDialog(named fileName: String) {
        guard !isClosing, isAuthenticated, !isPreparingUpload, fileNames.contains(fileName),
              let capabilities = serverCapabilities else { return }
        let account = sessionStore.getSession().account
        let alert = UIAlertController.renameFile(fileName: fileName, capabilities: capabilities, account: account) { [weak self] newFileName in
            self?.renameFile(oldName: fileName, newName: newFileName)
        }

        presenter?.present(alert, animated: true)
    }

    private func renameFile(oldName: String, newName: String) {
        guard !isClosing, isAuthenticated, !isPreparingUpload else { return }
        guard newName != oldName else { return }
        guard !newName.isEmpty, let fileIx = self.fileNames.firstIndex(of: oldName),
              !self.fileNames.contains(newName),
              newName == (newName as NSString).lastPathComponent,
              newName != ".", newName != "..",
              utilityFileSystem.moveFile(atPath: inputFileURL(named: oldName).path, toPath: inputFileURL(named: newName).path) else {
            return showAlert(description: "'\(oldName)' -> '\(newName)'")
        }

        discardThumbnail(named: oldName)
        fileNames[fileIx] = newName

    }

    func removeFile(named fileName: String) {
        guard !isClosing, isAuthenticated, !isPreparingUpload else { return }
        guard let index = self.fileNames.firstIndex(of: fileName) else {
            return showAlert(description: fileName)
        }
        discardThumbnail(named: fileName)
        try? FileManager.default.removeItem(at: inputFileURL(named: fileName))
        self.fileNames.remove(at: index)
        if self.fileNames.isEmpty {
            cancel(with: NCShareRequestError.noFiles)
        }
    }

}

extension NCShareViewModel {
    /// Require authentication once per foreground session without reopening after dismissal.
    private func requestPasscodeIfNeeded() {
        if !NCPreferences().presentPasscode || isPasscodeAuthenticated {
            isAuthenticated = true
            return
        }
        isAuthenticated = false
        guard !isPresentingPasscode,
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
                    if self.accounts.isEmpty { self.loadAccounts() }
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
    var isFavorite = false
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
        let documents = NCShareFolderItem(ocId: "documents", name: "Documents", serverUrl: home + "/Documents", path: "/Documents", image: UIImage(systemName: "folder.fill"), isEncrypted: false, isFavorite: true)
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
