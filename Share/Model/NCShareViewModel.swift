// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
import LucidBanner

@MainActor
final class NCShareViewModel: NSObject, ObservableObject {
    @Published var folders: [NCShareFolderItem] = []
    @Published var fileNames: [String] = []
    @Published var isLoading = false
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
    @Published var isShowingAccounts = false
    @Published var isLoadingAccounts = false
    @Published var isSwitchingAccount = false
    var pendingAccountSelection: String?
    var accountPickerTask: Task<Void, Never>?
    var accountChangeTask: Task<Void, Never>?
    var accountChangeID = UUID()
    @Published var canGoBack = false
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
            Task { @MainActor [weak self] in self?.dismissAccountPicker() }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isClosing else { return }
                self.dismissAccountPicker()
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

    func inputFileURL(named fileName: String) -> URL {
        inputDirectory.appendingPathComponent(fileName)
    }

    func showInputErrorIfNeeded() {
        // Do not present import errors over the passcode screen.
        if isAuthenticated && !isShowingAccounts && !isLoadingAccounts && !inputErrorMessage.isEmpty {
            isShowingInputError = true
        }
    }

    func acknowledgeInputError() {
        inputErrorMessage = ""
        if filesName.isEmpty { cancel(with: .noFiles) }
    }

    isolated deinit {
        inputTask?.cancel()
        uploadTask?.cancel()
        accountPickerTask?.cancel()
        accountChangeTask?.cancel()
        dataSourceTask?.cancel()
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
        dataSourceTask?.cancel()
        dataSourceTask = nil
        metadataFolder = nil
        isAvailable = false
        folders = []
        accountName = ""
        canGoBack = false
        navigationTitle = NCBrandOptions.shared.brand
    }

    func showAccountView() {
        isAvailable = true
    }

    func cancel(with error: NCShareRequestError? = nil) {
        isClosing = true
        dismissAccountPicker()
        uploadConfirmation = nil
        pendingUploadConfirmation = nil
        uploadChoice = nil
        inputTask?.cancel()
        uploadTask?.cancel()
        accountPickerTask?.cancel()
        accountChangeTask?.cancel()
        dataSourceTask?.cancel()
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
        accountName = account.alias.isEmpty ? account.displayName : account.alias
        canGoBack = serverUrl != utilityFileSystem.getHomeServer(session: sessionStore.getSession())
    }

    func goBack() {
        guard canGoBack, !isLoading, !isPreparingUpload, !isSwitchingAccount else { return }
        serverUrl = (serverUrl as NSString).deletingLastPathComponent
        let home = utilityFileSystem.getHomeServer(session: sessionStore.getSession())
        setNavigationBar(navigationTitle: serverUrl == home ? NCBrandOptions.shared.brand : (serverUrl as NSString).lastPathComponent)
        Task {
            await reloadData()
            await loadFolder()
        }
    }

    func setCommandView() {
        if filesName.isEmpty { cancel(with: .noFiles) }
    }

    func createFolder() {
        let session = sessionStore.getSession()
        guard let capabilities = NCNetworking.shared.capabilities[session.account] else { return }
        let alert = UIAlertController.createFolderWith(serverUrl: serverUrl, session: session, capabilities: capabilities) { [weak self] error in
            guard let self else { return }
            if error == .success {
                Task { await self.loadFolder() }
            } else {
                self.showAlert(title: "_error_createsubfolders_upload_", description: error.errorDescription)
            }
        }
        presenter?.present(alert, animated: true)
    }

    func showRenameFileDialog(named fileName: String, account: String) {
        guard let capabilities = NCNetworking.shared.capabilities[account] else {
            return
        }
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

        filesName[fileIx] = newName

    }

    func removeFile(named fileName: String) {
        guard let index = self.filesName.firstIndex(of: fileName) else {
            return showAlert(title: "_file_not_found_", description: fileName)
        }
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
        guard isAuthenticated, !isPreparingInput, inputErrorMessage.isEmpty, !isPreparingUpload,
              !isSwitchingAccount, !isLoadingAccounts, !isShowingAccounts, !isLoading, !fileNames.isEmpty else { return }
        isPreparingUpload = true
        actionUpload()
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
    let id: String
    let name: String
    let image: UIImage?
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
        model.isAuthenticated = true
        model.accountName = "Personal"
        model.folders = [
            NCShareFolderItem(id: "documents", name: "Documents", image: UIImage(systemName: "folder.fill")),
            NCShareFolderItem(id: "photos", name: "Photos", image: UIImage(systemName: "folder.fill")),
            NCShareFolderItem(id: "shared", name: "Shared with the team", image: UIImage(systemName: "person.2.fill"))
        ]
        model.fileNames = ["Report.pdf", "Photo.jpg", "Notes.txt"]
        model.accounts = [
            NCShareAccountItem(id: "personal", name: "Personal", user: "marino", serverUrl: "https://cloud.example.com", isSelected: true),
            NCShareAccountItem(id: "work", name: "Work", user: "marino.work", serverUrl: "https://team.example.com", isSelected: false)
        ]
        return model
    }
}
#endif
