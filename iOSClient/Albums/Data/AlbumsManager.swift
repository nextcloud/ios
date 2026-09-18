// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import NextcloudKit

final class AlbumsManager {
    static let shared = AlbumsManager()
    private var account: String = ""

    // Albums publisher - Central
    private let albumsSubject = CurrentValueSubject<LoadableState<[NKPhotoAlbum]>, Never>(.idle)
    var albumsPublisher: AnyPublisher<LoadableState<[NKPhotoAlbum]>, Never> {
        albumsSubject.eraseToAnyPublisher()
    }

    private init() {}

    // MARK: - Public Methods
    func setAccount(_ acc: String) {
        self.account = acc
    }

    func syncAlbums(optionalActionOnSuccess: (([NKPhotoAlbum]) -> Void)? = nil) {
        albumsSubject.send(.loading)

        NextcloudKit.shared.fetchAllAlbums(for: account) { [weak self] result in
            switch result {
            case .success(let albums):
                self?.albumsSubject.send(.success(albums))
                optionalActionOnSuccess?(albums)
            case .failure(let error):
                self?.albumsSubject.send(.failure(error))
            }
        }
    }
}
