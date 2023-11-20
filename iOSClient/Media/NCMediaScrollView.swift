//
//  NCMediaScrollView.swift
//  Nextcloud
//
//  Created by Milen on 13.10.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Queuer

struct NCMediaScrollView: View, Equatable {
    static func == (lhs: NCMediaScrollView, rhs: NCMediaScrollView) -> Bool {
        return lhs.metadatas == rhs.metadatas
    }

    @Binding var metadatas: [tableMetadata]
    @Binding var isInSelectMode: Bool
    @Binding var selectedMetadatas: [tableMetadata]
    @Binding var columnCountStages: [Int]
    @Binding var columnCountStagesIndex: Int
    @Binding var shouldScrollToTop: Bool
//    @Binding var title: String
    let proxy: ScrollViewProxy

    let queuer: Queuer

    let onCellSelected: (ScaledThumbnail, Bool) -> Void
    let onCellContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void
    let onRefresh: () async -> Void

    @Namespace var topID

    var body: some View {
        let _ = Self._printChanges()

//        ScrollViewReader { proxy in
            ScrollView {
                Spacer(minLength: 70).id(topID)

                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), id: \.self) { rowMetadatas in
                        NCMediaRow(metadatas: rowMetadatas, isInSelectMode: $isInSelectMode, queuer: queuer) { tappedThumbnail, isSelected in
                            onCellSelected(tappedThumbnail, isSelected)
                        } onCellContextMenuItemSelected: { thumbnail, selection in
                            onCellContextMenuItemSelected(thumbnail, selection)
                        }
                        //                    .equatable()
                        .onAppear {
                            //                        title = CCUtility.getTitleSectionDate(rowMetadatas.first?.date as? Date) ?? ""
                        }
                        //                .listRowSeparator(.hidden)
                        //                .listRowSpacing(0)
                        //                .listRowInsets(.init(top: 2, leading: 0, bottom: 0, trailing: 0))
                    }

                    //                if vm.needsLoadingMoreItems {
                    //                    ProgressView()
                    //                        .frame(maxWidth: .infinity)
                    //                        .onAppear { vm.loadMoreItems() }
                    //                        .padding(.top, 10)
                    //                }

                    //                Spacer(minLength: 40).listRowSeparator(.hidden)
                }
                //            .listStyle(.plain)
//                .padding(.top, 70)
                .padding(.bottom, 40)
                //        }
                //            .coordinateSpace(name: "scroll")
                //        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                //            isScrolledToTop = value.y >= 40
                //        }
                // Not possible to move the refresh control view via SwiftUI, so we have to introspect the internal UIKit views to move it.
                // TODO: Maybe .contentMargins() will resolve this but it's iOS 17+
                //        .introspect(.scrollView, on: .iOS(.v15...)) { scrollView in
                //            scrollView.refreshControl?.translatesAutoresizingMaskIntoConstraints = false
                //            scrollView.refreshControl?.topAnchor.constraint(equalTo: scrollView.superview!.topAnchor, constant: 120).isActive = true
                //            scrollView.refreshControl?.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor).isActive = true
                //
                //            if offsetPublisherSubscription == nil {
                //                                    offsetPublisherSubscription = scrollView.publisher(for: \.contentOffset)
                //                                        .sink { offset in
                //                                            isScrolledToTop = offset.y <= 10
                //
                ////                                            withAnimation(.easeInOut) {
                ////                                                titleColor = isScrolledToTop ? Color.primary : .white
                ////                                                toolbarItemsColor = isScrolledToTop ? .blue : .white
                ////                                                toolbarColors = isScrolledToTop ? [.clear] : [.black.opacity(0.8), .black.opacity(0.0)]
                ////                                            }
                //                                        }
                //                                }
                //        }
                //        .preference(key: TitlePreferenceKey.self, value: title)
            }
//            .refreshable {
//                await onRefresh()
//                //            await vm.onPullToRefresh()
//            }
            .onChange(of: shouldScrollToTop) { newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo(topID)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        shouldScrollToTop = false

                    }
                }
//            }
        }
    }
}
//}
