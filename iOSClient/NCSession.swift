//
//  NCSession.swift
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

public class NCSession: NSObject {
    static let shared = NCSession()

    public class Session {
        var account: String
        var urlBase: String
        var user: String
        var userId: String
        var sceneIdentifier: String?

        init(account: String, urlBase: String, user: String, userId: String, sceneIdentifier: String? = nil) {
            self.account = account
            self.urlBase = urlBase
            self.user = user
            self.userId = userId
            self.sceneIdentifier = sceneIdentifier
        }
    }
    private var session: ThreadSafeArray<Session> = ThreadSafeArray()
    private var activeTableAccount = tableAccount()

    override private init() {}

    /// SESSION
    ///
    public func appendSession(account: String, urlBase: String, user: String, userId: String) {
        if self.session.filter({ $0.account == account }).first != nil {
            return updateSession(account, userId: userId)
        }
        self.session.append(Session(account: account, urlBase: urlBase, user: user, userId: userId))
    }

    public func updateSession(_ account: String, userId: String? = nil) {
        guard let session = self.session.filter({ $0.account == account }).first else { return }
        if let userId {
            session.userId = userId
        }
    }

    public func removeSession(account: String) {
        self.session.remove(where: { $0.account == account })
    }

    public func getSession(account: String) -> Session {
        if let domain = self.session.filter({ $0.account == account }).first {
            return domain
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }

    public func isValidSession(account: String) -> Bool {
        return !getSession(account: account).account.isEmpty
    }

    public func setSceneIdentifier(account: String, sceneIdentifier: String?) {
        if let session = self.session.filter({ $0.account == account }).first {
            session.sceneIdentifier = sceneIdentifier
        }
    }

    /// ACTIVE SESSION
    ///
    public func getActiveSession() -> Session {
        if let session = self.session.filter({ $0.account == self.activeTableAccount.account }).first {
            return session
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }

    public func isActiveSessionValid() -> Bool {
        return !getActiveSession().account.isEmpty
    }

#if !EXTENSION
    public func getActiveSession(sceneIdentifier: String) -> Session {
        if let session = self.session.filter({ $0.sceneIdentifier == sceneIdentifier }).first {
            return session
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }
    public func getActiveSession(controller: UIViewController?) -> Session {
        if let sceneIdentifier = (controller as? NCMainTabBarController)?.sceneIdentifier,
           let session = self.session.filter({ $0.sceneIdentifier == sceneIdentifier }).first {
            return session
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }
#endif

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
