//
//  ActionViewController.swift
//  Action Assistant
//
//  Created by Marino Faggiana on 14/05/2026.
//  Copyright © 2026 Marino Faggiana. All rights reserved.
//

import UIKit
import NextcloudKit
import UniformTypeIdentifiers

final class ActionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.isHidden = true
        view.alpha = 0
        view.backgroundColor = .clear
        preferredContentSize = .zero

        Task {
            await handleAction()
        }
    }

    private func handleAction() async {
        guard let text = await loadText() else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        NCAssistantSharedTextStore.save(text)
        openMainAppForAssistantSharedText()
    }

    private func loadText() async -> String? {
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

    private func openMainAppForAssistantSharedText() {
        guard let url = URL(string: "nextcloud://assistant/shared-text") else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        openAssistantSharedTextURLThroughResponderChain(url)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    /// Opens the Assistant shared-text deep link from the Share extension.
    ///
    /// Share extensions cannot use `UIApplication.shared` directly because it is not
    /// extension-safe. This method walks the responder chain until it finds the hidden
    /// `UIApplication` responder and invokes the modern `open(_:options:completionHandler:)`
    /// Objective-C selector dynamically.
    ///
    /// This is intentionally isolated because it relies on Objective-C runtime dispatch.
    ///
    /// - Parameter url: Deep link URL to open in the containing application.
    private func openAssistantSharedTextURLThroughResponderChain(_ url: URL) {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        let applicationClass: AnyClass? = NSClassFromString("UIApplication")
        var responder: UIResponder? = self

        while let currentResponder = responder {
            guard let applicationClass,
                  currentResponder.isKind(of: applicationClass),
                  currentResponder.responds(to: selector),
                  let implementation = currentResponder.method(for: selector) else {
                responder = currentResponder.next
                continue
            }

            typealias CompletionBlock = @convention(block) (Bool) -> Void
            typealias OpenURLFunction = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, CompletionBlock?) -> Void

            let openURL = unsafeBitCast(implementation, to: OpenURLFunction.self)

            let completion: CompletionBlock = { success in
                if success {
                    nkLog(debug: "Assistant shared text deep link performed through modern responder chain")
                } else {
                    nkLog(error: "Assistant shared text deep link modern responder chain returned false")
                }
            }

            openURL(currentResponder, selector, url as NSURL, NSDictionary(), completion)
            return
        }

        nkLog(error: "Assistant shared text deep link failed because no UIApplication responder can open URL")
    }
}
