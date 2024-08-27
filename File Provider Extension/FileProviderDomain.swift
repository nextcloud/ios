//
//  FileProviderDomain.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/06/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
