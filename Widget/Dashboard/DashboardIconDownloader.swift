// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import NextcloudKit

nonisolated enum DashboardIconDownloader {
    static func download(from url: URL, account: String) async -> Data? {
        guard let (session, headers, redirector) = dashboardIconRequest(for: url, account: account) else { return nil }
        let response = await session.request(url, headers: headers)
            .redirect(using: redirector)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        guard headers != nil, let destination = Self.dashboardIconRedirect(from: response.response) else { return response.value }
        return try? await AF.request(destination)
            .validate(statusCode: 200..<300)
            .serializingData()
            .value
    }

    static func download(from url: URL, account: String, to destination: URL) async -> URL? {
        guard let (session, headers, redirector) = dashboardIconRequest(for: url, account: account) else { return nil }
        let target: DownloadRequest.Destination = { _, _ in (destination, [.removePreviousFile]) }
        let response = await session.download(url, headers: headers, to: target)
            .redirect(using: redirector)
            .validate(statusCode: 200..<300)
            .serializingDownloadedFileURL()
            .response
        guard headers != nil, let redirectedURL = Self.dashboardIconRedirect(from: response.response) else { return response.value }
        return try? await AF.download(redirectedURL, to: target)
            .validate(statusCode: 200..<300)
            .serializingDownloadedFileURL()
            .value
    }

    private static func dashboardIconRequest(for url: URL, account: String) -> (Session, HTTPHeaders?, Redirector)? {
        let networking = NextcloudKit.shared.nkCommonInstance
        guard let session = networking.nksessions.session(forAccount: account),
              let serverURL = URL(string: session.urlBase),
              let serverOrigin = Self.dashboardCredentialOrigin(serverURL),
              let iconOrigin = Self.dashboardCredentialOrigin(url) else { return nil }

        // External icons can be public. Only attach account headers to the account's origin.
        guard iconOrigin == serverOrigin else {
            return (.default, nil, Redirector(behavior: .follow))
        }
        guard let headers = networking.getStandardHeaders(account: account) else { return nil }

        let redirector = Redirector(behavior: .modify { _, request, _ in
            request.url.flatMap(Self.dashboardCredentialOrigin) == serverOrigin ? request : nil
        })

        return (session.sessionData, headers, redirector)
    }

    private nonisolated static func dashboardIconRedirect(from response: HTTPURLResponse?) -> URL? {
        guard let response, (300..<400).contains(response.statusCode),
              let location = response.value(forHTTPHeaderField: "Location"),
              let destination = URL(string: location, relativeTo: response.url)?.absoluteURL,
              dashboardCredentialOrigin(destination) != nil else { return nil }
        return destination
    }

    private nonisolated static func dashboardCredentialOrigin(_ url: URL) -> URLComponents? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        var origin = URLComponents()
        origin.scheme = scheme
        origin.host = host
        origin.port = url.port ?? (scheme == "https" ? 443 : 80)
        return origin
    }
}
