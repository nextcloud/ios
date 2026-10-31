// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCShareUploadConflictView: View {
    let confirmation: NCShareUploadConfirmation
    let resolve: @MainActor (NCShareUploadChoice?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(confirmation.isBatch
                         ? NSLocalizedString("_share_conflict_batch_message_", comment: "")
                         : String(format: NSLocalizedString("_share_conflict_single_message_", comment: ""), confirmation.items[0].sourceName))
                }
                Section(NSLocalizedString("_share_conflict_new_names_", comment: "")) {
                    ForEach(confirmation.renamedItems, id: \.sourceName) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: item.sourceName)
                                .cappedFont(.caption, maxDynamicType: .accessibility2)
                                .foregroundStyle(.secondary)
                            Text(verbatim: item.fileName)
                        }
                    }
                }
                Section {
                    if !confirmation.isBatch, confirmation.replacementFileName != nil {
                        Button(NSLocalizedString("_share_conflict_replace_", comment: ""), role: .destructive) {
                            resolve(.replace)
                        }
                    }
                    Button(confirmation.isBatch
                           ? NSLocalizedString("_upload_", comment: "")
                           : NSLocalizedString("_share_conflict_keep_both_", comment: "")) {
                        resolve(.keepBoth)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("_share_conflict_title_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("_cancel_", comment: "")) { resolve(nil) }
                }
            }
        }
    }
}

#if DEBUG && SHARE_PREVIEWS
#Preview("Single file conflict") {
    NCShareUploadConflictView(
        confirmation: NCShareUploadConfirmation(
            account: "personal",
            serverUrl: "https://cloud.example.com/Documents",
            items: [NCShareUploadItem(sourceName: "Report.pdf", fileName: "Report (1).pdf")],
            replacementFileName: "Report.pdf",
            replacementETag: "preview-etag",
            requiresConfirmation: true),
        resolve: { _ in })
}

#Preview("Multiple file conflicts") {
    NCShareUploadConflictView(
        confirmation: NCShareUploadConfirmation(
            account: "personal",
            serverUrl: "https://cloud.example.com/Documents",
            items: [
                NCShareUploadItem(sourceName: "Report.pdf", fileName: "Report (1).pdf"),
                NCShareUploadItem(sourceName: "Photo.jpg", fileName: "Photo (2).jpg"),
                NCShareUploadItem(sourceName: "Notes.txt", fileName: "Notes.txt")
            ],
            replacementFileName: nil,
            replacementETag: nil,
            requiresConfirmation: true),
        resolve: { _ in })
}
#endif
