// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift
import NextcloudKit

final class TableAlbum: Object {
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted(indexed: true) var account = ""
    @Persisted var href = ""
    @Persisted var lastPhotoId: String?
    @Persisted var itemCount: Int?
    @Persisted var location: String?
    @Persisted var dateRange: String?
    @Persisted var collaborators: String?
    @Persisted var photosLoaded = false
    @Persisted var photos: List<String>

    convenience init(album: NKPhotoAlbum, copyingPhotosFrom existing: TableAlbum? = nil) {
        self.init()
        primaryKey = album.id
        account = album.account
        update(from: album)
        if let existing {
            photosLoaded = existing.photosLoaded
            photos.append(objectsIn: existing.photos)
        }
    }

    /// Resolve only this account's files, returning copies detached from Realm.
    func metadatas(in realm: Realm) -> [tableMetadata] {
        photos.compactMap { ocId in
            guard let metadata = realm.object(ofType: tableMetadata.self, forPrimaryKey: ocId),
                  metadata.account == account else { return nil }
            return metadata.detachedCopy()
        }
    }

    /// Update server properties without changing the identity or cached photo references.
    func update(from album: NKPhotoAlbum) {
        href = album.href
        lastPhotoId = album.lastPhotoId
        itemCount = album.itemCount
        location = album.location
        dateRange = album.dateRange
        collaborators = album.collaborators
    }

    var album: NKPhotoAlbum {
        NKPhotoAlbum(account: account, href: href, lastPhotoId: lastPhotoId,
                     itemCount: itemCount, location: location, dateRange: dateRange,
                     collaborators: collaborators)
    }
}

extension NCManageDatabase {
    /// An empty database returns an empty list; nil means the Realm read failed.
    func getAlbums(account: String) -> [NKPhotoAlbum]? {
        core.performRealmRead { realm in
            realm.objects(TableAlbum.self).filter("account == %@", account).map(\.album)
        }
    }

    /// Reconcile this account's albums without replacing cached photo references.
    func replaceAlbums(_ albums: [NKPhotoAlbum], account: String) {
        core.performRealmWrite { realm in
            let albums = albums.filter { $0.account == account }
            let ids = albums.map(\.id)
            realm.delete(realm.objects(TableAlbum.self).filter("account == %@ AND NOT (primaryKey IN %@)", account, ids))
            for album in albums {
                if let existing = realm.object(ofType: TableAlbum.self, forPrimaryKey: album.id) {
                    existing.update(from: album)
                } else {
                    realm.add(TableAlbum(album: album))
                }
            }
        }
    }

    /// nil distinguishes photos never loaded from a successfully synchronized empty album.
    func getAlbumPhotos(album: NKPhotoAlbum) -> [tableMetadata]? {
        core.performRealmRead { realm in
            guard let entry = realm.object(ofType: TableAlbum.self, forPrimaryKey: album.id),
                  entry.photosLoaded else { return nil }
            return entry.metadatas(in: realm)
        }
    }

    func replaceAlbumPhotos(_ photos: [tableMetadata], album: NKPhotoAlbum) {
        core.performRealmWrite { realm in
            guard let entry = realm.object(ofType: TableAlbum.self, forPrimaryKey: album.id) else { return }
            var seenOcIds: Set<String> = []
            let ocIds = photos.filter {
                $0.account == album.account && !$0.ocId.isEmpty && seenOcIds.insert($0.ocId).inserted
            }.map(\.ocId)
            entry.photos.removeAll()
            entry.photos.append(objectsIn: ocIds)
            entry.photosLoaded = true
        }
    }

    func deleteAlbum(_ album: NKPhotoAlbum) {
        core.performRealmWrite { realm in
            guard let entry = realm.object(ofType: TableAlbum.self, forPrimaryKey: album.id) else { return }
            realm.delete(entry)
        }
    }

    /// A changed href requires a new primary key; transfer the cached references atomically.
    func updateAlbum(_ album: NKPhotoAlbum, previousHref: String) {
        core.performRealmWrite { realm in
            guard let existing = realm.objects(TableAlbum.self)
                .filter("account == %@ AND href == %@", album.account, previousHref).first else { return }
            if existing.primaryKey == album.id {
                existing.update(from: album)
            } else {
                let renamed = TableAlbum(album: album, copyingPhotosFrom: existing)
                realm.delete(existing)
                realm.add(renamed, update: .modified)
            }
        }
    }
}
