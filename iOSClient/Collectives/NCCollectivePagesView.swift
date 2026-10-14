// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The page tree of a collective, with search and page management.
struct NCCollectivePagesView: View {
    @State var model: NCCollectivePagesModel
    @State private var action: NCCollectivePageAction?
    @State private var searchText = ""
    @State private var searchResults: [NCCollectivePage] = []
    @State private var isSearching = false
    @State private var createdPage: NCCollectivePage?

    private var canEdit: Bool {
        model.collective.canEdit
    }

    var body: some View {
        content
            .navigationTitle(model.collective.name)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: NCCollectivePage.self) { page in
                NCCollectivePageView(page: page, model: model)
            }
            .navigationDestination(item: $createdPage) { page in
                NCCollectivePageView(page: page, model: model)
            }
            .toolbar {
                if canEdit, let landingPage = model.landingPage {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            action = .create(parent: landingPage)
                        } label: {
                            Label("_collectives_new_page_", systemImage: "plus")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text("_collectives_search_prompt_"))
            .task(id: searchText) {
                guard !searchText.isEmpty else {
                    searchResults = []
                    return
                }
                isSearching = true
                // Debounce typing before asking the server for full-text results.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let results = await model.search(searchText)
                guard !Task.isCancelled else { return }
                searchResults = results
                isSearching = false
            }
            .task {
                if model.pages.isEmpty {
                    await model.load()
                }
            }
            .modifier(NCCollectivePageDialogs(action: $action, model: model, onCreated: { page in
                createdPage = page
            }))
    }

    @ViewBuilder
    private var content: some View {
        if model.pages.isEmpty {
            if model.isLoading {
                ProgressView()
            } else if let error = model.error {
                NCCollectivesErrorView(error: error) {
                    Task { await model.load() }
                }
            }
        } else if !searchText.isEmpty {
            searchList
        } else {
            pageList
        }
    }

    private var pageList: some View {
        List {
            if let landingPage = model.landingPage {
                Section {
                    NavigationLink(value: landingPage) {
                        NCCollectivePageRow(title: model.collective.name, page: landingPage, emoji: model.collective.emoji, systemImage: "house")
                    }
                }
            }
            let tree = model.tree
            if !tree.isEmpty {
                Section("_collectives_pages_") {
                    OutlineGroup(tree, children: \.children) { node in
                        NavigationLink(value: node.page) {
                            NCCollectivePageRow(title: node.page.title, page: node.page, emoji: node.page.emoji)
                        }
                        .contextMenu { menu(for: node.page) }
                        .swipeActions(edge: .trailing) {
                            if canEdit {
                                Button(role: .destructive) {
                                    action = .trash(node.page)
                                } label: {
                                    Label("_collectives_trash_page_", systemImage: "trash")
                                }
                                Button {
                                    action = .rename(node.page)
                                } label: {
                                    Label("_rename_", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.load() }
    }

    private var searchList: some View {
        List(searchResults) { page in
            NavigationLink(value: page) {
                NCCollectivePageRow(title: page.title, page: page, emoji: page.emoji)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if searchResults.isEmpty {
                if isSearching {
                    ProgressView()
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for page: NCCollectivePage) -> some View {
        if canEdit {
            Button {
                action = .create(parent: page)
            } label: {
                Label("_collectives_new_subpage_", systemImage: "doc.badge.plus")
            }
            Button {
                action = .rename(page)
            } label: {
                Label("_rename_", systemImage: "pencil")
            }
            Button(role: .destructive) {
                action = .trash(page)
            } label: {
                Label("_collectives_trash_page_", systemImage: "trash")
            }
        }
    }
}
