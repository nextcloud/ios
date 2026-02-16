// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

@Observable class NCAssistantChatConversationsModel {
    var conversations: [AssistantConversation] = []
    var isLoading: Bool = false
    var hasError: Bool = false

    private let ncSession: NCSession.Session

    init(controller: NCMainTabBarController?) {
        self.ncSession = NCSession.shared.getSession(controller: controller)
        loadAllSessions()
    }

    func loadAllSessions() {
        Task {
            let result = await NextcloudKit.shared.getAssistantChatConversations(account: ncSession.account)
            conversations = result.sessions ?? []
        }
    }

    func createNewConversation(title: String? = nil) async -> AssistantConversation? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let result = await NextcloudKit.shared.createAssistantChatConversation(title: title, timestamp: timestamp, account: ncSession.account)
        if result.error == .success, let newConversation = result.conversation?.conversation {
            conversations.insert(newConversation, at: 0)
            return newConversation
        } else {
            hasError = true
            return nil
        }
    }
}
