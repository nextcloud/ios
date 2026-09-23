// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift
import Testing
@testable import Nextcloud

@Suite("Album persistence")
struct NCAlbumsPersistenceTests {
    private func configuration(fileURL: URL? = nil) -> Realm.Configuration {
        Realm.Configuration(
            fileURL: fileURL,
            inMemoryIdentifier: fileURL == nil ? UUID().uuidString : nil,
            objectTypes: [TableAlbum.self, tableMetadata.self, tableMetadataTag.self, NCKeyValue.self]
        )
    }

    private func makePhoto() -> tableMetadata {
        let metadata = tableMetadata()
        metadata.account = "account"
        metadata.fileId = "42"
        metadata.ocId = "00000042instance"
        metadata.fileName = "original.heic"
        metadata.serverUrl = "https://example.com/remote.php/dav/files/user/Photos"
        metadata.serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        return metadata
    }

    @Test("References resolve current metadata and ignore another account's files")
    func metadataReference() throws {
        let realm = try Realm(configuration: configuration())
        let original = makePhoto()
        let album = TableAlbum(album: NKPhotoAlbum(account: original.account, href: "/albums/Holiday/"))
        album.photos.append(original.ocId)
        #expect(album.metadatas(in: realm).isEmpty)
        try realm.write { realm.add(original) }
        let resolved = try #require(album.metadatas(in: realm).first)
        #expect(resolved.realm == nil)
        #expect(resolved.serverUrlFileName == original.serverUrlFileName)
        try realm.write { original.fileNameView = "renamed.heic" }
        #expect(album.metadatas(in: realm).first?.fileNameView == "renamed.heic")
        let other = TableAlbum(album: NKPhotoAlbum(account: "other", href: album.href))
        other.photos.append(original.ocId)
        #expect(other.metadatas(in: realm).isEmpty)
    }

    @Test("Account cleanup deletes only its albums, leaving files and other accounts intact")
    func accountIsolation() throws {
        let realm = try Realm(configuration: configuration())
        let original = makePhoto()
        let first = TableAlbum(album: NKPhotoAlbum(account: original.account, href: "/albums/Holiday/"))
        let second = TableAlbum(album: NKPhotoAlbum(account: "other", href: first.href))
        first.photos.append(original.ocId)
        try realm.write {
            realm.add(original)
            realm.add([first, second])
        }
        #expect(first.primaryKey != second.primaryKey)
        try realm.write {
            realm.delete(realm.objects(TableAlbum.self).filter("account == %@", original.account))
        }
        #expect(first.isInvalidated)
        #expect(!second.isInvalidated)
        #expect(!original.isInvalidated)
        #expect(realm.objects(TableAlbum.self).count == 1)
    }

    @Test("A renamed album gets a new primary key while keeping its photo references")
    func renamePreservesReferences() throws {
        let realm = try Realm(configuration: configuration())
        let original = NKPhotoAlbum(account: "account", href: "/albums/Old/")
        let renamed = NKPhotoAlbum(account: original.account, href: "/albums/New%20name/", itemCount: 1)
        let entry = TableAlbum(album: original)
        entry.photos.append("00000042instance")
        entry.photosLoaded = true
        try realm.write { realm.add(entry) }
        try realm.write {
            let replacement = TableAlbum(album: renamed, copyingPhotosFrom: entry)
            realm.delete(entry)
            realm.add(replacement, update: .modified)
        }
        #expect(realm.object(ofType: TableAlbum.self, forPrimaryKey: original.id) == nil)
        let saved = try #require(realm.object(ofType: TableAlbum.self, forPrimaryKey: renamed.id))
        #expect(saved.album == renamed)
        #expect(saved.photosLoaded)
        #expect(Array(saved.photos) == ["00000042instance"])
        try realm.write { saved.update(from: NKPhotoAlbum(account: renamed.account, href: renamed.href, itemCount: 2)) }
        #expect(saved.itemCount == 2)
        #expect(saved.photos.count == 1)
    }

    @Test("Albums and photo references survive reopening the database")
    func reopenReferences() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = configuration(fileURL: folder.appendingPathComponent("albums.realm"))
        let album = NKPhotoAlbum(account: "account", href: "/albums/Holiday%20photos/", lastPhotoId: "42", itemCount: 1)
        try autoreleasepool {
            let realm = try Realm(configuration: configuration)
            let original = makePhoto()
            let entry = TableAlbum(album: album)
            entry.photos.append(original.ocId)
            entry.photosLoaded = true
            try realm.write {
                realm.add(original)
                realm.add(entry)
            }
        }
        try autoreleasepool {
            let realm = try Realm(configuration: configuration)
            let entry = try #require(realm.object(ofType: TableAlbum.self, forPrimaryKey: album.id))
            #expect(entry.album == album)
            #expect(entry.photosLoaded)
            #expect(entry.photos.first == "00000042instance")
            #expect(entry.metadatas(in: realm).first?.fileName == "original.heic")
            try realm.write { entry.photos.removeAll() }
            #expect(entry.photosLoaded)
            #expect(entry.photos.isEmpty)
        }
    }
}
