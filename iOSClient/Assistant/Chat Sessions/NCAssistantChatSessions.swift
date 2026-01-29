// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import NextcloudKit

//@Observable class NCAssistantChatSessionsModel {
//    var sessions: [AssistantSession] = []
//    var isLoading: Bool = false
//    var hasError: Bool = false
//    let controller: NCMainTabBarController?
//
//    private let session: NCSession.Session
//
//    init(controller: NCMainTabBarController?) {
//        self.controller = controller
//        session = NCSession.shared.getSession(controller: controller)
//
//        loadSessions()
//    }
//
//    func loadSessions() {
//        Task {
//            let result = await NextcloudKit.shared.textProcessingGetChatSessionsV2Async(account: session.account)
//            sessions = result.sessions ?? []
//        }
//    }
//}

struct NCAssistantChatSessions: View {
    @Binding var model: NCAssistantChatModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
//            if model.isLoading {
//                ProgressView()
//            if model.sessions.isEmpty {
//                Text("No sessions found")
//            } else {
                List(model.sessions, id: \.id) { session in
                    Text(session.validTitle)
                        .onTapGesture {
                            model.selectedSession = session
                            dismiss()
                        }
                }
//            }
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Conversation", systemImage: "plus.message.fill") {
                    Task {
                        _ = await model.createNewSession()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var model = NCAssistantChatModel(controller: nil)
    return NCAssistantChatSessions(model: $model)}
