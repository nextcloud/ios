//
//  AlbumsViewModel.swift
//  Nextcloud
//
//  Created by A200118228 on 08/07/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import Foundation
import Combine
import NextcloudKit

class AlbumsListViewModel: ObservableObject {
    
    private var account: String
    
    @Published private(set) var albums: [Album] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String? = nil
    
    private var thumbnailsTask: Task<Void, Never>?
    @Published private(set) var albumThumbnails: [String: UIImage] = [:]
    
    @Published var isLoadingPopupVisible: Bool = false
    
    @Published var isNewAlbumCreationPopupVisible: Bool = false
    @Published var newAlbumName: String = ""
    @Published private(set) var newAlbumNameError: String? = nil
    
    @Published var isPhotoSelectionSheetVisible: Bool = false
    @Published var newlyCreatedAlbum: Album? = nil
    
    @Published var navigationDestination: AlbumsListScreen.NavigationDestination? = nil
    
    private var cancellables: Set<AnyCancellable> = []
    private var isNavigatingToDetails: Bool = false
    
    init(account: String) {
        self.account = account
        observeAlbums()
        registerPublishers()
    }
    
    // MARK: - Subscriptions
    private func observeAlbums() {
        AlbumsManager.shared.albumsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle:
                    self?.isLoading = false
                case .loading:
                    self?.isLoading = true
                    self?.errorMessage = nil
                case .success(let albums):
                    self?.isLoading = false
                    self?.albums = albums
                case .failure:
                    self?.isLoading = false
                    self?.errorMessage = NSLocalizedString("_albums_list_error_msg_", comment: "")
                }
            }
            .store(in: &cancellables)
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
    
    // MARK: - Events
    func onAlbumClicked(_ album: Album) {
        guard !isNavigatingToDetails else { return }
        isNavigatingToDetails = true
        DispatchQueue.main.async { [weak self] in
            AlbumsNavigator.shared.push(.albumDetails(album: album))
            self?.isNavigatingToDetails = false
        }
    }
    
    // MARK: - Album name popup
    func onNewAlbumClick() {
        // Reset any previous error and open the popup with a clean state
        newAlbumNameError = nil
        isNewAlbumCreationPopupVisible = true
    }
    
    func onNewAlbumPopupCancel() {
        // Clear input and error when cancelling
        newAlbumName = ""
        newAlbumNameError = nil
        isNewAlbumCreationPopupVisible = false
    }
    
    func onNewAlbumPopupCreate() {
        // Prevent double submission while a request is in-flight
        guard !isLoadingPopupVisible else { return }

        // Trim and validate before proceeding (defensive for iOS 17 timing)
        let trimmedName = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = validateAlbumName(trimmedName)
        if let firstError = errors.first {
            newAlbumNameError = firstError
            return
        }

        // Capture the valid name, then reset UI state deterministically
        let nameToCreate = trimmedName

        // Dismiss the popup and clear the field AFTER we've captured the value
        isNewAlbumCreationPopupVisible = false
        newAlbumName = ""
        newAlbumNameError = nil

        // Kick off creation with a clean state
        createNewAlbum(for: nameToCreate)
    }
    
    // MARK: - APIs
    func onPulledToRefresh() {
        AlbumsManager.shared.syncAlbums()
    }
    
    private func createNewAlbum(for name: String) {
        
        guard !isLoadingPopupVisible else { return }
        
        isLoadingPopupVisible = true
        
        NextcloudKit.shared.createNewAlbum(for: account, albumName: name) { [weak self] result in
            
            self?.isLoadingPopupVisible = false
            
            switch result {
            case .success(_):
                
                AlbumsManager.shared.syncAlbums { [weak self] resultAlbums in
                    if let newAlbum = resultAlbums.first(where: { $0.name == name }) {
                        self?.newlyCreatedAlbum = newAlbum
                        self?.isPhotoSelectionSheetVisible = true
                    }
                }
                
            case .failure(let error):
                let nkError = NKError(error: error)
                // Prefer friendly info alert for duplicate album names (409)
                if let inner = nkError.error as? NKError, inner.errorCode == NCGlobal.shared.errorConflict {
                    let message = NSLocalizedString("_album_already_exists_", comment: "Album already exists")
                    let conflict = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: message)
                    NCContentPresenter().showInfo(error: conflict)
                } else if nkError.errorCode == NCGlobal.shared.errorConflict {
                    // Top-level conflict
                    let message = NSLocalizedString("_album_already_exists_", comment: "Album already exists")
                    let conflict = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: message)
                    NCContentPresenter().showInfo(error: conflict)
                } else {
                    // Other errors
                    NCContentPresenter().showError(error: nkError)
                }
            }
        }
    }
    
    func onPhotosSelected(selectedPhotos: [String]) {
        isPhotoSelectionSheetVisible = false
        
        guard let album = newlyCreatedAlbum else { return }
        
        if selectedPhotos.isEmpty {
            guard !isNavigatingToDetails else { return }
            isNavigatingToDetails = true
            DispatchQueue.main.async { [weak self] in
                AlbumsNavigator.shared.push(.albumDetails(album: album))
                self?.isNavigatingToDetails = false
            }
            return
        }
        
        // Batch copy operations and navigate only once after a final sync to avoid iOS 17 navigation race conditions
        let group = DispatchGroup()
        var hadAnySuccess = false
        
        for photo in selectedPhotos {
            group.enter()
            let metadata: tableMetadata? = NCManageDatabase.shared.getMetadataFromOcId(photo)
            
            NextcloudKit.shared.copyPhotoToAlbum(
                account: account,
                sourcePath: metadata?.serverUrlFileName ?? photo,
                albumName: album.name,
                fileName: metadata?.fileName ?? photo
            ) { result in
                switch result {
                case .success:
                    hadAnySuccess = true
                case .failure(let error):
                    let nkError = NKError(error: error)
                    
                    // Check nested conflict first (409), then top-level, otherwise show error
                    if let innerError = nkError.error as? NKError,
                       innerError.errorCode == NCGlobal.shared.errorConflict {
                        let conflictError = NKError(errorCode: NCGlobal.shared.errorConflict,
                                                    errorDescription: "_file_already_exists_")
                        NCContentPresenter().showInfo(error: conflictError)
                    } else if nkError.errorCode == NCGlobal.shared.errorConflict {
                        NCContentPresenter().showInfo(error: nkError)
                    } else {
                        NCContentPresenter().showError(error: nkError)
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if hadAnySuccess {
                AlbumsManager.shared.syncAlbums { _ in
                    guard !self.isNavigatingToDetails else { return }
                    self.isNavigatingToDetails = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        AlbumsNavigator.shared.push(.albumDetails(album: album))
                        self.isNavigatingToDetails = false
                    }
                }
            } else {
                guard !self.isNavigatingToDetails else { return }
                self.isNavigatingToDetails = true
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    AlbumsNavigator.shared.push(.albumDetails(album: album))
                    self.isNavigatingToDetails = false
                }
            }
        }
    }
}

