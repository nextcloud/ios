// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import NextcloudKit

class AlbumsListViewModel: ObservableObject {
    private let account: String
    private(set) weak var controller: NCMainTabBarController?
    let navigator: AlbumsNavigator

    @Published private(set) var albums: [Album] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var isLoadingPopupVisible: Bool = false
    @Published var isNewAlbumCreationPopupVisible: Bool = false
    @Published var newAlbumName: String = ""
    @Published private(set) var newAlbumNameError: String?
    @Published var isPhotoSelectionSheetVisible: Bool = false
    @Published var newlyCreatedAlbum: Album?

    @MainActor
    private var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    private var cancellables: Set<AnyCancellable> = []
    private var isNavigatingToDetails: Bool = false

    init(controller: NCMainTabBarController, navigator: AlbumsNavigator = AlbumsNavigator()) {
        self.account = controller.account
        self.controller = controller
        self.navigator = navigator
        observeAlbums()
        registerPublishers()
    }

    // MARK: - Subscriptions
    private func observeAlbums() {
        AlbumsManager.shared.albumsPublisher(for: account)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle:
                    self?.isLoading = false
                case .loading:
                    self?.isLoading = true
                    self?.errorMessage = nil
                case .success(let albums):
                    self?.errorMessage = nil
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
            self?.navigator.push(.albumDetails(album: album))
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
        AlbumsManager.shared.syncAlbums(for: self.account)
    }

    private func createNewAlbum(for name: String) {
        guard !isLoadingPopupVisible else { return }
        isLoadingPopupVisible = true

        NextcloudKit.shared.createNewAlbum(for: account, albumName: name) { [weak self] result in
            self?.isLoadingPopupVisible = false
            switch result {
            case .success(let account):
                AlbumsManager.shared.syncAlbums(for: account) { [weak self] resultAlbums in
                    if let newAlbum = resultAlbums.first(where: { $0.name == name }) {
                        self?.newlyCreatedAlbum = newAlbum
                        self?.isPhotoSelectionSheetVisible = true
                    }
                }
            case .failure(let error):
                Task {
                    await showErrorBanner(windowScene: self?.windowScene, text: error.errorDescription)
                }
            }
        }
    }

    func onPhotosSelected(selectedPhotos: [String]) {
        isPhotoSelectionSheetVisible = false

        guard let album = newlyCreatedAlbum else { return }

        if selectedPhotos.isEmpty {
            onAlbumClicked(album)
            return
        }

        // Batch copy operations and navigate only once after a final sync to avoid iOS 17 navigation race conditions
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

            NextcloudKit.shared.copyPhotoToAlbum(account: account, sourcePath: metadata.serverUrlFileName, albumName: album.name, fileName: metadata.fileName) { result in
                switch result {
                case .success:
                    hadAnySuccess = true
                case .failure(let error):
                    Task {
                        await showErrorBanner(windowScene: self.windowScene, text: error.errorDescription)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if hadAnySuccess {
                Task { @MainActor in
                    AlbumsManager.shared.invalidatePhotoRequest(for: album)
                    AlbumsManager.shared.syncAlbums(for: self.account) { [weak self] _ in
                        self?.onAlbumClicked(album)
                    }
                }
            } else {
                onAlbumClicked(album)
            }
        }
    }
}
