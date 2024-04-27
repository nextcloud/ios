//
//  AutoUploadViewModel.swift
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
import NextcloudKit

/// A model that allows the user to configure the `auto upload settings for Nextcloud`
class AutoUploadModel: ObservableObject, ViewOnAppearHandling, NCSelectDelegate {
    var appDelegate = AppDelegate()
    /// A state variable that indicates whether auto upload is enabled or not
    @Published var autoUpload: Bool = false
    /// A state variable that indicates whether to open NCSelect View or not
    @Published var autoUploadFolder: Bool = false
    /// A state variable that indicates whether auto upload for photos is enabled or not
    @Published var autoUploadImage: Bool = false
    /// A state variable that indicates whether auto upload for photos is restricted to Wi-Fi only or not
    @Published var autoUploadWWAnPhoto: Bool = false
    /// A state variable that indicates whether auto upload for videos is enabled or not
    @Published var autoUploadVideo: Bool = false
    /// A state variable that indicates whether auto upload for videos is enabled or not
    @Published var autoUploadWWAnVideo: Bool = false
    /// A state variable that indicates whether auto upload for full resolution photos is enabled or not
    @Published var autoUploadFull: Bool = false
    /// A state variable that indicates whether auto upload creates subfolders based on date or not
    @Published var autoUploadCreateSubfolder: Bool = false
    /// A state variable that indicates the granularity of the subfolders, either daily, monthly, or yearly
    @Published var autoUploadSubfolderGranularity: Granularity = .monthly
    /// A state variable that shows error in view in case of an error
    @Published var showErrorAlert: Bool = false
    @Published var sectionName = ""
    @Published var isAuthorized: Bool = false
    /// A string variable that contains error text
    @Published var error: String = ""
    private let manageDatabase = NCManageDatabase.shared
    @Published var autoUploadPath = "\(NCManageDatabase.shared.getAccountAutoUploadFileName())"
    var serverUrl: String = NCUtilityFileSystem().getHomeServer(urlBase: AppDelegate().urlBase, userId: AppDelegate().userId)
    /// Initialization code to set up the ViewModel with the active account
    init() {
        onViewAppear()
    }
    // MARK: All functions
    /// A function to update the published properties based on the active account
    func onViewAppear() {
        let activeAccount: tableAccount? = NCManageDatabase.shared.getActiveAccount()
        if let account = activeAccount {
            autoUpload = account.autoUpload
            autoUploadImage = account.autoUploadImage
            autoUploadWWAnPhoto = account.autoUploadWWAnPhoto
            autoUploadVideo = account.autoUploadVideo
            autoUploadWWAnVideo = account.autoUploadWWAnVideo
            autoUploadFull = account.autoUploadFull
            autoUploadCreateSubfolder = account.autoUploadCreateSubfolder
            autoUploadSubfolderGranularity = Granularity(rawValue: account.autoUploadSubfolderGranularity) ?? .monthly
            if autoUpload {
                requestAuthorization()
            }
        }
    }
    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorized = status == .authorized
            }
        }
    }
    /// Updates the auto-upload setting.
    func handleAutoUploadChange(newValue: Bool) {
        updateAccountProperty(\.autoUpload, value: newValue)
    }
    /// Updates the auto-upload image setting.
    func handleAutoUploadImageChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadImage, value: newValue)
    }
    /// Updates the auto-upload image over WWAN setting.
    func handleAutoUploadWWAnPhotoChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadWWAnPhoto, value: newValue)
    }
    /// Updates the auto-upload video setting.
    func handleAutoUploadVideoChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadVideo, value: newValue)
    }
    /// Updates the auto-upload video over WWAN setting.
    func handleAutoUploadWWAnVideoChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadWWAnVideo, value: newValue)
    }
    /// Updates the auto-upload full content setting.
    func handleAutoUploadFullChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadFull, value: newValue)
    }
    /// Updates the auto-upload create subfolder setting.
    func handleAutoUploadCreateSubfolderChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadCreateSubfolder, value: newValue)
    }
    /// Updates the auto-upload subfolder granularity setting.
    func handleAutoUploadSubfolderGranularityChange(newValue: Granularity) {
        updateAccountProperty(\.autoUploadSubfolderGranularity, value: newValue.rawValue)
    }
    /// Updates a property of the active account in the database.
    private func updateAccountProperty<T>(_ keyPath: ReferenceWritableKeyPath<tableAccount, T>, value: T) {
        guard let activeAccount = manageDatabase.getActiveAccount() else { return }
        activeAccount[keyPath: keyPath] = value
        manageDatabase.updateAccount(activeAccount)
    }
    /// Returns the path for auto-upload based on the active account's settings.
    ///
    /// - Returns: The path for auto-upload.
    func returnPath() -> String {
        let path = NCManageDatabase.shared.getAccountAutoUploadFileName()
        return path.replacingOccurrences(of: NCUtilityFileSystem().deleteLastPath(serverUrlPath: path) ?? "", with: "")
    }
    /// Sets the auto-upload directory based on the provided server URL.
    ///
    /// - Parameter
    /// serverUrl: The server URL to set as the auto-upload directory.
    func setAutoUploadDirectory(serverUrl: String?) {
        guard let serverUrl = serverUrl else { return }

        // It checks if the provided server URL is the home server. If it is, an error is set, and the function returns early.
        let home = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        if serverUrl == home {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_autoupload_error_select_folder_", responseData: nil)
            self.error = error.errorDescription
            self.showErrorAlert = true
            return
        }

        // Otherwise, it updates the auto-upload directory in the database
        NCManageDatabase.shared.setAccountAutoUploadFileName(serverUrl)
        if let path = NCUtilityFileSystem().deleteLastPath(serverUrlPath: serverUrl, home: home) {
            NCManageDatabase.shared.setAccountAutoUploadDirectory(path, urlBase: appDelegate.urlBase, userId: appDelegate.userId, account: appDelegate.account)
        }
        onViewAppear()
    }
    // MARK: NCSelectDelegate
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {}
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
