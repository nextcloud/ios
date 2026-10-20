// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import UIKit
import NextcloudKit

/// Offline canvas data. Never reads the database, contacts a server or downloads media.
struct NCMediaViewerPreviewLoader: NCMediaViewerLoading {
    let imageURL: URL?

    func metadata(for ocId: String, account: String) async -> tableMetadata? { nil }
    func localMediaURL(for metadata: tableMetadata) async -> URL? { nil }
    func previewURL(for metadata: tableMetadata, ext: String) async -> URL? { imageURL }
    func downloadMedia(for metadata: tableMetadata, onDownloadStarted: (@Sendable () async -> Void)?) async throws -> URL { throw URLError(.unsupportedURL) }
    func localLivePhotoURL(for metadata: tableMetadata) async -> URL? { nil }
    func downloadLivePhotoMedia(for metadata: tableMetadata) async -> URL? { nil }
    func cancelDownload(for ocId: String) async { }
    func cancelLivePhotoMediaDownload(for metadata: tableMetadata) async { }
    func cancelAllDownloads() async { }

    @MainActor
    static func makeModel(classFile: String) -> NCMediaViewerModel {
        let types = [NKTypeClassFile.image.rawValue, NKTypeClassFile.audio.rawValue, NKTypeClassFile.video.rawValue]
        let selectedIndex = types.firstIndex(of: classFile) ?? 0
        let items = (0..<12).map { index -> tableMetadata in
            let metadata = tableMetadata()
            metadata.ocId = "canvas-media-\(index)"
            metadata.classFile = types[index % types.count]
            metadata.fileName = ["Waterfall.jpg", "Waterfall.m4a", "Waterfall.mp4"][index % types.count]
            metadata.fileNameView = metadata.fileName
            metadata.size = 3_200_000
            if metadata.classFile == NKTypeClassFile.image.rawValue {
                metadata.width = 3000
                metadata.height = 2002
            }
            return metadata
        }
        var imageURL: URL?
        if let data = UIImage(named: "testimage")?.jpegData(compressionQuality: 0.8) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("nc-media-canvas.jpg")
            if (try? data.write(to: url, options: .atomic)) != nil { imageURL = url }
        }
        let model = NCMediaViewerModel(
            currentMetadata: items[selectedIndex], ocIds: items.map(\.ocId),
            session: NCSession.Session(account: "", urlBase: "", user: "", userId: ""),
            loader: NCMediaViewerPreviewLoader(imageURL: imageURL)
        )
        for (index, metadata) in items.enumerated() {
            let page = model.pageModel(at: index)
            page?.metadata = metadata
            if metadata.classFile == NKTypeClassFile.audio.rawValue {
                page?.state = .audio(localURL: URL(fileURLWithPath: "/canvas-audio.m4a"), previewURL: imageURL)
            }
        }
        return model
    }
}
#endif
