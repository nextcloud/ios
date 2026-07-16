// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import Combine
import NextcloudKit

// MARK: - Media Viewer Paging View

struct NCMediaViewerPagingView: UIViewRepresentable {
    @ObservedObject var model: NCMediaViewerModel

    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?
    let onVisibleMetadataChanged: (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void
    let onZoomChanged: (Bool) -> Void
    let onClose: (_ ocId: String?) -> Void

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> NCMediaViewerCollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let collectionView = NCMediaViewerCollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        collectionView.backgroundColor = .black
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = model.numberOfPages > 1
        collectionView.alwaysBounceVertical = false
        collectionView.isScrollEnabled = model.numberOfPages > 1
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator

        collectionView.register(
            NCMediaViewerPagingCell.self,
            forCellWithReuseIdentifier: NCMediaViewerPagingCell.reuseIdentifier
        )

        context.coordinator.collectionView = collectionView

        collectionView.onLayoutSubviews = { [weak coordinator = context.coordinator] in
            coordinator?.updateLayoutAfterBoundsChangeIfNeeded()
        }

        DispatchQueue.main.async {
            context.coordinator.scrollToInitialIndexIfNeeded(animated: false)
            context.coordinator.updateCollectionBackground()
            context.coordinator.updateVisibleMetadataTitle(for: context.coordinator.model.selectedIndex)
        }

        return collectionView
    }

    func updateUIView(
        _ collectionView: NCMediaViewerCollectionView,
        context: Context
    ) {
        context.coordinator.model = model
        context.coordinator.navigationBar = navigationBar
        context.coordinator.onVisibleMetadataChanged = onVisibleMetadataChanged
        context.coordinator.onZoomChanged = onZoomChanged
        context.coordinator.onClose = onClose
        context.coordinator.updateCollectionBackground()

        collectionView.isScrollEnabled = model.numberOfPages > 1
        collectionView.alwaysBounceHorizontal = model.numberOfPages > 1

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let itemSize = collectionView.bounds.size

            if itemSize.width > 0,
               itemSize.height > 0,
               layout.itemSize != itemSize {
                context.coordinator.relayoutAndKeepCurrentIndex(size: itemSize)
            }
        }

        context.coordinator.jumpToSelectedIndexIfNeeded(animated: false)
    }

    func makeCoordinator() -> NCMediaViewerPagingCoordinator {
        NCMediaViewerPagingCoordinator(
            model: model,
            contextMenuController: contextMenuController,
            navigationBar: navigationBar,
            onVisibleMetadataChanged: onVisibleMetadataChanged,
            onZoomChanged: onZoomChanged,
            onClose: onClose
        )
    }
}

// MARK: - Media Viewer Collection View

final class NCMediaViewerCollectionView: UICollectionView {
    var onLayoutSubviews: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutSubviews?()
    }
}

// MARK: - Media Viewer Paging Coordinator

@MainActor
final class NCMediaViewerPagingCoordinator: NSObject,
                                            UICollectionViewDataSource,
                                            UICollectionViewDelegateFlowLayout {
    var model: NCMediaViewerModel
    weak var collectionView: UICollectionView?
    let contextMenuController: NCMainTabBarController?
    weak var navigationBar: UINavigationBar?
    var onVisibleMetadataChanged: (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void
    var onZoomChanged: (Bool) -> Void
    var onClose: (_ ocId: String?) -> Void

    private var didScrollToInitialIndex = false
    private var lastCollectionViewBoundsSize: CGSize = .zero
    private var cancellable: AnyCancellable?
    private var lastVisibleIndex: Int?
    private var isUserPaging = false
    private var isAdjustingLayout = false

    // MARK: - Init

    init(
        model: NCMediaViewerModel,
        contextMenuController: NCMainTabBarController?,
        navigationBar: UINavigationBar?,
        onVisibleMetadataChanged: @escaping (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void,
        onZoomChanged: @escaping (Bool) -> Void,
        onClose: @escaping (_ ocId: String?) -> Void
    ) {
        self.model = model
        self.contextMenuController = contextMenuController
        self.navigationBar = navigationBar
        self.onVisibleMetadataChanged = onVisibleMetadataChanged
        self.onZoomChanged = onZoomChanged
        self.onClose = onClose

        super.init()

        self.cancellable = model.$revision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                self.refreshVisibleCells()
                self.updateCollectionBackground()
                self.updateVisibleMetadataTitle(for: self.model.selectedIndex)
            }
    }

    // MARK: - Layout

    func updateLayoutAfterBoundsChangeIfNeeded() {
        guard let collectionView else {
            return
        }

        let boundsSize = collectionView.bounds.size

        guard boundsSize.width > 0,
              boundsSize.height > 0 else {
            return
        }

        guard boundsSize != lastCollectionViewBoundsSize else {
            return
        }

        relayoutAndKeepCurrentIndex(size: boundsSize)
    }

    func relayoutAndKeepCurrentIndex(size: CGSize) {
        guard let collectionView else {
            return
        }

        guard size.width > 0,
              size.height > 0 else {
            return
        }

        // Ignore intermediate offsets while the layout is being resized.
        lastCollectionViewBoundsSize = size
        isAdjustingLayout = true

        let index = model.selectedIndex

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = size
            layout.invalidateLayout()
        }

        collectionView.performBatchUpdates(nil) { [weak self] _ in
            guard let self else {
                return
            }

            self.scrollToIndex(
                index,
                animated: false
            )

            DispatchQueue.main.async { [weak self] in
                self?.isAdjustingLayout = false
            }
        }
    }

    // MARK: - Background

    private func backgroundColor(for page: NCMediaViewerPageModel?) -> UIColor {
        UIColor.ncViewerBackground(
            ncViewerBackgroundStyle(
                for: page?.metadata,
                isChromeHidden: model.isChromeHidden
            )
        )
    }

    func updateCollectionBackground(for index: Int? = nil) {
        let pageIndex = index ?? model.selectedIndex
        let page = model.pageModel(at: pageIndex)
        let color = backgroundColor(for: page)

        collectionView?.backgroundColor = color
    }

    func updateVisibleMetadataTitle(for index: Int) {
        guard index >= 0,
              index < model.numberOfPages else {
            return
        }

        let page = model.pageModel(at: index)

        onVisibleMetadataChanged(
            page?.metadata,
            backgroundColor(for: page)
        )
    }

    // MARK: - Initial Scroll

    func scrollToInitialIndexIfNeeded(animated: Bool) {
        guard !didScrollToInitialIndex else {
            return
        }

        guard model.numberOfPages > 0 else {
            return
        }

        guard let collectionView else {
            return
        }

        collectionView.layoutIfNeeded()

        let index = model.currentSelectedIndex

        guard index >= 0,
              index < model.numberOfPages else {
            return
        }

        jumpToIndex(
            index,
            animated: animated
        )

        didScrollToInitialIndex = true
        lastVisibleIndex = index
        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()
    }

    func scrollToCurrentIndex(animated: Bool) {
        scrollToIndex(
            model.selectedIndex,
            animated: animated
        )
    }

    func jumpToSelectedIndexIfNeeded(animated: Bool) {
        guard model.numberOfPages > 0 else {
            return
        }

        let index = model.selectedIndex

        guard index >= 0,
              index < model.numberOfPages else {
            return
        }

        guard lastVisibleIndex != index else {
            return
        }

        scrollToIndex(
            index,
            animated: animated
        )
    }

    private func scrollToIndex(
        _ index: Int,
        animated: Bool
    ) {
        guard model.numberOfPages > 0 else {
            return
        }

        guard index >= 0,
              index < model.numberOfPages else {
            return
        }

        let didChangePage = lastVisibleIndex != index
        lastVisibleIndex = index

        if didChangePage {
            onZoomChanged(false)
        }

        jumpToIndex(
            index,
            animated: animated
        )

        if !animated {
            isUserPaging = false
            model.setSelectedIndex(index)
            refreshVisibleCells()

            Task {
                await model.displayPage(at: index)
            }
        }

        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()
    }

    private func jumpToIndex(
        _ index: Int,
        animated: Bool
    ) {
        guard let collectionView else {
            return
        }

        collectionView.layoutIfNeeded()

        guard collectionView.bounds.width > 0 else {
            return
        }

        if animated {
            collectionView.scrollToItem(
                at: IndexPath(item: index, section: 0),
                at: .centeredHorizontally,
                animated: true
            )
        } else {
            let targetOffset = CGPoint(
                x: CGFloat(index) * collectionView.bounds.width,
                y: 0
            )

            collectionView.setContentOffset(
                targetOffset,
                animated: false
            )
        }
    }

    // MARK: - Visible Cell Refresh

    func refreshVisibleCells() {
        guard let collectionView else {
            return
        }

        for cell in collectionView.visibleCells {
            guard let cell = cell as? NCMediaViewerPagingCell,
                  let indexPath = collectionView.indexPath(for: cell),
                  let page = model.pageModel(at: indexPath.item) else {
                continue
            }

            configure(
                cell: cell,
                page: page
            )
        }
    }

    // MARK: - Page Navigation

    private func moveToPage(
        offset: Int,
        shouldAutoPlay: Bool
    ) {
        let targetIndex = model.selectedIndex + offset

        guard targetIndex >= 0,
              targetIndex < model.numberOfPages else {
            return
        }

        // Stop the current media playback before programmatic page navigation.
        // This is intentionally broad because previous/next can move across image,
        // audio, AVPlayer, and VLC pages.
        NotificationCenter.default.post(
            name: .ncMediaViewerStopPlayback,
            object: nil
        )

        if shouldAutoPlay {
            model.requestAutoPlay(at: targetIndex)
        }

        // Selection is finalized when the scroll animation ends.
        isUserPaging = true

        updateCollectionBackground(for: targetIndex)
        updateVisibleMetadataTitle(for: targetIndex)
        refreshVisibleCells()

        scrollToIndex(
            targetIndex,
            animated: true
        )
    }

    private func configure(cell: NCMediaViewerPagingCell, page: NCMediaViewerPageModel) {
        let pageBackgroundColor = backgroundColor(for: page)

        cell.configure(
            model: model,
            page: page,
            isSelected: !isUserPaging && page.index == model.selectedIndex,
            isChromeHidden: model.isChromeHidden,
            backgroundColor: pageBackgroundColor,
            canGoPrevious: page.index > 0,
            canGoNext: page.index < model.numberOfPages - 1,
            shouldAutoPlay: model.autoPlayTargetIndex == page.index,
            onToggleChrome: { [weak model] in
                model?.toggleChromeVisibility()
            },
            onPreviousPage: { [weak self] shouldAutoPlay in
                self?.moveToPage(
                    offset: -1,
                    shouldAutoPlay: shouldAutoPlay
                )
            },
            onNextPage: { [weak self] shouldAutoPlay in
                self?.moveToPage(
                    offset: 1,
                    shouldAutoPlay: shouldAutoPlay
                )
            },
            onAutoPlayConsumed: { [weak model] in
                model?.clearAutoPlayIfNeeded(for: page.index)
            },
            onZoomChanged: { [weak self] isZoomed in
                guard let self,
                      !self.isUserPaging,
                      page.index == self.model.selectedIndex else {
                    return
                }

                self.onZoomChanged(isZoomed)
            },
            onClose: { [weak self] ocId in
                self?.onClose(ocId)
            },
            contextMenuController: contextMenuController,
            navigationBar: navigationBar
        )
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        model.numberOfPages
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: NCMediaViewerPagingCell.reuseIdentifier,
            for: indexPath
        )

        guard let pagingCell = cell as? NCMediaViewerPagingCell else {
            return cell
        }

        if let page = model.pageModel(at: indexPath.item) {
            configure(
                cell: pagingCell,
                page: page
            )
        } else {
            pagingCell.configureEmpty(
                backgroundColor: backgroundColor(for: nil)
            )
        }

        return pagingCell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserPaging = true

        // Stop the current media playback before manual page navigation.
        // This is intentionally broad because dragging can move across image,
        // audio, AVPlayer, and VLC pages.
        NotificationCenter.default.post(
            name: .ncMediaViewerStopPlayback,
            object: nil
        )

        refreshVisibleCells()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard isScrollGeometryStable(scrollView) else {
            return
        }

        guard let index = pageIndex(
            forContentOffsetX: targetContentOffset.pointee.x,
            width: scrollView.bounds.width
        ) else {
            return
        }

        guard lastVisibleIndex != index else {
            return
        }

        lastVisibleIndex = index
        onZoomChanged(false)
        model.setSelectedIndex(index)
        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()
    }

    private func isScrollGeometryStable(_ scrollView: UIScrollView) -> Bool {
        guard !isAdjustingLayout else {
            return false
        }

        let boundsSize = scrollView.bounds.size

        guard boundsSize.width > 0,
              boundsSize.height > 0 else {
            return false
        }

        return boundsSize == lastCollectionViewBoundsSize
    }

    private func pageIndex(for scrollView: UIScrollView) -> Int? {
        pageIndex(
            forContentOffsetX: scrollView.contentOffset.x,
            width: scrollView.bounds.width
        )
    }

    private func pageIndex(
        forContentOffsetX contentOffsetX: CGFloat,
        width: CGFloat
    ) -> Int? {
        guard width > 0 else {
            return nil
        }

        let rawIndex = contentOffsetX / width
        let index = Int(round(rawIndex))

        guard index >= 0,
              index < model.numberOfPages else {
            return nil
        }

        return index
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isScrollGeometryStable(scrollView) else {
            return
        }

        guard let index = pageIndex(for: scrollView) else {
            return
        }

        guard lastVisibleIndex != index else {
            return
        }

        lastVisibleIndex = index
        onZoomChanged(false)
        model.setSelectedIndex(index)
        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()

        Task {
            await model.prefetchVisiblePageIfNeeded(index: index)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateSelectedIndexFromScrollView(scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateSelectedIndexFromScrollView(scrollView)
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        if !decelerate {
            updateSelectedIndexFromScrollView(scrollView)
        }
    }

    private func updateSelectedIndexFromScrollView(_ scrollView: UIScrollView) {
        guard isScrollGeometryStable(scrollView) else {
            return
        }

        guard let index = pageIndex(for: scrollView) else {
            return
        }

        // The settled page is now the selected page.
        isUserPaging = false
        lastVisibleIndex = index

        model.setSelectedIndex(index)
        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()

        Task {
            await model.displayPage(at: index)
        }
    }
}

// MARK: - Media Viewer Paging Cell

final class NCMediaViewerPagingCell: UICollectionViewCell {
    static let reuseIdentifier = "NCMediaViewerPagingCell"

    private var currentOcId: String?
    private var hostingController: UIHostingController<AnyView>?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        contentView.backgroundColor = .black
        contentView.clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        backgroundColor = .black
        contentView.backgroundColor = .black
        contentView.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        currentOcId = nil

        hostingController?.view.removeFromSuperview()
        hostingController = nil

        backgroundColor = .black
        contentView.backgroundColor = .black
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        hostingController?.view.frame = contentView.bounds
    }

    // MARK: - Configuration

    func configure(
        model: NCMediaViewerModel,
        page: NCMediaViewerPageModel,
        isSelected: Bool,
        isChromeHidden: Bool,
        backgroundColor: UIColor,
        canGoPrevious: Bool,
        canGoNext: Bool,
        shouldAutoPlay: Bool,
        onToggleChrome: @escaping () -> Void,
        onPreviousPage: @escaping (_ shouldAutoPlay: Bool) -> Void,
        onNextPage: @escaping (_ shouldAutoPlay: Bool) -> Void,
        onAutoPlayConsumed: @escaping () -> Void,
        onZoomChanged: @escaping (Bool) -> Void,
        onClose: @escaping (_ ocId: String?) -> Void,
        contextMenuController: NCMainTabBarController?,
        navigationBar: UINavigationBar?
    ) {
        self.backgroundColor = backgroundColor
        contentView.backgroundColor = backgroundColor

        let view = AnyView(
            NCMediaViewerPageView(
                model: model,
                page: page,
                onToggleChrome: onToggleChrome,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                shouldAutoPlay: shouldAutoPlay,
                onPreviousPage: onPreviousPage,
                onNextPage: onNextPage,
                onClose: onClose,
                onAutoPlayConsumed: onAutoPlayConsumed,
                onZoomChanged: onZoomChanged,
                contextMenuController: contextMenuController,
                navigationBar: navigationBar
            )
            .id(page.ocId)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        )

        if currentOcId != page.ocId {
            hostingController?.view.removeFromSuperview()
            hostingController = nil
            currentOcId = page.ocId
        }

        if let hostingController,
           currentOcId == page.ocId {
            hostingController.view.backgroundColor = backgroundColor
            hostingController.view.frame = contentView.bounds
        } else {
            let hostingController = UIHostingController(rootView: view)
            hostingController.view.backgroundColor = backgroundColor
            hostingController.view.frame = contentView.bounds
            hostingController.view.autoresizingMask = [
                .flexibleWidth,
                .flexibleHeight
            ]

            contentView.addSubview(hostingController.view)
            self.hostingController = hostingController
        }
    }

    func configureEmpty(backgroundColor: UIColor = .black) {
        self.backgroundColor = backgroundColor
        contentView.backgroundColor = backgroundColor

        currentOcId = nil

        hostingController?.view.removeFromSuperview()
        hostingController = nil

        let view = AnyView(
            Color(backgroundColor)
                .ignoresSafeArea()
        )

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = backgroundColor
        hostingController.view.frame = contentView.bounds
        hostingController.view.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        contentView.addSubview(hostingController.view)
        self.hostingController = hostingController
    }
}
