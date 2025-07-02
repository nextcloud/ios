// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class FileProviderDomain: NSObject {
    /// Registers a File Provider domain for the specified user and server URL, if it is not already registered.
    ///
    /// This function constructs a domain identifier using the format `"userId (host)"` based on the provided
    /// `userId` and the host extracted from `urlBase`. It checks whether a domain with this identifier is already
    /// registered in the system, and if not, registers a new `NSFileProviderDomain` pointing to the default
    /// document storage path.
    ///
    /// - Parameters:
    ///   - userId: The user identifier for the account (e.g. `"user"`).
    ///   - urlBase: The base URL of the Nextcloud server (e.g. `"https://cloud.nextcloud.com"`).
    ///
    /// - Throws: An error if the domain list cannot be retrieved or if the registration of the new domain fails.
    ///
    /// - Note: If the domain is already registered, the function does nothing.
    func ensureDomainRegistered(userId: String, urlBase: String) async throws {
        guard let urlBase = NSURL(string: urlBase),
              let host = urlBase.host else {
            return
        }
        let domainIdentifier = userId + " (" + host + ")"
        let relativePath = NCUtilityFileSystem().getPathDomain(userId: userId, host: host)
        let domains = try await NSFileProviderManager.domains()

        if domains.contains(where: { $0.identifier.rawValue == domainIdentifier }) {
            return
        }

        let newDomain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier(rawValue: domainIdentifier),
            displayName: domainIdentifier,
            pathRelativeToDocumentStorage: relativePath
        )

        try await NSFileProviderManager.add(newDomain)
    }

    /// Removes the associated File Provider domain for a specific user and server URL, if it is currently registered.
    ///
    /// This function constructs the domain identifier from the given `userId` and `urlBase`,
    /// in the format `"userId (host)"`, and attempts to find and remove the corresponding
    /// `NSFileProviderDomain` from the system.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier for the user account (e.g. `"user"`).
    ///   - urlBase: The base URL of the Nextcloud server (e.g. `"https://cloud.nextcloud.com"`).
    ///
    /// - Throws: An error if the call to `NSFileProviderManager.domains()` or `.remove(...)` fails,
    ///   or if the `urlBase` is invalid.
    ///
    /// - Note: If the domain is not currently registered, the function does nothing.
    func ensureDomainRemoved(userId: String, urlBase: String) async throws {
        guard let urlBase = NSURL(string: urlBase),
              let host = urlBase.host else {
            return
        }
        let domainIdentifier = userId + " (" + host + ")"
        let domains = try await NSFileProviderManager.domains()

        guard let domainToRemove = domains.first(where: { $0.identifier.rawValue == domainIdentifier }) else {
            return
        }

        try await NSFileProviderManager.remove(domainToRemove)
    }
}
