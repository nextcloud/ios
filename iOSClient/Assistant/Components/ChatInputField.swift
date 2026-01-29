// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ChatInputField: View {
    @FocusState private var isInputFocused: Bool
    @State var text: String = ""
    @Binding var isLoading: Bool
    var onSend: ((_ input: String) -> Void)? = nil
    
    init(isLoading: Binding<Bool> = .constant(false), onSend: ((_: String) -> Void)? = nil) {
        _isLoading = isLoading
        self.onSend = onSend
    }
    
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
                onSend?(text.trimmingCharacters(in: .whitespaces))
                text = ""
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
}
