// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import NextcloudKit
import UIKit

protocol AlbumActionHandler: AnyObject {
    func deleteMetadataFromAlbum(_ selectedMetadatas: [tableMetadata])
}

class AlbumDetailsViewModel: ObservableObject {
    private weak var controller: NCMainTabBarController?
    private var album: Album
    private let navigator: AlbumsNavigator

    @Published var account: String
    @Published private(set) var screenTitle: String
    @Published private(set) var photos: [AlbumPhoto] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasCachedPhotos: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var isLoadingPopupVisible: Bool = false
    @Published var isDeleteAlbumPopupVisible: Bool = false
    @Published var isRenameAlbumPopupVisible: Bool = false
    @Published var newAlbumName: String = ""
    @Published private(set) var newAlbumNameError: String?
    @Published var isPhotoSelectionSheetVisible: Bool = false

    @MainActor
    private var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    private var cancellables: Set<AnyCancellable> = []

    init(controller: NCMainTabBarController, album: Album, navigator: AlbumsNavigator) {
        self.account = controller.account
        self.controller = controller
        self.album = album
        self.navigator = navigator
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
        let trimmedName = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = validateAlbumName(trimmedName)
        if let firstError = errors.first {
            newAlbumNameError = firstError
            return
        }

        isRenameAlbumPopupVisible = false
        renameAlbum()
    }

    // MARK: - APIs
    func onPulledToRefresh() {
        loadAlbumPhotos()
    }

    private func loadAlbumPhotos() {

        guard !isLoading else { return }

        let requestedAlbum = album
        let cached = NCManageDatabase.shared.getAlbumPhotos(album: requestedAlbum)
        if let cached {
            photos = cached.map { AlbumPhoto(metadata: $0) }
        }
        hasCachedPhotos = cached != nil
        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isLoading = false }
            do {
                let photos = try await AlbumsManager.shared.refreshAlbumPhotos(requestedAlbum)
                guard self.account == requestedAlbum.account, self.album.id == requestedAlbum.id else { return }
                self.photos = photos
                self.hasCachedPhotos = true
            } catch is CancellationError {
                // A newer refresh or a successful edit superseded this response.
            } catch {
                guard self.account == requestedAlbum.account, self.album.id == requestedAlbum.id else { return }
                if !self.hasCachedPhotos {
                    self.errorMessage = NSLocalizedString("_albums_photos_error_msg_", comment: "")
                }
            }
        }
    }

    func deleteAlbum() {
        guard !isLoadingPopupVisible else { return }
        isLoadingPopupVisible = true

        let deletedAlbum = album
        NextcloudKit.shared.deleteAlbum(albumName: deletedAlbum.name, account: account) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isLoadingPopupVisible = false
                switch result {
                case .success(let account):
                    AlbumsManager.shared.invalidatePhotoRequest(for: deletedAlbum)
                    NCManageDatabase.shared.deleteAlbum(deletedAlbum)
                    AlbumsManager.shared.syncAlbums(for: account)
                    self?.navigator.pop()
                case .failure(let error):
                    // User-initiated failures must not be hidden by the network-error cooldown.
                    await showErrorBanner(windowScene: self?.windowScene, text: error.errorDescription)
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
            await showErrorBanner(windowScene: windowScene, text: error.errorDescription)
            return
        }

        photos.removeAll { $0.id == photo.id }
        persistPhotosAfterRemoval()
        AlbumsManager.shared.syncAlbums(for: account)
    }

    @MainActor
    func deletePhotos(with metadatas: [tableMetadata]) async {
        guard !isLoadingPopupVisible else { return }
        isLoadingPopupVisible = true
        defer {
            isLoadingPopupVisible = false
            AlbumsManager.shared.syncAlbums(for: account)
        }

        for metadata in metadatas where metadata.account == account {
            guard let photo = photos.first(where: { $0.metadata.fileId == metadata.fileId }) else { continue }
            let error = await deletePhotoFromAlbum(photo, metadata: metadata)
            guard error == .success else {
                await showErrorBanner(windowScene: windowScene, text: error.errorDescription)
                return
            }
            photos.removeAll { $0.id == photo.id }
            persistPhotosAfterRemoval()
        }
    }

    @MainActor
    private func persistPhotosAfterRemoval() {
        AlbumsManager.shared.invalidatePhotoRequest(for: album)
        NCManageDatabase.shared.replaceAlbumPhotos(photos.map(\.metadata), album: album)
    }

    func deletePhotoFromAlbum(_ photo: AlbumPhoto, metadata: tableMetadata) async -> NKError {
        do {
            // The album's DAV filename can differ from the original metadata filename.
            // Resolve it when deleting instead of persisting a second photo representation.
            let files: [NKFile] = try await withCheckedThrowingContinuation { continuation in
                NextcloudKit.shared.fetchAlbumPhotos(for: album.name, account: account) { result in
                    continuation.resume(with: result)
                }
            }
            guard let membership = files.first(where: {
                !$0.directory && $0.account == account && $0.fileId == photo.id
            }) else {
                return .success // Already removed from this album on the server.
            }
            try await NextcloudKit.shared.deletePhotoFromAlbumAsync(
                albumName: album.name,
                fileName: membership.fileName,
                account: account
            ) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: metadata.account,
                        path: photo.metadata.serverUrlFileName,
                        name: "deletePhotoFromAlbum"
                    )
                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task
                    )
                }
            }

            return .success

        } catch let nkError as NKError {
            if nkError.errorCode == NCGlobal.shared.errorResourceNotFound {
                return .success
            }

            if nkError.errorCode == NCGlobal.shared.errorForbidden && metadata.isLivePhotoVideo {
                return .success
            }

            return nkError

        } catch {
            return NKError(error: error)
        }
    }

    func renameAlbum() {
        guard !isLoadingPopupVisible else { return }
        isLoadingPopupVisible = true

        let name = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalAlbum = album
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isLoadingPopupVisible = false }
            do {
                let renamed = try await AlbumsManager.shared.renameAlbum(originalAlbum, to: name)
                self.album = renamed
                self.screenTitle = renamed.name
                self.newAlbumName = ""
                self.loadAlbumPhotos()
            } catch {
                self.isLoadingPopupVisible = false
                let error = (error as? NKError) ?? NKError(error: error)
                // Report every failed rename, even after another offline operation.
                await showErrorBanner(windowScene: self.windowScene, text: error.errorDescription)
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
        let group = DispatchGroup()
        var hadAnySuccess = false

        for photo in selectedPhotos {
            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(photo) else {
                Task {
                    await showErrorBanner(
                        windowScene: self.windowScene,
                        text: NKError.invalidData.errorDescription
                    )
                }
                continue
            }
            group.enter()

            NextcloudKit.shared.copyPhotoToAlbum(
                account: account,
                sourcePath: metadata.serverUrlFileName,
                albumName: album.name,
                fileName: metadata.fileName
            ) { [weak self] result in
                Task { @MainActor [weak self] in
                    defer { group.leave() }
                    switch result {
                    case .success:
                        hadAnySuccess = true
                    case .failure(let error):
                        await showErrorBanner(windowScene: self?.windowScene, text: error.errorDescription)
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoadingPopupVisible = false
                guard hadAnySuccess else { return }
                AlbumsManager.shared.invalidatePhotoRequest(for: self.album)
                self.loadAlbumPhotos()
                AlbumsManager.shared.syncAlbums(for: self.account)
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
