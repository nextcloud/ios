// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCShareView: View {
    @ObservedObject var model: NCShareViewModel
    @State private var fileActions: String?

    var body: some View {
        NavigationStack {
            Group {
                if model.isAvailable && model.isAuthenticated {
                    VStack(spacing: 0) {
                        statusView
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                        GeometryReader { geometry in
                            if UIDevice.current.userInterfaceIdiom == .phone && geometry.size.width > geometry.size.height {
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
                    .background(Color(uiColor: .systemGroupedBackground))
                } else if model.isSwitchingAccount && model.isAuthenticated {
                    ProgressView()
                                .accessibilityLabel(NSLocalizedString("_request_in_progress_", comment: ""))
                } else {
                    Color(uiColor: .systemBackground)
                }
            }
            .dynamicTypeSize(.xSmall ... .accessibility2)
            .background(Color(uiColor: .systemBackground))
            .sheet(item: $model.uploadConfirmation, onDismiss: { model.uploadConfirmationDismissed() }) { confirmation in
                NCShareUploadConflictView(confirmation: confirmation, resolve: model.resolveUploadConfirmation)
            }
            .navigationTitle(model.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if model.isAvailable && model.isAuthenticated {
                        HStack(spacing: 8) {
                            NCShareAccountMenu(model: model)
                                .disabled(model.isLoading || model.isPreparingUpload || model.isSwitchingAccount || model.isLoadingAccounts)
                            if model.isLoading || !model.loadingFolderURLs.isEmpty {
                                ProgressView()
                                    .accessibilityLabel(NSLocalizedString(model.isLoading ? "_share_checking_folder_" : "_share_loading_folders_", comment: ""))
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
        if !model.alertMessage.isEmpty {
            statusError(model.alertMessage) { model.acknowledgeAlert() }
        } else if !model.inputErrorMessage.isEmpty && model.isShowingInputError {
            statusError(model.inputErrorMessage) { model.acknowledgeInputError() }
        } else if model.isOffline {
            VStack(spacing: 8) {
                Label(NSLocalizedString("_share_online_required_", comment: ""), systemImage: "wifi.slash")
                    .cappedFont(.subheadline, maxDynamicType: .accessibility2)
                    .multilineTextAlignment(.center)
                Button(NSLocalizedString("_share_capabilities_retry_", comment: ""), action: model.retryConnection)
            }
            .padding()
        } else if !model.capabilitiesErrorMessage.isEmpty {
            VStack(spacing: 8) {
                Text(verbatim: model.capabilitiesErrorMessage)
                    .cappedFont(.subheadline, maxDynamicType: .accessibility2)
                    .multilineTextAlignment(.center)
                Button(NSLocalizedString("_share_capabilities_retry_", comment: ""), action: model.retryCapabilities)
                    .disabled(model.isSwitchingAccount)
            }
            .padding()
        } else if let row = model.visibleFolderRows.first(where: { model.folderLoadErrors[$0.folder.serverUrl] != nil }),
                  let error = model.folderLoadErrors[row.folder.serverUrl] {
            VStack(spacing: 8) {
                Text(verbatim: error)
                    .cappedFont(.subheadline, maxDynamicType: .accessibility2)
                    .multilineTextAlignment(.center)
                Button(NSLocalizedString("_share_retry_folder_", comment: "")) { model.retryFolder(row.folder) }
            }
            .padding()
        } else if model.isLoadingCapabilities {
            ProgressView(NSLocalizedString("_share_capabilities_loading_", comment: ""))
                .padding()
        } else if model.isPreparingInput {
            ProgressView(NSLocalizedString("_share_import_preparing_", comment: ""))
                .padding()
        }
    }

    private func statusError(_ message: String, acknowledge: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text(verbatim: message)
                .cappedFont(.subheadline, maxDynamicType: .accessibility2)
                .multilineTextAlignment(.center)
            Button(NSLocalizedString("_ok_", comment: ""), action: acknowledge)
        }
        .padding()
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
                        folderListTitle("_share_recent_folders_")
                        ForEach(model.recentFolders) { folder in
                            folderRow(folder, depth: nil)
                        }
                    }
                    folderListTitle("_share_all_folders_")
                    ForEach(model.visibleFolderRows) { row in
                        folderRow(row.folder, depth: row.depth)
                        if model.expandedFolderURLs.contains(row.folder.serverUrl) {
                            if model.folderLoadErrors[row.folder.serverUrl] == nil,
                               model.loadedFolderURLs.contains(row.folder.serverUrl),
                               model.folderChildren[row.folder.serverUrl]?.isEmpty == true {
                                Text(NSLocalizedString("_files_no_folders_", comment: ""))
                                    .cappedFont(.caption, maxDynamicType: .accessibility2)
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
            .environment(\.defaultMinListRowHeight, 0)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, horizontalInset)
        }
        .frame(maxHeight: .infinity)
        .clipped()
        .background(Color(uiColor: .systemGroupedBackground))
        .disabled(model.isLoading || model.isPreparingUpload || !model.isAccountReady || model.isLoadingAccounts)
    }

    private func folderListTitle(_ key: String) -> some View {
        Text(NSLocalizedString(key, comment: ""))
            .cappedFont(.caption, maxDynamicType: .accessibility2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var createFolderHeader: some View {
        HStack {
            Spacer()
            Button(action: model.createFolder) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("_create_folder_", comment: ""))
                    Image(systemName: "folder.badge.plus")
                }
                .cappedFont(.subheadline, maxDynamicType: .accessibility2)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(.blue)
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
                    Image(systemName: model.expandedFolderURLs.contains(folder.serverUrl) ? "chevron.down" : "chevron.right")
                        .frame(width: 50, height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(format: NSLocalizedString(
                    model.expandedFolderURLs.contains(folder.serverUrl) ? "_share_collapse_folder_" : "_share_expand_folder_", comment: ""), folder.name))
                .padding(.leading, CGFloat(min(depth, 8)) * 16)
            } else {
                Image(systemName: "clock")
                    .cappedFont(.subheadline, maxDynamicType: .accessibility2)
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
                            .overlay(alignment: .topTrailing) {
                                if folder.isFavorite {
                                    Image(systemName: "star.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(Color(uiColor: NCBrandColor.shared.yellowFavorite))
                                        .frame(width: 10, height: 10)
                                        .background {
                                            Image(systemName: "star")
                                                .resizable()
                                                .scaledToFit()
                                                .fontWeight(.thin)
                                                .foregroundStyle(Color(uiColor: .systemBackground))
                                                .frame(width: 12, height: 12)
                                        }
                                        .offset(x: 3, y: -3)
                                        .accessibilityLabel(NSLocalizedString("_share_favorite_folder_", comment: ""))
                                }
                            }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: folder.name)
                            .cappedFont(.body, maxDynamicType: .accessibility2)
                            .foregroundStyle(Color(uiColor: .label))
                            .lineLimit(1)
                        if depth == nil {
                            Text(verbatim: folder.path)
                                .cappedFont(.caption2, maxDynamicType: .accessibility2)
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
                    .padding(.horizontal, 5)
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2))
        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func fileList(fillsHeight: Bool = false, horizontalInset: CGFloat = 16) -> some View {
        List(model.fileNames, id: \.self) { fileName in
            Button {
                fileActions = fileName
            } label: {
                HStack {
                    Label {
                        Text(verbatim: fileName).lineLimit(2)
                    } icon: {
                        Group {
                            if let thumbnail = model.fileThumbnails[fileName] {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
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
                    Spacer(minLength: 0)
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 50, height: 50)
                        .accessibilityHidden(true)
                }
                .cappedFont(.body, maxDynamicType: .accessibility2)
                .frame(maxWidth: .infinity, minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .confirmationDialog(Text(verbatim: fileName), isPresented: Binding(
                get: { fileActions == fileName },
                set: { if !$0 { fileActions = nil } }
            ), titleVisibility: .visible) {
                Button(NSLocalizedString("_rename_file_", comment: "")) {
                    model.rename(fileName)
                }
                Button(NSLocalizedString("_remove_file_", comment: ""), role: .destructive) {
                    model.remove(fileName)
                }
                Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 2))
            .listRowSeparator(.hidden)
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
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
            HStack(spacing: 8) {
                if model.isPreparingUpload {
                    ProgressView()
                        .tint(.white)
                    Text(NSLocalizedString("_share_conflict_checking_", comment: ""))
                } else {
                    Text(String.localizedStringWithFormat(NSLocalizedString("_share_upload_to_", comment: ""), model.fileNames.count))
                }
            }
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .padding(.horizontal, 16)
        .disabled(model.fileNames.isEmpty || !model.isUploadDestinationReady || model.isLoading ||
                  model.isPreparingUpload || model.isPreparingInput || !model.isAccountReady ||
                  model.isLoadingAccounts || !model.inputErrorMessage.isEmpty)
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
        .environment(\.locale, Locale(identifier: "en_US"))
        .allowsHitTesting(false)
}

#Preview("No folders") {
    let model = NCShareViewModel.preview()
    model.folderChildren = [:]
    model.recentFolders = []
    model.loadedFolderURLs = Set(model.folders.map(\.serverUrl))
    return NCShareView(model: model)
        .environment(\.locale, Locale(identifier: "en_US"))
        .allowsHitTesting(false)
}

#Preview("Preparing files") {
    let model = NCShareViewModel.preview()
    model.fileNames = []
    model.isPreparingInput = true
    return NCShareView(model: model)
        .environment(\.locale, Locale(identifier: "en_US"))
        .allowsHitTesting(false)
}
#Preview("Capabilities unavailable") {
    let model = NCShareViewModel.preview()
    model.serverCapabilities = nil
    model.capabilitiesErrorMessage = NSLocalizedString("_share_capabilities_unavailable_", comment: "")
    return NCShareView(model: model)
        .environment(\.locale, Locale(identifier: "en_US"))
        .allowsHitTesting(false)
}

#Preview("Loading capabilities") {
    let model = NCShareViewModel.preview()
    model.serverCapabilities = nil
    model.isLoadingCapabilities = true
    return NCShareView(model: model)
        .environment(\.locale, Locale(identifier: "en_US"))
        .allowsHitTesting(false)
}
#endif
