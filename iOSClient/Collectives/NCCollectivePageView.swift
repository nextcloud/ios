// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import QuickLook
import NextcloudKit

/// Shows a rendered page with its subpages and offers editing in Nextcloud Text.
struct NCCollectivePageView: View {
    let page: NCCollectivePage
    let model: NCCollectivePagesModel

    @Environment(\.dismiss) private var dismiss
    @State private var markdown: String?
    @State private var error: NKError?
    @State private var action: NCCollectivePageAction?
    @State private var destination: NCCollectivePage?
    @State private var attachments: [NCCollectivePageAttachment] = []
    @State private var openingEmbed: String?
    @State private var previewURL: URL?

    /// The latest server state of the page, which changes after renaming or editing.
    private var current: NCCollectivePage {
        model.page(id: page.id) ?? page
    }

    private var canEdit: Bool {
        model.collective.canEdit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                pageContent(markdown: markdown)
                otherAttachments
                subpages
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(model.title(of: current))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .refreshable {
            await model.load()
            await loadContent()
        }
        .task(id: current.timestamp) {
            await loadContent()
        }
        .navigationDestination(item: $destination) { page in
            NCCollectivePageView(page: page, model: model)
        }
        .quickLookPreview($previewURL)
        .modifier(NCCollectivePageDialogs(action: $action, model: model, onCreated: { page in
            destination = page
        }, onTrashed: { _ in
            dismiss()
        }))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let emoji = model.emoji(of: current), !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 48))
                    .accessibilityHidden(true)
            }
            Text(model.title(of: current))
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(lastEdited)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var lastEdited: String {
        let date = current.modificationDate.formatted(.relative(presentation: .named))
        if let user = current.lastUserDisplayName, !user.isEmpty {
            return String(format: NSLocalizedString("_collectives_last_edited_by_", comment: ""), user, date)
        }
        return String(format: NSLocalizedString("_collectives_last_edited_", comment: ""), date)
    }

    @ViewBuilder
    private func pageContent(markdown: String?) -> some View {
        if let markdown {
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("_collectives_empty_page_")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(NCCollectivesMarkdownBlock.blocks(from: markdown).enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .text(let text):
                            NCCollectivesMarkdownView(markdown: text, openLink: openLink)
                        case .embed(let alt, let source):
                            embedView(NCCollectivesEmbed(alt: alt, source: source, page: current, attachments: attachments))
                        }
                    }
                }
            }
        } else if let error {
            NCCollectivesErrorView(error: error) {
                Task { await loadContent() }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        }
    }

    @ViewBuilder
    private func embedView(_ embed: NCCollectivesEmbed) -> some View {
        if embed.isImage {
            NCCollectivesImageView(embed: embed, account: model.account, isOpening: openingEmbed == embed.id) {
                open(embed)
            }
        } else {
            NCCollectivesAttachmentRow(embed: embed, isOpening: openingEmbed == embed.id) {
                open(embed)
            }
        }
    }

    /// Attachments that the page content does not show, like files uploaded in the web sidebar.
    @ViewBuilder
    private var otherAttachments: some View {
        let sources = Set((markdown.map(NCCollectivesMarkdownBlock.blocks(from:)) ?? []).compactMap { block -> String? in
            if case .embed(_, let source) = block { return source.removingPercentEncoding ?? source }
            return nil
        })
        let others = attachments.filter { !sources.contains($0.src.removingPercentEncoding ?? $0.src) }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("_collectives_attachments_")
                    .font(.headline)
                    .padding(.top, 12)
                ForEach(others) { attachment in
                    let embed = NCCollectivesEmbed(attachment: attachment)
                    NCCollectivesAttachmentRow(embed: embed, isOpening: openingEmbed == embed.id) {
                        open(embed)
                    }
                }
            }
        }
    }

    private func openLink(_ url: URL) -> Bool {
        if let linked = model.page(for: url) {
            destination = linked
            return true
        }
        // Relative links point to attachments or other files of the collective.
        guard url.scheme == nil, current.relativePath(forSource: url.absoluteString) != nil else { return false }
        open(NCCollectivesEmbed(alt: "", source: url.absoluteString, page: current, attachments: attachments))
        return true
    }

    private func open(_ embed: NCCollectivesEmbed) {
        guard openingEmbed == nil else { return }
        openingEmbed = embed.id
        Task {
            let result = await NCCollectivesFileLoader.shared.localFile(for: embed, account: model.account)
            openingEmbed = nil
            switch result {
            case .success(let url):
                previewURL = url
            case .failure(let error):
                model.showError(error)
            }
        }
    }

    @ViewBuilder
    private var subpages: some View {
        let subpages = model.subpages(of: current)
        if !subpages.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("_collectives_subpages_")
                    .font(.headline)
                    .padding(.top, 12)
                VStack(spacing: 0) {
                    ForEach(subpages) { subpage in
                        NavigationLink(value: subpage) {
                            HStack {
                                NCCollectivePageRow(title: subpage.title, page: subpage, emoji: subpage.emoji)
                                Spacer()
                                Image(systemName: "chevron.forward")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if subpage.id != subpages.last?.id {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if canEdit {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await model.openEditor(page: current) {
                            Task { await loadContent() }
                        }
                    }
                } label: {
                    Label("_edit_", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier("collectivesEditPage")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    action = .create(parent: current)
                } label: {
                    Label("_collectives_new_subpage_", systemImage: "doc.badge.plus")
                }
            }
            if !current.isLandingPage {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        action = .rename(current)
                    } label: {
                        Label("_rename_", systemImage: "pencil")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button(role: .destructive) {
                        action = .trash(current)
                    } label: {
                        Label("_collectives_trash_page_", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func loadContent() async {
        async let attachments = model.attachments(of: current)
        let content = await model.content(of: current)
        self.attachments = await attachments
        switch content {
        case .success(let markdown):
            self.markdown = markdown
            error = nil
        case .failure(let error):
            if markdown == nil {
                self.error = error
            }
        }
    }
}
