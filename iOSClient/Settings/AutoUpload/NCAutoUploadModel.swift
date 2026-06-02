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
    case allPhotos = "_all_photos_"
    case newPhotosOnly = "_new_photos_only_"
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
    /// Whether auto upload creates subfolders based on date or not
    @Published var autoUploadCreateSubfolder: Bool = false
    /// The granularity of the subfolders, either daily, monthly, or yearly
    @Published var autoUploadSubfolderGranularity: Granularity = .monthly
    /// The date from when new photos/videos will be uploaded.
    @Published var autoUploadSinceDate: Date?
    /// Whether a warning should be shown if all photos must be uploaded.
    @Published var showUploadAllPhotosWarning = false
    /// Whether Photos permissions have been granted or not.
    @Published var photosPermissionsGranted = true
    /// Whether `Always` location authorization has been granted, enabling background location-based auto upload.
    @Published var locationAutoUploadPermissionGranted: Bool = false

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
        }

        serverUrl = NCUtilityFileSystem().getHomeServer(session: session)

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

    /// Sets the cut-off date so only photos/videos created after it are uploaded.
    func handleAutoUploadOnlyNew(newValue: Bool) {
        if newValue {
            autoUploadSinceDate = Date.now
        } else {
            autoUploadSinceDate = nil
        }
        Task {
            await database.updateAccountPropertyAsync(\.autoUploadSinceDate, value: autoUploadSinceDate, account: session.account)
        }
    }

    /// Updates the auto-upload full content setting.
    func handleAutoUploadChange(newValue: Bool, assetCollections: [PHAssetCollection]) {
        Task {
            if let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account)),
               tblAccount.autoUploadStart == newValue {
                return
            }

            await database.updateAccountPropertyAsync(\.autoUploadStart, value: newValue, account: session.account)

            if newValue {
                _ = await NCAutoUpload.shared.startManualAutoUploadForAlbums(controller: self.controller,
                                                                             model: self,
                                                                             assetCollections: assetCollections,
                                                                             account: session.account)
            } else {
                await database.clearMetadatasUploadAsync(account: session.account)
            }
        }
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
            let home = NCUtilityFileSystem().getHomeServer(session: session)
            if home != serverUrl {
                let fileName = (serverUrl as NSString).lastPathComponent
                await self.database.setAccountAutoUploadFileNameAsync(fileName)
                if let serverDirectoryUp = NCUtilityFileSystem().serverDirectoryUp(serverUrl: serverUrl, home: home) {
                    await self.database.setAccountAutoUploadDirectoryAsync(serverDirectoryUp, session: session)
                }
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

    /// Whether any auto-upload entry exists for the current account.
    func existsAutoUpload() -> Bool {
        let autoUploadServerUrlBase = NCManageDatabase.shared.getAccountAutoUploadServerUrlBase(session: session)
        return NCManageDatabase.shared.existsAutoUpload(account: session.account, autoUploadServerUrlBase: autoUploadServerUrlBase)
    }

    /// Deletes pending auto-upload transfers for the current account.
    func deleteAutoUploadTransfer() {
        Task {
            let autoUploadServerUrlBase = await NCManageDatabase.shared.getAccountAutoUploadServerUrlBaseAsync(session: session)
            await NCManageDatabase.shared.deleteAutoUploadTransferAsync(account: session.account, autoUploadServerUrlBase: autoUploadServerUrlBase)
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
