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
import Combine
@_spi(Advanced) import SwiftUIIntrospect
import Queuer

struct NCMediaNew: View {
    @StateObject private var vm = NCMediaViewModel()
    @EnvironmentObject private var parent: NCMediaUIKitWrapper
    @State private var metadatas: [tableMetadata] = []
    @State private var title = NSLocalizedString("_media_", comment: "")
    @State private var isScrolledToTop = true
    @State private var isScrolledToBottom = false
    @State private var isScrollingStopped = true
    @State private var tappedMetadata = tableMetadata()

    @State private var loadingIndicatorColor = Color.gray
    @State private var titleColor = Color.primary
    @State private var toolbarItemsColor = Color.blue
    @State private var toolbarColors = [Color.clear]

    @State private var showDeleteConfirmation = false
    @State private var showPlayFromURLAlert = false
    @State private var playFromUrlString = ""

    @State private var columnCountStages = [2, 3, 4]
    @State private var columnCountStagesIndex = 0
    @State private var columnCountChanged = false

    @State private var selectedMetadatas: [tableMetadata] = []
    @State private var isInSelectMode = false

    @State private var shouldScrollToTop = false
    @State private var hasOldMedia = true

    @State private var showEmptyView = false
    @State private var topMostVisibleMetadataDate: Date?
    @State private var bottomMostVisibleMetadataDate: Date?

    var body: some View {
        let _ = Self._printChanges()

        ZStack(alignment: .top) {
            if showEmptyView {
                EmptyMediaView()
            }

            ScrollViewReader { proxy in
                NCMediaScrollView(metadatas: metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), isInSelectMode: $isInSelectMode, selectedMetadatas: $selectedMetadatas, title: $title, shouldShowPaginationLoading: $hasOldMedia, topMostVisibleMetadataDate: $topMostVisibleMetadataDate, bottomMostVisibleMetadataDate: $bottomMostVisibleMetadataDate, proxy: proxy) { tappedThumbnail, isSelected in
                    if isInSelectMode, isSelected {
                        selectedMetadatas.append(tappedThumbnail.metadata)
                    } else {
                        selectedMetadatas.removeAll(where: { $0.ocId == tappedThumbnail.metadata.ocId })
                    }

                    if !isInSelectMode {
                        let selectedMetadata = tappedThumbnail.metadata
                        vm.onCellTapped(metadata: selectedMetadata)
                        NCViewer().view(viewController: parent, metadata: selectedMetadata, metadatas: vm.metadatas, imageIcon: tappedThumbnail.image)
                    }
                } onCellContextMenuItemSelected: { thumbnail, selection in
                    onCellContentMenuItemSelected(thumbnail: thumbnail, selection: selection)
                }
                .equatable()
                .ignoresSafeArea(.all, edges: .horizontal)
                .scrollStatusByIntrospect(isScrolledToTop: $isScrolledToTop, isScrolledToBottom: $isScrolledToBottom, isScrollingStopped: $isScrollingStopped)
            }

            HStack {
                ToolbarTitle(title: $title, titleColor: $titleColor)

                Spacer()

                if vm.isLoading {
                    ProgressView()
                        .tint(loadingIndicatorColor)
                        .padding(.horizontal, 6)
                }

                ToolbarSelectButton(isInSelectMode: $isInSelectMode, toolbarItemsColor: $toolbarItemsColor)

                if isInSelectMode, !selectedMetadatas.isEmpty {
                    ToolbarCircularButton(imageSystemName: "trash.fill", color: .red)
                        .onTapGesture {
                            showDeleteConfirmation = true
                        }
                        .confirmationDialog("", isPresented: $showDeleteConfirmation) {
                            Button(NSLocalizedString("_delete_selected_media_", comment: ""), role: .destructive) {
                                vm.deleteMetadata(metadatas: selectedMetadatas)
                                cancelSelection()
                            }
                        }
                }

                ToolbarMenu(isInSelectMode: $isInSelectMode, selectedMetadatas: $selectedMetadatas, showPlayFromURLAlert: $showPlayFromURLAlert, toolbarItemsColor: $toolbarItemsColor)
            }
            .frame(maxWidth: .infinity)
            .padding([.horizontal, .top], 10)
            .padding(.bottom, 20)
            .background(LinearGradient(gradient: Gradient(colors: toolbarColors), startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -50)
                .ignoresSafeArea(.all, edges: [.all])
            )
        }
        .onRotate { orientation in
            if orientation.isLandscapeHardCheck {
                columnCountStages = [4, 6, 8]
            } else {
                columnCountStages = [2, 3, 4]
            }
        }
        .onReceive(vm.$metadatas) { newValue in
            metadatas = newValue
            showEmptyView = metadatas.isEmpty
        }
        .onReceive(vm.$triggerLoadMedia) { newValue in
            if newValue {
                vm.triggerLoadMedia = false

                var fromDate: Date?
                var toDate: Date?

                if let topMostVisibleMetadataDate, let bottomMostVisibleMetadataDate {
                    fromDate = min(topMostVisibleMetadataDate, bottomMostVisibleMetadataDate)
                    toDate = max(topMostVisibleMetadataDate, bottomMostVisibleMetadataDate)
                }

                vm.searchMedia(from: fromDate, to: toDate, isScrolledToTop: isScrolledToTop, isScrolledToBottom: isScrolledToBottom)
            }
        }
        .onReceive(vm.$hasOldMedia) { newValue in
            hasOldMedia = newValue
        }
        .onReceive(vm.$filter) { _ in
            cancelSelection()
        }
        .onChange(of: isInSelectMode) { newValue in
            if newValue == false { selectedMetadatas.removeAll() }
        }

        .onChange(of: columnCountStagesIndex) { _ in
            columnCountChanged = true
        }
        .onChange(of: isScrolledToTop) { newValue in
            withAnimation(.default) {
                titleColor = newValue ? Color.primary : .white
                loadingIndicatorColor = newValue ? Color.gray : .white
                toolbarItemsColor = newValue ? .blue : .white
                toolbarColors = newValue ? [.clear] : [Color.black.opacity(0.8), Color.black.opacity(0.4), .clear]
            }
        }
        .onChange(of: isScrollingStopped) { newValue in
            if newValue {
                vm.startLoadingNewMediaTimer()
            }
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
        .gesture(
            MagnificationGesture(minimumScaleDelta: 0)
                .onChanged { scale in
                    if !columnCountChanged {
                        let newZoom = Double(columnCountStages[columnCountStagesIndex]) * 1 / scale
                        let newZoomIndex = findClosestZoomIndex(value: newZoom)
                        columnCountStagesIndex = newZoomIndex
                    }
                }
                .onEnded({ _ in
                    columnCountChanged = false
                })
        )
        .environmentObject(vm)
        .environmentObject(parent)
    }

    private func findClosestZoomIndex(value: Double) -> Int {
        let distanceArray = columnCountStages.map { abs(Double($0) - value) } // absolute difference between zoom stages and actual pinch zoom
        return distanceArray.indices.min(by: {distanceArray[$0] < distanceArray[$1]}) ?? 0 // return index of element that is "closest"
    }

    private func playVideoFromUrl() {
        guard let metadata = vm.getMetadataFromUrl(playFromUrlString) else { return }
        NCViewer().view(viewController: parent, metadata: metadata, metadatas: [metadata], imageIcon: nil)
    }

    private func cancelSelection() {
        isInSelectMode = false
        selectedMetadatas.removeAll()
    }

    private func onCellContentMenuItemSelected(thumbnail: ScaledThumbnail, selection: ContextMenuSelection) {
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
}

struct ToolbarMenu: View {
    @EnvironmentObject var vm: NCMediaViewModel
    @EnvironmentObject var parent: NCMediaUIKitWrapper
    @Binding var isInSelectMode: Bool
    @Binding var selectedMetadatas: [tableMetadata]
    @Binding var showPlayFromURLAlert: Bool
    @Binding var toolbarItemsColor: Color

    var body: some View {
        Menu {
            if isInSelectMode, !selectedMetadatas.isEmpty {
                Section {
                    Button {
                        vm.copyOrMoveMetadataInApp(metadatas: selectedMetadatas)
                        cancelSelection()
                    } label: {
                        Label(NSLocalizedString("_move_selected_files_", comment: ""), systemImage: "arrow.up.right.square")
                    }

                    Button {
                        vm.copyMetadata(metadatas: selectedMetadatas)
                        cancelSelection()
                    } label: {
                        Label(NSLocalizedString("_copy_file_", comment: ""), systemImage: "doc.on.doc")
                    }
                }
            } else {
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
                        if let tabBarController = vm.appDelegate.window?.rootViewController as? UITabBarController {
                            NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: parent)
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
            }
        } label: {
            ToolbarCircularButton(imageSystemName: "ellipsis", color: $toolbarItemsColor)
        }
    }

    private func cancelSelection() {
        isInSelectMode = false
        selectedMetadatas.removeAll()
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
}

struct ToolbarTitle: View {
    @Binding var title: String
    @Binding var titleColor: Color

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(titleColor)
    }
}

struct ToolbarSelectButton: View {
    @Binding var isInSelectMode: Bool
    @Binding var toolbarItemsColor: Color

    var body: some View {
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

final class ScrollDelegate: NSObject, UITableViewDelegate, UIScrollViewDelegate {
    var isScrolledToTop: Binding<Bool>?
    var isScrolledToBottom: Binding<Bool>?
    var isScrollingStopped: Binding<Bool>?

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.isScrollingStopped?.wrappedValue = false
            self.isScrolledToTop?.wrappedValue = scrollView.contentOffset.y <= -20
            self.isScrolledToBottom?.wrappedValue = scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.isScrollingStopped?.wrappedValue = true
        }
    }
}

extension View {
    func scrollStatusByIntrospect(isScrolledToTop: Binding<Bool>, isScrolledToBottom: Binding<Bool>, isScrollingStopped: Binding<Bool>) -> some View {
        modifier(ScrollStatusByIntrospectModifier(isScrolledToTop: isScrolledToTop, isScrolledToBottom: isScrolledToBottom, isScrollingStopped: isScrollingStopped))
    }
}

struct ScrollStatusByIntrospectModifier: ViewModifier {
    @State var delegate = ScrollDelegate()
    @Binding var isScrolledToTop: Bool
    @Binding var isScrolledToBottom: Bool
    @Binding var isScrollingStopped: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                self.delegate.isScrolledToTop = $isScrolledToTop
                self.delegate.isScrolledToBottom = $isScrolledToBottom
                self.delegate.isScrollingStopped = $isScrollingStopped
            }
            .introspect(.scrollView, on: .iOS(.v15...)) { scrollView in
                scrollView.delegate = delegate
            }
    }
}

struct EmptyMediaView: View {
    var body: some View {
        VStack {
            Image(systemName: "photo.on.rectangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 130)
                .foregroundStyle(.gray)
                .ignoresSafeArea()

            Text(NSLocalizedString("_no_photos_or_videos_yet", comment: ""))
                .font(.system(size: 20, weight: .bold))
                .padding(.bottom, 2)

            Text(NSLocalizedString("_new_photos_and_videos_will_appear_here", comment: ""))
                .font(.system(size: 14))
                .foregroundStyle(.gray)
        }
        .padding(.top, 250)
    }
}
