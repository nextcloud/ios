// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    @Published private(set) var photos: [AlbumPhoto] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    @Published var isLoadingPopupVisible: Bool = false

    @Published var isDeleteAlbumPopupVisible: Bool = false

    @Published var isRenameAlbumPopupVisible: Bool = false
    @Published var newAlbumName: String = ""
    @Published private(set) var newAlbumNameError: String?

    @Published var isPhotoSelectionSheetVisible: Bool = false

    @MainActor
    private var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: SceneManager.shared.getController(account: account))
    }

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

        let requestedAccount = account
        NextcloudKit.shared.fetchAlbumPhotos(for: album.name, account: requestedAccount) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.isLoading = false }
                guard self.account == requestedAccount else { return }

                switch result {
                case .success(let files):
                    let converter = NCManageDatabaseCreateMetadata()
                    var albumPhotos: [AlbumPhoto] = []
                    var seenFileIds: Set<String> = []
                    for file in files where !file.directory && !file.fileId.isEmpty {
                        guard seenFileIds.insert(file.fileId).inserted else { continue }
                        let metadata = await converter.convertFileToMetadataAsync(file)
                        albumPhotos.append(AlbumPhoto(metadata: metadata, albumFileName: file.fileName))
                    }
                    guard self.account == requestedAccount else { return }
                    self.photos = albumPhotos
                    doOnSuccess?()

                case .failure:
                    self.errorMessage = NSLocalizedString("_albums_photos_error_msg_", comment: "")
                }
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
            case .success:
                AlbumsManager.shared.syncAlbums()
                AlbumsNavigator.shared.pop()

            case .failure(let error):
                Task { @MainActor in
                    await showErrorBanner(windowScene: self?.windowScene, error: NKError(error: error))
                }
            }
        }
    }

    @MainActor
    func removePhoto(_ photo: AlbumPhoto) async {
        guard !isLoadingPopupVisible, photos.contains(where: { $0.id == photo.id }) else { return }
        isLoadingPopupVisible = true
        defer { isLoadingPopupVisible = false }

        let error = await deletePhotoFromAlbum(photo, metadata: photo.metadata)
        guard error == .success else {
            await showErrorBanner(windowScene: windowScene, error: error)
            return
        }

        photos.removeAll { $0.id == photo.id }
        AlbumsManager.shared.syncAlbums()
    }

    @MainActor
    func deletePhotos(with metadatas: [tableMetadata]) async {
        guard !isLoadingPopupVisible else { return }
        isLoadingPopupVisible = true
        defer {
            isLoadingPopupVisible = false
            AlbumsManager.shared.syncAlbums()
        }

        for metadata in metadatas where metadata.account == account {
            guard let photo = photos.first(where: { $0.metadata.fileId == metadata.fileId }) else { continue }
            let error = await deletePhotoFromAlbum(photo, metadata: metadata)
            guard error == .success else {
                await showErrorBanner(windowScene: windowScene, error: error)
                return
            }
            photos.removeAll { $0.id == photo.id }
        }
    }

    func deletePhotoFromAlbum(_ photo: AlbumPhoto, metadata: tableMetadata) async -> NKError {
        do {
            // NKFile.fileName is already decoded; NextcloudKit encodes the album entry once.
            _ = try await NextcloudKit.shared.deletePhotoFromAlbumAsync(
                albumName: album.name,
                fileName: photo.albumFileName,
                account: account
            ) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: metadata.account,
                        path: photo.metadata.serverUrlFileName,
                        name: "deletePhotoFromAlbum"
                    )
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            return .success
        } catch {
            let nkError = (error as? NKError) ?? NKError(error: error)
            if nkError.errorCode == NCGlobal.shared.errorResourceNotFound {
                return .success
            }
            if nkError.errorCode == NCGlobal.shared.errorForbidden && metadata.isLivePhotoVideo {
                return .success
            }
            return nkError
        }
    }

    func renameAlbum() {

        guard !isLoadingPopupVisible else { return }

        isLoadingPopupVisible = true

        NextcloudKit.shared.renameAlbum(account: account, from: album.name, to: newAlbumName) { [weak self] result in

            switch result {
            case .success:
                self?.reloadAlbumAfterRenaming(albumName: self?.newAlbumName ?? "")

            case .failure(let error):
                self?.isLoadingPopupVisible = false
                let nkError = NKError(error: error)

                if nkError.errorCode == NCGlobal.shared.errorConflict {
                    let conflictError = NKError(errorCode: NCGlobal.shared.errorConflict,
                                                errorDescription: "_album_already_exists_")
                    Task { @MainActor in
                        await showInfoBanner(windowScene: self?.windowScene, text: conflictError.errorDescription, errorCode: conflictError.errorCode)
                    }
                } else if let innerError = nkError.error as? NKError,
                          innerError.errorCode == NCGlobal.shared.errorConflict {
                    let conflictError = NKError(errorCode: NCGlobal.shared.errorConflict,
                                                errorDescription: "_album_already_exists_")
                    Task { @MainActor in
                        await showInfoBanner(windowScene: self?.windowScene, text: conflictError.errorDescription, errorCode: conflictError.errorCode)
                    }
                } else {
                    Task { @MainActor in
                        await showErrorBanner(windowScene: self?.windowScene, error: nkError)
                    }
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
                        Task { @MainActor in
                            await showInfoBanner(windowScene: self?.windowScene, text: conflictError.errorDescription, errorCode: conflictError.errorCode)
                        }

                    } else if nkError.errorCode == NCGlobal.shared.errorConflict {
                        // Fallback check if the top-level error itself is 409
                        Task { @MainActor in
                            await showInfoBanner(windowScene: self?.windowScene, text: nkError.errorDescription, errorCode: nkError.errorCode)
                        }
                    } else {
                        // Handle all other errors (Network, 404, 500, etc.)
                        Task { @MainActor in
                            await showErrorBanner(windowScene: self?.windowScene, error: nkError)
                        }
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
