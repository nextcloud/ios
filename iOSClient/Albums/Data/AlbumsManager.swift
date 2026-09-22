// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import NextcloudKit

final class AlbumsManager {
    static let shared = AlbumsManager()
    private let lock = NSLock()
    private var albumsSubjects: [String: CurrentValueSubject<LoadableState<[NKPhotoAlbum]>, Never>] = [:]

    private init() {}

    func albumsPublisher(for account: String) -> AnyPublisher<LoadableState<[NKPhotoAlbum]>, Never> {
        albumsSubject(for: account).eraseToAnyPublisher()
    }

    func syncAlbums(for account: String, optionalActionOnSuccess: (([NKPhotoAlbum]) -> Void)? = nil) {
        let albumsSubject = albumsSubject(for: account)
        albumsSubject.send(.loading)

        NextcloudKit.shared.fetchAllAlbums(for: account) { result in
            switch result {
            case .success(let albums):
                albumsSubject.send(.success(albums))
                optionalActionOnSuccess?(albums)
            case .failure(let error):
                albumsSubject.send(.failure(error))
            }
        }
    }

    private func albumsSubject(for account: String) -> CurrentValueSubject<LoadableState<[NKPhotoAlbum]>, Never> {
        lock.lock()
        defer { lock.unlock() }

        if let albumsSubject = albumsSubjects[account] {
            return albumsSubject
        }

        let albumsSubject = CurrentValueSubject<LoadableState<[NKPhotoAlbum]>, Never>(.idle)
        albumsSubjects[account] = albumsSubject
        return albumsSubject
    }
}
