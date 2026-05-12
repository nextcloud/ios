// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import NextcloudKit

extension NCShareExtension {
    /// Handles selected text shared from another app and redirects it to the Assistant flow.
    ///
    /// - Parameter inputItems: Extension input items received from the host application.
    /// - Returns: `true` when text was handled and the normal file upload flow must stop.
    func handleAssistantSharedTextIfNeeded(inputItems: [NSExtensionItem]) async -> Bool {
        guard let text = await loadAssistantSharedText(from: inputItems),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        NCAssistantSharedTextStore.save(text)
        openMainAppForAssistantSharedText()

        return true
    }

    /// Loads the first valid text payload from the extension input items.
    ///
    /// - Parameter inputItems: Extension input items received from the host application.
    /// - Returns: Shared text when available, otherwise `nil`.
    private func loadAssistantSharedText(from inputItems: [NSExtensionItem]) async -> String? {
        for item in inputItems {
            guard let attachments = item.attachments else {
                continue
            }

            for provider in attachments {
                if let text = await loadAssistantText(from: provider) {
                    return text
                }
            }
        }

        return nil
    }

    /// Loads text from an item provider when it exposes a supported text representation.
    ///
    /// - Parameter provider: Item provider received from the host application.
    /// - Returns: Text content when the provider supports a text type.
    private func loadAssistantText(from provider: NSItemProvider) async -> String? {
        let plainTextIdentifier = UTType.plainText.identifier
        let textIdentifier = UTType.text.identifier

        if provider.hasItemConformingToTypeIdentifier(plainTextIdentifier) {
            return await loadAssistantString(from: provider, typeIdentifier: plainTextIdentifier)
        }

        if provider.hasItemConformingToTypeIdentifier(textIdentifier) {
            return await loadAssistantString(from: provider, typeIdentifier: textIdentifier)
        }

        if provider.canLoadObject(ofClass: NSString.self) {
            return await loadAssistantNSString(from: provider)
        }

        return nil
    }

    /// Loads a string payload using a specific uniform type identifier.
    ///
    /// - Parameters:
    ///   - provider: Item provider received from the host application.
    ///   - typeIdentifier: Uniform type identifier to load.
    /// - Returns: String representation of the payload, when available.
    private func loadAssistantString(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data,
                          let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: text)
                } else if let url = item as? URL,
                          let text = try? String(contentsOf: url, encoding: .utf8) {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Loads an NSString object from the provided item provider.
    ///
    /// - Parameter provider: Item provider received from the host application.
    /// - Returns: String value when NSString loading succeeds.
    private func loadAssistantNSString(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSString.self) { object, _ in
                if let string = object as? NSString {
                    continuation.resume(returning: string as String)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Opens the main app using the Assistant shared-text deep link.
    private func openMainAppForAssistantSharedText() {
        guard let url = URL(string: "nextcloud://assistant/shared-text") else {
            return
        }

        extensionContext?.open(url) { [weak self] success in
            if success {
                nkLog(debug: "Assistant shared text deep link opened successfully")
            } else {
                nkLog(error: "Assistant shared text deep link failed to open")
            }

            DispatchQueue.main.async {
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }
}
