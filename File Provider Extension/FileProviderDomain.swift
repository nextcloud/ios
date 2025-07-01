// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class FileProviderDomain: NSObject {
    /*
    func registerDomains() async {
        do {
            let fileProviderDomains = try await NSFileProviderManager.domains()

            var domains: [String] = []
            let pathRelativeToDocumentStorage = NSFileProviderManager.default.documentStorageURL.absoluteString
            let tableAccounts = await NCManageDatabase.shared.getAllTableAccountAsync()

            for domain in fileProviderDomains {
                domains.append(domain.identifier.rawValue)
            }

            // Delete
            for domain in domains {
                var domainFound = false
                for tableAccount in tableAccounts {
                    guard let urlBase = NSURL(string: tableAccount.urlBase),
                          let host = urlBase.host else {
                        continue
                    }
                    let accountDomain = tableAccount.userId + " (" + host + ")"

                    if domain == accountDomain {
                        domainFound = true
                        break
                    }
                }

                if !domainFound {
                    let fileProviderDomain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(rawValue: domain), displayName: domain, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)

                    do {
                        try await NSFileProviderManager.remove(fileProviderDomain)
                    } catch {
                        nkLog(error: "Error  domain: \(fileProviderDomain) error: \(error)")
                    }
                }
            }

            // Add
            for tableAccount in tableAccounts {
                var domainFound = false
                guard let urlBase = NSURL(string: tableAccount.urlBase),
                      let host = urlBase.host else {
                    continue
                }
                let accountDomain = tableAccount.userId + " (" + host + ")"
                for domain in domains {
                    if domain == accountDomain {
                        domainFound = true
                        break
                    }
                }

                if !domainFound {
                    let fileProviderDomain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(rawValue: accountDomain), displayName: accountDomain, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)

                    do {
                        try await NSFileProviderManager.add(fileProviderDomain)
                    } catch {
                        nkLog(error: "Error  domain: \(fileProviderDomain) error: \(error)")
                    }
                }
            }
        } catch {
            nkLog(error: "RegisterDomains error: \(error)")
        }
    }
    */
}
