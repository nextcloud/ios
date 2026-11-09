// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCShareUploadConflictView: View {
    let confirmation: NCShareUploadConfirmation
    let resolve: @MainActor (NCShareUploadChoice?) -> Void

    var body: some View {
        let renamedItems = confirmation.renamedItems
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("_share_conflict_new_names_", comment: ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 12)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(renamedItems, id: \.sourceName) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                NCShareFilenameView(name: item.sourceName)
                                    .cappedFont(.caption, maxDynamicType: .accessibility2)
                                    .foregroundStyle(.secondary)
                                NCShareFilenameView(name: item.fileName)
                            }
                            .padding(.vertical, 12)
                            if item.sourceName != renamedItems.last?.sourceName {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    Text(confirmation.isBatch
                         ? NSLocalizedString("_share_conflict_batch_message_", comment: "")
                         : String(format: NSLocalizedString("_share_conflict_single_message_", comment: ""), NCShareFilenameView.displayName(confirmation.items[0].sourceName)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 16) {
                    if !confirmation.isBatch, confirmation.replacementFileName != nil {
                        Button(role: .destructive) {
                            resolve(.replace)
                        } label: {
                            Text(NSLocalizedString("_share_conflict_replace_", comment: ""))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                        .tint(.red)
                        .padding(.horizontal, 16)
                    }

                    NCShareUploadButton(
                        fileCount: confirmation.items.count,
                        title: confirmation.isBatch ? nil : NSLocalizedString("_share_conflict_upload_with_new_name_", comment: "")
                    ) {
                        resolve(.keepBoth)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .background(Color(uiColor: .systemGroupedBackground))
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
