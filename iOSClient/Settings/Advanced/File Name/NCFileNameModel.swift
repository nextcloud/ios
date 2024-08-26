//
//  NCFileNameModel.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import SwiftUI
import Photos

/// A view model responsible for managing auto-upload file names.
class NCFileNameModel: ObservableObject, ViewOnAppearHandling {
    /// A keychain instance for handling authentication.
    private var keychain = NCKeychain()
    /// A shared global instance for managing application-wide settings.
    private let globalKey = NCGlobal.shared
    /// A boolean indicating whether to maintain the original file name.
    @Published var maintainFilenameOriginal: Bool = NCKeychain().fileNameOriginal
    /// A boolean indicating whether to specify a custom file name.
    @Published var addFileNameType: Bool = NCKeychain().fileNameType
    /// The changed file name.
    @Published var changedName: String = ""
    /// The complete new file name.
    @Published var fileNamePreview: String = ""
    /// Root View Controller
    @Published var controller: NCMainTabBarController?
    /// Get session
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
        changedName = keychain.fileNameMask
        getFileName()
    }

    // MARK: - All functions

    func getFileName() {
        fileNamePreview = previewFileName()
    }

    /// Toggles adding filename type.
    func toggleAddFilenameType(newValue: Bool) {
        keychain.fileNameType = newValue
    }

    /// Toggles maintain original asset filename.
    func toggleMaintainFilenameOriginal(newValue: Bool) {
        keychain.fileNameOriginal = newValue
    }

    /// Submits the changed file name.
    func submitChangedName() {
        let fileNameWithoutForbiddenChars = NCUtility().removeForbiddenCharacters(changedName)
        if changedName != fileNameWithoutForbiddenChars {
            changedName = fileNameWithoutForbiddenChars
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), NCGlobal.shared.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: errorDescription)
            NCContentPresenter().showInfo(error: error)
        }
    }

    /// Generates a preview file name based on current settings and file name mask.
    /// - Returns: The preview file name.
    func previewFileName() -> String {
        // Check if maintaining original file name is enabled
        let valueRenameTrimming = changedName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        // If the changed name is empty, set the filename mask to empty and generate a new filename
        if valueRenameTrimming.isEmpty {
            keychain.fileNameMask = ""
        } else {
            // If there is a changed name, set the filename mask and generate a new filename
            keychain.fileNameMask = changedName
        }
        return NCUtilityFileSystem().createFileName("IMG_0001.JPG", fileDate: Date(), fileType: PHAssetMediaType.image)
    }
}
