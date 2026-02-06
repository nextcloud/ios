// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import NextcloudKit

struct NCAssistantChatConversations: View {
    var conversationsModel: NCAssistantChatConversationsModel
    var selectedConversation: AssistantConversation?
    var onConversationSelected: (AssistantConversation?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            List(conversationsModel.conversations, id: \.id) { conversation in
                Button {
                    onConversationSelected(conversation)
                    dismiss()
                } label: {
                    HStack {
                        Text(conversation.validTitle)
                        Spacer()
                        if selectedConversation?.id == conversation.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .navigationTitle(NSLocalizedString("_conversations_", comment: ""))
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
    NCAssistantChatConversations(conversationsModel: NCAssistantChatConversationsModel(controller: nil), selectedConversation: nil, onConversationSelected: { _ in })
}
