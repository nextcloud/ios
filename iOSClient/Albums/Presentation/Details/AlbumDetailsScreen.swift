//
//  AlbumDetailsScreen.swift
//  Nextcloud
//
//  Created by Dhanesh on 01/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct AlbumDetailsScreen: View {
    
    private let album: Album
    @StateObject private var viewModel: AlbumDetailsViewModel
    @State private var showMedia = false
    
    init(account: String, album: Album) {
        self.album = album
        _viewModel = StateObject(
            wrappedValue: AlbumDetailsViewModel(account: account, album: album)
        )
    }
    
    var body: some View {
        
        ZStack {
            content()
            
            if viewModel.isLoadingPopupVisible {
                NCLoadingAlert()
            }
        }
        .navigationTitle(viewModel.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !viewModel.isLoading {
                    Button(action: handleAddPhotosIntent) {
                        Image(systemName: "plus")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .tint(Color(NCBrandColor.shared.iconImageColor))

                    Menu {
                        Button(NSLocalizedString("_albums_photos_rename_album_btn_", comment: "")) {
                            viewModel.onRenameAlbumIntent()
                        }
                        Button(
                            NSLocalizedString("_albums_photos_delete_album_btn_", comment: ""),
                            role: .destructive
                        ) {
                            viewModel.onDeleteAlbumIntent()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .tint(Color(NCBrandColor.shared.iconImageColor))
                }
            }
        }
        .sheet(
            isPresented: $viewModel.isPhotoSelectionSheetVisible
        ) {
            PhotoSelectionSheet(
                onPhotosSelected: viewModel.onPhotosSelected
            )
        }
        .inputAlbumNameAlert(
            isPresented: $viewModel.isRenameAlbumPopupVisible,
            albumName: $viewModel.newAlbumName,
            error: viewModel.newAlbumNameError,
            isForRenamingAlbum: true,
            onCreate: {
                viewModel.onRenameAlbumPopupConfirm()
            },
            onCancel: {
                viewModel.onRenameAlbumPopupCancel()
            }
        )
        .alert(
            NSLocalizedString("_albums_delete_album_popup_title_", comment: ""),
            isPresented: $viewModel.isDeleteAlbumPopupVisible,
            actions: {
                Button(
                    NSLocalizedString("_albums_delete_album_popup_positive_btn_", comment: ""),
                    role: .destructive,
                    action: viewModel.onDeleteAlbumPopupConfirm
                )
                Button(
                    NSLocalizedString("_albums_delete_album_popup_negative_btn_", comment: ""),
                    role: .cancel,
                    action: viewModel.onDeleteAlbumPopupCancel
                )
            },
            message: {
                Text(NSLocalizedString("_albums_delete_album_popup_desc_", comment: ""))
            }
        )
        .onAppear {
            // Force end selection mode so the tab bar remains visible on this screen
            NotificationCenter.default.post(name: Notification.Name("NCSelectionModeDidEnd"), object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: Notification.Name("NCSelectionModeDidEnd"), object: nil)
        }
        .onChange(of: viewModel.isPhotoSelectionSheetVisible) { isPresented in
            if isPresented == false {
                NotificationCenter.default.post(name: Notification.Name("NCSelectionModeDidEnd"), object: nil)
            }
        }
    }
    
    @ViewBuilder
    private func content() -> some View {
        if viewModel.isLoading {
            ProgressView(NSLocalizedString("_albums_photos_loading_msg_", comment: ""))
        } else if let error = viewModel.errorMessage {
            Text(error)
                .refreshable {
                    viewModel.onPulledToRefresh()
                }
        } else if viewModel.photos.isEmpty {
            NoPhotosEmptyView(
                onAddPhotosIntent: handleAddPhotosIntent
            )
            .refreshable {
                viewModel.onPulledToRefresh()
            }
        } else {
            PhotosGridView(
                localAccount: viewModel.account,
                photos: viewModel.photos,
                onAddPhotosIntent: handleAddPhotosIntent,
                album: album
            )
            .refreshable {
                viewModel.onPulledToRefresh()
            }
        }
    }
    
    private func handleAddPhotosIntent() {
        viewModel.onAddPhotosIntent()
        showMedia = true
    }
}
