//
//  ActionViewController.swift
//  Action Assistant
//
//  Created by Marino Faggiana on 14/05/2026.
//  Copyright © 2026 Marino Faggiana. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

final class ActionViewController: UIViewController {
    private let callbackURL = URL(string: "nextcloud://assistant/shared-text")!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep the action visually neutral because it only forwards the selected text.
        view.backgroundColor = .clear

        Task {
            await handleAction()
        }
    }

    private func handleAction() async {
        guard let text = await loadSelectedText() else {
            complete()
            return
        }

        NCAssistantSharedTextStore.save(text)
        openMainApp()
    }

    private func loadSelectedText() async -> String? {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else {
                continue
            }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    return await loadText(from: provider, typeIdentifier: UTType.plainText.identifier)
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                    return await loadText(from: provider, typeIdentifier: UTType.utf8PlainText.identifier)
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    return await loadText(from: provider, typeIdentifier: UTType.text.identifier)
                }
            }
        }

        return nil
    }

    private func loadText(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                let text: String?

                if let string = item as? String {
                    text = string
                } else if let attributedString = item as? NSAttributedString {
                    text = attributedString.string
                } else if let data = item as? Data {
                    text = String(data: data, encoding: .utf8)
                } else if let url = item as? URL {
                    text = try? String(contentsOf: url, encoding: .utf8)
                } else {
                    text = nil
                }

                guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: text)
            }
        }
    }

    private func openMainApp() {
        extensionContext?.open(callbackURL) { [weak self] _ in
            self?.complete()
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
