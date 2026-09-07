//
//  AlbumsListScreen.swift
//  Nextcloud
//
//  Created by A200118228 on 07/07/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

extension Notification.Name {
    static let albumsPopToRootRequested = Notification.Name("NCAlbumsPopToRootRequested")
}

struct AlbumsListScreen: View {
    
    @Environment(\.localAccount) var localAccount: String
//    let metadata: tableMetadata?

    enum NavigationDestination: Hashable {
        case albumDetails(album: Album)
    }
    
    @StateObject private var viewModel: AlbumsListViewModel
    @State private var popToRootTrigger: Int = 0
    
    init(viewModel: AlbumsListViewModel) {
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
        .overlay(setupNavigation.hidden())
        .sheet(
            isPresented: $viewModel.isPhotoSelectionSheetVisible,
            onDismiss: {
                viewModel.onPhotosSelected(selectedPhotos: [])
            }
        ) {
            PhotoSelectionSheet(
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
        .onReceive(NotificationCenter.default.publisher(for: .albumsPopToRootRequested)) { _ in
            // Clear any programmatic navigation and force root content
            viewModel.navigationDestination = nil
            popToRootTrigger += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NCMediaNavigationController.showAlbumDetailsNotification)) { output in
            guard let album = output.object as? Album else { return }
            // Reset to root first
            viewModel.navigationDestination = nil
            popToRootTrigger += 1
            // Navigate to the requested album
            DispatchQueue.main.async {
                viewModel.navigationDestination = .albumDetails(album: album)
            }
        }
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
    
    private var setupNavigation: some View {
        
        let binding = Binding<Bool> { [weak viewModel] in
            viewModel?.navigationDestination != nil
        } set: { [weak viewModel] value in
            guard !value else { return }
            viewModel?.navigationDestination = nil
        }
        
        return NavigationLink(isActive: binding) {
            switch viewModel.navigationDestination {
            case .some(let value):
                navigationDestination(value)
                
            case .none:
                EmptyView()
            }
        } label: {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func navigationDestination(_ destination: NavigationDestination) -> some View {
        switch destination {
        case .albumDetails(let album):
            AlbumDetailsScreen(account: localAccount, album: album)
        }
    }
}

//#if DEBUG
//#Preview {
//    NavigationView {
//        AlbumsListScreen(viewModel: .init(account: "123"))
//    }.onAppear {
//        UIView
//            .appearance(
//                whenContainedInInstancesOf: [UIAlertController.self]
//            ).tintColor = NCBrandColor.shared.customer
//    }
//}
//#endif




