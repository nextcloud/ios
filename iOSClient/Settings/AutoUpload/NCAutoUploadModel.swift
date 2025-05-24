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
import EasyTipView

enum AutoUploadTimespan: String, CaseIterable, Identifiable {
    case allPhotos = "_all_photos_"
    case newPhotosOnly = "_new_photos_only_"
    var id: Self { self }
}

/// A model that allows the user to configure the `auto upload settings for Nextcloud`
class NCAutoUploadModel: ObservableObject, ViewOnAppearHandling {
    /// A state variable that indicates whether auto upload for photos is enabled or not
    @Published var autoUploadImage: Bool = false
    /// A state variable that indicates whether auto upload for photos is restricted to Wi-Fi only or not
    @Published var autoUploadWWAnPhoto: Bool = false
    /// A state variable that indicates whether auto upload for videos is enabled or not
    @Published var autoUploadVideo: Bool = false
    /// A state variable that indicates whether auto upload for videos is enabled or not
    @Published var autoUploadWWAnVideo: Bool = false
    /// A state variable that indicates whether auto upload is enabled or not
    @Published var autoUploadStart: Bool = false
    /// A state variable that indicates whether auto upload creates subfolders based on date or not
    @Published var autoUploadCreateSubfolder: Bool = false
    /// A state variable that indicates the granularity of the subfolders, either daily, monthly, or yearly
    @Published var autoUploadSubfolderGranularity: Granularity = .monthly
    /// A state variable that indicates the date from when new photos/videos will be uploaded.
    @Published var autoUploadOnlyNewSinceDate: Date?
    /// A state variable that indicates from whether new photos only or all photos will be uploaded.
    @Published var autoUploadOnlyNew: Bool = false
    /// A state variable that indicates whether a warning should be shown if all photos must be uploaded.
    @Published var showUploadAllPhotosWarning = false
    /// A state variable that indicates whether Photos permissions have been granted or not.
    @Published var photosPermissionsGranted = true

    /// A state variable that shows error in view in case of an error
    @Published var showErrorAlert: Bool = false
    @Published var sectionName = ""
    @Published var isAuthorized: Bool = false
    /// A string variable that contains error text
    @Published var error: String = ""
    let database = NCManageDatabase.shared

    /// Tip
    var tip: EasyTipView?
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

        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                               object: nil,
                                               queue: .main) { _ in
            self.tip?.dismiss()
            self.tip = nil
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        if let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) {
            autoUploadImage = tableAccount.autoUploadImage
            autoUploadWWAnPhoto = tableAccount.autoUploadWWAnPhoto
            autoUploadVideo = tableAccount.autoUploadVideo
            autoUploadWWAnVideo = tableAccount.autoUploadWWAnVideo
            autoUploadStart = tableAccount.autoUploadStart
            autoUploadCreateSubfolder = tableAccount.autoUploadCreateSubfolder
            autoUploadSubfolderGranularity = Granularity(rawValue: tableAccount.autoUploadSubfolderGranularity) ?? .monthly
            autoUploadOnlyNewSinceDate = tableAccount.autoUploadOnlyNewSinceDate
            autoUploadOnlyNew = tableAccount.autoUploadOnlyNew
        }

        serverUrl = NCUtilityFileSystem().getHomeServer(session: session)

        requestAuthorization()

        if !autoUploadImage && !autoUploadVideo { autoUploadImage = true }

        showTip()
    }

    func onViewDisappear() {
        tip?.dismiss()
        tip = nil
    }

    // MARK: - All functions

    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async { [self] in
                let value = (status == .authorized)
                photosPermissionsGranted = value

                if value, UIApplication.shared.backgroundRefreshStatus != .available {
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_access_background_app_refresh_denied_", comment: ""), responseData: nil)
                    NCContentPresenter().messageNotification("_info_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .info)
                }
            }
        }
    }

    /// Updates the auto-upload image setting.
    func handleAutoUploadImageChange(newValue: Bool) {
        database.updateAccountProperty(\.autoUploadImage, value: newValue, account: session.account)
    }

    /// Updates the auto-upload image over WWAN setting.
    func handleAutoUploadWWAnPhotoChange(newValue: Bool) {
        database.updateAccountProperty(\.autoUploadWWAnPhoto, value: newValue, account: session.account)
    }

    /// Updates the auto-upload video setting.
    func handleAutoUploadVideoChange(newValue: Bool) {
        database.updateAccountProperty(\.autoUploadVideo, value: newValue, account: session.account)
    }

    /// Updates the auto-upload video over WWAN setting.
    func handleAutoUploadWWAnVideoChange(newValue: Bool) {
        database.updateAccountProperty(\.autoUploadWWAnVideo, value: newValue, account: session.account)
    }

    func handleAutoUploadOnlyNew(newValue: Bool) {
        database.updateAccountProperty(\.autoUploadOnlyNew, value: newValue, account: session.account)
    }

    /// Updates the auto-upload full content setting.
    func handleAutoUploadChange(newValue: Bool, assetCollections: [PHAssetCollection]) {
        if let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)), tableAccount.autoUploadStart == newValue { return }

        database.updateAccountProperty(\.autoUploadStart, value: newValue, account: session.account)

        if newValue {
            if autoUploadOnlyNew {
                database.updateAccountProperty(\.autoUploadOnlyNewSinceDate, value: Date.now, account: session.account)
            }
            NCAutoUpload.shared.autoUploadSelectedAlbums(controller: self.controller, assetCollections: assetCollections, log: "Auto upload selected albums", account: session.account)
        } else {
            database.clearMetadatasUpload(account: session.account)
        }
    }

    /// Updates the auto-upload create subfolder setting.
    func handleAutoUploadCreateSubfolderChange(newValue: Bool) {
        database.updateAccountProperty(\.autoUploadCreateSubfolder, value: newValue, account: session.account)
    }

    /// Updates the auto-upload subfolder granularity setting.
    func handleAutoUploadSubfolderGranularityChange(newValue: Granularity) {
        database.updateAccountProperty(\.autoUploadSubfolderGranularity, value: newValue.rawValue, account: session.account)
    }

    /// Returns the path for auto-upload based on the active account's settings.
    ///
    /// - Returns: The path for auto-upload.
    func returnPath() -> String {
        let autoUploadPath = self.database.getAccountAutoUploadDirectory(session: session) + "/" + self.database.getAccountAutoUploadFileName(account: session.account)
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

    func createAlbumTitle(autoUploadAlbumIds: Set<String>) -> String {
        if autoUploadAlbumIds.count == 1 {
            let album = PHAssetCollection.allAlbums.first(where: { autoUploadAlbumIds.first == $0.localIdentifier })
            return (album?.assetCollectionSubtype == .smartAlbumUserLibrary) ? NSLocalizedString("_camera_roll_", comment: "") : (album?.localizedTitle ?? "")
        } else {
            return NSLocalizedString("_multiple_albums_", comment: "")
        }
    }

    func existsAutoUpload() -> Bool {
        let autoUploadServerUrlBase = NCManageDatabase.shared.getAccountAutoUploadServerUrlBase(session: session)
        return NCManageDatabase.shared.existsAutoUpload(account: session.account, autoUploadServerUrlBase: autoUploadServerUrlBase)
    }

    func deleteAutoUploadTransfer() {
        let autoUploadServerUrlBase = NCManageDatabase.shared.getAccountAutoUploadServerUrlBase(session: session)
        NCManageDatabase.shared.deleteAutoUploadTransfer(account: session.account, autoUploadServerUrlBase: autoUploadServerUrlBase)
    }
}

extension NCAutoUploadModel: EasyTipViewDelegate {
    func showTip() {
        guard !session.account.isEmpty,
              !database.tipExists(NCGlobal.shared.tipAutoUploadButton)
        else {
            return
        }

        var preferences = EasyTipView.Preferences()

        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = .lightGray
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .any
        preferences.drawing.cornerRadius = 10

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 0.5
        preferences.animating.dismissDuration = 0.5

        if tip == nil {
            tip = EasyTipView(text: NSLocalizedString("_tip_autoupload_button_", comment: ""), preferences: preferences, delegate: self, tip: NCGlobal.shared.tipAutoUploadButton)
            if let view = controller?.tabBar {
                tip?.show(forView: view)
            }
        }
    }

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        database.addTip(NCGlobal.shared.tipAutoUploadButton)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) {
        tip = nil
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
