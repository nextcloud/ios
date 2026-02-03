// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct NCAssistantChat: View {
    @Environment(NCAssistantChatModel.self) var chatModel

    var body: some View {
        @Bindable var chatModel = chatModel

        if chatModel.messages.isEmpty {
            NCAssistantEmptyView(titleKey: "_no_tasks_", subtitleKey: "_no_chat_subtitle_")
        }

        ZStack {
            VStack(spacing: 0) {
                messageListView
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputField(isLoading: $chatModel.isThinking) { input in
                chatModel.sendMessage(input: input)
            }
        }
        .navigationTitle("Assistant Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            chatModel.stopPolling()
        }
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chatModel.messages) { message in
                        MessageBubbleView(message: message, account: chatModel.controller?.account ?? "")
                            .id(message.id)
                    }

                    if chatModel.isThinking {
                        ThinkingBubbleView()
                            .id("thinking")
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: chatModel.messages.count) { _, _ in
                withAnimation {
                    if let lastMessage = chatModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatModel.isThinking) { _, isThinking in
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
            if message.isFromHuman {
                Spacer(minLength: 50)
            }

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

            if !message.isFromHuman {
                Spacer(minLength: 50)
            }
        }
    }

    private var bubbleBackground: Color {
        if message.isFromHuman {
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

// MARK: - Empty Chat View

struct EmptyChatView: View {
    @Environment(NCAssistantChatModel.self) var chatModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color(NCBrandColor.shared.getElement(account: chatModel.controller?.account)))
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
        NCAssistantChat()
            .environment(NCAssistantChatModel(controller: nil))
    }
}

#Preview("With Messages") {
    NavigationStack {
        NCAssistantChat()
            .environment(NCAssistantChatModel.example)
    }
}
