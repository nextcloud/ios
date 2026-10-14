// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

/// Pages of a single collective, shared by the page tree and the page screens.
@MainActor
@Observable
final class NCCollectivePagesModel {
    let collective: NCCollective
    var pages: [NCCollectivePage] = []
    var isLoading = false
    var error: NKError?

    @ObservationIgnored let collectivesModel: NCCollectivesModel
    @ObservationIgnored private let networking = NCCollectivesNetworking.shared

    var landingPage: NCCollectivePage? {
        pages.first { $0.isLandingPage }
    }

    var tree: [NCCollectivePageNode] {
        guard let landingPage else { return [] }
        return NCCollectivePageNode.tree(pages: pages, parentId: landingPage.id)
    }

    private var account: String {
        collectivesModel.account
    }

    init(collective: NCCollective, collectivesModel: NCCollectivesModel) {
        self.collective = collective
        self.collectivesModel = collectivesModel
    }

    func page(id: Int) -> NCCollectivePage? {
        pages.first { $0.id == id }
    }

    func subpages(of page: NCCollectivePage) -> [NCCollectivePage] {
        NCCollectivePageNode.tree(pages: pages, parentId: page.id).map(\.page)
    }

    func page(for url: URL) -> NCCollectivePage? {
        NCCollectivePage.pageId(linkedBy: url).flatMap(page(id:))
    }

    /// The display title; the landing page carries the collective's name.
    func title(of page: NCCollectivePage) -> String {
        page.isLandingPage ? collective.name : page.title
    }

    func emoji(of page: NCCollectivePage) -> String? {
        page.isLandingPage ? collective.emoji : page.emoji
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        switch await networking.getPages(collectiveId: collective.id, account: account) {
        case .success(let pages):
            self.pages = pages
            error = nil
        case .failure(let error):
            self.error = error
        }
    }

    func content(of page: NCCollectivePage) async -> Result<String, NKError> {
        // Reload the page first: adding a subpage moves a page's file into a folder.
        let current = self.page(id: page.id) ?? page
        return await networking.getContent(page: current, account: account)
    }

    @discardableResult
    func createPage(title: String, parent: NCCollectivePage) async -> NCCollectivePage? {
        switch await networking.createPage(title: title, parentId: parent.id, collectiveId: collective.id, account: account) {
        case .success(let page):
            await load()
            return page
        case .failure(let error):
            collectivesModel.showError(error)
            return nil
        }
    }

    func rename(_ page: NCCollectivePage, to title: String) async {
        switch await networking.renamePage(page, title: title, collectiveId: collective.id, account: account) {
        case .success:
            await load()
        case .failure(let error):
            collectivesModel.showError(error)
        }
    }

    func trash(_ page: NCCollectivePage) async -> Bool {
        switch await networking.trashPage(page, collectiveId: collective.id, account: account) {
        case .success:
            await load()
            return true
        case .failure(let error):
            collectivesModel.showError(error)
            return false
        }
    }

    /// Matches page titles locally and adds the server's full-text results.
    func search(_ text: String) async -> [NCCollectivePage] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        var results = pages.filter { !$0.isLandingPage && $0.title.localizedStandardContains(query) }
        if case .success(let found) = await networking.searchPages(text: query, collectiveId: collective.id, account: account) {
            let known = Set(results.map(\.id))
            results += found.filter { !known.contains($0.id) }.map { self.page(id: $0.id) ?? $0 }
        }
        return results
    }

    /// Opens the editor and reloads the pages once it is closed.
    func openEditor(page: NCCollectivePage, onClose: @escaping () -> Void) async {
        await collectivesModel.openEditor(page: self.page(id: page.id) ?? page) { [weak self] in
            Task {
                await self?.load()
                onClose()
            }
        }
    }
}
