// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class FileProviderDomain: NSObject {
    func registerDomains() {
        NSFileProviderManager.getDomainsWithCompletionHandler { fileProviderDomain, error in
            var domains: [String] = []
            let pathRelativeToDocumentStorage = NSFileProviderManager.default.documentStorageURL.absoluteString
            let tableAccounts = NCManageDatabase.shared.getAllTableAccount()

            for domain in fileProviderDomain {
                domains.append(domain.identifier.rawValue)
            }

            // Delete
            for domain in domains {
                var domainFound = false
                for tableAccount in tableAccounts {
                    guard let urlBase = NSURL(string: tableAccount.urlBase) else { continue }
                    guard let host = urlBase.host else { continue }
                    let accountDomain = tableAccount.userId + " (" + host + ")"
                    if domain == accountDomain {
                        domainFound = true
                        break
                    }
                }
                if !domainFound {
                    let fileProviderDomain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(rawValue: domain), displayName: domain, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)
                    NSFileProviderManager.remove(fileProviderDomain, completionHandler: { error in
                        if let error {
                            print("Error  domain: \(fileProviderDomain) error: \(String(describing: error))")
                        }
                    })
                }
            }

            // Add
            for tableAccount in tableAccounts {
                var domainFound = false
                guard let urlBase = NSURL(string: tableAccount.urlBase) else { continue }
                guard let host = urlBase.host else { continue }
                let accountDomain = tableAccount.userId + " (" + host + ")"
                for domain in domains {
                    if domain == accountDomain {
                        domainFound = true
                        break
                    }
                }
                if !domainFound {
                    let fileProviderDomain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(rawValue: accountDomain), displayName: accountDomain, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)
                    NSFileProviderManager.add(fileProviderDomain, completionHandler: { error in
                        if let error {
                            print("Error  domain: \(fileProviderDomain) error: \(String(describing: error))")
                        }
                    })
                }
            }
        }
    }
}
