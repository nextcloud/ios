// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import SwiftUI
import Photos

/// A view model responsible for managing auto-upload file names.
class NCFileNameModel: ObservableObject, ViewOnAppearHandling {
    // A keychain instance for handling authentication.
    private var keychain = NCKeychain()
    // A shared global instance for managing application-wide settings.
    private let globalKey = NCGlobal.shared
    // A boolean indicating whether to maintain the original file name.
    @Published var maintainFilenameOriginal: Bool = NCKeychain().fileNameOriginal
    // A boolean indicating whether to specify a custom file name.
    @Published var addFileNameType: Bool = NCKeychain().fileNameType
    // The changed file name.
    @Published var changedName: String = ""
    // The complete new file name.
    @Published var fileNamePreview: String = ""
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
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        changedName = FileAutoRenamer.rename(changedName, capabilities: capabilities)
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
