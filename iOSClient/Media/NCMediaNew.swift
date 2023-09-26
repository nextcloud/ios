//
//  NCMediaNew.swift
//  Nextcloud
//
//  Created by Milen on 25.08.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots
import NextcloudKit
import VisibilityTrackingScrollView
@_spi(Advanced) import SwiftUIIntrospect

struct NCMediaNew: View {
    @StateObject private var vm = NCMediaViewModel()
    @EnvironmentObject var parent: NCMediaUIKitWrapper
    @State private var columns = 2
    @State private var title = "Media"
    @State private var isScrolledToTop = true
    @State private var tappedMetadata = tableMetadata()

    @State var titleColor = Color.primary
    @State var toolbarItemsColor = Color.blue
    @State var toolbarColors = [Color.clear]

    @State private var showDeleteConfirmation = false
    @State private var showPlayFromURLAlert = false
    @State private var playFromUrlString = ""

    var body: some View {
        GeometryReader { outerProxy in
            ZStack(alignment: .top) {
                VisibilityTrackingScrollView(action: cellVisibilityDidChange) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.metadatas.chunked(into: columns), id: \.self) { rowMetadatas in
                            NCMediaRow(metadatas: rowMetadatas, geometryProxy: outerProxy, isInSelectMode: $vm.isInSelectMode) { tappedThumbnail, isSelected in

                                //TODO: Put in VM
                                if vm.isInSelectMode, isSelected {
                                    vm.selectedMetadatas.append(tappedThumbnail.metadata)
                                } else {
                                    vm.selectedMetadatas.removeAll(where: { $0.ocId == tappedThumbnail.metadata.ocId })
                                }

                                if !vm.isInSelectMode {
                                    let selectedMetadata = tappedThumbnail.metadata
                                    vm.onCellTapped(metadata: selectedMetadata)
                                    NCViewer.shared.view(viewController: parent, metadata: selectedMetadata, metadatas: vm.metadatas, imageIcon: tappedThumbnail.image)
                                }
                            } onCellContextMenuItemSelected: { thumbnail, selection in
                                let selectedMetadata = thumbnail.metadata

                                switch selection {
                                case .addToFavorites:
                                    vm.addToFavorites(metadata: selectedMetadata)
                                case .details:
                                    NCActionCenter.shared.openShare(viewController: parent, metadata: selectedMetadata, page: .activity)
                                case .openIn:
                                    vm.openIn(metadata: selectedMetadata)
                                case .saveToPhotos:
                                    vm.saveToPhotos(metadata: selectedMetadata)
                                case .viewInFolder:
                                    vm.viewInFolder(metadata: selectedMetadata)
                                case .modify:
                                    vm.modify(metadata: selectedMetadata)
                                case .delete:
                                    vm.delete(metadatas: selectedMetadata)
                                }
                            }

                            if vm.needsLoadingMoreItems {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .onAppear { vm.loadMoreItems() }
                                    .padding(.top, 10)
                            }
                        }
                    }
                    .padding(.top, 70)
                    .padding(.bottom, 40)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
                    })
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        let isScrolledToTop = value.y >= -10

                        withAnimation(.default) {
                            titleColor = isScrolledToTop ? Color.primary : .white
                            toolbarItemsColor = isScrolledToTop ? .blue : .white
                            toolbarColors = isScrolledToTop ? [.clear] : [.black.opacity(0.8), .black.opacity(0.0)]
                        }
                    }
                }
                .refreshable {
                    await vm.onPullToRefresh()
                }
                // Not possible to move the refresh control view via SwiftUI, so we have to introspect the internal UIKit views to move it.
                // TODO: Maybe .contespontMargins() will resolve this but it's iOS 17+
                .introspect(.scrollView, on: .iOS(.v15...)) { scrollView in
                    scrollView.refreshControl?.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.refreshControl?.topAnchor.constraint(equalTo: scrollView.superview!.topAnchor, constant: 120).isActive = true
                    scrollView.refreshControl?.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor).isActive = true
                }
                .coordinateSpace(name: "scroll")

                // Toolbar

                HStack(content: {
                    HStack {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(titleColor)

                        Spacer()

                        Button(action: {
                            vm.isInSelectMode.toggle()
                        }, label: {
                            Text(NSLocalizedString(vm.isInSelectMode ? "_cancel_" : "_select_", comment: "")).font(.system(size: 14))
                                .foregroundStyle(toolbarItemsColor)
                        })
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(.infinity)

                        if vm.isInSelectMode, !vm.selectedMetadatas.isEmpty {
                            ToolbarCircularButton(imageSystemName: "trash.fill", color: .red)
                                .onTapGesture {
                                    showDeleteConfirmation = true
                                }
                                .confirmationDialog("", isPresented: $showDeleteConfirmation) {
                                    Button(NSLocalizedString("_delete_selected_media_", comment: ""), role: .destructive) {
                                        vm.deleteSelectedMetadata()
                                    }
                                }
                        }

                        Menu {
                            if vm.isInSelectMode, !vm.selectedMetadatas.isEmpty {
                                Section {
                                    Button {
                                        vm.copyOrMoveSelectedMetadataInApp()
                                    } label: {
                                        Label(NSLocalizedString("_move_selected_files_", comment: ""), systemImage: "arrow.up.right.square")
                                    }

                                    Button {
                                        vm.copySelectedMetadata()
                                    } label: {
                                        Label(NSLocalizedString("_copy_file_", comment: ""), systemImage: "doc.on.doc")
                                    }
                                }
                            }

                            Section {
                                Picker(NSLocalizedString("_media_view_options_", comment: ""), selection: $vm.filter) {
                                    Label(NSLocalizedString("_media_viewimage_show_", comment: ""), systemImage: "photo.fill").tag(Filter.onlyPhotos)

                                    Label(NSLocalizedString("_media_viewvideo_show_", comment: ""), systemImage: "video.fill").tag(Filter.onlyVideos)

                                    Text(NSLocalizedString("_media_show_all_", comment: "")).tag(Filter.all)
                                }.pickerStyle(.menu)

                                Button {
                                    selectMediaFolder()
                                } label: {
                                    Label(NSLocalizedString("_select_media_folder_", comment: ""), systemImage: "folder")
                                }
                            }

                            Section {
                                Button(action: {
                                    var documentPickerViewController: NCDocumentPickerViewController?

                                    if let tabBarController = vm.appDelegate?.window?.rootViewController as? UITabBarController {
                                        documentPickerViewController = NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: parent)
                                    }
                                }, label: {
                                    Label(NSLocalizedString("_play_from_files_", comment: ""), systemImage: "play.circle")
                                })

                                Button(action: {
                                    showPlayFromURLAlert = true
                                }, label: {
                                    Label(NSLocalizedString("_play_from_url_", comment: ""), systemImage: "link")
                                })
                            }
                        } label: {
                            ToolbarCircularButton(imageSystemName: "ellipsis", color: $toolbarItemsColor)
                        }
                    }
                })
                .frame(maxWidth: .infinity)
                .padding([.horizontal, .top], 10)
                .padding(.bottom, 20)
                .background(LinearGradient(gradient: Gradient(colors: toolbarColors), startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.top))
            }
        }
        .onRotate { orientation in
            if orientation.isLandscapeHardCheck {
                columns = 6
            } else {
                columns = 2
            }
        }
        .onAppear { vm.loadMediaFromDB() }
        .onChange(of: vm.isInSelectMode) { newValue in
            if newValue == false { vm.selectedMetadatas.removeAll() }
        }
        .alert("", isPresented: $showPlayFromURLAlert) {
            TextField("https://...", text: $playFromUrlString)
                .keyboardType(.URL)
                .textContentType(.URL)

            Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("_ok_", comment: "")) {
                playVideoFromUrl()
            }
        } message: {
            Text(NSLocalizedString("_valid_video_url_", comment: ""))
        }
    }

    private func cellVisibilityDidChange(_ id: String, change: VisibilityChange, tracker: VisibilityTracker<String>) {
        DispatchQueue.main.async {
            if let date = tracker.topVisibleView, !date.isEmpty {
                title = date
            }
        }
    }

    private func selectMediaFolder() {
        guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
              let viewController = navigationController.topViewController as? NCSelect
        else { return }

        viewController.delegate = vm
        viewController.typeOfCommandView = .select
        viewController.type = "mediaFolder"

        parent.present(navigationController, animated: true, completion: nil)
    }

    private func playVideoFromUrl() {
        guard let metadata = vm.getMetadataFromUrl(playFromUrlString) else { return }
        NCViewer.shared.view(viewController: parent, metadata: metadata, metadatas: [metadata], imageIcon: nil)
    }
}

struct ToolbarCircularButton: View {
    let imageSystemName: String
    @Binding var color: Color

    init(imageSystemName: String, color: Binding<Color>) {
        self.imageSystemName = imageSystemName
        self._color = color
    }

    init(imageSystemName: String, color: Color) {
        self.imageSystemName = imageSystemName
        self._color = .constant(color)
    }

    var body: some View {
        Image(systemName: imageSystemName)
            .resizable()
            .scaledToFit()
            .frame(width: 13, height: 12)
            .padding(5)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .foregroundColor(color)
    }
}

struct NCMediaNew_Previews: PreviewProvider {
    static var previews: some View {
        snapshots.previews.previewLayout(.sizeThatFits)
    }

    static var snapshots: PreviewSnapshots<String> {
        PreviewSnapshots(
            configurations: [
                .init(name: NCGlobal.shared.defaultSnapshotConfiguration, state: "")
            ],
            configure: { _ in
                NCMediaNew()
                    .environmentObject(NCMediaUIKitWrapper())
            })
    }
}
