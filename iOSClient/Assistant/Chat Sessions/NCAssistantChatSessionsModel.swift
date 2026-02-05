// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

@Observable class NCAssistantChatSessionsModel {
    var sessions: [AssistantSession] = []
    var isLoading: Bool = false
    var hasError: Bool = false

    private let ncSession: NCSession.Session

    init(controller: NCMainTabBarController?) {
        self.ncSession = NCSession.shared.getSession(controller: controller)
        loadAllSessions()
    }

    func loadAllSessions() {
        Task {
            let result = await NextcloudKit.shared.getAssistantChatConversationsAsync(account: ncSession.account)
            sessions = result.sessions ?? []
        }
    }

    func createNewConversation(title: String? = nil) async -> AssistantSession? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let result = await NextcloudKit.shared.createAssistantChatConversationAsync(title: title, timestamp: timestamp, account: ncSession.account)
        if result.error == .success, let newSession = result.conversation?.session {
            sessions.insert(newSession, at: 0)
            return newSession
        } else {
            hasError = true
            return nil
        }
    }
}
