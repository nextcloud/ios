//
//  NCAutoUploadModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 08/03/24.
//  Created by Marino Faggiana on 30/05/24.
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
import Photos
import NextcloudKit

/// A model that allows the user to configure the `auto upload settings for Nextcloud`
class NCAutoUploadModel: ObservableObject, ViewOnAppearHandling {
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
    /// A state variable that indicates whether only assets marked as favorites should be uploaded
    @Published var autoUploadFavoritesOnly: Bool = false
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
    let database = NCManageDatabase.shared
    @Published var autoUploadPath = "\(NCManageDatabase.shared.getAccountAutoUploadFileName())"
    /// Root View Controller
    var controller: NCMainTabBarController?
    /// A variable user for change the auto upload directory
    var serverUrl: String = ""
    /// Get session
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        if let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) {
            autoUpload = tableAccount.autoUpload
            autoUploadImage = tableAccount.autoUploadImage
            autoUploadWWAnPhoto = tableAccount.autoUploadWWAnPhoto
            autoUploadVideo = tableAccount.autoUploadVideo
            autoUploadWWAnVideo = tableAccount.autoUploadWWAnVideo
            autoUploadFavoritesOnly = tableAccount.autoUploadFavoritesOnly
            autoUploadFull = tableAccount.autoUploadFull
            autoUploadCreateSubfolder = tableAccount.autoUploadCreateSubfolder
            autoUploadSubfolderGranularity = Granularity(rawValue: tableAccount.autoUploadSubfolderGranularity) ?? .monthly
        }
        serverUrl = NCUtilityFileSystem().getHomeServer(session: session)
        if autoUpload {
            requestAuthorization { value in
                self.autoUpload = value
                self.updateAccountProperty(\.autoUpload, value: value)
            }
        }
    }

    // MARK: - All functions

    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                let value = (status == .authorized)
                if !value {
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_access_photo_not_enabled_msg_", comment: ""), responseData: nil)
                    NCContentPresenter().messageNotification("_error_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                } else if UIApplication.shared.backgroundRefreshStatus != .available {
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_access_background_app_refresh_denied_", comment: ""), responseData: nil)
                    NCContentPresenter().messageNotification("_info_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .info)
                }
                completion(value)
            }
        }
    }

    /// Updates the auto-upload setting.
    func handleAutoUploadChange(newValue: Bool) {
        if newValue {
            requestAuthorization { value in
                self.autoUpload = value
                self.updateAccountProperty(\.autoUpload, value: value)
                self.database.setAccountAutoUploadFileName("")
                self.database.setAccountAutoUploadDirectory("", session: self.session)
                NCAutoUpload.shared.alignPhotoLibrary(controller: self.controller, account: self.session.account)
            }
        } else {
            updateAccountProperty(\.autoUpload, value: newValue)
            updateAccountProperty(\.autoUploadFull, value: newValue)
            self.database.clearMetadatasUpload(account: session.account)
        }
    }

    /// Updates the auto-upload image setting.
    func handleAutoUploadImageChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadImage, value: newValue)
        if newValue {
            NCAutoUpload.shared.alignPhotoLibrary(controller: controller, account: session.account)
        }
    }

    /// Updates the auto-upload image over WWAN setting.
    func handleAutoUploadWWAnPhotoChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadWWAnPhoto, value: newValue)
    }

    /// Updates the auto-upload video setting.
    func handleAutoUploadVideoChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadVideo, value: newValue)
        if newValue {
            NCAutoUpload.shared.alignPhotoLibrary(controller: controller, account: session.account)
        }
    }

    /// Updates the auto-upload video over WWAN setting.
    func handleAutoUploadWWAnVideoChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadWWAnVideo, value: newValue)
    }

    /// Updates the auto-upload favorite only.
    func handleAutoUploadFavoritesOnlyChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadFavoritesOnly, value: newValue)
        if newValue {
            NCAutoUpload.shared.alignPhotoLibrary(controller: controller, account: session.account)
        }
    }

    /// Updates the auto-upload full content setting.
    func handleAutoUploadFullChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadFull, value: newValue)
        if newValue {
            NCAutoUpload.shared.autoUploadFullPhotos(controller: self.controller, log: "Auto upload full", account: session.account)
        } else {
            self.database.clearMetadatasUpload(account: session.account)
        }
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
        guard let activeAccount = self.database.getActiveTableAccount() else { return }
        activeAccount[keyPath: keyPath] = value
        self.database.updateAccount(activeAccount)
    }

    /// Returns the path for auto-upload based on the active account's settings.
    ///
    /// - Returns: The path for auto-upload.
    func returnPath() -> String {
        let autoUploadPath = self.database.getAccountAutoUploadDirectory(session: session) + "/" + self.database.getAccountAutoUploadFileName()
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
        let home = NCUtilityFileSystem().getHomeServer(session: session)
        if home != serverUrl {
            let fileName = (serverUrl as NSString).lastPathComponent
            self.database.setAccountAutoUploadFileName(fileName)
            if let path = NCUtilityFileSystem().deleteLastPath(serverUrlPath: serverUrl, home: home) {
                self.database.setAccountAutoUploadDirectory(path, session: session)
            }
        }
        onViewAppear()
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
