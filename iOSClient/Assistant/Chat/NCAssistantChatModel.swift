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
        }
    }

    var sessions: [AssistantSession] = []
    private let ncSession: NCSession.Session
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored var controller: NCMainTabBarController?
    @ObservationIgnored private var chatResponseTaskId: Int?

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        self.ncSession = NCSession.shared.getSession(controller: controller)
        loadAllSessions()
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

    private func loadAllSessions() {
        Task {
            let result = await NextcloudKit.shared.getAssistantChatConversationsAsync(account: ncSession.account)
            sessions = result.sessions ?? []
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
        if let selectedSession {
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
        } else {
            Task {
                let session = await createNewConversation(title: input)
                selectedSession = session
                sendMessage(input: input)
            }
        }
    }

    func createNewConversation(title: String? = nil) async -> AssistantSession? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let result = await NextcloudKit.shared.createAssistantChatConversationAsync(title: title, timestamp: timestamp, account: ncSession.account)
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

