// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import NextcloudKit

struct NCAssistantChatConversations: View {
    var conversationsModel: NCAssistantChatConversationsModel
    var onConversationSelected: (AssistantConversation?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            List(conversationsModel.conversations, id: \.id) { conversations in
                Text(conversations.validTitle)
                    .onTapGesture {
                        onConversationSelected(conversations)
                        dismiss()
                    }
            }
        }
        .navigationTitle("_conversations_")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("_new_conversation_", systemImage: "plus.message.fill") {
                    Task {
                        let session = await conversationsModel.createNewConversation()
                        onConversationSelected(session)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NCAssistantChatConversations(conversationsModel: NCAssistantChatConversationsModel(controller: nil), onConversationSelected: { _ in })
}
