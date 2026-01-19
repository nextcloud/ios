// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Data Models

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}

// MARK: - View Model

@Observable class NCAssistantChatModel {
    var messages: [ChatMessage] = []
    var isThinking: Bool = false
    var inputText: String = ""
    var hasError: Bool = false

//    @ObservationIgnored private let session: NCSession.Session
    var sessions: [AssistantSession]
//    @ObservationIgnored private let taskType: TaskTypeData?
//    @ObservationIgnored private let useV2: Bool
    @ObservationIgnored var controller: NCMainTabBarController?
    private let session: NCSession.Session

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        let session = NCSession.shared.getSession(controller: controller)
//        self.session = session
//        self.taskType = taskType

        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
//        self.useV2 = capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion30
    }

    func getSessions() {
        Task {
            let result = await NextcloudKit.shared.textProcessingGetChatSessionsV2Async(account: session.account)
            sessions = result.sessions
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = inputText
        addUserMessage(userMessage)
        inputText = ""

        isThinking = true
        scheduleTask(input: userMessage)
    }

    func scheduleTask(input: String) {
        // TODO: Implement actual API call when chat API is ready
        // Reference pattern from NCAssistantModel.swift:87-115
        /*
        if useV2 {
            guard let taskType else { return }
            NextcloudKit.shared.textProcessingScheduleV2(
                input: input,
                taskType: taskType,
                account: account
            ) { _, task, _, error in
                self.handleTaskResponse(task: task, error: error)
            }
        } else {
            NextcloudKit.shared.textProcessingSchedule(
                input: input,
                typeId: taskType?.id ?? "",
                identifier: "assistant",
                account: account
            ) { _, task, _, error in
                guard let task, let taskV2 = NKTextProcessingTask.toV2(tasks: [task]).tasks.first else { return }
                self.handleTaskResponse(task: taskV2, error: error)
            }
        }
        */

        // Temporary mock for testing UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isThinking = false
            self.addAssistantMessage("This is a placeholder response. The actual API integration will be implemented when the chat API is ready.")
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
        let message = ChatMessage(content: text, isFromUser: true)
        messages.append(message)
    }

    private func addAssistantMessage(_ text: String) {
        let message = ChatMessage(content: text, isFromUser: false)
        messages.append(message)
    }

    func loadDummyData() {
        messages = [
            ChatMessage(
                content: "Hello! Can you help me summarize this document?",
                isFromUser: true,
                timestamp: Date().addingTimeInterval(-300)
            ),
            ChatMessage(
                content: "Of course! I'd be happy to help you summarize your document. Please share the document or paste the text you'd like me to summarize.",
                isFromUser: false,
                timestamp: Date().addingTimeInterval(-240)
            ),
            ChatMessage(
                content: "Here is the text: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                isFromUser: true,
                timestamp: Date().addingTimeInterval(-180)
            ),
            ChatMessage(
                content: "Based on the text you provided, here's a concise summary: The document discusses the classic Lorem Ipsum placeholder text, which has been used in the printing and typesetting industry for centuries as a standard dummy text.",
                isFromUser: false,
                timestamp: Date().addingTimeInterval(-120)
            )
        ]
    }
}

// MARK: - Main View

struct NCAssistantChat: View {
    @State var model: NCAssistantChatModel

    init(controller: NCMainTabBarController?) {
        self.model = NCAssistantChatModel(controller: controller)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                messageListView
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputField(model: model)
            }

            if model.messages.isEmpty && !model.isThinking {
                EmptyChatView(model: model)
            }
        }
        .navigationTitle("Assistant Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.messages) { message in
                        MessageBubbleView(message: message, account: model.controller?.account ?? "")
                            .id(message.id)
                    }

                    if model.isThinking {
                        ThinkingBubbleView()
                            .id("thinking")
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: model.messages.count) { _, _ in
                withAnimation {
                    if let lastMessage = model.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: model.isThinking) { _, isThinking in
                if isThinking {
                    withAnimation {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    let account: String

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.isFromUser ? .white : .primary)
                    .padding()
                    .background(bubbleBackground)
                    .clipShape(.rect(cornerRadius: 16))

                Text(NCUtility().getRelativeDateTitle(message.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
            .padding(.horizontal)

            if !message.isFromUser {
                Spacer(minLength: 50)
            }
        }
    }

    private var bubbleBackground: Color {
        if message.isFromUser {
            return Color(NCBrandColor.shared.getElement(account: account))
        } else {
            return Color(NCBrandColor.shared.textColor2).opacity(0.1)
        }
    }
}

// MARK: - Thinking Bubble View

struct ThinkingBubbleView: View {
    @State private var scale1: CGFloat = 1.0
    @State private var scale2: CGFloat = 1.0
    @State private var scale3: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 8, height: 8)
                .scaleEffect(scale1)

            Circle()
                .fill(Color.secondary)
                .frame(width: 8, height: 8)
                .scaleEffect(scale2)

            Circle()
                .fill(Color.secondary)
                .frame(width: 8, height: 8)
                .scaleEffect(scale3)
        }
        .padding()
        .background(Color(NCBrandColor.shared.textColor2).opacity(0.1))
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            scale1 = 1.3
        }
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.15)) {
            scale2 = 1.3
        }
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.3)) {
            scale3 = 1.3
        }
    }
}

// MARK: - Chat Input Field

struct ChatInputField: View {
    @Bindable var model: NCAssistantChatModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(NSLocalizedString("_type_message_", comment: ""), text: $model.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NCBrandColor.shared.textColor2).opacity(0.1))
                .clipShape(.rect(cornerRadius: 20))
                .focused($isInputFocused)
                .lineLimit(1...5)

            Button(action: {
                model.sendMessage()
                isInputFocused = false
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(NCBrandColor.shared.getElement(account: model.controller?.account)))
            }
            .disabled(model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isThinking)
            .opacity(model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isThinking ? 0.5 : 1.0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Empty Chat View

struct EmptyChatView: View {
//    let account: String
    @Bindable var model: NCAssistantChatModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color(NCBrandColor.shared.getElement(account: model.controller?.account)))
                .font(Font.system(.body).weight(.light))
                .frame(height: 100)

            Text(NSLocalizedString("_start_conversation_", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 5)

            Text(NSLocalizedString("_ask_assistant_anything_", comment: ""))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NCAssistantChat(controller: nil)
            .onAppear {
                // Preview will show empty state
            }
    }
}

#Preview("With Messages") {
    let chat = NCAssistantChat(controller: nil)

    return NavigationStack {
        chat
            .onAppear {
                chat.model.loadDummyData()
            }
    }
}
