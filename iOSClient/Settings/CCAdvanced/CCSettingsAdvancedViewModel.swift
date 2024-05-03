//
//  CCSettingsAdvancedViewModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 08/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Aditya Tyagi <adityagi02@yahoo.com>
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

import Foundation
import UIKit
import NextcloudKit
import Combine
import SwiftUI

class CCSettingsAdvancedModel: ObservableObject, ViewOnAppearHandling, AccountUpdateHandling {

    /// Keychain access
    var keychain = NCKeychain()
    /// Callback to notify the view to present the UIViewController
    var goToCapabilitiesView: ((UIViewController) -> Void)?
    // MARK: All published properties for the toggles
    /// State variable for indicating whether hidden files are shown.
    @Published var showHiddenFiles: Bool = false
    /// State variable for indicating the most compatible format.
    @Published var mostCompatible: Bool = false
    /// State variable for enabling live photo uploads.
    @Published var livePhoto: Bool = false
    /// State variable for indicating whether to remove photos from the camera roll after upload.
    @Published var removeFromCameraRoll: Bool = false
    /// State variable for app integration.
    @Published var appIntegration: Bool = false
    /// State variable for enabling the crash reporter.
    @Published var crashReporter: Bool = false
    /// State variable for indicating whether the log file has been cleared.
    @Published var logFileCleared: Bool = false
    // Properties for log level and cache deletion
    /// State variable for storing the selected log level.
    @Published var selectedLogLevel: LogLevel = .standard
    /// State variable for storing the selected cache deletion interval.
    @Published var selectedInterval: CacheDeletionInterval = .never
    /// State variable for storing the footer title, usually used for cache deletion.
    @Published var footerTitle: String = NSLocalizedString("_clear_cache_footer_", comment: "")
    /// Initializes the view model with default values.
    init() {
        onViewAppear()
    }
    /// Updates the account information.
    func updateAccount() {
        self.keychain = NCKeychain()
    }
    /// Triggered when the view appears.
    func onViewAppear() {
        updateAccount()
        // Initialize all properties with values from the keychain or defaults
        showHiddenFiles = keychain.showHiddenFiles
        mostCompatible = keychain.formatCompatibility
        livePhoto = keychain.livePhoto
        removeFromCameraRoll = keychain.removePhotoCameraRoll
        appIntegration = !keychain.disableFilesApp
        crashReporter = !keychain.disableCrashservice
        // Default log level and cache deletion interval
        selectedLogLevel = LogLevel(rawValue: keychain.logLevel) ?? .standard
        selectedInterval = CacheDeletionInterval(rawValue: keychain.cleanUpDay) ?? .never
        calculateSize()
    }
    // MARK: All protocol functions to update keychain values when toggles change
    /// Updates the value of `showHiddenFiles` in the keychain.
    func updateShowHiddenFiles() {
        keychain.showHiddenFiles = showHiddenFiles
    }
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
        keychain.disableFilesApp = !appIntegration
    }
    /// Updates the value of `crashReporter` in the keychain.
    func updateCrashReporter() {
        keychain.disableCrashservice = !crashReporter
    }
    /// Updates the value of `selectedLogLevel` in the keychain and sets it for NextcloudKit.
    func updateSelectedLogLevel() {
        keychain.logLevel = selectedLogLevel.rawValue
        NextcloudKit.shared.nkCommonInstance.levelLog = selectedLogLevel.rawValue
    }
    /// Updates the value of `selectedInterval` in the keychain.
    func updateSelectedInterval() {
        keychain.cleanUpDay = selectedInterval.rawValue
    }
    /// Clears cache associated with the specified account.
    ///
    /// - Parameter
    /// acount: The account identifier.
    func clearCache(_ account: String) {
        // Cancel all networking tasks
        NCNetworking.shared.cancelAllTask()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let ufs = NCUtilityFileSystem()
            // Clear URL cache
            URLCache.shared.memoryCapacity = 0
            URLCache.shared.diskCapacity = 0
            // Clear database and remove directories
            NCManageDatabase.shared.clearDatabase(account: account, removeAccount: false)
            ufs.removeGroupDirectoryProviderStorage()
            ufs.removeGroupLibraryDirectory()
            ufs.removeDocumentsDirectory()
            ufs.removeTemporaryDirectory()
            ufs.createDirectoryStandard()
            NCImageCache.shared.createMediaCache(account: account, withCacheSize: true)
            // Stop activity indicator and recalculate cache size
            NCActivityIndicator.shared.stop()
            self.calculateSize()
        }
    }

    /// Initiates cache clearance after starting the activity indicator.
    func clearAllCacheRequest() {
        NCActivityIndicator.shared.startActivity(style: .large, blurEffect: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.clearCache(AppDelegate().account)
        }
    }

    /// Asynchronously calculates the size of cache directory and updates the footer title.
    func calculateSize() {
            let ufs = NCUtilityFileSystem()
            let directory = ufs.directoryProviderStorage
            let totalSize = ufs.getDirectorySize(directory: directory)
            self.footerTitle = "\(NSLocalizedString("_clear_cache_footer_", comment: "")). (\(NSLocalizedString("_used_space_", comment: "")) \(ufs.transformedSize(totalSize)))"
    }
    /// Exits the Nextcloud application if specified.
    ///
    /// - Parameter
    /// exit: Boolean indicating whether to exit the application.
    func exitNextCloud(exit: Bool) {
        if exit {
            AppDelegate().resetApplication()
        } else { }
    }
    /// Presents the log file viewer.
    func viewLogFile() {
        // Instantiate NCViewerQuickLook with the log file URL, editing disabled, and no metadata
        let viewerQuickLook = NCViewerQuickLook(with: NSURL(fileURLWithPath: NextcloudKit.shared.nkCommonInstance.filenamePathLog) as URL, isEditingEnabled: false, metadata: nil)
        // Present the NCViewerQuickLook view controller
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(viewerQuickLook, animated: true, completion: nil)
        }
    }
    /// Clears the log file.
    func clearLogFile() {
        // Clear the log file using NextcloudKit
        NextcloudKit.shared.nkCommonInstance.clearFileLog()
        // Fetch the log level from the keychain
        let logLevel = NCKeychain().logLevel
        // Check if the app is running in a simulator or TestFlight environment
        let isSimulatorOrTestFlight = NCUtility().isSimulatorOrTestFlight()
        // Get the app's version and copyright information
        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility().getVersionApp(withBuild: true))
        // Construct the log message
        let logMessage = "[INFO] Clear log with level \(logLevel) \(versionNextcloudiOS)" + (isSimulatorOrTestFlight ? " (Simulator / TestFlight)" : "")
        // Write the log entry about the log clearance
        NextcloudKit.shared.nkCommonInstance.writeLog(logMessage)
        // Set the alert state to show that log file has been cleared
        self.logFileCleared = true
    }
    func triggerGoToCapabilitiesView() {
        // Create an instance of NCHostingCapabilitiesView
        let capabilitiesView = NCHostingCapabilitiesView()
        // Call the callback to present the UIViewController
        goToCapabilitiesView?(capabilitiesView.makeShipDetailsUI())
    }
}

/// An enum that represents the level of the log
enum LogLevel: Int, CaseIterable, Identifiable, Equatable {
    /// Represents that logging is disabled
    case disabled = 0
    /// Represents standard logging level
    case standard = 1
    /// Represents maximum logging level
    case maximum = 2
    var id: Int { self.rawValue }
}

extension LogLevel {
    var displayText: String {
        switch self {
        case .disabled:
            return NSLocalizedString("_disabled_", comment: "")
        case .standard:
            return NSLocalizedString("_standard_", comment: "")
        case .maximum:
            return NSLocalizedString("_maximum_", comment: "")
        }
    }
}

/// An enum that represents the intervals for cache deletion
enum CacheDeletionInterval: Int, CaseIterable, Identifiable {
    case never = 0
    case oneYear = 1
    case sixMonths = 2
    case threeMonths = 3
    case oneMonth = 4
    case oneWeek = 5
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
