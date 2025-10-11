// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
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
    // State variable for app integration.
    @Published var appIntegration: Bool = false
    // State variable for enabling the crash reporter.
    @Published var crashReporter: Bool = false
    // State variable for indicating whether the log file has been cleared.
    @Published var logFileCleared: Bool = false
    // Properties for log level and cache deletion
    // State variable for storing the selected log level.
    @Published var selectedLogLevel: NKLogLevel = .normal
    // State variable for storing the selected cache deletion interval.
    @Published var selectedInterval: CacheDeletionInterval = .never
    // State variable for storing the footer title, usually used for cache deletion.
    @Published var footerTitle: String = ""
    // Root View Controller
    @Published var controller: NCMainTabBarController?
    // Get session
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
        appIntegration = keychain.disableFilesApp
        crashReporter = keychain.disableCrashservice
        selectedLogLevel = keychain.log
        selectedInterval = CacheDeletionInterval(rawValue: keychain.cleanUpDay) ?? .never

        Task {
            await self.calculateSize()
        }
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

            try? await Task.sleep(nanoseconds: 1_000_000_000)

            NCNetworking.shared.removeServerErrorAccount(self.session.account)
            NCManageDatabase.shared.clearDBCache()

            let ufs = NCUtilityFileSystem()
            ufs.removeGroupDirectoryProviderStorage()
            ufs.removeGroupLibraryDirectory()
            ufs.removeDocumentsDirectory()
            ufs.removeTemporaryDirectory()
            ufs.createDirectoryStandard()

            await NCService().startRequestServicesServer(account: self.session.account, controller: self.controller)

            await self.calculateSize()

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterClearCache)

            NCActivityIndicator.shared.stop()
        }
    }

    /// Asynchronously calculates the size of cache directory and updates the footer title.
    @MainActor
    func calculateSize() async {
        // Run the heavy calculation off the main thread
        let totalSize = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let size = NCUtilityFileSystem().getAppSize()
                continuation.resume(returning: size)
            }
        }

        self.footerTitle = "\(NSLocalizedString("_clear_cache_footer_", comment: "")). (\(NSLocalizedString("_used_space_", comment: "")) \(NCUtilityFileSystem().transformedSize(totalSize)))"
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

    /// Presents the log file viewer.
    func viewLogFile() {
        // Path of the current (active) log file
        let currentLogURL = NKLogFileManager.shared.currentLogFileURL()

        // Create NCViewerQuickLook with the current log file
        let viewerQuickLook = NCViewerQuickLook(
            with: currentLogURL,
            isEditingEnabled: false,
            metadata: nil
        )

        controller?.present(viewerQuickLook, animated: true, completion: nil)
    }

    /// Presents the log file viewer.
    func viewMetadataStore() {
        if let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) {
            let backupDirectory = groupDirectory.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud)
            let url = backupDirectory.appendingPathComponent(fileMetadataStore)

            // Create NCViewerQuickLook with the metadata store file
            let viewerQuickLook = NCViewerQuickLook(
                with: url,
                isEditingEnabled: false,
                metadata: nil
            )

            controller?.present(viewerQuickLook, animated: true, completion: nil)
        }
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
