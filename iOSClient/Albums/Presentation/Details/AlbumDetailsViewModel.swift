//
//  AlbumDetailsViewModel.swift
//  Nextcloud
//
//  Created by Dhanesh on 01/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import Foundation
import Combine
import NextcloudKit
import UIKit

// Place this at the top level of a file (outside any class)
protocol AlbumActionHandler: AnyObject {
    func deleteMetadataFromAlbum(_ selectedMetadatas: [tableMetadata])
}

class AlbumDetailsViewModel: ObservableObject {
    
    @Published var account: String
    private var album: Album
    
    @Published private(set) var screenTitle: String
    
    @Published private(set) var photos: [AlbumPhoto : tableMetadata?] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String? = nil
    
    @Published var isLoadingPopupVisible: Bool = false
    
    @Published var isDeleteAlbumPopupVisible: Bool = false
    
    @Published var isRenameAlbumPopupVisible: Bool = false
    @Published var newAlbumName: String = ""
    @Published private(set) var newAlbumNameError: String? = nil
    
    @Published var isPhotoSelectionSheetVisible: Bool = false
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(account: String, album: Album) {
        self.account = account
        self.album = album
        self.screenTitle = album.name
        registerPublishers()
        loadAlbumPhotos()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("deletePhotosFromAlbum"), object: nil, queue: .main) { [weak self] notification in
            if let metadatas = notification.userInfo?["metadatas"] as? [tableMetadata] {
                self?.deleteMetadataFromAlbum(metadatas)
            }
        }
    }
    
    // MARK: - Album name validation
    private func registerPublishers() {
        $newAlbumName
            .removeDuplicates()
            .sink { [weak self] name in
                guard let self = self else { return }
                self.newAlbumNameError = self.validateAlbumName(name).first
            }
            .store(in: &cancellables)
    }
    
    private func validateAlbumName(_ name: String) -> [String] {
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return [NSLocalizedString("_albums_list_album_name_validation_nonempty_", comment: "")]
        } else if trimmed.count < 3 {
            return [NSLocalizedString("_albums_list_album_name_validation_min_length_", comment: "")]
        } else if trimmed.count > 30 {
            return [NSLocalizedString("_albums_list_album_name_validation_max_length_", comment: "")]
        } else if trimmed.contains("/") || trimmed.contains("\\") {
            return [NSLocalizedString("_albums_list_album_name_validation_specials_", comment: "")]
        }
        
        return []
    }
    
    // MARK: - Popups
    // MARK: Delete Album
    func onDeleteAlbumIntent() {
        isDeleteAlbumPopupVisible = true
    }
    
    func onDeleteAlbumPopupCancel() {
        isDeleteAlbumPopupVisible = false
    }
    
    func onDeleteAlbumPopupConfirm() {
        isDeleteAlbumPopupVisible = false
        deleteAlbum()
    }
    
    // MARK: Rename Album
    func onRenameAlbumIntent() {
        isRenameAlbumPopupVisible = true
    }
    
    func onRenameAlbumPopupCancel() {
        newAlbumName = ""
        isRenameAlbumPopupVisible = false
    }
    
    func onRenameAlbumPopupConfirm() {
        isRenameAlbumPopupVisible = false
        renameAlbum()
    }
    
    // MARK: - APIs
    func onPulledToRefresh() {
        loadAlbumPhotos()
    }
    
    private func loadAlbumPhotos(
        doOnSuccess: (() -> Void)? = nil
    ) {
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        NextcloudKit.shared.fetchAlbumPhotos(for: album.name, account: account) { [weak self] result in
            
            self?.isLoading = false
            
            switch result {
            case .success(let photos):
                self?.photos = Dictionary(uniqueKeysWithValues: photos.map { photo in
                    let meta = NCManageDatabase.shared.getMetadataFromFileId(photo.fileId)
                    return (photo.toAlbumPhoto(), meta)
                })
                doOnSuccess?()
                
            case .failure(let error):
                NCContentPresenter().showError(error: NKError(error: error))
                self?.errorMessage = NSLocalizedString("_albums_photos_error_msg_", comment: "")
            }
        }
    }
    
    func deleteAlbum() {
        
        guard !isLoadingPopupVisible else { return }
        
        isLoadingPopupVisible = true
        
        NextcloudKit.shared.deleteAlbum(
            albumName: album.name,
            account: account
        ) { [weak self] result in
            
            self?.isLoadingPopupVisible = false
            
            switch result {
            case .success():
                AlbumsManager.shared.syncAlbums()
                AlbumsNavigator.shared.pop()
                
            case .failure(let error):
                NCContentPresenter().showError(error: NKError(error: error))
            }
        }
    }
    
    @MainActor func deletePhotos(with metadatas: [tableMetadata]) async {
        for metadata in metadatas {
            if let photo = photos.first(where: { $0.value?.ocId == metadata.ocId })?.key {
                
                guard !isLoadingPopupVisible else { return }
                await MainActor.run {
                    isLoadingPopupVisible = true
                }
                // Perform the deletion off the main actor but marshal UI updates back to main
                let error = await self.deletePhotoFromAlbum(photo, metadata: metadata)
                
                await MainActor.run {
                    self.isLoadingPopupVisible = false
                }
                
                guard error == .success else {
                    NCContentPresenter().showError(error: NKError(error: error))
                    return
                }
                
                // Refresh album contents and sync albums list on main thread
                await MainActor.run {
                    self.loadAlbumPhotos()
                    AlbumsManager.shared.syncAlbums()
                    UINavigationController().popupFromNavigationStack(context: "after-pop-deletePhotos")
                }
            }
        }
    }

    func deletePhotoFromAlbum(_ photo: AlbumPhoto, metadata: tableMetadata) async -> NKError {
        
        // Use the album entry's lastPathComponent (includes fileId prefix), do not decode
        let fileName: String = photo.fileName
        print("DEBUG: Attempting to remove: \(fileName)")
        
        let results = await NextcloudKit.shared.deletePhotoFromAlbumAsync(albumName: album.name, fileName: fileName, serverUrlFileName: metadata.serverUrlFileName, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: metadata.serverUrlFileName,
                                                                                            name: "deletePhotoFromAlbum")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        
        if results.error == .success {
            // Successfully unlinked from album. Do not delete local file or metadata.
            return .success
        } else if results.error.errorCode == NCGlobal.shared.errorResourceNotFound {
            // Treat missing resource as already unlinked; do not delete local entities.
            return .success
        } else if results.error.errorCode == NCGlobal.shared.errorForbidden && metadata.isLivePhotoVideo {
            // Some servers may forbid removing the video part of a Live Photo; ignore and treat as success.
            return .success
        } else {
            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  status: NCGlobal.shared.metadataStatusNormal)
            return results.error
        }
    }
    
    func renameAlbum() {
        
        guard !isLoadingPopupVisible else { return }
        
        isLoadingPopupVisible = true
        
        NextcloudKit.shared.renameAlbum(account: account, from: album.name, to: newAlbumName) { [weak self] result in
            
            switch result {
            case .success():
                self?.reloadAlbumAfterRenaming(albumName: self?.newAlbumName ?? "")
                
            case .failure(let error):
                self?.isLoadingPopupVisible = false
                let nkError = NKError(error: error)

                if nkError.errorCode == NCGlobal.shared.errorConflict {
                    let conflictError = NKError(errorCode: NCGlobal.shared.errorConflict,
                                                errorDescription: "_album_already_exists_")
                    NCContentPresenter().showInfo(error: conflictError)
                } else if let innerError = nkError.error as? NKError,
                          innerError.errorCode == NCGlobal.shared.errorConflict {
                    let conflictError = NKError(errorCode: NCGlobal.shared.errorConflict,
                                                errorDescription: "_album_already_exists_")
                    NCContentPresenter().showInfo(error: conflictError)
                } else {
                    NCContentPresenter().showError(error: nkError)
                }
            }
        }
    }
    
    private func reloadAlbumAfterRenaming(albumName: String) {
        
        AlbumsManager.shared.syncAlbums { [weak self] resultAlbums in
            
            self?.isLoadingPopupVisible = false
            
            if let newAlbum = resultAlbums.first(where: { $0.name == albumName }) {
                self?.album = newAlbum
                self?.loadAlbumPhotos {
                    self?.screenTitle = self?.album.name ?? ""
                    self?.newAlbumName = ""
                }
            }
        }
    }
    
    func onAddPhotosIntent() {
        isPhotoSelectionSheetVisible = true
    }
    
    func onPhotosSelected(selectedPhotos: [String]) {
        
        isPhotoSelectionSheetVisible = false
        
        if selectedPhotos.isEmpty {
            return
        }
        
        self.isLoadingPopupVisible = true
        
        for photo in selectedPhotos {
            
            let metadata: tableMetadata? = NCManageDatabase.shared.getMetadataFromOcId(photo)
            
            NextcloudKit.shared.copyPhotoToAlbum(
                account: account,
                sourcePath: metadata?.serverUrlFileName ?? photo,
                albumName: album.name,
                fileName: metadata?.fileName ?? photo
            ) { [weak self] result in
                
                DispatchQueue.main.async {
                    self?.isLoadingPopupVisible = false
                }
                
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self?.loadAlbumPhotos()
                        AlbumsManager.shared.syncAlbums()
                    }
                case .failure(let error):
                    let nkError = NKError(error: error)
                        
                    // 1. Log the high-level error (usually 1)
                    debugPrint("Top-level errorCode:", nkError.errorCode)

                    // 2. Check the nested error for the 409 Conflict
                    if let innerError = nkError.error as? NKError,
                       innerError.errorCode == NCGlobal.shared.errorConflict {
                        
                        // This is the "File already exists" case (409)
                        let conflictError = NKError(errorCode: NCGlobal.shared.errorConflict,
                                                    errorDescription: "_file_already_exists_")
                        NCContentPresenter().showInfo(error: conflictError)
                        
                    } else if nkError.errorCode == NCGlobal.shared.errorConflict {
                        // Fallback check if the top-level error itself is 409
                        NCContentPresenter().showInfo(error: nkError)
                    } else {
                        // Handle all other errors (Network, 404, 500, etc.)
                        NCContentPresenter().showError(error: nkError)
                    }
                }
            }
        }
    }
}

extension AlbumDetailsViewModel: AlbumActionHandler {
    func deleteMetadataFromAlbum(_ selectedMetadatas: [tableMetadata]) {
        Task {
            await self.deletePhotos(with: selectedMetadatas)
            
        }
    }
}

