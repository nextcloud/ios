// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

struct NCTagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: NCTagEditorModel
    @State private var isSearchPresented = false

    private let onApplied: ([NKTag]) -> Void

    init(metadata: tableMetadata, initialTags: [String], windowScene: UIWindowScene?, onApplied: @escaping ([NKTag]) -> Void) {
        _model = State(initialValue: NCTagEditorModel(metadata: metadata, initialTags: initialTags, windowScene: windowScene))
        self.onApplied = onApplied
    }

    var body: some View {
        NavigationStack {
            List {
                if let createCandidateName = model.createCandidateName {
                    Section {
                        Button {
                            addTagAndExitSearch(tagName: createCandidateName)
                        } label: {
                            Label(
                                String(format: NSLocalizedString("_share_tags_create_", comment: ""), createCandidateName),
                                systemImage: "plus.circle.fill"
                            )
                        }
                    }
                }

                Section {
                    if model.filteredTags.isEmpty, model.createCandidateName == nil, !model.isLoading {
                        Text(NSLocalizedString("_share_tags_no_results_", comment: ""))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.filteredTags, id: \.id) { tag in
                            Button {
                                model.toggleSelection(for: tag)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(color(for: tag))
                                        .frame(width: 10, height: 10)

                                    Text(tag.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if model.isSelected(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color(NCBrandColor.shared.getElement(account: model.account)))
                                    }
                                }
                            }
                            .contextMenu {
                                Button {
                                    model.openTagColorPicker(for: tag)
                                } label: {
                                    Label(NSLocalizedString("_change_color_", comment: ""), systemImage: "paintpalette")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    model.openTagColorPicker(for: tag)
                                } label: {
                                    Label(NSLocalizedString("_change_color_", comment: ""), systemImage: "paintpalette")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(NSLocalizedString("_tags_", comment: ""))
            .searchable(
                text: $model.searchText,
                isPresented: $isSearchPresented,
                prompt: Text(NSLocalizedString("_search_or_create_tags", comment: ""))
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("_cancel_", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("_done_", comment: "")) {
                        Task { @MainActor in
                            guard let selectedTags = await model.saveChanges() else {
                                return
                            }
                            onApplied(selectedTags)
                            dismiss()
                        }
                    }
                    .disabled(model.isSaving || model.isLoading || model.isUpdatingTagColor)
                }
            }
            .overlay {
                if model.isLoading || model.isSaving || model.isUpdatingTagColor {
                    ProgressView()
                }
            }
        }
        .task {
            await model.loadTagsIfNeeded()
        }
    }

    private func color(for tag: NKTag) -> Color {
        if let colorHex = tag.color, let color = UIColor(hex: colorHex) {
            return Color(color)
        }
        return .secondary
    }

    private func addTagAndExitSearch(tagName: String) {
        model.addCreateCandidateToSelection()
        Task { @MainActor in
            await model.showTagAddedBanner(tagName: tagName)
        }
        isSearchPresented = false
        unfocusSearchField()
    }

    private func unfocusSearchField() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    NCTagEditorPreviewSheetScaffold()
}

private struct NCTagEditorPreviewSheetScaffold: View {
    @State private var isPresentingTagEditor = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Tag Editor Preview")
                    .font(.headline)

                Button("Open Tag Editor Sheet") {
                    isPresentingTagEditor = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Preview Host")
            .sheet(isPresented: $isPresentingTagEditor) {
                previewTagEditor
            }
        }
    }

    private var previewTagEditor: NCTagEditorView {
        let metadata = tableMetadata()
        metadata.account = "preview"
        metadata.fileId = "1"
        metadata.ocId = "preview-ocid"
        metadata.serverUrl = "/"
        metadata.urlBase = "https://cloud.example.com"

        return NCTagEditorView(
            metadata: metadata,
            initialTags: ["Important", "Ideas"],
            windowScene: nil
        ) { _ in }
    }
}
