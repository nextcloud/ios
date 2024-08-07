//
//  NCDomain.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit

public class NCDomain: NSObject {
    static let shared = NCDomain()

    public struct Domain {
        var account: String
        var urlBase: String
        var user: String
        var userId: String
        var sceneIdentifier: String?
    }
    private var domain: ThreadSafeArray<Domain> = ThreadSafeArray()
    private var activeTableAccount = tableAccount()

    override private init() {}

    /// DOMAIN
    ///
    public func appendDomain(account: String, urlBase: String, user: String, userId: String) {
        if self.domain.filter({ $0.account == account }).first != nil {
            return updateDomain(account, userId: userId)
        }
        self.domain.append(Domain(account: account, urlBase: urlBase, user: user, userId: userId))
    }

    public func updateDomain(_ account: String, userId: String? = nil) {
        guard var domain = self.domain.filter({ $0.account == account }).first else { return }
        if let userId {
            domain.userId = userId
        }
    }

    public func removeDomain(account: String) {
        self.domain.remove(where: { $0.account == account })
    }

    public func getDomain(account: String) -> Domain {
        if let domain = self.domain.filter({ $0.account == account }).first {
            return domain
        }
        return Domain(account: "", urlBase: "", user: "", userId: "")
    }

    public func setSceneIdentifier(account: String, sceneIdentifier: String?) {
        if var domain = self.domain.filter({ $0.account == account }).first {
            domain.sceneIdentifier = sceneIdentifier
        }
    }

    /// ACTIVE DOMAIN
    ///
    public func getActiveDomain() -> Domain {
        if let domain = self.domain.filter({ $0.account == self.activeTableAccount.account }).first {
            return domain
        }
        return Domain(account: "", urlBase: "", user: "", userId: "")
    }

    public func isActiveDomainValid() -> Bool {
        return !getActiveDomain().account.isEmpty
    }

    /// ACTIVE TABLE ACCOUNT
    ///
    func setActiveTableAccount(_ activeTableAccount: tableAccount) {
        self.activeTableAccount = activeTableAccount
    }

    func updateTableAccount(_ tableAccount: tableAccount) {
        if self.activeTableAccount.account == tableAccount.account {
            self.activeTableAccount = tableAccount
        }
    }

    func getActiveTableAccount() -> tableAccount {
        return activeTableAccount
    }

    /// UTILITY
    ///
    public func getFileName(urlBase: String, user: String) -> String {
        let url = (URL(string: urlBase)?.host) ?? "localhost"
        let fileName = user + "@" + url + ".png"
        return fileName
    }
}
