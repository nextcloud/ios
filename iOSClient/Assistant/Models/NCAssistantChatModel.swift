// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

@Observable class NCAssistantChatModel {
    var messages: [ChatMessage] = []
    var isThinking: Bool = false
    var hasError: Bool = false
    var selectedSession: AssistantSession? {
        didSet {
            loadMessages()
        }
    }

    var sessions: [AssistantSession] = []
    @ObservationIgnored var controller: NCMainTabBarController?
    private let session: NCSession.Session

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        self.session = NCSession.shared.getSession(controller: controller)
        loadAllSessions()
    }

    func loadAllSessions() {
        Task {
            let result = await NextcloudKit.shared.getAssistantChatSessionsAsync(account: session.account)
            sessions = result.sessions ?? []
        }
    }

    func loadMessages() {
        Task {
            let result = await NextcloudKit.shared.getAssistantChatMessagesAsync(sessionId: selectedSession?.id ?? 0, account: session.account)
            messages = result.chatMessage ?? []
        }
    }

    func sendMessage(input: String) {
        guard let selectedSession else { return }

        let request = ChatMessageRequest(sessionId: selectedSession.id, role: "human", content: input, timestamp: Int(Date().timeIntervalSince1970 * 1000))

        Task {
            let result = await NextcloudKit.shared.createAssistantChatMessageAsync(messageRequest: request, account: session.account)
            if result.error == .success {
                guard let chatMessage = result.chatMessage else { return }
                messages.append(chatMessage)
            }
            if result.error != .success {
                // TODO
            }
        }

    }

    func createNewSession(title: String? = nil) async -> AssistantSession? {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let result = await NextcloudKit.shared.createAssistantChatSessionAsync(title: title, timestamp: ts, account: session.account)
        if result.error == .success, let newSession = result.conversation?.session {
            sessions.insert(newSession, at: 0)
            selectedSession = newSession
            return newSession
        } else {
            hasError = true
            return nil
        }
    }

    private func handleTaskResponse(task: AssistantTask?, error: NKError?) {
        isThinking = false

        if error != .success {
            hasError = true
            return
        }

        guard let task, let output = task.output?.output else {
            hasError = true
            return
        }

        addAssistantMessage(output)
    }

    private func addUserMessage(_ text: String) {
//        let message = ChatMessage(content: text, isFromUser: true)
//        messages.append(message)
    }

    private func addAssistantMessage(_ text: String) {
//        let message = ChatMessage(content: text, isFromUser: false)
//        messages.append(message)
    }

//    func loadDummyData() {
//        messages = [
//            ChatMessage(
//                content: "Hello! Can you help me summarize this document?",
//                isFromUser: true,
//                timestamp: Date().addingTimeInterval(-300)
//            ),
//            ChatMessage(
//                content: "Of course! I'd be happy to help you summarize your document. Please share the document or paste the text you'd like me to summarize.",
//                isFromUser: false,
//                timestamp: Date().addingTimeInterval(-240)
//            ),
//            ChatMessage(
//                content: "Here is the text: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
//                isFromUser: true,
//                timestamp: Date().addingTimeInterval(-180)
//            ),
//            ChatMessage(
//                content: "Based on the text you provided, here's a concise summary: The document discusses the classic Lorem Ipsum placeholder text, which has been used in the printing and typesetting industry for centuries as a standard dummy text.",
//                isFromUser: false,
//                timestamp: Date().addingTimeInterval(-120)
//            )
//        ]
//    }
}

