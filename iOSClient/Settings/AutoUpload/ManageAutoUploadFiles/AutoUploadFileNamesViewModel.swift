//
//  AutoUploadFileNamesViewModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 12/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import NextcloudKit
import SwiftUI
import Combine

protocol AutoUploadFileNamesViewModelProtocol: ObservableObject {
    /// A boolean indicating whether to maintain the original file name.
    var maintainFilename: Bool { get set }
    /// A boolean indicating whether to specify a custom file name.
    var specifyFilename: Bool { get set }
    /// The changed file name.
    var changedName: String { get set }
    /// The original file name.
    var oldName: String { get set }
}


/// A view model responsible for managing auto-upload file names.
class AutoUploadFileNamesViewModel: AutoUploadFileNamesViewModelProtocol {
    // MARK: - Properties
    private let keychain = NCKeychain()
    private let globalKey = NCGlobal.shared
    
    @Published var maintainFilename: Bool = false
    @Published var specifyFilename: Bool = false
    @Published var changedName: String = ""
    @Published var oldName: String = ""
    let dateExample = Date()
    
    // MARK: - Initialization
    
    /// Initializes the view model with default values.
    init() {
        onViewAppear()
    }
    
    func onViewAppear() {
        maintainFilename = keychain.getOriginalFileName(key: globalKey.keyFileNameOriginalAutoUpload)
        specifyFilename = keychain.getOriginalFileName(key: globalKey.keyFileNameAutoUploadType)
        
        changedName = keychain.getFileNameMask(key: globalKey.keyFileNameAutoUploadMask)
        oldName = keychain.getFileNameMask(key: globalKey.keyFileNameAutoUploadMask)
    }
    
    // MARK: - Methods
    
    /// Toggles maintaining the original filename.
    func toggleMaintainOriginalFilename(newValue: Bool) {
        NCKeychain().setOriginalFileName(key: NCGlobal.shared.keyFileNameOriginalAutoUpload, value: newValue)
    }
    
    /// Toggles adding filename type.
    func toggleAddFilenameType(newValue: Bool) {
        NCKeychain().setFileNameType(key: NCGlobal.shared.keyFileNameAutoUploadType, prefix: newValue)
    }
    
    /// Submits the changed file name.
    func submitChangedName() {
        changedName = checkUploadFileName()
        presentForbiddenCharError()
        oldName = changedName
    }
    
    /// Presents an error message if the changed file name contains forbidden characters.
    func presentForbiddenCharError(){
        if changedName != oldName {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), NCGlobal.shared.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: errorDescription)
            NCContentPresenter().showInfo(error: error)
        }
    }
    
    /// Checks and removes forbidden characters from the changed file name.
    /// - Returns: The sanitized file name.
    func checkUploadFileName() -> String {
        return NCUtility().removeForbiddenCharacters(changedName)
    }
    
    /// Generates a preview file name based on current settings and file name mask.
    /// - Returns: The preview file name.
    func previewFileName() -> String {
        var returnString: String = ""
        
        // Check if maintaining original file name is enabled
        if NCKeychain().getOriginalFileName(key: NCGlobal.shared.keyFileNameOriginalAutoUpload) {
            // If maintaining original file name, return a default filename
            return (NSLocalizedString("_filename_", comment: "") + ": IMG_0001.JPG")
        } else {
            let valueRenameTrimming = changedName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // If the changed name is empty, set the filename mask to empty and generate a new filename
            if valueRenameTrimming.isEmpty {
                NCKeychain().setFileNameMask(key: NCGlobal.shared.keyFileNameAutoUploadMask, mask: "")
                returnString = CCUtility.createFileName("IMG_0001.JPG", fileDate: dateExample, fileType: PHAssetMediaType.image, keyFileName: nil, keyFileNameType: NCGlobal.shared.keyFileNameAutoUploadType, keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginalAutoUpload, forcedNewFileName: false)
            } else {
                // If there is a changed name, set the filename mask and generate a new filename
                NCKeychain().setFileNameMask(key: NCGlobal.shared.keyFileNameAutoUploadMask, mask: changedName)
                returnString = CCUtility.createFileName("IMG_0001.JPG", fileDate: dateExample, fileType: PHAssetMediaType.image, keyFileName: NCGlobal.shared.keyFileNameAutoUploadMask, keyFileNameType: NCGlobal.shared.keyFileNameAutoUploadType, keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginalAutoUpload, forcedNewFileName: false)
            }
        }
        return returnString
    }
}

