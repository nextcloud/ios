// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import NextcloudKit

// Subject access is locked; refresh state is isolated to the main actor.
final class AlbumsManager: @unchecked Sendable {
    static let shared = AlbumsManager()
    private let lock = NSLock()
    private var albumsSubjects: [String: CurrentValueSubject<LoadableState<[NKPhotoAlbum]>, Never>] = [:]

    @MainActor private var photoSyncTasks: [String: Task<Void, Never>] = [:]
    @MainActor private var photoRequests: [String: (id: UUID, task: Task<Void, Error>)] = [:]
    @MainActor private var albumRequests: [String: UUID] = [:]
    // Successful server renames awaiting an authoritative album-list response.
    @MainActor private var pendingRenames: [String: [String: String]] = [:]

    private init() {}

    func albumsPublisher(for account: String) -> AnyPublisher<LoadableState<[NKPhotoAlbum]>, Never> {
        albumsSubject(for: account).eraseToAnyPublisher()
    }

    func syncAlbums(for account: String, optionalActionOnSuccess: (([NKPhotoAlbum]) -> Void)? = nil) {
        Task { @MainActor in
            guard let albums = try? await refreshAlbums(for: account) else { return }
            optionalActionOnSuccess?(albums)
        }
    }

    @MainActor
    private func refreshAlbums(for account: String) async throws -> [NKPhotoAlbum] {
        let subject = albumsSubject(for: account)
        let database = NCManageDatabase.shared
        subject.send(database.getAlbums(account: account).map { .success($0) } ?? .loading)

        let request = UUID()
        albumRequests[account] = request
        photoSyncTasks[account]?.cancel()
        defer {
            if albumRequests[account] == request { albumRequests[account] = nil }
        }

        do {
            let albums: [NKPhotoAlbum] = try await withCheckedThrowingContinuation { continuation in
                NextcloudKit.shared.fetchAllAlbums(for: account) { continuation.resume(with: $0) }
            }
            guard albumRequests[account] == request else { throw CancellationError() }
            guard database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) != nil else {
                subject.send(.idle)
                throw CancellationError()
            }

            // Apply server-confirmed renames before reconciling the list to keep cached photos.
            for (previousHref, name) in pendingRenames[account] ?? [:] {
                if let renamed = albums.first(where: { $0.account == account && $0.name == name }) {
                    database.updateAlbum(renamed, previousHref: previousHref)
                    pendingRenames[account]?[previousHref] = nil
                }
            }
            database.replaceAlbums(albums, account: account)
            subject.send(.success(database.getAlbums(account: account) ?? albums))
            photoSyncTasks[account] = Task { @MainActor in
                for album in albums {
                    guard !Task.isCancelled else { return }
                    _ = try? await self.refreshAlbumPhotos(album)
                }
            }
            return albums
        } catch {
            // An obsolete response must not change the state of a newer refresh.
            guard albumRequests[account] == request, !(error is CancellationError) else { throw CancellationError() }
            let error = (error as? NKError) ?? NKError(error: error)
            subject.send(database.getAlbums(account: account).map { .success($0) } ?? .failure(error))
            throw error
        }
    }

    @MainActor
    func renameAlbum(_ album: NKPhotoAlbum, to name: String) async throws -> NKPhotoAlbum {
        let _: String = try await withCheckedThrowingContinuation { continuation in
            NextcloudKit.shared.renameAlbum(account: album.account, from: album.name, to: name) {
                continuation.resume(with: $0)
            }
        }
        invalidatePhotoRequest(for: album)
        pendingRenames[album.account, default: [:]][album.href] = name
        let albums = try await refreshAlbums(for: album.account)
        guard let renamed = albums.first(where: { $0.account == album.account && $0.name == name }) else {
            throw NKError.invalidData
        }
        return renamed
    }

    /// The detail screen and background synchronization share the same persistence path.
    @MainActor
    func refreshAlbumPhotos(_ album: NKPhotoAlbum) async throws -> [AlbumPhoto] {
        if let existing = photoRequests[album.id] {
            try await existing.task.value
            return try cachedPhotos(for: album)
        }
        let request = UUID()
        let task = Task { @MainActor in
            try await self.fetchAndSaveAlbumPhotos(album)
        }
        photoRequests[album.id] = (request, task)
        defer {
            if photoRequests[album.id]?.id == request { photoRequests[album.id] = nil }
        }
        try await task.value
        return try cachedPhotos(for: album)
    }

    @MainActor
    private func fetchAndSaveAlbumPhotos(_ album: NKPhotoAlbum) async throws {
        let files: [NKFile] = try await withCheckedThrowingContinuation { continuation in
            NextcloudKit.shared.fetchAlbumPhotos(for: album.name, account: album.account) { result in
                continuation.resume(with: result)
            }
        }
        try Task.checkCancellation()
        let database = NCManageDatabase.shared
        var metadatas: [tableMetadata] = []
        var seenFileIds: Set<String> = []
        for file in files where file.account == album.account && !file.directory && !file.fileId.isEmpty {
            guard seenFileIds.insert(file.fileId).inserted else { continue }
            // Album DAV paths must never replace the original file's path in tableMetadata.
            let metadata: tableMetadata
            if let existing = await database.getMetadataAsync(predicate: NSPredicate(format: "account == %@ AND fileId == %@", album.account, file.fileId)) {
                metadata = existing
            } else {
                let result = await NextcloudKit.shared.getFileFromFileIdAsync(fileId: file.fileId, account: album.account)
                guard result.error == .success else { throw result.error }
                guard let original = result.file, original.account == album.account, original.fileId == file.fileId else {
                    throw NKError.invalidData
                }
                metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(original)
                try Task.checkCancellation()
                guard !metadata.ocId.isEmpty else { throw NKError.invalidData }
                await database.addMetadataAsync(metadata)
            }
            metadatas.append(metadata)
        }
        try Task.checkCancellation()
        database.replaceAlbumPhotos(metadatas, album: album)
    }

    @MainActor
    private func cachedPhotos(for album: NKPhotoAlbum) throws -> [AlbumPhoto] {
        guard let cached = NCManageDatabase.shared.getAlbumPhotos(album: album) else {
            throw NKError.invalidData
        }
        return cached.map { AlbumPhoto(metadata: $0) }
    }

    @MainActor
    func invalidatePhotoRequest(for album: NKPhotoAlbum) {
        // Called after a successful edit: a list response started before that edit
        // must not restore a deleted album or its old name/count.
        albumRequests[album.account] = nil
        photoRequests[album.id]?.task.cancel()
        photoRequests[album.id] = nil
    }

    private func albumsSubject(for account: String) -> CurrentValueSubject<LoadableState<[NKPhotoAlbum]>, Never> {
        lock.lock()
        defer { lock.unlock() }

        if let albumsSubject = albumsSubjects[account] {
            return albumsSubject
        }

        let cached = NCManageDatabase.shared.getAlbums(account: account)
        let initialState: LoadableState<[NKPhotoAlbum]> = cached.map { .success($0) } ?? .idle
        let albumsSubject = CurrentValueSubject<LoadableState<[NKPhotoAlbum]>, Never>(initialState)
        albumsSubjects[account] = albumsSubject
        return albumsSubject
    }
}
