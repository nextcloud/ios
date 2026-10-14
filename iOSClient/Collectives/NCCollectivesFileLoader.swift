// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import ImageIO
import NextcloudKit

/// Loads embedded images for display and downloads files for Quick Look.
final class NCCollectivesFileLoader: @unchecked Sendable {
    static let shared = NCCollectivesFileLoader()

    // NSCache is thread-safe and evicts images under memory pressure.
    private let cache = NSCache<NSString, UIImage>()
    private let networking = NCCollectivesNetworking.shared
    private let previewSize = 2048

    private func cacheKey(_ embed: NCCollectivesEmbed, account: String) -> NSString {
        "\(account)|\(embed.attachment.map { "\($0.id)-\($0.filesize)" } ?? embed.relativePath ?? embed.source)" as NSString
    }

    func cachedImage(for embed: NCCollectivesEmbed, account: String) -> UIImage? {
        cache.object(forKey: cacheKey(embed, account: account))
    }

    /// An image scaled down to at most `previewSize` pixels, using the server preview when available.
    func image(for embed: NCCollectivesEmbed, account: String) async -> UIImage? {
        let key = cacheKey(embed, account: account)
        if let image = cache.object(forKey: key) {
            return image
        }
        var data: Data?
        if let attachment = embed.attachment, attachment.hasPreview,
           case .success(let preview) = await networking.preview(fileId: attachment.id, size: previewSize, account: account) {
            data = preview
        }
        if data == nil {
            data = try? await originalData(for: embed, account: account).get()
        }
        guard let data, let image = downsample(data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Downloads the original file into a temporary folder, keeping its name for Quick Look.
    func localFile(for embed: NCCollectivesEmbed, account: String) async -> Result<URL, NKError> {
        switch await originalData(for: embed, account: account) {
        case .success(let data):
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("Collectives", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let name = (embed.name as NSString).lastPathComponent
            let url = folder.appendingPathComponent(name.isEmpty ? "file" : name)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: url, options: .completeFileProtection)
                return .success(url)
            } catch {
                return .failure(NKError(error: error))
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    private func originalData(for embed: NCCollectivesEmbed, account: String) async -> Result<Data, NKError> {
        if let relativePath = embed.relativePath {
            return await networking.download(relativePath: relativePath, account: account)
        }
        guard let remoteURL = embed.remoteURL else {
            return .failure(.invalidData)
        }
        do {
            return .success(try await URLSession.shared.data(from: remoteURL).0)
        } catch {
            return .failure(NKError(error: error))
        }
    }

    private func downsample(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: previewSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: image)
    }
}
