// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WebKit

/// SVG rasterizer based on WKWebView + takeSnapshot.
///
/// Design goals:
/// - Render at the final pixel size (avoid "rasterize small then upscale").
/// - Prefer inline SVG in the DOM (avoid <img src="data:..."> rasterization path).
/// - Keep alpha edges intact (avoid trimming that kills antialiasing).
@MainActor
final class NCSVGRenderer: NSObject, WKNavigationDelegate {

    // MARK: - State

    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var webView: WKWebView?

<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> d99135d60a (svg-fix (#3990))
    // MARK: - Public API

    /// Renders an SVG into a UIImage using WKWebView snapshotting.
    ///
    /// - Parameters:
    ///   - svgData: Raw SVG data (UTF-8 expected).
    ///   - size: Target output size in *pixels* (e.g. 256x256).
    ///   - backgroundColor: Background fill behind the SVG (use .clear for transparency).
    ///   - trimTransparentPixels: If true, crops transparent borders.
    ///   - alphaThreshold: Pixels with alpha <= threshold are considered transparent during trimming.
    /// - Returns: A UIImage with sharp edges at the requested pixel size, or nil if input is nil.
    func renderSVGToUIImage(
        svgData: Data?,
        size: CGSize = CGSize(width: 256, height: 256),
        backgroundColor: UIColor = .clear,
        trimTransparentPixels: Bool = true,
        alphaThreshold: UInt8 = 0
    ) async throws -> UIImage? {
<<<<<<< HEAD
=======
    func renderSVGToUIImage(svgData: Data?,
                            size: CGSize = CGSize(width: 256, height: 256),
                            backgroundColor: UIColor = .clear,
                            trimTransparentPixels: Bool = true,
                            alphaThreshold: UInt8 = 8) async throws -> UIImage? {
>>>>>>> fd0de89732 (Fix gui svg (#3989))
=======
>>>>>>> d99135d60a (svg-fix (#3990))
        guard let svgData else {
            return nil
        }

        // Treat `size` as pixels. Convert to points for WKWebView/snapshot.
        let scale = max(UIScreen.main.scale, 1)
        let targetPixelSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        let targetPointSize = CGSize(
            width: max(1, targetPixelSize.width / scale),
            height: max(1, targetPixelSize.height / scale)
        )

        // Build a dedicated WKWebView sized in points.
        let webView = makeWebView(sizeInPoints: targetPointSize, backgroundColor: backgroundColor)
        self.webView = webView

        // Inline the SVG into the DOM to avoid <img> rasterization path.
        let html = makeHTML(svgData: svgData, canvasPointSize: targetPointSize, backgroundColor: backgroundColor)

        try await loadHTMLAsync(webView: webView, html: html)
        try await waitForInlineSVGReady(webView: webView)

        // Snapshot exactly the webView bounds; WebKit will render at device scale.
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: targetPointSize)
        config.afterScreenUpdates = true
        config.snapshotWidth = NSNumber(value: Double(targetPointSize.width))

        let snapshot = try await takeSnapshotAsync(webView: webView, configuration: config)

        // Ensure the returned image is exactly the requested pixel dimensions.
        // This is a defensive step; it should usually already match.
        let finalImage = Self.normalize(snapshot, toPixelSize: targetPixelSize, scale: scale)

        if trimTransparentPixels,
           let trimmed = Self.trimTransparentPixels(in: finalImage, alphaThreshold: alphaThreshold) {
            return trimmed
        }

        return finalImage
    }

    // MARK: - WebView / HTML

    private func makeWebView(sizeInPoints: CGSize, backgroundColor: UIColor) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: CGRect(origin: .zero, size: sizeInPoints), configuration: config)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.layer.backgroundColor = backgroundColor.cgColor
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    private func makeHTML(svgData: Data, canvasPointSize: CGSize, backgroundColor: UIColor) -> String {
        let w = Int(canvasPointSize.width.rounded(.down))
        let h = Int(canvasPointSize.height.rounded(.down))

        // Base64 payload is decoded in JS and inserted as inline SVG markup.
        let base64 = svgData.base64EncodedString()
        let cssBackground = (backgroundColor == .clear) ? "transparent" : backgroundColor.toCSSColor()

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=\(w), height=\(h), initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: \(w)px;
              height: \(h)px;
              overflow: hidden;
              background: \(cssBackground);
            }
            #container {
              width: 100%;
              height: 100%;
              display: block;
              background: \(cssBackground);
            }
            /* Make sure the inline SVG scales to fill the canvas. */
            #container svg {
              width: 100%;
              height: 100%;
              display: block;
            }
          </style>
        </head>
        <body>
          <div id="container"></div>
          <script>
            (function() {
              const container = document.getElementById('container');
              const svgText = atob('\(base64)');
              container.innerHTML = svgText;

              // Ensure a viewBox exists (better scaling behavior for many icons).
              const svg = container.querySelector('svg');
              if (svg) {
                const hasViewBox = svg.getAttribute('viewBox');
                if (!hasViewBox) {
                  const width = svg.getAttribute('width') || \(w);
                  const height = svg.getAttribute('height') || \(h);
                  svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
                }
                svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
              }
            })();
          </script>
        </body>
        </html>
        """
<<<<<<< HEAD
<<<<<<< HEAD
=======

        try await loadHTMLAsync(webView: webView, html: html)
        try await waitForImageReady(webView: webView)

        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: logicalSize)
        config.afterScreenUpdates = true

        let image = try await takeSnapshotAsync(webView: webView, configuration: config)
        // Upscale to requested target size using Core Graphics
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        if trimTransparentPixels,
           let trimmed = Self.trimTransparentPixels(in: scaled, alphaThreshold: alphaThreshold) {
            return trimmed
        }

        return scaled
>>>>>>> fd0de89732 (Fix gui svg (#3989))
=======
>>>>>>> d99135d60a (svg-fix (#3990))
    }

    private func loadHTMLAsync(webView: WKWebView, html: String) async throws {
        webView.stopLoading()

        if let pending = navigationContinuation {
            pending.resume(throwing: NSError(
                domain: "NCSVGRenderer",
                code: -22,
                userInfo: [NSLocalizedDescriptionKey: "Cancelled previous load."]
            ))
            navigationContinuation = nil
        }

        try await withCheckedThrowingContinuation { cont in
            navigationContinuation = cont
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func waitForInlineSVGReady(webView: WKWebView) async throws {
        // Wait until the inline SVG exists and has a non-zero bounding box.
        let js = """
        (function() {
          const svg = document.querySelector('#container svg');
          if (!svg) return false;
          const box = svg.getBoundingClientRect();
          return box.width > 0 && box.height > 0;
        })();
        """

        // ~3 seconds max (100 * 30ms)
        for _ in 0..<100 {
            let ready = try await webView.evaluateJavaScript(js) as? Bool
            if ready == true { return }
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        throw NSError(
            domain: "NCSVGRenderer",
            code: -24,
            userInfo: [NSLocalizedDescriptionKey: "Inline SVG not ready within timeout."]
        )
    }

    private func takeSnapshotAsync(webView: WKWebView, configuration: WKSnapshotConfiguration) async throws -> UIImage {
        try await withCheckedThrowingContinuation { cont in
            webView.takeSnapshot(with: configuration) { image, error in
                if let image {
                    cont.resume(returning: image)
                } else {
                    cont.resume(throwing: error ?? NSError(domain: "NCSVGRenderer", code: -21))
                }
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume()
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }

    // MARK: - Image helpers

    /// Ensures an image matches a requested pixel size without "double scaling" artifacts.
    /// If the snapshot already matches, it is returned unchanged.
    private static func normalize(_ image: UIImage, toPixelSize pixelSize: CGSize, scale: CGFloat) -> UIImage {
        let currentPixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)

        // Close enough: avoid any resample.
        if abs(currentPixelSize.width - pixelSize.width) < 0.5,
           abs(currentPixelSize.height - pixelSize.height) < 0.5 {
            return image
        }

        // Render in points with the intended scale, producing exactly `pixelSize` pixels.
        let targetPointSize = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetPointSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetPointSize))
        }
    }

    /// Crops transparent borders while preserving antialiased edges.
    /// To avoid clipping feathered pixels, default alphaThreshold should be 0.
    private static func trimTransparentPixels(in image: UIImage, alphaThreshold: UInt8) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var found = false

        for y in 0..<height {
            for x in 0..<width {
                let alpha = buffer[(y * bytesPerRow) + (x * 4) + 3]
                if alpha > alphaThreshold {
                    found = true
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard found else { return nil }

        // Expand by 1 pixel to preserve edge AA when threshold > 0.
        minX = max(minX - 1, 0)
        minY = max(minY - 1, 0)
        maxX = min(maxX + 1, width - 1)
        maxY = min(maxY + 1, height - 1)

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }
<<<<<<< HEAD

    private func loadHTMLAsync(webView: WKWebView, html: String) async throws {
        webView.stopLoading()

        if let pending = navigationContinuation {
            pending.resume(throwing: NSError(
                domain: "NCSVGRenderer",
                code: -22,
                userInfo: [NSLocalizedDescriptionKey: "Cancelled previous load."]
            ))
            navigationContinuation = nil
        }

        try await withCheckedThrowingContinuation { cont in
            navigationContinuation = cont
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func waitForInlineSVGReady(webView: WKWebView) async throws {
        // Wait until the inline SVG exists and has a non-zero bounding box.
        let js = """
        (function() {
          const svg = document.querySelector('#container svg');
          if (!svg) return false;
          const box = svg.getBoundingClientRect();
          return box.width > 0 && box.height > 0;
        })();
        """

        // ~3 seconds max (100 * 30ms)
        for _ in 0..<100 {
            let ready = try await webView.evaluateJavaScript(js) as? Bool
            if ready == true { return }
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        throw NSError(
            domain: "NCSVGRenderer",
            code: -24,
            userInfo: [NSLocalizedDescriptionKey: "Inline SVG not ready within timeout."]
        )
    }

    private func takeSnapshotAsync(webView: WKWebView, configuration: WKSnapshotConfiguration) async throws -> UIImage {
        try await withCheckedThrowingContinuation { cont in
            webView.takeSnapshot(with: configuration) { image, error in
                if let image {
                    cont.resume(returning: image)
                } else {
                    cont.resume(throwing: error ?? NSError(domain: "NCSVGRenderer", code: -21))
                }
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume()
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }

    // MARK: - Image helpers

    /// Ensures an image matches a requested pixel size without "double scaling" artifacts.
    /// If the snapshot already matches, it is returned unchanged.
    private static func normalize(_ image: UIImage, toPixelSize pixelSize: CGSize, scale: CGFloat) -> UIImage {
        let currentPixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)

        // Close enough: avoid any resample.
        if abs(currentPixelSize.width - pixelSize.width) < 0.5,
           abs(currentPixelSize.height - pixelSize.height) < 0.5 {
            return image
        }

        // Render in points with the intended scale, producing exactly `pixelSize` pixels.
        let targetPointSize = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetPointSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetPointSize))
        }
    }

    /// Crops transparent borders while preserving antialiased edges.
    /// To avoid clipping feathered pixels, default alphaThreshold should be 0.
    private static func trimTransparentPixels(in image: UIImage, alphaThreshold: UInt8) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var found = false

        for y in 0..<height {
            for x in 0..<width {
                let alpha = buffer[(y * bytesPerRow) + (x * 4) + 3]
                if alpha > alphaThreshold {
                    found = true
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard found else { return nil }

        // Expand by 1 pixel to preserve edge AA when threshold > 0.
        minX = max(minX - 1, 0)
        minY = max(minY - 1, 0)
        maxX = min(maxX + 1, width - 1)
        maxY = min(maxY + 1, height - 1)

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }
=======
>>>>>>> d99135d60a (svg-fix (#3990))
}
