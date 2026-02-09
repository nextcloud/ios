// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

@Observable class NCAssistantChatModel {
    var messages: [ChatMessage] = []
    var isSending: Bool = false
    var isThinking: Bool = false
    var isSendingDisabled = false
    var hasError: Bool = false
    var showRetryResponseGenerationButton = false

    var selectedConversation: AssistantConversation? {
        didSet {
            onConversationSelected()
        }
    }

    var currentSession: AssistantSession?

    private let ncSession: NCSession.Session
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored var controller: NCMainTabBarController?
    @ObservationIgnored private var chatMessageTaskId: Int?

    init(controller: NCMainTabBarController?, messages: [ChatMessage] = []) {
        self.controller = controller
        self.ncSession = NCSession.shared.getSession(controller: controller)
        self.messages = messages
    }

    func startPollingForResponse(interval: TimeInterval = 4.0) {
        stopPolling()
        isSendingDisabled = true
        isThinking = true
        showRetryResponseGenerationButton = false

        pollingTask = Task {
            while !Task.isCancelled {

                await loadLastMessage()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isThinking = false
        isSendingDisabled = false
    }

    private func onConversationSelected() {
        guard let selectedConversation else { return }

        stopPolling()
        showRetryResponseGenerationButton = false
        currentSession = nil

        Task {
            await loadAllMessages()
            currentSession = await checkChatSession(sessionId: selectedConversation.id)
            chatMessageTaskId = currentSession?.messageTaskId

            if messages.last?.isFromHuman == true, chatMessageTaskId == nil, isSending == false {
                ////                if isSelectedConversationAlreadyMessaged {
                ////                    generateChatSession()
                ////                } else {
                showRetryResponseGenerationButton = true
                ////                }
            } else if chatMessageTaskId != nil {
                startPollingForResponse()
            }

        }
    }

    func generateChatSession() {
        guard let sessionId = selectedConversation?.id else { return }

        Task {
            let result = await NextcloudKit.shared.generateAssistantChatSession(sessionId: sessionId, account: ncSession.account)
            chatMessageTaskId = result.sessionTask?.taskId
        }
    }

    func onRetryResponseGeneration() {
        generateChatSession()
        startPollingForResponse()
    }

    private func checkChatSession(sessionId: Int) async -> AssistantSession? {
        let result = await NextcloudKit.shared.checkAssistantChatSession(sessionId: sessionId, account: ncSession.account)
        return result.session
    }

    private func loadAllMessages() async {
        guard let sessionId = selectedConversation?.id else { return }

        let result = await NextcloudKit.shared.getAssistantChatMessages(sessionId: sessionId, account: ncSession.account)
        messages = result.chatMessages ?? []
    }

    private func loadLastMessage() async {
        guard let chatMessageTaskId else { return }

        let result = await NextcloudKit.shared.checkAssistantChatGeneration(taskId: chatMessageTaskId, sessionId: selectedConversation?.id ?? 0, account: ncSession.account)
        let lastMessage = result.chatMessage

        if let lastMessage, lastMessage.role == "assistant" {
            stopPolling()
            messages.append(lastMessage)
        }
    }

    func sendMessage(input: String) {
        guard let selectedConversation else { return }

        let request = ChatMessageRequest(sessionId: selectedConversation.id, role: "human", content: input, timestamp: Int(Date().timeIntervalSince1970), firstHumanMessage: messages.isEmpty)
        isSending = true
        isSendingDisabled = true

        Task {
            let result = await NextcloudKit.shared.createAssistantChatMessage(messageRequest: request, account: ncSession.account)
            if result.error == .success {
                guard let chatMessage = result.chatMessage else { return }
                messages.append(chatMessage)

                stopPolling()
                generateChatSession()
                startPollingForResponse()
            } else {
                //TODO
            }

            isSending = false
        }
    }

    func startNewConversation(input: String, sessionsModel: NCAssistantChatConversationsModel) {
        Task {
            let session = await sessionsModel.createNewConversation(title: input)
            sendMessage(input: input)
            selectedConversation = session
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
