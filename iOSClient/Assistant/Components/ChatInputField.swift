// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI


struct ChatInputField: View {
//    @Bindable var model: NCAssistantChatModel
    var onSend: ((_ input: String) -> Void)? = nil
    @FocusState private var isInputFocused: Bool
    @State var text: String = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField(NSLocalizedString("_type_message_", comment: ""), text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NCBrandColor.shared.textColor2).opacity(0.1))
                .clipShape(.rect(cornerRadius: 20))
                .focused($isInputFocused)
                .lineLimit(1...5)

            Button(action: {
                isInputFocused = false
                onSend?(text)
                text = ""
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
//                    .foregroundStyle(Color(NCBrandColor.shared.getElement(account: model.controller?.account)))
            }
//            .disabled(model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isThinking)
//            .opacity(model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isThinking ? 0.5 : 1.0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
}

