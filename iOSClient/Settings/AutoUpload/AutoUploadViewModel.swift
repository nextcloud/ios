//
//  AutoUploadViewModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 08/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

protocol AutoUploadViewModelProtocol: ObservableObject {
    /// A state variable that indicates whether auto upload is enabled or not
    var autoUpload: Bool { get set }
    
    /// A state variable that indicates whether auto upload for photos is enabled or not
    var autoUploadImage: Bool { get set }
    /// A state variable that indicates whether auto upload for photos is restricted to Wi-Fi only or not
    var autoUploadWWAnPhoto: Bool { get set }
    
    /// A state variable that indicates whether auto upload for videos is enabled or not
    var autoUploadVideo: Bool { get set }
    /// A state variable that indicates whether auto upload for videos is restricted to Wi-Fi only or not
    var autoUploadWWAnVideo: Bool { get set }
    
    /// A state variable that indicates whether auto upload for full resolution photos is enabled or not
    var autoUploadFull: Bool { get set }
    /// A state variable that indicates whether auto upload creates subfolders based on date or not
    var autoUploadCreateSubfolder: Bool { get set }
    
    /// A state variable that indicates the granularity of the subfolders, either daily, monthly, or yearly
    var autoUploadSubfolderGranularity: Granularity { get set }
}

/// A viewModel that allows the user to configure the `auto upload settings for Nextcloud`
class AutoUploadViewModel: AutoUploadViewModelProtocol {
    @Published var autoUpload: Bool = false
    @Published var autoUploadImage: Bool = false
    @Published var autoUploadWWAnPhoto: Bool = false
    
    @Published var autoUploadVideo: Bool = false
    @Published var autoUploadWWAnVideo: Bool = false
    
    @Published var autoUploadFull: Bool = false
    @Published var autoUploadCreateSubfolder: Bool = false
    
    @Published var autoUploadSubfolderGranularity: Granularity = .monthly
    
    @Published var isAuthorized: Bool = false
    private let manageDatabase = NCManageDatabase()
    
    // Initialization code to set up the ViewModel with the active account
    init() {
        onViewAppear()
    }
    
    /// A function to update the published properties based on the active account
    func onViewAppear() {
        var activeAccount: tableAccount? = NCManageDatabase().getActiveAccount()
        if let account = activeAccount {
            autoUpload = account.autoUpload
            autoUploadImage = account.autoUploadImage
            autoUploadWWAnPhoto = account.autoUploadWWAnPhoto
            autoUploadVideo = account.autoUploadVideo
            autoUploadWWAnVideo = account.autoUploadWWAnVideo
            autoUploadFull = account.autoUploadFull
            autoUploadCreateSubfolder = account.autoUploadCreateSubfolder
            autoUploadSubfolderGranularity = Granularity(rawValue: account.autoUploadSubfolderGranularity) ?? .monthly
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
        guard var activeAccount = manageDatabase.getActiveAccount() else { return }
        activeAccount[keyPath: keyPath] = value
        manageDatabase.updateAccount(activeAccount)
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
