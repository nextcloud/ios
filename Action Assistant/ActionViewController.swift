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
    private let debugPrefix = "[ActionAssistant]"

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep the action visually neutral because it only forwards the selected text.
        view.backgroundColor = .clear

        print("\(debugPrefix) viewDidLoad")

        Task {
            await handleAction()
        }
    }

    private func handleAction() async {
        print("\(debugPrefix) handleAction started")

        guard let text = await loadSelectedText() else {
            print("\(debugPrefix) no selected text found")
            complete()
            return
        }

        print("\(debugPrefix) selected text length: \(text.count)")

        NCAssistantSharedTextStore.save(text)
        print("\(debugPrefix) text saved to shared store")

        openMainApp()
    }

    private func loadSelectedText() async -> String? {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("\(debugPrefix) extensionContext inputItems missing")
            return nil
        }

        print("\(debugPrefix) extension items count: \(extensionItems.count)")

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else {
                print("\(debugPrefix) extension item without attachments")
                continue
            }

            print("\(debugPrefix) attachments count: \(attachments.count)")

            for provider in attachments {
                print("\(debugPrefix) registered types: \(provider.registeredTypeIdentifiers)")
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
            print("\(self.debugPrefix) loading type identifier: \(typeIdentifier)")

            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    print("\(self.debugPrefix) loadItem error: \(error)")
                }

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
                    if let item {
                        print("\(self.debugPrefix) unsupported item type: \(type(of: item))")
                    } else {
                        print("\(self.debugPrefix) loaded item is nil")
                    }
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
        print("\(debugPrefix) opening main app with URL: \(callbackURL.absoluteString)")

        extensionContext?.open(callbackURL) { [weak self] success in
            guard let self else { return }

            print("\(self.debugPrefix) open main app result: \(success)")
            self.complete()
        }
    }

    private func complete() {
        print("\(debugPrefix) complete")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
