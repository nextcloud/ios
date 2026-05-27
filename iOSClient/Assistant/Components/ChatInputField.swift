// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ChatInputField: View {
    @FocusState private var isInputFocused: Bool
    @State private var hasAppliedInitialText = false

    @Binding var text: String
    @Binding var initialText: String
    @Binding var isLoading: Bool
    @Binding var isDisabled: Bool

    var onSend: ((_ input: String) -> Void)?

    init(
        text: Binding<String> = .constant(""),
        initialText: Binding<String> = .constant(""),
        isLoading: Binding<Bool> = .constant(false),
        isDisabled: Binding<Bool> = .constant(false),
        onSend: ((_: String) -> Void)? = nil
    ) {
        _text = text
        _initialText = initialText
        _isLoading = isLoading
        _isDisabled = isDisabled
        self.onSend = onSend
    }

    var body: some View {
        VStack {
            Text("_assistant_ai_warning_")
                .cappedFont(.body, maxDynamicType: .accessibility2)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.5)

            HStack(spacing: 8) {
                TextField(NSLocalizedString("_type_message_", comment: ""), text: $text, axis: .vertical)
                    .cappedFont(.body, maxDynamicType: .accessibility2)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.primary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 20))
                    .focused($isInputFocused)
                    .lineLimit(1...5)

                Button(action: {
                    isInputFocused = false
                    onSend?(text.trimmingCharacters(in: .whitespaces))
                    text = ""
                }) {
                    if isLoading {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.icon(28))
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isDisabled || isLoading)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(.background)
        .task {
            applyInitialTextIfNeeded()
        }
    }

    private func applyInitialTextIfNeeded() {
        guard !hasAppliedInitialText else {
            return
        }

        hasAppliedInitialText = true

        guard text.isEmpty, !initialText.isEmpty else {
            return
        }

        text = initialText
        initialText = ""
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var initialText = "Text received from outside"

    VStack(spacing: 16) {
        ChatInputField(
            text: $text,
            initialText: $initialText,
            isLoading: .constant(false)
        )

        ChatInputField(
            text: .constant("Loading state"),
            initialText: .constant(""),
            isLoading: .constant(true)
        )
    }
}
