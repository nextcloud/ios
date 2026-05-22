// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

// MARK: - Image Viewer Content View

struct NCImageViewerContentView: View {
    let identifier: String
    let previewURL: URL?
    let fullURL: URL?
    let backgroundStyle: NCViewerBackgroundStyle

    @State private var currentImage: UIImage?
    @State private var loadedPreviewURL: URL?
    @State private var loadedFullURL: URL?
    @State private var loadedIdentifier: String?
    @State private var failedMessage: String?

    private var taskIdentifier: String {
        "\(identifier)|\(previewURL?.absoluteString ?? "")|\(fullURL?.absoluteString ?? "")"
    }

    init(identifier: String, previewURL: URL?, fullURL: URL?, backgroundStyle: NCViewerBackgroundStyle = .system) {
        self.identifier = identifier
        self.previewURL = previewURL
        self.fullURL = fullURL
        self.backgroundStyle = backgroundStyle
    }

    var body: some View {
        ZStack {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()

            if let currentImage {
                NCImageZoomView(
                    image: currentImage,
                    backgroundStyle: backgroundStyle,
                    allowsImageAnalysis: allowsImageAnalysis
                )
                .ignoresSafeArea()
            } else if let failedMessage {
                failedView(failedMessage)
            } else {
                Color.ncViewerBackground(backgroundStyle)
                    .ignoresSafeArea()
            }
        }
        .background(Color.ncViewerBackground(backgroundStyle))
        .task(id: taskIdentifier) {
            await loadBestAvailableImage()
        }
    }

    // MARK: - Views

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44, weight: .regular))

            Text("Image load failed")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(secondaryForegroundStyle)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(primaryForegroundStyle)
        .padding(24)
    }

    // MARK: - Appearance

    private var primaryForegroundStyle: Color {
        switch backgroundStyle {
        case .black:
            return .white

        case .system,
             .white,
             .custom:
            return .primary
        }
    }

    private var secondaryForegroundStyle: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.65)

        case .system,
             .white,
             .custom:
            return .secondary
        }
    }

    // MARK: - Loading

    // Decode preview first, then replace it with the full image when ready.
    @MainActor
    private func loadBestAvailableImage() async {
        let expectedIdentifier = identifier
        let expectedPreviewURL = previewURL
        let expectedFullURL = fullURL

        if loadedIdentifier != expectedIdentifier {
            currentImage = nil
            loadedPreviewURL = nil
            loadedFullURL = nil
            failedMessage = nil
            loadedIdentifier = expectedIdentifier
        }

        failedMessage = nil

        if let expectedPreviewURL,
           currentImage == nil,
           loadedPreviewURL != expectedPreviewURL {
            if let previewImage = await decodePreviewImageIfPossible(url: expectedPreviewURL) {
                guard !Task.isCancelled,
                      identifier == expectedIdentifier,
                      previewURL == expectedPreviewURL else {
                    return
                }

                loadedPreviewURL = expectedPreviewURL
                failedMessage = nil
                currentImage = previewImage

                await Task.yield()
            }
        }

        guard let expectedFullURL else {
            return
        }

        guard loadedFullURL != expectedFullURL else {
            return
        }

        if loadedPreviewURL == expectedFullURL,
           currentImage != nil {
            loadedFullURL = expectedFullURL
            return
        }

        let fullImage: UIImage?

        if isGIF(expectedFullURL) {
            fullImage = await decodeGIFImageIfPossible(url: expectedFullURL)
        } else if isSVG(expectedFullURL) {
            fullImage = await decodeSVGImageIfPossible(url: expectedFullURL)
        } else {
            fullImage = await decodeImageIfPossible(url: expectedFullURL)
        }

        guard !Task.isCancelled,
              identifier == expectedIdentifier,
              fullURL == expectedFullURL else {
            return
        }

        if let fullImage {
            loadedFullURL = expectedFullURL
            failedMessage = nil
            currentImage = fullImage
            return
        }

        if currentImage == nil {
            if isGIF(expectedFullURL) {
                failedMessage = "GIF file could not be decoded."
            } else if isSVG(expectedFullURL) {
                failedMessage = "SVG file could not be rendered."
            } else {
                failedMessage = "UIImage could not decode this file."
            }
        }
    }

    // Prepare the full image before replacing the preview.
    private func decodeImageIfPossible(url: URL) async -> UIImage? {
        guard isValidLocalFile(url: url) else {
            return nil
        }

        let path = url.path

        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                guard let image = UIImage(contentsOfFile: path) else {
                    return nil
                }

                return image.preparingForDisplay() ?? image
            }
        }.value
    }

    private func decodePreviewImageIfPossible(url: URL) async -> UIImage? {
        guard isValidLocalFile(url: url) else {
            return nil
        }

        let path = url.path

        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                UIImage(contentsOfFile: path)
            }
        }.value
    }

    private func decodeGIFImageIfPossible(url: URL) async -> UIImage? {
        guard isValidLocalFile(url: url) else {
            return nil
        }

        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                UIImage.animatedImage(withAnimatedGIFURL: url)
            }
        }.value
    }

    // SVG rendering uses WKWebView and must stay on the main actor.
    @MainActor
    private func decodeSVGImageIfPossible(url: URL) async -> UIImage? {
        guard isValidLocalFile(url: url) else {
            return nil
        }

        guard let svgData = try? Data(contentsOf: url) else {
            return nil
        }

        return try? await NCSVGRenderer().renderSVGToUIImage(
            svgData: svgData,
            size: CGSize(width: 1024, height: 1024)
        )
    }

    private func isGIF(_ url: URL?) -> Bool {
        url?.pathExtension.lowercased() == "gif"
    }

    private func isSVG(_ url: URL?) -> Bool {
        url?.pathExtension.lowercased() == "svg"
    }

    private func isValidLocalFile(url: URL) -> Bool {
        let path = url.path

        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            return false
        }

        return true
    }

    private var allowsImageAnalysis: Bool {
        let url = fullURL ?? previewURL

        guard let url else {
            return false
        }

        if isGIF(url) {
            return false
        }

        /* for now disable (marino)
        if isSVG(url) {
            return false
        }
        */

        return true
    }
}
