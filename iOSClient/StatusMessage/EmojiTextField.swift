// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// UIKit-backed emoji-only text field that forces the Emoji keyboard
final class EmojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "" } // return non-nil to show the Emoji keyboard

    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                return mode
            }
        }
        return nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(inputModeDidChange), name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
        addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }

    @objc func inputModeDidChange(_ notification: Notification) {
        guard isFirstResponder else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.reloadInputViews()
        }
    }

    // Keep only a single emoji character
    @objc private func textChanged() {
        guard let t = text, !t.isEmpty else { return }
        // Trim to first extended grapheme cluster (so flags/skin tones stay intact)
        let first = String(t.prefix(1))
        if first != t { text = first }
    }
}

struct EmojiField: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> EmojiTextField {
        let tf = EmojiTextField(frame: .zero)
        tf.delegate = context.coordinator
        tf.text = text
        tf.setContentHuggingPriority(.required, for: .horizontal)
        tf.setContentCompressionResistancePriority(.required, for: .horizontal)
        return tf
    }

    func updateUIView(_ uiView: EmojiTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiField
        init(_ parent: EmojiField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if textField is EmojiTextField {
                if string.isEmpty {
                    textField.text = "😀"
                    parent.text = "😀"
                    return false
                }
                textField.text = string
                parent.text = string
                textField.endEditing(true)
            }
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return false
        }
    }
}
