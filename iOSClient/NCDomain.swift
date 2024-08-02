//
//  NCDomain.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
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

public class NCDomain: NSObject {
    static let shared = NCDomain()

    public struct Domain {
        var account: String
        var urlBase: String
        var user: String
        var userId: String
        var sceneIdentifier: String
    }
    var domain: ThreadSafeArray<Domain> = ThreadSafeArray()

    func addDomain(account: String, urlBase: String, user: String, userId: String, sceneIdentifier: String) {
        if self.domain.filter({ $0.account == account }).first != nil {
            return updateDomain(account, userId: userId, sceneIdentifier: sceneIdentifier)
        }
        self.domain.append(Domain(account: account, urlBase: urlBase, user: user, userId: userId, sceneIdentifier: sceneIdentifier))
    }

    func updateDomain(_ account: String, userId: String? = nil, sceneIdentifier: String? = nil) {
        guard var domain = self.domain.filter({ $0.account == account }).first else { return }
        if let userId {
            domain.userId = userId
        }
        if let sceneIdentifier {
            domain.sceneIdentifier = sceneIdentifier
        }
    }

    func getActiveAccount() -> Domain? {
        if let activeAccount = NCManageDatabase.shared.getActiveStringAccount(),
           let domain = self.domain.filter({ $0.account == activeAccount }).first {
            return domain
        }
        return nil
    }
}
