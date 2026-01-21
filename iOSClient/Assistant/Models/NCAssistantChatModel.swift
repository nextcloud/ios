// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

@Observable class NCAssistantChatModel {
    var messages: [ChatMessage] = []
    var isThinking: Bool = false
//    var inputText: String = ""
    var hasError: Bool = false
    var selectedSession: AssistantSession? {
        didSet {
            loadMessages()
        }
    }

//    @ObservationIgnored private let session: NCSession.Session
    var sessions: [AssistantSession] = []
//    @ObservationIgnored private let taskType: TaskTypeData?
//    @ObservationIgnored private let useV2: Bool
    @ObservationIgnored var controller: NCMainTabBarController?
    private let session: NCSession.Session

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        self.session = NCSession.shared.getSession(controller: controller)
//        self.session = session
//        self.taskType = taskType

//        self.useV2 = capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion30

//        getSessions()
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
//        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

//        let userMessage = inputText
        addUserMessage(input)

        isThinking = true
//        scheduleTask(input: userMessage)
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
