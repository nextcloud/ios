//
//  NCMediaCellView.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import VisibilityTrackingScrollView
import Shimmer
import NextcloudKit

enum ContextMenuSelection {
    case addToFavorites, details, openIn, saveToPhotos, viewInFolder, modify, delete
}

struct NCMediaCell: View {
    let thumbnail: ScaledThumbnail
    let shrinkRatio: CGFloat
    @Binding var isInSelectMode: Bool
    @State private var isSelected = false
    let onSelected: (ScaledThumbnail, Bool) -> Void
    let onContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void

    @State var isFavorite: Bool

    @State private var showDeleteConfirmation = false

    var body: some View {
        let image = Image(uiImage: thumbnail.image)
            .resizable()
            .trackVisibility(id: CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date) ?? "")

        ZStack(alignment: .center) {
            if thumbnail.isPlaceholderImage {
                image
                    .foregroundColor(Color(uiColor: .systemGray4))
                    .scaledToFit()
                    .frame(width: 40)
            } else {
                image
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            if thumbnail.metadata.isVideo, !thumbnail.isPlaceholderImage {
                Image(systemName: "play.fill")
                    .resizable()
                    .foregroundColor(Color(uiColor: .white))
                    .scaledToFit()
                    .frame(width: 16)
                    .padding([.leading, .bottom], 10)
            }
        }
        .overlay {
            if isInSelectMode, isSelected {
                Color.black.opacity(0.6).frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isInSelectMode, isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .foregroundColor(.blue)
                    .background(.white)
                    .clipShape(Circle())
                    .scaledToFit()
                    .frame(width: 20)
                    .padding([.trailing, .bottom], 10)
            }
        }
        .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
        .background(Color(uiColor: .systemGray6))
        .onTapGesture {
            if isInSelectMode { isSelected.toggle() }
            onSelected(thumbnail, isSelected)
        }
        .onChange(of: isInSelectMode) { newValue in
            isSelected = !newValue
        }
        .contextMenu(menuItems: {
            Button {
                onContextMenuItemSelected(thumbnail, .details)
            } label: {
                Label(NSLocalizedString("_details_", comment: ""), systemImage: "info")
            }

            Button {
                isFavorite.toggle()
                onContextMenuItemSelected(thumbnail, .addToFavorites)
            } label: {
                Label(isFavorite ?
                      NSLocalizedString("_remove_favorites_", comment: "") :
                      NSLocalizedString("_add_favorites_", comment: ""), systemImage: "star.fill")
            }

            Button {
                onContextMenuItemSelected(thumbnail, .openIn)
            } label: {
                Label(NSLocalizedString("_open_in_", comment: ""), systemImage: "square.and.arrow.up")
            }

            Button {
                onContextMenuItemSelected(thumbnail, .saveToPhotos)
            } label: {
                Label(NSLocalizedString("_save_selected_files_", comment: ""), systemImage: "square.and.arrow.down")
            }

            Button {
                onContextMenuItemSelected(thumbnail, .viewInFolder)
            } label: {
                Label(NSLocalizedString("_view_in_folder_", comment: ""), systemImage: "folder.fill")
            }

            Button {
                onContextMenuItemSelected(thumbnail, .modify)
            } label: {
                Label(NSLocalizedString("_modify_", comment: ""), systemImage: "pencil.tip.crop.circle")
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("_delete_file_", comment: ""), systemImage: "trash")
            }
        })
        .confirmationDialog("", isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("_delete_file_", comment: ""), role: .destructive) {
                onContextMenuItemSelected(thumbnail, .delete)
            }
        }
    }
}

struct NCMediaLoadingCell: View {
    let itemsInRow: Int
    let metadata: tableMetadata
    let geometryProxy: GeometryProxy
    let spacing: CGFloat

    let gradient = Gradient(colors: [
        .black.opacity(0.4),
        .black.opacity(0.7),
        .black.opacity(0.4)
    ])

    var body: some View {
        ZStack {
            Image(uiImage: UIImage())
                .resizable()
                .trackVisibility(id: CCUtility.getTitleSectionDate(metadata.date as Date) ?? "")// TODO: Fix spacing
                .aspectRatio(1.5, contentMode: .fit)
                .frame(width: (geometryProxy.size.width - spacing) / CGFloat(itemsInRow))
                .redacted(reason: .placeholder)
                .shimmering(gradient: gradient, bandSize: 0.7)
        }
    }
}
