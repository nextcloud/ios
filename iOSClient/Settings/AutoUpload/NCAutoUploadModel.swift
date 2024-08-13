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
import Photos
import NextcloudKit

/// A model that allows the user to configure the `auto upload settings for Nextcloud`
class NCAutoUploadModel: ObservableObject, ViewOnAppearHandling {
    /// AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
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
    /// Root View Controller
    var controller: NCMainTabBarController?
    /// A variable user for change the auto upload directory
    var serverUrl: String = ""

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        let activeAccount: tableAccount? = manageDatabase.getActiveAccount()
        if let account = activeAccount {
            autoUpload = account.autoUpload
            autoUploadImage = account.autoUploadImage
            autoUploadWWAnPhoto = account.autoUploadWWAnPhoto
            autoUploadVideo = account.autoUploadVideo
            autoUploadWWAnVideo = account.autoUploadWWAnVideo
            autoUploadFull = account.autoUploadFull
            autoUploadCreateSubfolder = account.autoUploadCreateSubfolder
            autoUploadSubfolderGranularity = Granularity(rawValue: account.autoUploadSubfolderGranularity) ?? .monthly
            serverUrl = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        }
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
                NCManageDatabase.shared.setAccountAutoUploadFileName("")
                NCManageDatabase.shared.setAccountAutoUploadDirectory("", urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId, account: self.appDelegate.account)
                NCAutoUpload.shared.alignPhotoLibrary(viewController: self.controller)
            }
        } else {
            updateAccountProperty(\.autoUpload, value: newValue)
            updateAccountProperty(\.autoUploadFull, value: newValue)
            NCManageDatabase.shared.clearMetadatasUpload(account: appDelegate.account)
        }
    }

    /// Updates the auto-upload image setting.
    func handleAutoUploadImageChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadImage, value: newValue)
        if newValue {
            NCAutoUpload.shared.alignPhotoLibrary(viewController: controller)
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
            NCAutoUpload.shared.alignPhotoLibrary(viewController: controller)
        }
    }

    /// Updates the auto-upload video over WWAN setting.
    func handleAutoUploadWWAnVideoChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadWWAnVideo, value: newValue)
    }

    /// Updates the auto-upload full content setting.
    func handleAutoUploadFullChange(newValue: Bool) {
        updateAccountProperty(\.autoUploadFull, value: newValue)
        if newValue {
            NCAutoUpload.shared.autoUploadFullPhotos(viewController: self.controller, log: "Auto upload full")
        } else {
            NCManageDatabase.shared.clearMetadatasUpload(account: appDelegate.account)
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
        guard let activeAccount = manageDatabase.getActiveAccount() else { return }
        activeAccount[keyPath: keyPath] = value
        manageDatabase.updateAccount(activeAccount)
    }

    /// Returns the path for auto-upload based on the active account's settings.
    ///
    /// - Returns: The path for auto-upload.
    func returnPath() -> String {
        let autoUploadPath = manageDatabase.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, userId: appDelegate.userId, account: appDelegate.account) + "/" + manageDatabase.getAccountAutoUploadFileName()
        let homeServer = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        let path = autoUploadPath.replacingOccurrences(of: homeServer, with: "")
        return path
    }

    /// Sets the auto-upload directory based on the provided server URL.
    ///
    /// - Parameter
    /// serverUrl: The server URL to set as the auto-upload directory.
    func setAutoUploadDirectory(serverUrl: String?) {
        guard let serverUrl = serverUrl else { return }
        let home = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        if home != serverUrl {
            let fileName = (serverUrl as NSString).lastPathComponent
            NCManageDatabase.shared.setAccountAutoUploadFileName(fileName)
            if let path = NCUtilityFileSystem().deleteLastPath(serverUrlPath: serverUrl, home: home) {
                NCManageDatabase.shared.setAccountAutoUploadDirectory(path, urlBase: appDelegate.urlBase, userId: appDelegate.userId, account: appDelegate.account)
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
