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

    func renderSVGToUIImage(svgData: Data,
                            size: CGSize,
                            fileName: String,
                            backgroundColor: UIColor = .clear) async throws -> UIImage {
        // try to get from directoryUserData
        let fileName = fileName.replacingOccurrences(of: ".svg", with: ".png")
        let path = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: fileName)
        if FileManager.default.fileExists(atPath: path) {
            do {
                let url = URL(fileURLWithPath: path)
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    return image
                }
            } catch { }
        }

        let webView = WKWebView(frame: CGRect(origin: .zero, size: size))
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
        <meta name="viewport" content="width=\(Int(size.width)), height=\(Int(size.height)), initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
        <style>
        html, body {
            margin: 0;
            padding: 0;
            width: \(Int(size.width))px;
            height: \(Int(size.height))px;
            overflow: hidden;
            background: \(cssBackground);
        }

        #svgImage {
            position: absolute;
            left: 0;
            top: 0;
            width: \(Int(size.width))px;
            height: \(Int(size.height))px;
        }
        </style>
        </head>
        <body>
        <img id="svgImage"
             src="data:image/svg+xml;base64,\(svgData.base64EncodedString())"/>
        </body>
        </html>
        """

        try await loadHTMLAsync(webView: webView, html: html)
        try await waitForImageReady(webView: webView)

        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: size)

        let image = try await takeSnapshotAsync(webView: webView, configuration: config)
        if let data = image.pngData() {
            try data.write(to: URL(fileURLWithPath: path))
        }

        return image
    }

    func xx(path: String) async throws -> UIImage? {
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let image = UIImage(data: data)
            return image
        } catch {
            print("SVG render failed: \(error)")
            return nil
        }
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
