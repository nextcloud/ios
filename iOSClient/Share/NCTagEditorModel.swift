// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

@MainActor
@Observable final class NCTagEditorModel {
    var searchText: String = ""
    private(set) var tags: [NKTag] = []
    private(set) var selectedTagIDs: Set<String> = []
    private(set) var pendingNewTagNames: Set<String> = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isUpdatingTagColor = false
    private(set) var hasLoaded = false

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

    func openTagColorPicker(for tag: NKTag) {
        guard let picker = UIStoryboard(name: "NCColorPicker", bundle: nil).instantiateInitialViewController() as? NCColorPicker,
              let presenter = topViewController() else {
            return
        }

        if let colorHex = tag.color, let color = UIColor(hex: colorHex) {
            picker.selectedColor = color
        }
        picker.onColorSelected = { [weak self] hexColor in
            guard let self else { return }
            Task { @MainActor in
                await self.updateTagColor(tagID: tag.id, colorHex: hexColor)
            }
        }

        let popup = NCPopupViewController(contentController: picker, popupWidth: 200, popupHeight: 320)
        popup.backgroundAlpha = 0
        presenter.present(popup, animated: true)
    }

    func addCreateCandidateToSelection() {
        guard let candidate = createCandidateName else {
            return
        }
        pendingNewTagNames.insert(candidate)
        tags.append(NKTag(id: candidate, name: candidate, color: nil))
        tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedTagIDs.insert(candidate)
        searchText = ""
    }

    var selectedTags: [NKTag] {
        tags
            .filter { selectedTagIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func saveChanges() async -> [NKTag]? {
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

        let hasNewTags = !pendingNewTagNames.isEmpty

        if hasNewTags {
            for name in pendingNewTagNames.sorted() {
                let createResult = await NextcloudKit.shared.createTag(name: name, account: metadata.account)
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
            let addResult = await NextcloudKit.shared.addTagToFile(tagId: tagID, fileId: metadata.fileId, account: metadata.account)
            if addResult.error != .success {
                await showErrorBanner(windowScene: windowScene, error: addResult.error)
                return nil
            }
        }

        for tagID in tagsToRemove.sorted() {
            let removeResult = await NextcloudKit.shared.removeTagFromFile(tagId: tagID, fileId: metadata.fileId, account: metadata.account)
            if removeResult.error != .success {
                await showErrorBanner(windowScene: windowScene, error: removeResult.error)
                return nil
            }
        }

        let selectedTags = self.selectedTags

        await NCManageDatabase.shared.setMetadataTagsAsync(ocId: metadata.ocId, account: metadata.account, tags: selectedTags)
        metadata.tags.removeAll()
        metadata.tags.append(objectsIn: selectedTags, account: metadata.account)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferReloadDataSource(serverUrl: self.metadata.serverUrl, requestData: true, status: nil)
        }

        initialAssignedTagIDs = selectedTagIDs
        pendingNewTagNames.removeAll()

        return selectedTags
    }

    func showTagAddedBanner(tagName: String) async {
        let message = String(format: NSLocalizedString("_share_tags_added_named_", comment: ""), tagName)
        await showInfoBanner(
            windowScene: windowScene,
            title: "_success_",
            text: message
        )
    }

    private func reloadTags(keepCurrentSelection: Bool) async -> Bool {
        isLoading = true

        defer {
            isLoading = false
            hasLoaded = true
        }

        let result = await NextcloudKit.shared.getTags(account: metadata.account)
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

    private func updateTagColor(tagID: String, colorHex: String?) async {
        isUpdatingTagColor = true
        defer { isUpdatingTagColor = false }

        let result = await NextcloudKit.shared.updateTagColor(tagId: tagID, color: colorHex, account: metadata.account)
        guard result.error == .success else {
            await showErrorBanner(windowScene: windowScene, error: result.error)
            return
        }

        guard let index = tags.firstIndex(where: { $0.id == tagID }) else {
            return
        }

        let oldTag = tags[index]
        tags[index] = NKTag(id: oldTag.id, name: oldTag.name, color: colorHex)
    }

    private func topViewController() -> UIViewController? {
        let root = windowScene?.keyWindow?.rootViewController ?? windowScene?.windows.first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
