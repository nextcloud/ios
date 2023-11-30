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
    @Binding var title: String
    @Binding var shouldShowPaginationLoading: Bool
    @Binding var latestDisappearedMetadata: tableMetadata?
    @Binding var latestVisibleMetadata: tableMetadata?

    let proxy: ScrollViewProxy

    let onCellSelected: (ScaledThumbnail, Bool) -> Void
    let onCellContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void
    let shouldLoadMore: () -> Void

    @Namespace private var topID

    var body: some View {
//        let _ = Self._printChanges()

//        GeometryReader { outerProxy in
            ScrollView {
                Spacer(minLength: 70).id(topID)

                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), id: \.self) { rowMetadatas in
                        NCMediaRow(metadatas: rowMetadatas, isInSelectMode: $isInSelectMode) { tappedThumbnail, isSelected in
                            onCellSelected(tappedThumbnail, isSelected)
                        } onCellContextMenuItemSelected: { thumbnail, selection in
                            onCellContextMenuItemSelected(thumbnail, selection)
                        }
                        // NOTE: This only works properly on device. On simulator, for some reason, these get called way too early or way too late.
                        .onAppear {
                            latestVisibleMetadata = rowMetadatas.first
                            title = NCUtility().getTitleFromDate(rowMetadatas.first?.date as? Date ?? Date.now)
                        }
                        .onDisappear {
                            latestDisappearedMetadata = rowMetadatas.last
                        }
//                        .background(GeometryReader { proxy in
//                            let imageRect = proxy.frame(in: .named("scroll"))
//
//                            if isInView(innerRect: imageRect, isIn: outerProxy) {
////                                let _ = print("Appears : \(rowMetadatas.first?.fileName)")
//                            } else {
//                                let _ = print("Disappears : \(rowMetadatas.last?.fileName)")
//                            }
//                        })
                    }

                    if !metadatas.isEmpty, shouldShowPaginationLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                            .onAppear {
                                shouldLoadMore()
                            }
                    }

                    //                    .hidden(metadatas.count == 0)

                    //                GeometryReader { proxy in
                    //                    let offset = proxy.frame(in: .named("scroll")).minY
                    //                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                    //                }
                }
                .background(GeometryReader { proxy in
                    let offset = proxy.frame(in: .named("scroll")).minY
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                })
                .padding(.bottom, 40)
            }
            .coordinateSpace(name: "scroll")
            //        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            //                        print(value)
            //                    }
            .onChange(of: shouldScrollToTop) { newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo(topID)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        shouldScrollToTop = false
                    }
                }
            }
//        }
    }

    private func isInView(innerRect:CGRect, isIn outerProxy:GeometryProxy) -> Bool {
          let innerOrigin = innerRect.origin.y
          let imageWidth = innerRect.height
          let scrollOrigin = outerProxy.frame(in: .global).origin.y
          let scrollWidth = outerProxy.size.height
          if innerOrigin + imageWidth < scrollOrigin + scrollWidth && innerOrigin + imageWidth > scrollOrigin ||
              innerOrigin + imageWidth > scrollOrigin && innerOrigin < scrollOrigin + scrollWidth {
              return true
          }
          return false
      }
}
