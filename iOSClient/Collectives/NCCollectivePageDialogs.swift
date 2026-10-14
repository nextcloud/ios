// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Presents the title prompt and trash confirmation for a `NCCollectivePageAction`.
struct NCCollectivePageDialogs: ViewModifier {
    @Binding var action: NCCollectivePageAction?
    let model: NCCollectivePagesModel
    var onCreated: (NCCollectivePage) -> Void = { _ in }
    var onTrashed: (NCCollectivePage) -> Void = { _ in }

    @State private var title = ""
    // Kept after dismissal, which resets `action` before or after the button action runs.
    @State private var pending: NCCollectivePageAction?

    private var isTitlePromptPresented: Binding<Bool> {
        Binding {
            switch action {
            case .create, .rename: true
            default: false
            }
        } set: { isPresented in
            if !isPresented { action = nil }
        }
    }

    private var isTrashConfirmationPresented: Binding<Bool> {
        Binding {
            if case .trash = action { return true }
            return false
        } set: { isPresented in
            if !isPresented { action = nil }
        }
    }

    private var promptTitle: LocalizedStringKey {
        switch pending {
        case .create(let parent) where !parent.isLandingPage: "_collectives_new_subpage_"
        case .rename: "_collectives_rename_page_"
        default: "_collectives_new_page_"
        }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: action) { _, action in
                guard let action else { return }
                pending = action
                if case .rename(let page) = action {
                    title = page.title
                } else {
                    title = ""
                }
            }
            .alert(promptTitle, isPresented: isTitlePromptPresented) {
                TextField("_collectives_page_title_", text: $title)
                Button("_cancel_", role: .cancel) {}
                Button(isRename ? "_rename_" : "_create_", action: submitTitle)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .confirmationDialog("_collectives_trash_page_", isPresented: isTrashConfirmationPresented, titleVisibility: .visible) {
                Button("_collectives_trash_page_", role: .destructive, action: trash)
            } message: {
                if case .trash(let page) = pending {
                    Text(String(format: NSLocalizedString("_collectives_trash_page_message_", comment: ""), page.title))
                }
            }
    }

    private var isRename: Bool {
        if case .rename = pending { return true }
        return false
    }

    private func submitTitle() {
        let title = title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, let action = pending else { return }
        Task {
            switch action {
            case .create(let parent):
                if let page = await model.createPage(title: title, parent: parent) {
                    onCreated(page)
                }
            case .rename(let page):
                await model.rename(page, to: title)
            case .trash:
                break
            }
        }
    }

    private func trash() {
        guard case .trash(let page) = pending else { return }
        Task {
            if await model.trash(page) {
                onTrashed(page)
            }
        }
    }
}
