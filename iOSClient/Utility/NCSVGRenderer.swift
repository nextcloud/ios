// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WebKit

@MainActor
final class NCSVGRenderer: NSObject, WKNavigationDelegate {
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var webView: WKWebView?
    private let utilityFileSystem = NCUtilityFileSystem()

    func renderSVGToUIImage(svgData: Data?,
                            size: CGSize = CGSize(width: 128, height: 128),
                            backgroundColor: UIColor = .clear) async throws -> UIImage? {
        guard let svgData else {
            return nil
        }

        let targetSize = size
        let logicalSize = CGSize(width: max(1, targetSize.width / max(UIScreen.main.scale, 1)),
                                 height: max(1, targetSize.height / max(UIScreen.main.scale, 1)))

        let webView = WKWebView(frame: CGRect(origin: .zero, size: logicalSize))
        self.webView = webView

        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.layer.backgroundColor = backgroundColor.cgColor

        let cssBackground = backgroundColor == .clear ? "transparent" : backgroundColor.toCSSColor()

        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=\(Int(logicalSize.width)), height=\(Int(logicalSize.height)), initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
        <style>
        html, body {
            margin: 0;
            padding: 0;
            width: \(Int(logicalSize.width))px;
            height: \(Int(logicalSize.height))px;
            overflow: hidden;
            background: \(cssBackground);
        }

        #svgImage {
            position: absolute;
            inset: 0;
            width: 100%;
            height: 100%;
            object-fit: contain; /* preserve aspect ratio, allow bands */
            display: block;
        }
        </style>
        </head>
        <body>
        <img id="svgImage" src="data:image/svg+xml;base64,\(svgData.base64EncodedString())"/>
        </body>
        </html>
        """

        try await loadHTMLAsync(webView: webView, html: html)
        try await waitForSVGReady(webView: webView)

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
        return scaled
    }

    private func loadHTMLAsync(webView: WKWebView, html: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            navigationContinuation = cont
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func waitForImageReady(webView: WKWebView) async throws {
        let js = """
        (function() {
          const img = document.getElementById('svgImage');
          if (!img) return false;
          return img.complete && img.naturalWidth > 0 && img.naturalHeight > 0;
        })();
        """

        // wait max 3 sec.
        for _ in 0..<60 {
            let ready = try await webView.evaluateJavaScript(js) as? Bool
            if ready == true { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func waitForSVGReady(webView: WKWebView) async throws {
        let js = """
        (function() {
          const svg = document.querySelector('#svgRoot') || document.querySelector('svg');
          if (!svg) return false;
          try {
            if (svg.getBBox) {
              const bb = svg.getBBox();
              return bb && bb.width > 0 && bb.height > 0;
            }
          } catch (e) {
            // Some SVGs may throw on getBBox; consider ready if the element exists
            return true;
          }
          return true;
        })();
        """
        for _ in 0..<60 {
            let ready = try await webView.evaluateJavaScript(js) as? Bool
            if ready == true { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
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

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }
}

