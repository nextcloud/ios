// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct AlbumsListScreen: View {
    private unowned let controller: NCMainTabBarController
    @StateObject private var viewModel: AlbumsListViewModel

    init(controller: NCMainTabBarController, viewModel: AlbumsListViewModel) {
        self.controller = controller
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            content()

            if viewModel.isLoadingPopupVisible {
                NCLoadingAlert()
            }
        }
        .navigationTitle(NSLocalizedString("_albums_list_nav_title_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: { viewModel.onNewAlbumClick() }) {
                    Text(NSLocalizedString("_albums_list_new_album_btn_", comment: ""))
                        .font(.body)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tint(Color(NCBrandColor.shared.iconImageColor))
            }
        }
        .sheet(
            isPresented: $viewModel.isPhotoSelectionSheetVisible,
            onDismiss: {
                viewModel.onPhotosSelected(selectedPhotos: [])
            }
        ) {
            PhotoSelectionSheet(
                controller: controller,
                onPhotosSelected: viewModel.onPhotosSelected
            )
        }
        .inputAlbumNameAlert(
            isPresented: $viewModel.isNewAlbumCreationPopupVisible,
            albumName: $viewModel.newAlbumName,
            error: viewModel.newAlbumNameError,
            onCreate: {
                viewModel.onNewAlbumPopupCreate()
            },
            onCancel: {
                viewModel.onNewAlbumPopupCancel()
            }
        )
    }

    @ViewBuilder
    private func content() -> some View {
        if viewModel.isLoading {
            ProgressView(NSLocalizedString("_albums_list_loading_msg_", comment: ""))
        } else if let error = viewModel.errorMessage {
            ScrollView(.vertical) {
                VStack {
                    Spacer()
                    Text(error)
                    Spacer()
                }
            }
            .refreshable {
                viewModel.onPulledToRefresh()
            }
        } else if viewModel.albums.isEmpty {
            NoAlbumsEmptyView(onNewAlbumCreationIntent: viewModel.onNewAlbumClick)
                .refreshable {
                    viewModel.onPulledToRefresh()
                }
        } else {
            AlbumsGridView(
                albums: viewModel.albums.sorted { (lhs: Album, rhs: Album) -> Bool in
                    let l = lhs.name
                    let r = rhs.name
                    return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
                },
                onAlbumClicked: viewModel.onAlbumClicked
            )
            .refreshable {
                viewModel.onPulledToRefresh()
            }
        }
    }
}
