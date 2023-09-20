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

protocol DataDelegate: AnyObject {
    func updateData(metadatas: [tableMetadata], selectedMetadata: tableMetadata, image: UIImage)
}

class NCMediaUIHostingController: UIHostingController<NCMediaNew>, DataDelegate {
    required init?(coder aDecoder: NSCoder) {
        let view = NCMediaNew()
        super.init(coder: aDecoder, rootView: view)
        rootView.dataModelDelegate = self
    }

    func updateData(metadatas: [tableMetadata], selectedMetadata: tableMetadata, image: UIImage) {
        if let viewController = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateInitialViewController() as? NCViewerMediaPage {
            var index = 0
            for medatasImage in metadatas {
                if medatasImage.ocId == selectedMetadata.ocId {
                    viewController.currentIndex = index
                    break
                }
                index += 1
            }
            viewController.metadatas = metadatas

            NCViewer.shared.view(viewController: self, metadata: selectedMetadata, metadatas: metadatas, imageIcon: image)
        }
    }
}

struct NCViewerMediaPageController: UIViewControllerRepresentable {
    let metadatas: [tableMetadata]
    let selectedMetadata: tableMetadata

    func makeUIViewController(context: UIViewControllerRepresentableContext<NCViewerMediaPageController>) -> NCViewerMediaPage {

        if let viewController = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateInitialViewController() as? NCViewerMediaPage {
            var index = 0
            for medatasImage in metadatas {
                if medatasImage.ocId == selectedMetadata.ocId {
                    viewController.currentIndex = index
                    break
                }
                index += 1
            }
            viewController.metadatas = metadatas
            return viewController
        } else {
            return NCViewerMediaPage()
        }
    }

    func updateUIViewController(_ uiViewController: NCViewerMediaPage, context: UIViewControllerRepresentableContext<NCViewerMediaPageController>) {}
}

struct NCMediaNew: View {
    @StateObject private var vm = NCMediaViewModel()
    @EnvironmentObject var parent: NCMediaUI
    @State private var columns = 2
    @State private var title = "Media"
    @State private var isScrolledToTop = true
    @State private var isMediaViewControllerPresented = false
    @State private var tappedMetadata = tableMetadata()
    @State private var isInSelectMode = false

    @State var titleColor = Color.primary
    @State var toolbarItemsColor = Color.blue
    @State var toolbarColors = [Color.clear]

    @State private var showDeleteConfirmation = false

    weak var dataModelDelegate: DataDelegate?

    var body: some View {
            GeometryReader { outerProxy in
//                        NavigationView {
                ZStack(alignment: .top) {
                    VisibilityTrackingScrollView(action: cellVisibilityDidChange) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(vm.metadatas.chunked(into: columns), id: \.self) { rowMetadatas in
                                NCMediaRow(metadatas: rowMetadatas, geometryProxy: outerProxy, isInSelectMode: $isInSelectMode) { tappedThumbnail, isSelected in

                                    if isInSelectMode, isSelected {
                                        vm.selectedMetadatas.append(tappedThumbnail.metadata)
                                    } else {
                                        vm.selectedMetadatas.removeAll(where: { $0.ocId == tappedThumbnail.metadata.ocId })
                                    }

                                    let selectedMetadata = tappedThumbnail.metadata

                                    if !isInSelectMode {
                                        if let viewController = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateInitialViewController() as? NCViewerMediaPage {
                                            var index = 0
                                            for medatasImage in vm.metadatas {
                                                if medatasImage.ocId == selectedMetadata.ocId {
                                                    viewController.currentIndex = index
                                                    break
                                                }
                                                index += 1
                                            }
                                            viewController.metadatas = vm.metadatas

//                                            NCViewer.shared.view(viewController: self, metadata: selectedMetadata, metadatas: metadatas, imageIcon: image)
                                            parent.navigationController?.pushViewController(viewController, animated: true)
                                        }

//                                        dataModelDelegate?.updateData(metadatas: vm.metadatas, selectedMetadata: tappedMetadata, image: tappedThumbnail.image)
                                        //                                        isMediaViewControllerPresented = true
//                                        print(selectedMetadataInSelectMode)
                                    }
                                }
                            }

                            if vm.needsLoadingMoreItems {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .onAppear { vm.loadMoreItems() }
                                    .padding(.top, 10)
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
                        vm.onPullToRefresh()
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
                                isInSelectMode.toggle()
                            }, label: {
                                Text(NSLocalizedString(isInSelectMode ? "_cancel_" : "_select_", comment: "")).font(.system(size: 14))
                                    .foregroundStyle(toolbarItemsColor)
                            })
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(.infinity)

                            if isInSelectMode, !vm.selectedMetadatas.isEmpty {
                                ToolbarCircularButton(imageSystemName: "trash.fill", toolbarItemsColor: $toolbarItemsColor)
                                    .onTapGesture {
                                        showDeleteConfirmation = true
                                    }
                                    .confirmationDialog("", isPresented: $showDeleteConfirmation) {
                                        Button("Delete selected media", role: .destructive) {
                                            vm.deleteSelectedMetadata()
                                            isInSelectMode = false
                                        }
                                    }
                            }

                            Menu {
                                Section {
                                    Button(action: {
                                        vm.filterClassTypeImage = !vm.filterClassTypeImage
                                        vm.filterClassTypeVideo = false
                                    }, label: {
                                        Label(NSLocalizedString(vm.filterClassTypeImage ? "_media_viewimage_show_" : "_media_viewimage_hide_", comment: ""), systemImage: "photo.fill")
                                    })
                                    Button(action: {
                                        vm.filterClassTypeVideo = !vm.filterClassTypeVideo
                                        vm.filterClassTypeImage = false
                                    }, label: {
                                        Label(NSLocalizedString(vm.filterClassTypeVideo ? "_media_viewvideo_show_" : "_media_viewvideo_hide_", comment: ""), systemImage: "video.fill")
                                    })
                                    Button(action: {}, label: {
                                        Label(NSLocalizedString("_select_media_folder_", comment: ""), systemImage: "folder")
                                    })
                                }

                                Section {
                                    Button(action: {}, label: {
                                        Label(NSLocalizedString("_play_from_files_", comment: ""), systemImage: "play.circle")
                                    })
                                    Button(action: {}, label: {
                                        Label(NSLocalizedString("_play_from_url_", comment: ""), systemImage: "link")
                                    })
                                }

                                Picker("Sorting options", selection: $vm.sortType) {
                                    Label(NSLocalizedString("_media_by_modified_date_", comment: ""), systemImage: "circle.grid.cross.up.fill").tag(SortType.modifiedDate)
                                    Label(NSLocalizedString("_media_by_created_date_", comment: ""), systemImage: "circle.grid.cross.down.fill").tag(SortType.creationDate)
                                    Label(NSLocalizedString("_media_by_upload_date_", comment: ""), systemImage: "circle.grid.cross.right.fill").tag(SortType.uploadDate)
                                }
                                .pickerStyle(.menu)
                            } label: {
                                ToolbarCircularButton(imageSystemName: "ellipsis", toolbarItemsColor: $toolbarItemsColor)
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
            .onAppear { vm.loadData() }
//            .fullScreenCover(isPresented: $isMediaViewControllerPresented) {
//                NCViewerMediaPageController(metadatas: vm.metadatas, selectedMetadata: tappedMetadata)
//            }
            .onChange(of: isInSelectMode) { newValue in
//                if newValue == false { vm.selectedMetadatas.removeAll() }
            }
//        }
    }

    func cellVisibilityDidChange(_ id: String, change: VisibilityChange, tracker: VisibilityTracker<String>) {
        DispatchQueue.main.async {
            if let date = tracker.topVisibleView, !date.isEmpty {
                title = date
            }
        }
    }
}

struct ToolbarCircularButton: View {
    let imageSystemName: String
    @Binding var toolbarItemsColor: Color

    var body: some View {
        Image(systemName: imageSystemName)
            .resizable()
            .scaledToFit()
            .frame(width: 13, height: 12)
            .padding(5)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .foregroundColor(toolbarItemsColor)
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
            })
    }
}
