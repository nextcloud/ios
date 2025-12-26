// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

struct NCLoginGrant {
    let urlBase: String
    let loginName: String
    let appPassword: String
}

final class NCLoginFlowPoller {
    private var pollingTask: Task<Void, Never>?

    func start(token: String, endpoint: String, onGrant: @escaping @MainActor (NCLoginGrant) async -> Void) {
        cancel()

        let options = NKRequestOptions(customUserAgent: userAgent)
        nkLog(start: "Starting polling at \(endpoint) with token \(token)")

        pollingTask = Task { [weak self] in
            guard let self else { return }
            defer { self.pollingTask = nil }

            guard let grantValues = await self.waitForGrant(token: token, endpoint: endpoint, options: options) else {
                return
            }

            await onGrant(grantValues)
            nkLog(debug: "Login flow polling task completed.")
        }

        nkLog(debug: "Login flow polling task created.")
    }

    func cancel() {
        guard pollingTask != nil else {
            return
        }

        nkLog(debug: "Cancelling login polling task...")
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func waitForGrant(token: String, endpoint: String, options: NKRequestOptions) async -> NCLoginGrant? {
        var grantValues: NCLoginGrant?

        repeat {
            guard !Task.isCancelled else {
                nkLog(debug: "Login polling task cancelled before receiving grant values.")
                return nil
            }

            grantValues = await pollOnce(token: token, endpoint: endpoint, options: options)
            if grantValues == nil {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // .seconds() is not supported on iOS 15 yet.
            }
        } while grantValues == nil

        return grantValues
    }

    private func pollOnce(token: String, endpoint: String, options: NKRequestOptions) async -> NCLoginGrant? {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.getLoginFlowV2Poll(token: token, endpoint: endpoint, options: options) { server, loginName, appPassword, _, error in

                guard error == .success else {
                    nkLog(error: "Login poll result for token \"\(token)\" is not successful!")
                    continuation.resume(returning: nil)
                    return
                }

                guard let urlBase = server else {
                    nkLog(error: "Login poll response field for server for token \"\(token)\" is nil!")
                    continuation.resume(returning: nil)
                    return
                }

                guard let user = loginName else {
                    nkLog(error: "Login poll response field for user name for token \"\(token)\" is nil!")
                    continuation.resume(returning: nil)
                    return
                }

                guard let password = appPassword else {
                    nkLog(error: "Login poll response field for app password for token \"\(token)\" is nil!")
                    continuation.resume(returning: nil)
                    return
                }

                nkLog(debug: "Returning login poll response for \"\(user)\" on \"\(urlBase)\" for token \"\(token)\".")
                continuation.resume(returning: NCLoginGrant(urlBase: urlBase, loginName: user, appPassword: password))
            }
        }
    }
}
