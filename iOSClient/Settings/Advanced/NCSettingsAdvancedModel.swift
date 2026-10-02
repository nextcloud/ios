// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-FileCopyrightText: 2026 Rasmus Wøldike
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import Combine
import SwiftUI

class NCSettingsAdvancedModel: ObservableObject, ViewOnAppearHandling {
    // Keychain access
    var keychain = NCPreferences()
    // State variable for indicating if the user is in Admin group
    @Published var isAdminGroup: Bool = false
    // State variable for indicating the most compatible format.
    @Published var mostCompatible: Bool = false
    // State variable for enabling live photo uploads.
    @Published var livePhoto: Bool = false
    // State variable for indicating whether to remove photos from the camera roll after upload.
    @Published var removeFromCameraRoll: Bool = false
    // State variable for saving custom camera media to camera roll.
    @Published var saveCameraMediaToCameraRoll: Bool = false
    // State variable for app integration.
    @Published var appIntegration: Bool = false
    // State variable for enabling the crash reporter.
    @Published var crashReporter: Bool = false
    // State variable for indicating whether the log file has been cleared.
    @Published var logFileCleared: Bool = false
    // Log files shared by the app and its extensions.
    @Published private(set) var logFiles: [URL] = []
    @Published private(set) var isPreparingLogPreview = false
    private var logPreviewDirectory: URL?
    // Properties for log level and cache deletion
    // State variable for storing the selected log level.
    @Published var selectedLogLevel: NKLogLevel = .normal
    // State variable for storing the selected cache deletion interval.
    @Published var selectedInterval: CacheDeletionInterval = .never
    // Root View Controller
    @Published var controller: NCMainTabBarController?
    // Get session
    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    /// Initializes the view model with default values.
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        let groups = NCManageDatabase.shared.getAccountGroups(account: session.account)
        isAdminGroup = groups.contains(NCGlobal.shared.groupAdmin)
#if DEBUG
        isAdminGroup = true
#endif
        mostCompatible = keychain.formatCompatibility
        livePhoto = keychain.livePhoto
        removeFromCameraRoll = keychain.removePhotoCameraRoll
        saveCameraMediaToCameraRoll = keychain.saveCameraMediaToCameraRoll
        appIntegration = keychain.disableFilesApp
        crashReporter = keychain.disableCrashservice
        selectedLogLevel = keychain.log
        selectedInterval = CacheDeletionInterval(rawValue: keychain.cleanUpDay) ?? .never
    }

    // MARK: - All functions

    /// Updates the value of `mostCompatible` in the keychain.
    func updateMostCompatible() {
        keychain.formatCompatibility = mostCompatible
    }

    /// Updates the value of `livePhoto` in the keychain.
    func updateLivePhoto() {
        keychain.livePhoto = livePhoto
    }

    /// Updates the value of `removeFromCameraRoll` in the keychain.
    func updateRemoveFromCameraRoll() {
        keychain.removePhotoCameraRoll = removeFromCameraRoll
    }

    /// Updates the value of `saveCameraMediaToCameraRoll` in the keychain.
    func updateSaveCameraMediaToCameraRoll() {
        keychain.saveCameraMediaToCameraRoll = saveCameraMediaToCameraRoll
    }

    /// Updates the value of `appIntegration` in the keychain.
    func updateAppIntegration() {
        NSFileProviderManager.removeAllDomains { _ in }
        keychain.disableFilesApp = appIntegration
    }

    /// Updates the value of `crashReporter` in the keychain.
    func updateCrashReporter() {
        keychain.disableCrashservice = crashReporter
    }

    /// Updates the value of `selectedLogLevel` in the keychain and sets it for NextcloudKit.
    func updateSelectedLogLevel() {
        keychain.log = selectedLogLevel
        NKLogFileManager.shared.logLevel = selectedLogLevel
    }

    /// Remove directory LOG
    @MainActor
    func clearLogFile() async {
        await Task.detached(priority: .utility) {
            NextcloudKit.flushLogger()
            let logsFolder = NCPreferences.sharedLogDirectory
                ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Logs", isDirectory: true)
            try? FileManager.default.removeItem(at: logsFolder)
            NKLogFileManager.createLogsFolder()
        }.value
        logFiles = []
    }

    /// Updates the value of `selectedInterval` in the keychain.
    func updateSelectedInterval() {
        keychain.cleanUpDay = selectedInterval.rawValue
    }

    /// Clears cache
    func clearCache() {
        Task { @MainActor in
            NCActivityIndicator.shared.startActivity(backgroundView: self.controller?.view, style: .large, blurEffect: true)

            // Cancel all networking tasks
            NCNetworking.shared.cancelAllTask()

            try? await Task.sleep(for: .seconds(1))

            NCNetworking.shared.removeServerErrorAccount(self.session.account)
            NCManageDatabase.shared.clearDBCache()
            do {
                try await NCLocalDatabase.shared.clearDBCache()
            } catch {
                nkLog(error: "Unable to clear the local GRDB cache: \(error)")
            }

            let ufs = NCUtilityFileSystem()
            ufs.removeGroupDirectoryProviderStorage()
            ufs.removeGroupLibraryDirectory()
            ufs.removeDocumentsDirectory()
            ufs.removeTemporaryDirectory()
            ufs.createDirectoryStandard()

            await NCService().startRequestServicesServer(account: self.session.account, controller: self.controller)

            NCActivityIndicator.shared.stop()
        }
    }

    /// Removes all accounts & exits the Nextcloud application if specified.
    ///
    /// - Parameter
    /// exit: Boolean indicating whether to reset the application.
    func resetNextCloud() {
        let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
        appDelegate.resetApplication()
    }

    /// Exits the Nextcloud application if specified.
    ///
    /// - Parameter
    /// exit: Boolean indicating whether to exit the application.
    func exitNextCloud(ext: Bool) {
        if ext {
            exit(0)
        } else { }
    }

    /// Loads the active and rotated log files from the shared App Group directory.
    @MainActor
    func loadLogFiles() async {
        logFiles = await Task.detached(priority: .utility) {
            NextcloudKit.flushLogger()
            guard let logsFolder = NCPreferences.sharedLogDirectory,
                  let files = try? FileManager.default.contentsOfDirectory(
                    at: logsFolder,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                  ) else { return [URL]() }
            return files
                .filter { $0.lastPathComponent == "log.txt" || ($0.lastPathComponent.hasPrefix("log-") && $0.pathExtension == "txt") }
                .sorted { lhs, rhs in
                    let lhsDate = try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    let rhsDate = try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    return (lhsDate ?? .distantPast) > (rhsDate ?? .distantPast)
                }
        }.value
    }

    /// Deletes a listed log file, coordinating with writes from the app and extensions.
    @MainActor
    func deleteLogFile(at url: URL) async throws {
        guard logFiles.contains(url) else { return }
        try await Task.detached(priority: .utility) {
            NextcloudKit.flushLogger()
            var coordinationError: NSError?
            var deletionError: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { coordinatedURL in
                do { try FileManager.default.removeItem(at: coordinatedURL) } catch { deletionError = error }
            }
            if let coordinationError { throw coordinationError }
            if let deletionError { throw deletionError }
        }.value
        logFiles.removeAll { $0 == url }
    }

    /// Returns the localized modification date and size shown below a log file name.
    func logFileDetails(for url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return ""
        }

        var details: [String] = []
        if let date = values.contentModificationDate {
            details.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        if let fileSize = values.fileSize {
            details.append(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
        }
        return details.joined(separator: " · ")
    }

    /// Previews an immutable copy so Quick Look never coordinates the file used by the logger.
    @MainActor
    func viewLogFile(at url: URL) async throws {
        guard !isPreparingLogPreview, let controller, controller.presentedViewController == nil else { return }
        isPreparingLogPreview = true
        defer { isPreparingLogPreview = false }
        let previousDirectory = logPreviewDirectory
        let previewURL = try await Task.detached(priority: .utility) {
            NextcloudKit.flushLogger()
            let fileManager = FileManager.default
            let directory = fileManager.temporaryDirectory.appendingPathComponent("LogPreview-" + UUID().uuidString, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(url.lastPathComponent)
            do {
                var coordinationError: NSError?
                var copyError: Error?
                NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { source in
                    do { try fileManager.copyItem(at: source, to: destination) } catch { copyError = error }
                }
                if let coordinationError { throw coordinationError }
                if let copyError { throw copyError }
                if let previousDirectory { try? fileManager.removeItem(at: previousDirectory) }
                return destination
            } catch {
                try? fileManager.removeItem(at: directory)
                throw error
            }
        }.value
        logPreviewDirectory = previewURL.deletingLastPathComponent()
        guard !Task.isCancelled,
              controller.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive,
              controller.presentedViewController == nil else { return }
        let viewerQuickLook = NCViewerQuickLook(with: previewURL, isEditingEnabled: false, metadata: nil)
        controller.present(viewerQuickLook, animated: true)
    }
}

/// An enum that represents the intervals for cache deletion
enum CacheDeletionInterval: Int, CaseIterable, Identifiable {
    case never = 0
    case oneYear = 365
    case sixMonths = 180
    case threeMonths = 90
    case oneMonth = 30
    case oneWeek = 7
    var id: Int { self.rawValue }
}

extension CacheDeletionInterval {
    var displayText: String {
        switch self {
        case .never:
            return NSLocalizedString("_never_", comment: "")
        case .oneYear:
            return NSLocalizedString("_1_year_", comment: "")
        case .sixMonths:
            return NSLocalizedString("_6_months_", comment: "")
        case .threeMonths:
            return NSLocalizedString("_3_months_", comment: "")
        case .oneMonth:
            return NSLocalizedString("_1_month_", comment: "")
        case .oneWeek:
            return NSLocalizedString("_1_week_", comment: "")
        }
    }
}
