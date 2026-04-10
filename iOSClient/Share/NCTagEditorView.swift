// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

struct NCTagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: NCTagEditorModel

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
                            model.addCreateCandidateToSelection()
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
                        }
                    }
                } header: {
                    Text(NSLocalizedString("_tags_", comment: ""))
                }
            }
            .listStyle(.plain)
//            .scrollContentBackground(.hidden)
            .background(.regularMaterial)
            .navigationTitle(NSLocalizedString("_tags_", comment: ""))
            .searchable(text: $model.searchText, prompt: Text(NSLocalizedString("_search_", comment: "")))
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
                    .disabled(model.isSaving || model.isLoading)
                }
            }
            .overlay {
                if model.isLoading || model.isSaving {
                    ProgressView()
                }
            }
        }
        .background(.regularMaterial)
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
