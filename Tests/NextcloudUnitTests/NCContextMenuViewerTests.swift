// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
import NextcloudKit
@testable import Nextcloud

@Suite("Photo viewer edit menu", .serialized)
@MainActor
struct NCContextMenuViewerTests {
    private let account = "viewer-edit-menu"

    @Test("An online preview-only image offers one Edit action without downloading")
    func previewOnlyImageOffersEdit() async throws {
        try await performOnline {
            let metadata = makeImage(fileName: "photo.jpg")
            #expect(metadata.isImage)
            #expect(metadata.isModifiableWithQuickLook)
            #expect(metadata.session.isEmpty)
            #expect(metadata.status == NCGlobal.shared.metadataStatusNormal)

            let menu = try #require(viewMenu(for: metadata, webView: false))

            #expect(editActions(in: menu).count == 1)
            #expect(metadata.session.isEmpty)
            #expect(metadata.status == NCGlobal.shared.metadataStatusNormal)
            let stored = await NCManageDatabase.shared.getMetadataFromOcIdAsync(metadata.ocId)
            #expect(stored?.ocId == nil)
        }
    }

    @Test("Web view, non-images, and encrypted photos omit Edit")
    func ineligibleItemsOmitEdit() async throws {
        try await performOnline {
            let webPhoto = makeImage(fileName: "web.jpg")
            let webMenu = try #require(viewMenu(for: webPhoto, webView: true))
            #expect(editActions(in: webMenu).isEmpty)

            let video = makeImage(fileName: "clip.mov")
            video.classFile = NKTypeClassFile.video.rawValue
            video.contentType = "video/mp4"
            let videoMenu = try #require(viewMenu(for: video, webView: false))
            #expect(editActions(in: videoMenu).isEmpty)

            let folder = encryptedFolder()
            await NCManageDatabase.shared.addMetadataAsync(folder)
            let photo = makeImage(fileName: "secret.jpg", serverUrl: folder.serverUrlFileName)
            photo.e2eEncrypted = true
            let isImage = photo.isImage
            let quickLookEligible = photo.isModifiableWithQuickLook
            let encryptedMenu = viewMenu(for: photo, webView: false)
            await NCManageDatabase.shared.deleteMetadataAsync(ocId: folder.ocId)

            #expect(isImage)
            #expect(!quickLookEligible)
            #expect(editActions(in: try #require(encryptedMenu)).isEmpty)
        }
    }

    private func performOnline(_ body: () async throws -> Void) async throws {
        let networking = NCNetworking.shared
        let previousReachability = networking.networkReachability
        let previousCapabilities = networking.capabilities[account]
        networking.networkReachability = NKTypeReachability.reachableEthernetOrWiFi
        networking.capabilities[account] = NKCapabilities.Capabilities()
        defer {
            networking.networkReachability = previousReachability
            networking.capabilities[account] = previousCapabilities
        }
        try await body()
    }

    private func viewMenu(for metadata: tableMetadata, webView: Bool) -> UIMenu? {
        NCContextMenuViewer(
            metadata: metadata,
            controller: NCMainTabBarController(),
            viewController: nil,
            webView: webView,
            sender: nil
        ).viewMenu()
    }

    private func editActions(in menu: UIMenu) -> [UIAction] {
        let title = NSLocalizedString("_edit_", comment: "")
        return actions(in: menu).filter { $0.title == title }
    }

    private func actions(in element: UIMenuElement) -> [UIAction] {
        if let action = element as? UIAction {
            return [action]
        }
        guard let menu = element as? UIMenu else {
            return []
        }
        return menu.children.flatMap(actions(in:))
    }

    private func makeImage(fileName: String, serverUrl: String? = nil) -> tableMetadata {
        let metadata = tableMetadata()
        metadata.account = account
        metadata.ocId = "viewer-edit-\(fileName)"
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.classFile = NKTypeClassFile.image.rawValue
        metadata.contentType = "image/jpeg"
        metadata.size = 2048
        metadata.urlBase = "https://example.com"
        metadata.userId = "user"
        metadata.serverUrl = serverUrl ?? "https://example.com/remote.php/dav/files/user/Photos"
        metadata.serverUrlFileName = metadata.serverUrl + "/" + fileName
        return metadata
    }

    private func encryptedFolder() -> tableMetadata {
        let folder = tableMetadata()
        folder.account = account
        folder.ocId = "viewer-edit-e2ee-folder"
        folder.fileName = "Secret"
        folder.fileNameView = folder.fileName
        folder.directory = true
        folder.e2eEncrypted = true
        folder.classFile = NKTypeClassFile.directory.rawValue
        folder.urlBase = "https://example.com"
        folder.userId = "user"
        folder.serverUrl = "https://example.com/remote.php/dav/files/user"
        folder.serverUrlFileName = folder.serverUrl + "/" + folder.fileName
        return folder
    }
}
