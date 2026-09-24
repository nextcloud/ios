// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct AddToAlbumsListView: View {
    private unowned let controller: NCMainTabBarController

    @StateObject private var viewModel: AlbumsListViewModel
    @State private var selectedAlbum: Album?

    var onFinish: (Album) -> Void
    var onDismiss: () -> Void
    var onCreateAlbum: () -> Void

    private var localAccount: String {
        controller.account
    }

    init(viewModel: AlbumsListViewModel, controller: NCMainTabBarController, onFinish: @escaping (Album) -> Void, onDismiss: @escaping () -> Void, onCreateAlbum: @escaping () -> Void) {
        self.controller = controller
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onFinish = onFinish
        self.onDismiss = onDismiss
        self.onCreateAlbum = onCreateAlbum
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    Section {
                        Button(action: {
                            onCreateAlbum()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: localAccount)))
                                Text(NSLocalizedString("_albums_list_new_album_popup_title_", comment: "Create new album"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: localAccount)))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemGroupedBackground).opacity(0.08))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }

                    Section(header: Text(NSLocalizedString("_albums_list_own_albums_heading_", comment: ""))
                        .listRowInsets(EdgeInsets())
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .navigationTitle(NSLocalizedString("_add_to_album", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel(NSLocalizedString("_cancel_", comment: ""))
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            if let selected = selectedAlbum {
                                onFinish(selected)
                            }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel(NSLocalizedString("_done_", comment: ""))
                        .disabled(selectedAlbum == nil)
                    }
                }
                content()
            }
            .onAppear {
                AlbumsManager.shared.syncAlbums(for: localAccount)
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
            NoAlbumsEmptyView(onNewAlbumCreationIntent: onCreateAlbum)
                .refreshable {
                    viewModel.onPulledToRefresh()
                }
        }
    }
}

struct AlbumRow: View {
    let album: Album
    var localAccount: String

    var body: some View {
        HStack {
            AlbumGridItemView(album: album)
                .environment(\.localAccount, localAccount)
                .frame(width: 60, height: 60)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let subtitle = makeSubtitle(for: album), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func makeSubtitle(for album: Album) -> String? {
        guard let count = album.itemCount else { return nil }
        var parts: [String] = [
            String.localizedStringWithFormat(
                NSLocalizedString("_albums_list_photos_and_videos_count_", comment: ""),
                count
            )
        ]
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
}
