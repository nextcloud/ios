//
//  AddToAlbumsListView.swift
//  Nextcloud
//
//  Created by Mangesh Murhe on 25/09/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct AddToAlbumsListView: View {
    
    @StateObject private var viewModel: AlbumsListViewModel
    @State private var selectedAlbum: Album? = nil
    var localAccount: String
    var onFinish: (Album) -> Void
    var onDismiss: () -> Void
    var onCreateAlbum: () -> Void
    
    init(viewModel: AlbumsListViewModel, localAccount: String, onFinish: @escaping (Album) -> Void, onDismiss: @escaping () -> Void, onCreateAlbum: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.localAccount = localAccount
        self.onFinish = onFinish
        self.onDismiss = onDismiss
        self.onCreateAlbum = onCreateAlbum
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    Section(header: Text(NSLocalizedString("_albums_list_own_albums_heading_", comment: ""))
                        .listRowInsets(EdgeInsets())
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)) {
                            ForEach(viewModel.albums) { album in
                                AlbumRow(album: album, localAccount: localAccount)
                                    .padding(.vertical, 8)
                                    .onTapGesture {
                                        selectedAlbum = album
                                    }
                                    .listRowBackground(
                                        selectedAlbum?.id == album.id
                                        ? Color.accentColor.opacity(0.2)  // light blue highlight (default iOS tint)
                                        : Color.clear
                                    )
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) // Match header padding
                                    .listRowSeparator(.hidden)
                            }
                        }
                }
                .listStyle(PlainListStyle())
                .navigationBarTitle(NSLocalizedString("_add_to_album", comment: ""), displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onDismiss) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(NSLocalizedString("_albums_photo_selection_sheet_back_btn_", comment: ""))
                            }.foregroundColor(Color(NCBrandColor.shared.customer))
                        }
                        .foregroundColor(.pink)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("_albums_photo_selection_sheet_done_btn_", comment: "")) {
                            if let selected = selectedAlbum {
                                onFinish(selected)
                            }
                        }
                        .foregroundColor(Color(NCBrandColor.shared.customer))
                        .opacity(selectedAlbum == nil ? 0.4 : 1.0)
                        .disabled(selectedAlbum == nil)
                    }
                }
                content()
            }
            .onAppear {
                AlbumsManager.shared.setAccount(localAccount)
                AlbumsManager.shared.syncAlbums()
            }
        }
//        .navigationViewStyle(StackNavigationViewStyle())
        .navigationViewStyle(.stack)
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
            NoAlbumsEmptyView(onNewAlbumCreationIntent: onCreateAlbum)
                .refreshable {
                    viewModel.onPulledToRefresh()
                }
        }
    }
}

struct AlbumRow: View {
    let album: Album
    private enum ImageState { case loading, empty, thumbnail(UIImage) }
    @State private var imageState: ImageState = .loading
    var localAccount: String
    
    var body: some View {
        HStack {
            thumbnailView()
                .frame(width: 80, height: 60)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let subtitle = makeSubtitle(for: album), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(UIColor.systemGray))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .task(id: album.lastPhotoId) {
            await loadThumbnail()
        }
    }
    
    private func makeSubtitle(for album: Album) -> String? {
        guard let count = album.itemCount else { return nil }
        var parts: [String] = ["\(count) \(NSLocalizedString("_albums_list_entities_", comment: ""))"]
        let formatter = DateFormatter()
        if count > 0, let end = album.endDate {
            formatter.dateStyle = .medium
            parts.append(formatter.string(from: end))
        } else if count == 0, let created = album.startDate {
            formatter.dateFormat = "MMMM yyyy" // "MMMM" for full month name, "yyyy" for year
            parts.append(formatter.string(from: created))
        }
        return parts.joined(separator: " - ")
    }
    
    /// Renders the thumbnail image based on the current state
    @ViewBuilder
    private func thumbnailView() -> some View {
        switch imageState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
        case .empty:
            Image("EmptyAlbum")
                .resizable()
                .scaledToFill()
                .clipped()
                .foregroundColor(.gray)
                .background(Color.gray.opacity(0.1))
        case .thumbnail(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipped()
        }
    }
    
    private func loadThumbnail() async {
        if album.lastPhotoId == "-1" || (album.itemCount ?? 0) == 0 {
            imageState = .empty
            return
        }
        guard let photoId = album.lastPhotoId else {
            imageState = .empty
            return
        }
        
        Task {

            let resultsPreview = await NextcloudKit.shared.downloadPreviewAsync(fileId: photoId, etag: "", account: localAccount) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: localAccount,
                                                                                                path: photoId,
                                                                                                name: "DownloadPreview")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if resultsPreview.error == .success, let data = resultsPreview.responseData?.data {
                NCUtility().createImageFileFrom(data: data, ocId: photoId, etag: "")
                if let image = NCUtility().getImage(ocId: photoId, etag: "", ext: NCGlobal().previewExt512) {
                    Task { @MainActor in
                        await MainActor.run { imageState = .thumbnail(image) }
                    }
                } else {
                    await MainActor.run { imageState = .empty }
                }
            }
        }
    }
}

//#if DEBUG
//#Preview {
//    NavigationView {
//        AddToAlbumsListView(viewModel: .init(account: "123"), localAccount: "", onFinish: { selectedAlbum in
//            print("Album:\(selectedAlbum)")
//        }, onDismiss: {
//           
//        }) {
//            
//        }
//    }.onAppear {
//        UIView
//            .appearance(
//                whenContainedInInstancesOf: [UIAlertController.self]
//            ).tintColor = NCBrandColor.shared.customer
//    }
//}
//#endif
