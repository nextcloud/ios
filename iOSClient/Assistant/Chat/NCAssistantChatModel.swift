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
            stopPolling()
            loadMessages()

            if messages.last?.isFromHuman == true {
                startPollingForResponse()
            }
        }
    }

    // A session that has been selected at least once while this screen is showing is added here.
    var alreadyOpenedSessions: Set<AssistantSession> = []

    private let ncSession: NCSession.Session
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored var controller: NCMainTabBarController?
    @ObservationIgnored private var chatResponseTaskId: Int?
    init(controller: NCMainTabBarController?, messages: [ChatMessage] = []) {
        self.controller = controller
        self.ncSession = NCSession.shared.getSession(controller: controller)
        self.messages = messages
    }

    func startPollingForResponse(interval: TimeInterval = 4.0) {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
//                if currentChatTaskId == nil {
//                    requestResponse()
//                }

                loadLastMessage()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func requestResponse() {
        guard let sessionId = selectedSession?.id else { return }

        Task {
            let result = await NextcloudKit.shared.generateAssistantChatSessionAsync(sessionId: sessionId, account: ncSession.account)
            chatResponseTaskId = result.sessionTask?.taskId

            startPollingForResponse()
        }
    }

    private func loadMessages() {
        guard let sessionId = selectedSession?.id else { return }

        Task {
            let result = await NextcloudKit.shared.getAssistantChatMessagesAsync(sessionId: sessionId, account: ncSession.account)
            messages = result.chatMessage ?? []
        }
    }

    private func loadLastMessage() {
        guard let chatResponseTaskId else { return }
        
        Task {
            let result = await NextcloudKit.shared.checkAssistantChatGenerationAsync(taskId: chatResponseTaskId, sessionId: selectedSession?.id ?? 0, account: ncSession.account)
            let lastMessage = result.chatMessage

            if let lastMessage, lastMessage.role == "assistant" {
                stopPolling()
                isThinking = false
                messages.append(lastMessage)
            }
        }
    }

    func sendMessage(input: String) {
        guard let selectedSession else { return }

        let request = ChatMessageRequest(sessionId: selectedSession.id, role: "human", content: input, timestamp: Int(Date().timeIntervalSince1970 * 1000), firstHumanMessage: messages.isEmpty)
        isThinking = true

        Task {
            let result = await NextcloudKit.shared.createAssistantChatMessageAsync(messageRequest: request, account: ncSession.account)
            if result.error == .success {
                guard let chatMessage = result.chatMessage else { return }
                messages.append(chatMessage)

                stopPolling()
                requestResponse()
            } else {
                //TODO
            }
        }
    }
}

extension NCAssistantChatModel {
    static var example = NCAssistantChatModel(controller: nil, messages: [
        ChatMessage(
            id: 1,
            sessionId: 0,
            role: "human",
            content: "Hello! Can you help me summarize this document?",
            timestamp: Int(Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000)
        ),
        ChatMessage(
            id: 2,
            sessionId: 0,
            role: "assistant",
            content: "Of course! I'd be happy to help you summarize your document. Please share the document or paste the text you'd like me to summarize.",
            timestamp: Int(Date().addingTimeInterval(-240).timeIntervalSince1970 * 1000)
        ),
        ChatMessage(
            id: 3,
            sessionId: 0,
            role: "human",
            content: "Here is the text: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            timestamp: Int(Date().addingTimeInterval(-180).timeIntervalSince1970 * 1000)
        ),
        ChatMessage(
            id: 4,
            sessionId: 0,
            role: "assistant",
            content: "Based on the text you provided, here's a concise summary: The document discusses the classic Lorem Ipsum placeholder text, which has been used in the printing and typesetting industry for centuries as a standard dummy text.",
            timestamp: Int(Date().addingTimeInterval(-120).timeIntervalSince1970 * 1000)
        )])
}
