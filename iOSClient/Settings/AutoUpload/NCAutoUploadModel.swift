// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Photos
import NextcloudKit
import SwiftUI

enum AutoUploadTimespan: String, CaseIterable, Identifiable {
    case allPhotos = "all"
    case fromDate = "fromDate"
    var id: Self { self }
}

/// A model that allows the user to configure the `auto upload settings for Nextcloud`
class NCAutoUploadModel: ObservableObject, ViewOnAppearHandling {
    /// Whether auto upload for photos is enabled or not
    @Published var autoUploadImage: Bool = false
    /// Whether auto upload for photos is restricted to Wi-Fi only or not
    @Published var autoUploadWWAnPhoto: Bool = false
    /// Whether auto upload for videos is enabled or not
    @Published var autoUploadVideo: Bool = false
    /// Whether auto upload for videos is enabled or not
    @Published var autoUploadWWAnVideo: Bool = false
    /// Whether auto upload is enabled or not
    @Published var autoUploadStart: Bool = false
    /// Prevents a restart while start/stop cleanup is being reconciled.
    @Published var isChangingAutoUpload = false
    /// Whether auto upload creates subfolders based on date or not
    @Published var autoUploadCreateSubfolder: Bool = false
    /// The granularity of the subfolders, either daily, monthly, or yearly
    @Published var autoUploadSubfolderGranularity: Granularity = .monthly
    /// The incremental restart date, editable while Auto Upload is stopped.
    @Published var autoUploadSinceDate: Date?
    @Published var autoUploadForceReupload = false
    var autoUploadTimespan: AutoUploadTimespan { autoUploadSinceDate == nil ? .allPhotos : .fromDate }
    /// Whether Photos permissions have been granted or not.
    @Published var photosPermissionsGranted = true
    /// Whether `Always` location authorization has been granted, enabling background location-based auto upload.
    @Published var locationAutoUploadPermissionGranted: Bool = false
    /// Whether the experimental PhotoKit background upload extension is enabled.
    @Published var backgroundUploadExtensionEnabled: Bool = false

    /// Legacy controls remain available when PhotoKit is disabled or unsupported for this account.
    var usesPhotoKitAutoUpload: Bool {
        guard #available(iOS 27, *),
              NCPreferences.canConfigureBackgroundUploadExtension,
              backgroundUploadExtensionEnabled,
              PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized,
              let capabilities = NCNetworking.shared.capabilities[session.account] else { return false }
        return NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v35)
    }

    /// Whether the error alert should be shown in the view.
    @Published var showErrorAlert: Bool = false
    /// The currently displayed section name.
    @Published var sectionName = ""
    /// Whether the user is authorized.
    @Published var isAuthorized: Bool = false
    /// Error text shown to the user.
    @Published var error: String = ""
    /// Shared Nextcloud database instance.
    let database = NCManageDatabase.shared

    /// Root view controller used to present UI from this model.
    var controller: NCMainTabBarController?
    /// Server URL used to change the auto-upload directory.
    var serverUrl: String = ""
    /// The current account session.
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    /// The active window scene, used for presenting banners.
    var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?) {
        self.controller = controller
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        self.checkPermission()
        if let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) {
            autoUploadImage = tableAccount.autoUploadImage
            autoUploadWWAnPhoto = tableAccount.autoUploadWWAnPhoto
            autoUploadVideo = tableAccount.autoUploadVideo
            autoUploadWWAnVideo = tableAccount.autoUploadWWAnVideo
            autoUploadStart = tableAccount.autoUploadStart
            autoUploadCreateSubfolder = tableAccount.autoUploadCreateSubfolder
            autoUploadSubfolderGranularity = Granularity(rawValue: tableAccount.autoUploadSubfolderGranularity) ?? .monthly
            autoUploadSinceDate = tableAccount.autoUploadSinceDate
            autoUploadForceReupload = tableAccount.autoUploadForceReupload
        }

        serverUrl = NCUtilityFileSystem().getHomeServer(session: session)
        backgroundUploadExtensionEnabled = NCPreferences().backgroundUploadExtensionEnabled

        requestAuthorization()

        if !autoUploadImage && !autoUploadVideo { autoUploadImage = true }
    }

    // MARK: - All functions

    /// Requests Photos library authorization and warns the user if background app refresh is disabled.
    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async { [self] in
                let value = (status == .authorized)
                photosPermissionsGranted = value

                if value, UIApplication.shared.backgroundRefreshStatus != .available {
                    Task {
                        await showInfoBanner(windowScene: self.windowScene,
                                             text: "_access_background_app_refresh_denied_")
                    }
                }
            }
        }
    }

    /// Updates the auto-upload image setting.
    func handleAutoUploadImageChange(newValue: Bool) {
        Task {
            await database.updateAccountPropertyAsync(\.autoUploadImage, value: newValue, account: session.account)
        }
    }

    /// Updates the auto-upload image over WWAN setting.
    func handleAutoUploadWWAnPhotoChange(newValue: Bool) {
        Task {
            await database.updateAccountPropertyAsync(\.autoUploadWWAnPhoto, value: newValue, account: session.account)
        }
    }

    /// Updates the auto-upload video setting.
    func handleAutoUploadVideoChange(newValue: Bool) {
        Task {
            await database.updateAccountPropertyAsync(\.autoUploadVideo, value: newValue, account: session.account)
        }
    }

    /// Updates the auto-upload video over WWAN setting.
    func handleAutoUploadWWAnVideoChange(newValue: Bool) {
        Task {
            await database.updateAccountPropertyAsync(\.autoUploadWWAnVideo, value: newValue, account: session.account)
        }
    }

    /// Starts from the whole library or the current incremental restart date.
    @MainActor
    func handleAutoUploadTimespan(_ timespan: AutoUploadTimespan) {
        handleAutoUploadSinceDate(timespan == .allPhotos ? nil : autoUploadSinceDate ?? Date.now)
    }

    /// Saves a new incremental restart date only while Auto Upload is stopped.
    @MainActor
    func handleAutoUploadSinceDate(_ date: Date?) {
        guard !isChangingAutoUpload, !autoUploadStart else { return }
        isChangingAutoUpload = true
        let accountIdentifier = session.account
        autoUploadSinceDate = date
        Task {
            defer { isChangingAutoUpload = false }
            await database.setAutoUploadSinceDateAsync(date, account: accountIdentifier)
        }
    }

    @MainActor
    func handleAutoUploadForceReupload(_ enabled: Bool) {
        guard !isChangingAutoUpload, !autoUploadStart else { return }
        isChangingAutoUpload = true
        let accountIdentifier = session.account
        autoUploadForceReupload = enabled
        Task {
            defer { isChangingAutoUpload = false }
            await database.setAutoUploadForceReuploadAsync(enabled, account: accountIdentifier)
        }
    }

    /// Stores the experimental extension opt-in and applies the new PhotoKit state immediately.
    /// Enabling still requires Auto Upload, full Photos access, and a supported server.
    func handleBackgroundUploadExtensionChange(newValue: Bool) {
        NCPreferences().backgroundUploadExtensionEnabled = newValue

        guard #available(iOS 27, *) else {
            return
        }

        Task {
            if newValue {
                _ = await NCBackgroundUploadExtensionManager.shared.ensureEnabled()
            } else {
                _ = await NCBackgroundUploadExtensionManager.shared.disableIfIdle()
            }
        }
    }

    /// Updates the auto-upload full content setting.
    @MainActor
    func handleAutoUploadChange(newValue: Bool, assetCollections: [PHAssetCollection]) {
        guard !isChangingAutoUpload else { return }
        isChangingAutoUpload = true
        let accountIdentifier = session.account

        Task {
            guard let account = await database.getTableAccountAsync(
                predicate: NSPredicate(format: "account == %@", accountIdentifier)
            ),
            account.autoUploadStart != newValue else {
                isChangingAutoUpload = false
                return
            }

            if newValue {
                if #available(iOS 27, *),
                   await hasUnresolvedAutoUploadTransfers(account: accountIdentifier) {
                    await cancelAutoUploadTransfers(account: accountIdentifier)
                    guard !(await hasUnresolvedAutoUploadTransfers(account: accountIdentifier)) else {
                        autoUploadStart = false
                        error = NSLocalizedString("_autoupload_cleanup_pending_", comment: "")
                        showErrorAlert = true
                        isChangingAutoUpload = false
                        return
                    }
                }
                await database.setAutoUploadStartAsync(true, account: accountIdentifier)
                // Enabling Auto Upload is an explicit request to resume a previously suspended queue.
                NCPreferences().setBackgroundUploadSuspended(false, account: accountIdentifier)

                guard let updatedAccount = await database.getTableAccountAsync(
                    predicate: NSPredicate(format: "account == %@", accountIdentifier)
                ), updatedAccount.autoUploadStart else {
                    await MainActor.run {
                        self.autoUploadStart = false
                    }
                    isChangingAutoUpload = false
                    return
                }

                // Stop remains available during the legacy initial scan.
                isChangingAutoUpload = false
                _ = await NCAutoUpload.shared.startManualAutoUploadForAlbums(
                    controller: controller,
                    model: self,
                    assetCollections: assetCollections,
                    account: accountIdentifier
                )
            } else {
                await database.setAutoUploadStartAsync(false, account: accountIdentifier)
                await cancelAutoUploadTransfers(account: accountIdentifier)

                if #available(iOS 27, *) {
                    _ = await NCBackgroundUploadExtensionManager.shared.disableIfIdle()
                }
                autoUploadSinceDate = database.getTableAccount(account: accountIdentifier)?.autoUploadSinceDate
                isChangingAutoUpload = false
            }
        }
    }

    private func hasUnresolvedAutoUploadTransfers(account: String) async -> Bool {
        let remaining = await database.getMetadatasAsync(predicate: NSPredicate(
            format: "account == %@ AND sessionSelector == %@ AND backgroundUploadJobIdentifier != ''",
            account,
            NCGlobal.shared.selectorUploadAutoUpload
        ))
        if !remaining.isEmpty { return true }
        if #available(iOS 27, *) {
            return NCBackgroundUploadExtensionManager.shared.hasOutstandingUploadJobs()
        }
        return false
    }

    private func cancelAutoUploadTransfers(account: String) async {
        await database.requestBackgroundAutoUploadCancellationAsync(account: account)

        if #available(iOS 27, *) {
            await NCBackgroundUploadExtensionManager.shared.cancelUploads(account: account)
        }

        let predicate = NSPredicate(
            format: "account == %@ AND sessionSelector == %@ AND backgroundUploadJobIdentifier == '' AND status != %d",
            account,
            NCGlobal.shared.selectorUploadAutoUpload,
            NCGlobal.shared.metadataStatusNormal
        )

        let metadatas: [tableMetadata] = await database.getMetadatasAsync(
            predicate: predicate
        )

        for metadata in metadatas {
            await NCNetworking.shared.cancelTask(metadata: metadata)
        }
    }

    func getOtherAutoUploadAccount() async -> tableAccount? {
        await database.getTableAccountAsync(
            predicate: NSPredicate(
                format: "autoUploadStart == true AND account != %@",
                session.account
            )
        )
    }

    /// Updates the auto-upload create subfolder setting.
    func handleAutoUploadCreateSubfolderChange(newValue: Bool) {
        Task {
            await database.updateAccountPropertyAsync(\.autoUploadCreateSubfolder, value: newValue, account: session.account)
        }
    }

    /// Updates the auto-upload subfolder granularity setting.
    func handleAutoUploadSubfolderGranularityChange(newValue: Granularity) {
        Task {
            await database.updateAccountPropertyAsync(\.autoUploadSubfolderGranularity, value: newValue.rawValue, account: session.account)
        }
    }

    /// Returns the path for auto-upload based on the active account's settings.
    ///
    /// - Returns: The path for auto-upload.
    func returnPath() -> String {
        let autoUploadPath = self.database.getAccountAutoUploadDirectory(account: session.account, urlBase: session.urlBase, userId: session.userId) + "/" + self.database.getAccountAutoUploadFileName(account: session.account)
        let homeServer = NCUtilityFileSystem().getHomeServer(session: session)
        let path = autoUploadPath.replacingOccurrences(of: homeServer, with: "")
        return path
    }

    /// Sets the auto-upload directory based on the provided server URL.
    ///
    /// - Parameter
    /// serverUrl: The server URL to set as the auto-upload directory.
    func setAutoUploadDirectory(serverUrl: String?) {
        guard let serverUrl else { return }
        Task {
            let previousDestination = database.getAccountAutoUploadServerUrlBase(session: session)
            let home = NCUtilityFileSystem().getHomeServer(session: session)
            if home != serverUrl {
                let fileName = (serverUrl as NSString).lastPathComponent
                await self.database.setAccountAutoUploadFileNameAsync(fileName)
                if let serverDirectoryUp = NCUtilityFileSystem().serverDirectoryUp(serverUrl: serverUrl, home: home) {
                    await self.database.setAccountAutoUploadDirectoryAsync(serverDirectoryUp, session: session)
                }
            }

            if database.getAccountAutoUploadServerUrlBase(session: session) != previousDestination {
                await database.setAutoUploadSinceDateAsync(nil, account: session.account)
            }
            onViewAppear()
        }
    }

    /// Returns a display title for the selected auto-upload albums.
    ///
    /// - Parameter autoUploadAlbumIds: The local identifiers of the selected albums.
    /// - Returns: The album's localized title, "Camera Roll" for the user library, or a localized "multiple albums" string when more than one is selected.
    func createAlbumTitle(autoUploadAlbumIds: Set<String>) -> String {
        if autoUploadAlbumIds.count == 1 {
            let album = PHAssetCollection.allAlbums.first(where: { autoUploadAlbumIds.first == $0.localIdentifier })
            return (album?.assetCollectionSubtype == .smartAlbumUserLibrary) ? NSLocalizedString("_camera_roll_", comment: "") : (album?.localizedTitle ?? "")
        } else {
            return NSLocalizedString("_multiple_albums_", comment: "")
        }
    }

    /// Requests or revokes `Always` location authorization for background location-based auto upload.
    func handleLocationChange(newValue: Bool) {
        if let controller = self.controller {
            if newValue {
                Task { @MainActor in
                    let result = await NCBackgroundLocationUploadManager.shared.requestAuthorizationAlwaysAsync(from: controller)
                    self.locationAutoUploadPermissionGranted = result
                    NCPreferences().location = result
                }
            } else {
                self.locationAutoUploadPermissionGranted = false
                NCPreferences().location = false
            }
        }
    }

    /// Refreshes `locationAutoUploadPermissionGranted` from the current location authorization status and stored preference.
    func checkPermission() {
        let status = CLLocationManager().authorizationStatus
        locationAutoUploadPermissionGranted = (status == .authorizedAlways && NCPreferences().location)
    }
}

/// An enum that represents the granularity of the subfolders for auto upload
enum Granularity: Int {
    /// Daily granularity, meaning the subfolders are named by day
    case daily = 2
    /// Monthly granularity, meaning the subfolders are named by month
    case monthly = 1
    /// Yearly granularity, meaning the subfolders are named by year
    case yearly = 0
}
