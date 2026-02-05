// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import NextcloudKit

struct NCAssistantChatSessions: View {
    var sessionsModel: NCAssistantChatSessionsModel
    var onSessionSelected: (AssistantSession?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            List(sessionsModel.sessions, id: \.id) { session in
                Text(session.validTitle)
                    .onTapGesture {
                        onSessionSelected(session)
                        dismiss()
                    }
            }
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Conversation", systemImage: "plus.message.fill") {
                    Task {
                        let session = await sessionsModel.createNewConversation()
                        onSessionSelected(session)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NCAssistantChatSessions(sessionsModel: NCAssistantChatSessionsModel(controller: nil), onSessionSelected: { _ in })
}
