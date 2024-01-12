//
//  NCMedia.swift
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

struct NCMedia: View {
    @StateObject private var vm = NCMediaViewModel()
    @StateObject private var selectionManager = SelectionManager()
    @EnvironmentObject private var parent: NCMediaUIKitWrapper

    @State private var metadatas: [tableMetadata] = []
    @State private var title = NSLocalizedString("_media_", comment: "")
    @State private var isScrolledToTop = true
    @State private var isScrolledToBottom = false
    @State private var isScrollingStopped = true
    @State private var tappedMetadata = tableMetadata()

    @State private var showDeleteConfirmation = false
    @State private var showPlayFromURLAlert = false
    @State private var playFromUrlString = ""

    @State private var columnCountStages = [2, 3, 4]
    @State private var columnCountStagesIndex = 0
    @State private var columnCountChanged = false

    @State private var shouldScrollToTop = false
    @State private var hasOldMedia = true

    @State private var showEmptyView = false
    @State private var topMostVisibleMetadataDate = Date.now
    @State private var bottomMostVisibleMetadataDate = Date.now

    var body: some View {
        ZStack(alignment: .top) {
            if showEmptyView {
                EmptyMediaView()
            }

            NCMediaScrollView(metadatas: metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), title: $title, shouldShowPaginationLoading: $hasOldMedia, topMostVisibleMetadataDate: $topMostVisibleMetadataDate, bottomMostVisibleMetadataDate: $bottomMostVisibleMetadataDate) { tappedThumbnail, isSelected in
                if selectionManager.isInSelectMode, isSelected {
                    selectionManager.selectedMetadatas.append(tappedThumbnail.metadata)
                } else {
                    selectionManager.selectedMetadatas.removeAll(where: { $0.ocId == tappedThumbnail.metadata.ocId })
                }

                if !selectionManager.isInSelectMode {
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

            Toolbar(showPlayFromURLAlert: $showPlayFromURLAlert, columnCountStagesIndex: $columnCountStagesIndex, columnCountStages: $columnCountStages, title: $title, showDeleteConfirmation: $showDeleteConfirmation, isScrolledToTop: $isScrolledToTop, isScrollingStopped: $isScrollingStopped)
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

                let fromDate = min(topMostVisibleMetadataDate, bottomMostVisibleMetadataDate)
                let toDate = max(topMostVisibleMetadataDate, bottomMostVisibleMetadataDate)

                vm.searchMedia(from: fromDate, to: toDate, isScrolledToTop: isScrolledToTop, isScrolledToBottom: isScrolledToBottom)
            }
        }
        .onReceive(vm.$hasOldMedia) { newValue in
            hasOldMedia = newValue
        }
        .onReceive(vm.$filter) { _ in
            selectionManager.cancelSelection()
        }
        .onChange(of: selectionManager.isInSelectMode) { newValue in
            if newValue == false { selectionManager.selectedMetadatas.removeAll() }
        }
        .onChange(of: columnCountStagesIndex) { _ in
            columnCountChanged = true
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
        .environmentObject(selectionManager)
    }

    private func findClosestZoomIndex(value: Double) -> Int {
        let distanceArray = columnCountStages.map { abs(Double($0) - value) } // absolute difference between zoom stages and actual pinch zoom
        return distanceArray.indices.min(by: {distanceArray[$0] < distanceArray[$1]}) ?? 0 // return index of element that is "closest"
    }

    private func playVideoFromUrl() {
        guard let metadata = vm.getMetadataFromUrl(playFromUrlString) else { return }
        NCViewer().view(viewController: parent, metadata: metadata, metadatas: [metadata], imageIcon: nil)
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

struct Toolbar: View {
    @State private var loadingIndicatorColor = Color.gray
    @State private var titleColor = Color.primary
    @State private var toolbarItemsColor = Color.blue
    @State private var toolbarColors = [Color.clear]

    @Binding var showPlayFromURLAlert: Bool
    @Binding var columnCountStagesIndex: Int
    @Binding var columnCountStages: [Int]
    @Binding var title: String
    @Binding var showDeleteConfirmation: Bool
    @Binding var isScrolledToTop: Bool
    @Binding var isScrollingStopped: Bool

    @EnvironmentObject var vm: NCMediaViewModel
    @EnvironmentObject var parent: NCMediaUIKitWrapper

    @EnvironmentObject var selectionManager: SelectionManager

    var body: some View {
        HStack {
            ToolbarTitle(title: $title, titleColor: $titleColor)

            Spacer()

            if vm.isLoading {
                ProgressView()
                    .tint(loadingIndicatorColor).scaleEffect(1.2)
                    .padding(.horizontal, 6)
            }

            ToolbarSelectButton(toolbarItemsColor: $toolbarItemsColor)

            if selectionManager.isInSelectMode, !selectionManager.selectedMetadatas.isEmpty {
                ToolbarCircularButton(imageSystemName: "trash.fill", color: .red)
                    .onTapGesture {
                        showDeleteConfirmation = true
                    }
                    .confirmationDialog("", isPresented: $showDeleteConfirmation) {
                        Button(NSLocalizedString("_delete_selected_media_", comment: ""), role: .destructive) {
                            vm.deleteMetadata(metadatas: selectionManager.selectedMetadatas)
                            selectionManager.cancelSelection()
                        }
                    }
            }

            ToolbarMenu(showPlayFromURLAlert: $showPlayFromURLAlert, toolbarItemsColor: $toolbarItemsColor, columnCountStagesIndex: $columnCountStagesIndex, columnCountStages: $columnCountStages)
        }
        .frame(maxWidth: .infinity)
        .padding([.horizontal, .top], 10)
        .padding(.bottom, 20)
        .background(LinearGradient(gradient: Gradient(colors: toolbarColors), startPoint: .top, endPoint: .bottom)
            .padding(.bottom, -50)
            .ignoresSafeArea(.all, edges: [.all])
        )
        .onChange(of: isScrolledToTop) { newValue in
            withAnimation(.default) {
                titleColor = newValue ? Color.primary : .white
                loadingIndicatorColor = newValue ? Color.gray : .white
                toolbarItemsColor = newValue ? .blue : .white
                toolbarColors = newValue ? [.clear] : [Color.black.opacity(0.8), Color.black.opacity(0.4), .clear]
            }
        }
        // This is here instead of in the parent so it does not update the whole view. Pragmatic solution, but there may be a better way.
        // This is also a result of using Introspect since SwiftUI does not have all features we need.
        .onChange(of: isScrollingStopped) { newValue in
            if newValue {
                vm.startLoadingNewMediaTimer()
            }
        }
    }
}

struct ToolbarMenu: View {
    @EnvironmentObject var vm: NCMediaViewModel
    @EnvironmentObject var parent: NCMediaUIKitWrapper
    @EnvironmentObject var selectionManager: SelectionManager

    @Binding var showPlayFromURLAlert: Bool
    @Binding var toolbarItemsColor: Color
    @Binding var columnCountStagesIndex: Int
    @Binding var columnCountStages: [Int]

    var body: some View {
        Menu {
            Section {
                if columnCountStagesIndex > 0 {
                    Button {
                        columnCountStagesIndex = max(columnCountStagesIndex - 1, 0)
                    } label: {
                        Label(NSLocalizedString("_zoom_in_", comment: ""), systemImage: "plus.magnifyingglass")
                    }
                }

                if columnCountStagesIndex < columnCountStages.count - 1 {
                    Button {
                        print(min(columnCountStagesIndex + 1, columnCountStages.count - 1))
                        columnCountStagesIndex = min(columnCountStagesIndex + 1, columnCountStages.count - 1)
                    } label: {
                        Label(NSLocalizedString("_zoom_out_", comment: ""), systemImage: "minus.magnifyingglass")
                    }
                }
            }

            if selectionManager.isInSelectMode, !selectionManager.selectedMetadatas.isEmpty {
                Section {
                    Button {
                        vm.copyOrMoveMetadataInApp(metadatas: selectionManager.selectedMetadatas)
                        selectionManager.cancelSelection()
                    } label: {
                        Label(NSLocalizedString("_move_selected_files_", comment: ""), systemImage: "arrow.up.right.square")
                    }

                    Button {
                        vm.copyMetadata(metadatas: selectionManager.selectedMetadatas)
                        selectionManager.cancelSelection()
                    } label: {
                        Label(NSLocalizedString("_copy_file_", comment: ""), systemImage: "doc.on.doc")
                    }
                }
            } else {
                Section {
                    Picker(NSLocalizedString("_media_view_options_", comment: ""), selection: $vm.filter) {
                        Label(NSLocalizedString("_media_viewimage_show_", comment: ""), systemImage: "photo").tag(Filter.onlyPhotos)

                        Label(NSLocalizedString("_media_viewvideo_show_", comment: ""), systemImage: "video").tag(Filter.onlyVideos)

                        Label(NSLocalizedString("_media_show_all_", comment: ""), systemImage: "photo.on.rectangle").tag(Filter.all)
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
            .minimumScaleFactor(0.7)
            .foregroundStyle(titleColor)
            .lineLimit(1)
    }
}

struct ToolbarSelectButton: View {
    @Binding var toolbarItemsColor: Color

    @EnvironmentObject var selectionManager: SelectionManager

    var body: some View {
        Button(action: {
            selectionManager.isInSelectMode.toggle()
        }, label: {
            Text(NSLocalizedString(selectionManager.isInSelectMode ? "_cancel_" : "_select_", comment: "")).font(.system(size: 14))
                .foregroundStyle(toolbarItemsColor)
        })
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
            .frame(width: 16, height: 14)
            .padding(7)
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
                NCMedia()
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
