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
            let accounts = NCManageDatabase.shared.getAllAccount()

            for domain in fileProviderDomain {
                domains.append(domain.identifier.rawValue)
            }

            // Delete
            for domain in domains {
                var domainFound = false
                for account in accounts {
                    guard let urlBase = NSURL(string: account.urlBase) else { continue }
                    guard let host = urlBase.host else { continue }
                    let accountDomain =  account.userId + " (" + host + ")"
                    if domain == accountDomain {
                        domainFound = true
                        break
                    }
                }
                if !domainFound {
                    let domainRawValue = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(rawValue: domain), displayName: domain, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)
                    NSFileProviderManager.remove(domainRawValue, completionHandler: { error in
                        if error != nil {
                            print("Error  domain: \(domainRawValue) error: \(String(describing: error))")
                        }
                    })
                }
            }

            // Add
            for account in accounts {
                var domainFound = false
                guard let urlBase = NSURL(string: account.urlBase) else { continue }
                guard let host = urlBase.host else { continue }
                let accountDomain =  account.userId + " (" + host + ")"
                for domain in domains {
                    if domain == accountDomain {
                        domainFound = true
                        break
                    }
                }
                if !domainFound {
                    let domainRawValue = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(rawValue: accountDomain), displayName: accountDomain, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)
                    NSFileProviderManager.add(domainRawValue, completionHandler: { error in
                        if error != nil {
                            print("Error  domain: \(domainRawValue) error: \(String(describing: error))")
                        }
                    })
                }
            }
        }
    }

    func removeAllDomains() {

        NSFileProviderManager.removeAllDomains { _ in }
    }
}
