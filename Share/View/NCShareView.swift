// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCShareView: View {
    @ObservedObject var model: NCShareViewModel

    var body: some View {
        NavigationStack {
            Group {
                if model.isAvailable && model.isAuthenticated {
                    VStack(spacing: 0) {
                        folderList
                        if model.isPreparingInput {
                            ProgressView(NSLocalizedString("_share_import_preparing_", comment: ""))
                                .padding()
                        }
                        if model.isPreparingUpload {
                            ProgressView(NSLocalizedString("_share_conflict_checking_", comment: ""))
                                .padding()
                        }
                        commands
                    }
                } else if model.isSwitchingAccount && model.isAuthenticated {
                    ProgressView(NSLocalizedString("_request_in_progress_", comment: ""))
                } else {
                    Color(uiColor: .systemBackground)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .alert(NSLocalizedString("_error_", comment: ""), isPresented: $model.isShowingInputError) {
                Button(NSLocalizedString("_ok_", comment: "")) { model.acknowledgeInputError() }
            } message: {
                Text(verbatim: model.inputErrorMessage)
            }
            .sheet(item: $model.uploadConfirmation, onDismiss: { model.uploadConfirmationDismissed() }) { confirmation in
                NCShareUploadConflictView(confirmation: confirmation, resolve: model.resolveUploadConfirmation)
            }
            .sheet(isPresented: $model.isShowingAccounts, onDismiss: { model.accountPickerDismissed() }) {
                NCShareAccountPickerView(model: model)
            }
            .navigationTitle(model.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if model.isAvailable && model.isAuthenticated {
                        if model.canGoBack {
                            Button(action: model.goBack) {
                                Label(NSLocalizedString("_back_", comment: ""), systemImage: "chevron.left")
                            }
                            .disabled(model.isLoading || model.isPreparingUpload || model.isSwitchingAccount || model.isLoadingAccounts)
                        }
                        Button(action: model.showAccountPicker) {
                            Label(model.accountName, systemImage: "person.crop.circle")
                                .lineLimit(1)
                        }
                        .disabled(model.isLoading || model.isPreparingUpload || model.isSwitchingAccount || model.isLoadingAccounts)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("_cancel_", comment: "")) { model.cancel() }
                }
            }
        }
    }

    private var folderList: some View {
        List(model.folders) { folder in
            Button {
                model.openFolder(folder)
            } label: {
                HStack(spacing: 12) {
                    if let image = folder.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }
                    Text(verbatim: folder.name)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .overlay {
            if model.folders.isEmpty {
                if model.isLoading {
                    ProgressView(NSLocalizedString("_request_in_progress_", comment: ""))
                } else {
                    ContentUnavailableView(NSLocalizedString("_files_no_folders_", comment: ""), systemImage: "folder")
                }
            }
        }
        .disabled(model.isLoading || model.isPreparingUpload || model.isSwitchingAccount || model.isLoadingAccounts)
    }

    private var commands: some View {
        VStack(spacing: 12) {
            Button(action: model.createFolder) {
                Label(NSLocalizedString("_create_folder_", comment: ""), systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            List(model.fileNames, id: \.self) { fileName in
                HStack {
                    Button {
                        model.rename(fileName)
                    } label: {
                        Label {
                            Text(verbatim: fileName).lineLimit(2)
                        } icon: {
                            Image(systemName: "doc")
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Menu {
                        Button(NSLocalizedString("_rename_file_", comment: "")) {
                            model.rename(fileName)
                        }
                        Button(NSLocalizedString("_remove_file_", comment: ""), role: .destructive) {
                            model.remove(fileName)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: fileName))
                }
            }
            .listStyle(.plain)
            .frame(height: CGFloat(min(max(model.fileNames.count, 1), 3)) * 64)

            Button(action: model.upload) {
                Text(NSLocalizedString("_upload_", comment: "") + " \(model.fileNames.count) " + NSLocalizedString("_files_", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.fileNames.isEmpty || model.isLoading || model.isShowingAccounts)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .disabled(model.isPreparingUpload || model.isPreparingInput || model.isSwitchingAccount || model.isLoadingAccounts || !model.inputErrorMessage.isEmpty)
    }
}

#if DEBUG
#Preview("Share") {
    NCShareView(model: .preview())
        .allowsHitTesting(false)
}

#Preview("No folders") {
    let model = NCShareViewModel.preview()
    model.folders = []
    return NCShareView(model: model)
        .allowsHitTesting(false)
}

#Preview("Preparing files") {
    let model = NCShareViewModel.preview()
    model.fileNames = []
    model.isPreparingInput = true
    return NCShareView(model: model)
        .allowsHitTesting(false)
}
#endif
