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
                        statusView
                        GeometryReader { geometry in
                            if geometry.size.width >= 600 && geometry.size.height < 450 && geometry.size.width > geometry.size.height {
                                VStack(spacing: 0) {
                                    createFolderHeader
                                        .padding(.horizontal, 16)
                                    HStack(spacing: 10) {
                                        folderList(showHeader: false, horizontalInset: 0)
                                            .frame(maxWidth: .infinity)
                                        fileList(fillsHeight: true, horizontalInset: 0)
                                            .frame(width: min(320, geometry.size.width * 0.38))
                                    }
                                    .padding(.horizontal, 16)
                                    uploadButton
                                        .padding(.top, 10)
                                        .padding(.bottom, 16)
                                }
                                .background(Color(uiColor: .systemGroupedBackground))
                            } else {
                                VStack(spacing: 0) {
                                    folderList()
                                    commands()
                                }
                            }
                        }
                    }
                } else if model.isSwitchingAccount && model.isAuthenticated {
                    ProgressView()
                                .accessibilityLabel(NSLocalizedString("_request_in_progress_", comment: ""))
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
            .navigationTitle(model.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if model.isAvailable && model.isAuthenticated {
                        HStack(spacing: 8) {
                            NCShareAccountMenu(model: model)
                                .disabled(model.isLoading || model.isPreparingUpload || model.isSwitchingAccount || model.isLoadingAccounts)
                            if model.isLoading || !model.loadingFolderURLs.isEmpty {
                                ProgressView()
                                    .accessibilityLabel(NSLocalizedString("_request_in_progress_", comment: ""))
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("_cancel_", comment: "")) { model.cancel() }
                }
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if model.isOffline {
            VStack(spacing: 8) {
                Label(NSLocalizedString("_share_online_required_", comment: ""), systemImage: "wifi.slash")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button(NSLocalizedString("_share_capabilities_retry_", comment: ""), action: model.retryConnection)
            }
            .padding()
        } else if !model.capabilitiesErrorMessage.isEmpty {
            VStack(spacing: 8) {
                Text(verbatim: model.capabilitiesErrorMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button(NSLocalizedString("_share_capabilities_retry_", comment: ""), action: model.retryCapabilities)
                    .disabled(model.isSwitchingAccount)
            }
            .padding()
        } else if model.isLoadingCapabilities {
            ProgressView(NSLocalizedString("_share_capabilities_loading_", comment: ""))
                .padding()
        } else if model.isPreparingInput {
            ProgressView(NSLocalizedString("_share_import_preparing_", comment: ""))
                .padding()
        } else if model.isPreparingUpload {
            ProgressView(NSLocalizedString("_share_conflict_checking_", comment: ""))
                .padding()
        }
    }

    private func folderList(showHeader: Bool = true, horizontalInset: CGFloat = 16) -> some View {
        VStack(spacing: 0) {
            if showHeader {
                createFolderHeader
                    .padding(.horizontal, horizontalInset)
            }
            List {
                Section {
                    if !model.recentFolders.isEmpty {
                        ForEach(model.recentFolders) { folder in
                            folderRow(folder, depth: nil)
                        }
                    }
                    ForEach(model.visibleFolderRows) { row in
                        folderRow(row.folder, depth: row.depth)
                            .padding(.top, !model.recentFolders.isEmpty && row.id == model.visibleFolderRows.first?.id ? 12 : 0)
                            .overlay(alignment: .top) {
                                if !model.recentFolders.isEmpty, row.id == model.visibleFolderRows.first?.id {
                                    Rectangle()
                                        .fill(Color(uiColor: .separator))
                                        .frame(height: 1)
                                        .padding(.top, 6)
                                        .padding(.horizontal, -12)
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }
                            }
                        if model.expandedFolderURLs.contains(row.folder.serverUrl) {
                            if let error = model.folderLoadErrors[row.folder.serverUrl] {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(verbatim: error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Button(NSLocalizedString("_share_retry_folder_", comment: "")) { model.retryFolder(row.folder) }
                                }
                                .padding(.leading, CGFloat(min(row.depth + 1, 8)) * 16)
                            } else if model.loadedFolderURLs.contains(row.folder.serverUrl),
                                      model.folderChildren[row.folder.serverUrl]?.isEmpty == true {
                                Text(NSLocalizedString("_files_no_folders_", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, CGFloat(min(row.depth + 1, 8)) * 16)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 50)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, horizontalInset)
        }
        .frame(maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .disabled(model.isLoading || model.isPreparingUpload || !model.isAccountReady || model.isLoadingAccounts)
    }

    private var createFolderHeader: some View {
        HStack {
            Spacer()
            Button(action: model.createFolder) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("_create_folder_", comment: ""))
                    Image(systemName: "folder.badge.plus")
                }
                .font(.subheadline)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(model.isPreparingInput || !model.inputErrorMessage.isEmpty ||
                      (model.selectedFolder.map { model.loadingFolderURLs.contains($0.serverUrl) } ?? true))
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    private func folderRow(_ folder: NCShareFolderItem, depth: Int?) -> some View {
        let isSelected = model.selectedFolder?.serverUrl == folder.serverUrl && model.isRecentFolderSelected == (depth == nil)
        return HStack(spacing: 4) {
            if let depth {
                Button {
                    model.toggleFolder(folder)
                } label: {
                    Group {
                        if model.loadingFolderURLs.contains(folder.serverUrl) {
                            ProgressView()
                        } else {
                            Image(systemName: model.expandedFolderURLs.contains(folder.serverUrl) ? "chevron.down" : "chevron.right")
                        }
                    }
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(format: NSLocalizedString(
                    model.expandedFolderURLs.contains(folder.serverUrl) ? "_share_collapse_folder_" : "_share_expand_folder_", comment: ""), folder.name))
                .padding(.leading, CGFloat(min(depth, 8)) * 16)
            } else {
                Image(systemName: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)
            }
            Button {
                model.selectFolder(folder, fromRecents: depth == nil)
            } label: {
                HStack(spacing: 8) {
                    if let image = folder.image {
                        Image(uiImage: image)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: folder.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if depth == nil {
                            Text(verbatim: folder.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .frame(width: 50, height: 50)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2))
        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func fileList(fillsHeight: Bool = false, horizontalInset: CGFloat = 16) -> some View {
    List(model.fileNames, id: \.self) { fileName in
        HStack {
            Button {
                model.rename(fileName)
            } label: {
                Label {
                    Text(verbatim: fileName).lineLimit(2)
                } icon: {
                    Group {
                        if let thumbnail = model.fileThumbnails[fileName] {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: model.fileIcon(named: fileName))
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .accessibilityHidden(true)
                    .task(id: fileName) { model.loadThumbnail(named: fileName) }
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
                    .frame(minWidth: 50, minHeight: 50)
            }
            .accessibilityLabel(Text(verbatim: fileName))
        }
        .font(.body)
        .frame(minHeight: 50)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 2))
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .contentMargins(.vertical, 0, for: .scrollContent)
    .scrollContentBackground(.hidden)
    .environment(\.defaultMinListRowHeight, 50)
    .frame(height: fillsHeight ? nil : CGFloat(min(max(model.fileNames.count, 1), 3)) * 50)
        .frame(maxHeight: fillsHeight ? .infinity : nil)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal, horizontalInset)

        .disabled(model.isPreparingUpload || model.isPreparingInput || !model.isAccountReady || model.isLoadingAccounts || !model.inputErrorMessage.isEmpty)
    }

    private var uploadButton: some View {
    Button(action: model.upload) {
        Text(String.localizedStringWithFormat(NSLocalizedString("_share_upload_to_", comment: ""), model.fileNames.count))
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.roundedRectangle(radius: 12))
    .padding(.horizontal, 16)
    .disabled(model.fileNames.isEmpty || model.selectedFolder == nil || model.isLoading)
        .disabled(model.isPreparingUpload || model.isPreparingInput || !model.isAccountReady || model.isLoadingAccounts || !model.inputErrorMessage.isEmpty)
    }

    private func commands() -> some View {
        VStack(spacing: 10) {
            fileList()
            uploadButton
        }
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Color(uiColor: .systemGroupedBackground))
    }

}

#if DEBUG && SHARE_PREVIEWS
#Preview("Share") {
    NCShareView(model: .preview())
        .allowsHitTesting(false)
}

#Preview("Landscape", traits: .fixedLayout(width: 844, height: 390)) {
    NCShareView(model: .preview())
        .allowsHitTesting(false)
}

#Preview("No folders") {
    let model = NCShareViewModel.preview()
    model.folderChildren = [:]
    model.recentFolders = []
    model.loadedFolderURLs = Set(model.folders.map(\.serverUrl))
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
#Preview("Capabilities unavailable") {
    let model = NCShareViewModel.preview()
    model.serverCapabilities = nil
    model.capabilitiesErrorMessage = NSLocalizedString("_share_capabilities_unavailable_", comment: "")
    return NCShareView(model: model)
        .allowsHitTesting(false)
}

#Preview("Loading capabilities") {
    let model = NCShareViewModel.preview()
    model.serverCapabilities = nil
    model.isLoadingCapabilities = true
    return NCShareView(model: model)
        .allowsHitTesting(false)
}
#endif
