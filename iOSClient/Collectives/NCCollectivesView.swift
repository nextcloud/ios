// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Lists the collectives of the current account.
struct NCCollectivesView: View {
    @State var model: NCCollectivesModel
    @State private var path = NavigationPath()
    @State private var searchText = ""

    private var filteredCollectives: [NCCollective] {
        guard !searchText.isEmpty else { return model.collectives }
        return model.collectives.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(Text("_collectives_"))
                .navigationDestination(for: NCCollective.self) { collective in
                    NCCollectivePagesView(model: NCCollectivePagesModel(collective: collective, collectivesModel: model))
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            model.controller?.presentSidebar()
                        } label: {
                            Label("_sidebar_navigation_", systemImage: "sidebar.left")
                        }
                        .accessibilityIdentifier("openSidebar")
                    }
                }
        }
        .task {
            await model.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name(NCGlobal.shared.notificationCenterChangeUser))) { notification in
            guard let account = notification.userInfo?["account"] as? String,
                  let controller = notification.userInfo?["controller"] as? NCMainTabBarController,
                  controller === model.controller,
                  account != model.account else { return }
            path = NavigationPath()
            Task {
                await model.switchAccount(account)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.collectives.isEmpty {
            if model.isLoading {
                ProgressView()
            } else if let error = model.error {
                NCCollectivesErrorView(error: error) {
                    Task { await model.load() }
                }
            } else {
                ContentUnavailableView {
                    Label("_collectives_empty_", systemImage: "books.vertical")
                } description: {
                    Text("_collectives_empty_description_")
                }
                .refreshable { await model.load() }
            }
        } else {
            List(filteredCollectives) { collective in
                NavigationLink(value: collective) {
                    HStack(spacing: 14) {
                        NCCollectivesEmojiIcon(emoji: collective.emoji, systemImage: "books.vertical", size: 40)
                        Text(collective.name)
                            .font(.body.weight(.medium))
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("collective-\(collective.id)")
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText)
            .refreshable { await model.load() }
            .overlay {
                if filteredCollectives.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}
