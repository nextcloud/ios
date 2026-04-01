// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

@MainActor
final class NCShareTagEditorModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var tags: [NKTag] = []
    @Published private(set) var selectedTagIDs: Set<String> = []
    @Published private(set) var pendingNewTagNames: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var hasLoaded = false

    private let metadata: tableMetadata
    private let initialTagTokens: Set<String>
    private let windowScene: UIWindowScene?
    private var initialAssignedTagIDs: Set<String> = []

    init(metadata: tableMetadata, initialTags: [String], windowScene: UIWindowScene?) {
        self.metadata = metadata
        self.initialTagTokens = Set(initialTags)
        self.windowScene = windowScene
    }

    var account: String {
        metadata.account
    }

    var filteredTags: [NKTag] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return tags
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var createCandidateName: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let hasExistingTag = tags.contains {
            $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if hasExistingTag {
            return nil
        }

        let alreadyPending = pendingNewTagNames.contains {
            $0.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }

        return alreadyPending ? nil : trimmed
    }

    func isSelected(_ tag: NKTag) -> Bool {
        selectedTagIDs.contains(tag.id)
    }

    func loadTagsIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        _ = await reloadTags(keepCurrentSelection: false)
    }

    func toggleSelection(for tag: NKTag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
    }

    func addCreateCandidateToSelection() {
        guard let candidate = createCandidateName else {
            return
        }
        pendingNewTagNames.insert(candidate)
        searchText = ""
    }

    func saveChanges() async -> [String]? {
        guard !metadata.fileId.isEmpty else {
            await showErrorBanner(
                windowScene: windowScene,
                text: "_error_occurred_",
                errorCode: NCGlobal.shared.errorInternalError
            )
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        if !pendingNewTagNames.isEmpty {
            for name in pendingNewTagNames.sorted() {
                let createResult = await NextcloudKit.shared.createTagAsync(name: name, account: metadata.account)
                if createResult.error != .success {
                    await showErrorBanner(windowScene: windowScene, error: createResult.error)
                    return nil
                }
            }

            guard await reloadTags(keepCurrentSelection: true) else {
                return nil
            }

            for pendingName in pendingNewTagNames {
                if let tag = tags.first(where: {
                    $0.name.compare(pendingName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }) {
                    selectedTagIDs.insert(tag.id)
                }
            }
        }

        let tagsToAdd = selectedTagIDs.subtracting(initialAssignedTagIDs)
        let tagsToRemove = initialAssignedTagIDs.subtracting(selectedTagIDs)

        for tagID in tagsToAdd.sorted() {
            let addResult = await NextcloudKit.shared.addTagToFileAsync(tagId: tagID, fileId: metadata.fileId, account: metadata.account)
            if addResult.error != .success {
                await showErrorBanner(windowScene: windowScene, error: addResult.error)
                return nil
            }
        }

        for tagID in tagsToRemove.sorted() {
            let removeResult = await NextcloudKit.shared.removeTagFromFileAsync(tagId: tagID, fileId: metadata.fileId, account: metadata.account)
            if removeResult.error != .success {
                await showErrorBanner(windowScene: windowScene, error: removeResult.error)
                return nil
            }
        }

        let selectedTagNames = tags
            .filter { selectedTagIDs.contains($0.id) }
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        await NCManageDatabase.shared.setMetadataTagsAsync(ocId: metadata.ocId, tags: selectedTagNames)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferReloadDataSource(serverUrl: self.metadata.serverUrl, requestData: false, status: nil)
        }

        initialAssignedTagIDs = selectedTagIDs
        pendingNewTagNames.removeAll()

        return selectedTagNames
    }

    private func reloadTags(keepCurrentSelection: Bool) async -> Bool {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        let result = await NextcloudKit.shared.getTagsAsync(account: metadata.account)
        guard result.error == .success, let receivedTags = result.tags else {
            await showErrorBanner(windowScene: windowScene, error: result.error)
            return false
        }

        tags = receivedTags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if keepCurrentSelection {
            let validTagIDs = Set(tags.map(\.id))
            selectedTagIDs = Set(selectedTagIDs.filter { validTagIDs.contains($0) })
            return true
        }

        let assignedIDs = Set(tags.filter { tag in
            initialTagTokens.contains(tag.id) || initialTagTokens.contains(tag.name)
        }.map(\.id))

        initialAssignedTagIDs = assignedIDs
        selectedTagIDs = assignedIDs
        return true
    }
}
