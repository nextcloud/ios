// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Data Models
//
//struct ChatMessage: Identifiable, Equatable {
//    let id: UUID
//    let content: String
//    let isFromUser: Bool
//    let timestamp: Date
//
//    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date()) {
//        self.id = id
//        self.content = content
//        self.isFromUser = isFromUser
//        self.timestamp = timestamp
//    }
//}

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
          

//            if model.messages.isEmpty && !model.isThinking {
//                EmptyChatView(model: model)
//            }
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputField { input in
                model.sendMessage(input: input)
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
//            if message.isFromUser {
//                Spacer(minLength: 50)
//            }

            VStack(alignment: true ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(true ? .white : .primary)
                    .padding()
                    .background(bubbleBackground)
                    .clipShape(.rect(cornerRadius: 16))

                Text(NCUtility().getRelativeDateTitle(Date(timeIntervalSince1970: TimeInterval(message.timestamp / 1000))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: true ? .trailing : .leading)
            .padding(.horizontal)

//            if !message.isFromUser {
//                Spacer(minLength: 50)
//            }
        }
    }

    private var bubbleBackground: Color {
        if true {
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

