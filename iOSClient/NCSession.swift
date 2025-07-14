// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

final class NCSession: @unchecked Sendable {
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

    // SESSION
    //
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

    public func getSession(account: String?) -> Session {
        if let session = sessions.filter({ $0.account == account }).first {
            return session
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }

#if !EXTENSION
    public func getSession(controller: UIViewController?) -> Session {
        if let account = (controller as? NCMainTabBarController)?.account {
            return getSession(account: account)
        } else if let tableAccount = NCManageDatabase.shared.getActiveTableAccount() {
            return getSession(account: tableAccount.account)
        }
        return Session(account: "", urlBase: "", user: "", userId: "")
    }
#endif

    // UTILITY
    //
    public func getFileName(urlBase: String, user: String) -> String {
        let url = (URL(string: urlBase)?.host) ?? "localhost"
        let fileName = user + "@" + url + ".png"
        return fileName
    }
}
