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

        init(account: String, urlBase: String, user: String, userId: String) {
            self.account = account
            self.urlBase = urlBase
            self.user = user
            self.userId = userId
        }
    }
    private var sessions: ThreadSafeArray<Session> = ThreadSafeArray()
    private var activeTableAccount = tableAccount()
    private var sceneIdentifierAccount: [String: String] = [:]

    override private init() {}

    /// SESSION
    ///
    public func appendSession(account: String, urlBase: String, user: String, userId: String) {
        if sessions.filter({ $0.account == account }).first != nil {
            return updateSession(account, userId: userId)
        }
        self.sessions.append(Session(account: account, urlBase: urlBase, user: user, userId: userId))
    }

    public func updateSession(_ account: String, userId: String? = nil) {
        guard let session = sessions.filter({ $0.account == account }).first else { return }
        if let userId {
            session.userId = userId
        }
    }

    public func removeSession(account: String) {
        sessions.remove(where: { $0.account == account })
    }

    public func getSession(account: String) -> Session {
        if let domain = sessions.filter({ $0.account == account }).first {
            return domain
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }

#if !EXTENSION
    public func getSession(sceneIdentifier: String) -> Session {
        if let account = sceneIdentifierAccount[sceneIdentifier] {
            return getSession(account: account)
        }
        return getActiveSession()
    }
    public func getSession(controller: UIViewController?) -> Session {
        if let sceneIdentifier = (controller as? NCMainTabBarController)?.sceneIdentifier,
           let account = sceneIdentifierAccount[sceneIdentifier] {
            return getSession(account: account)
        }
        return getActiveSession()
    }
#endif

    public func isValidSession(_ session: NCSession.Session) -> Bool {
        return !session.account.isEmpty
    }

    public func setSceneIdentifier(account: String, sceneIdentifier: String) {
        sceneIdentifierAccount[sceneIdentifier] = account
    }

    public func removeSceneIdentifier(sceneIdentifier: String) {
        sceneIdentifierAccount[sceneIdentifier] = nil

    }

    /// ACTIVE SESSION
    ///
    public func getActiveSession() -> Session {
        if let session = sessions.filter({ $0.account == self.activeTableAccount.account }).first {
            return session
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }

    public func isActiveSessionValid() -> Bool {
        return !getActiveSession().account.isEmpty
    }

    /// ACTIVE TABLE ACCOUNT / SCENEIDENTIFIER
    ///
    func setActiveTableAccount(_ activeTableAccount: tableAccount, sceneIdentifier: String?) {
        self.activeTableAccount = activeTableAccount
        if let sceneIdentifier {
            sceneIdentifierAccount[sceneIdentifier] = activeTableAccount.account
        }
    }

    /// UTILITY
    ///
    public func getFileName(urlBase: String, user: String) -> String {
        let url = (URL(string: urlBase)?.host) ?? "localhost"
        let fileName = user + "@" + url + ".png"
        return fileName
    }
}
