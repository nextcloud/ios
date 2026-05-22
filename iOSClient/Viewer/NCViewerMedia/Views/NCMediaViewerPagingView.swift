// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import Combine
import NextcloudKit

// MARK: - Media Viewer Paging View

/// UIKit-backed horizontal paging view for the media viewer.
///
/// This replaces SwiftUI `TabView(.page)` because `TabView` is not suitable for
/// very large virtualized media lists and can flicker when its page array changes.
///
/// The paging view uses a `UICollectionView` with reusable cells.
/// Each cell hosts a SwiftUI `NCMediaViewerPageView`.
struct NCMediaViewerPagingView: UIViewRepresentable {
    @ObservedObject var model: NCMediaViewerModel
    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?
    let onVisibleMetadataChanged: (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void
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
            context.coordinator.updateVisibleMetadataTitleForCurrentPage()
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

        context.coordinator.refreshVisibleCells()
    }

    func makeCoordinator() -> NCMediaViewerPagingCoordinator {
        NCMediaViewerPagingCoordinator(
            model: model,
            contextMenuController: contextMenuController,
            navigationBar: navigationBar,
            onVisibleMetadataChanged: onVisibleMetadataChanged,
            onClose: onClose
        )
    }
}

// MARK: - Media Viewer Collection View

/// Collection view subclass used to detect bounds changes reliably.
///
/// This is needed because rotation, iPad split view resizing, and floating window
/// resizing can change the collection view bounds without SwiftUI immediately
/// rebuilding the representable.
final class NCMediaViewerCollectionView: UICollectionView {
    var onLayoutSubviews: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutSubviews?()
    }
}

// MARK: - Media Viewer Paging Coordinator

/// Coordinator for the UIKit paging collection view.
///
/// It acts as:
/// - collection view data source
/// - collection view delegate flow layout
@MainActor
final class NCMediaViewerPagingCoordinator: NSObject,
                                            UICollectionViewDataSource,
                                            UICollectionViewDelegateFlowLayout {
    var model: NCMediaViewerModel
    weak var collectionView: UICollectionView?
    let contextMenuController: NCMainTabBarController?
    weak var navigationBar: UINavigationBar?
    var onVisibleMetadataChanged: (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void
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
        onClose: @escaping (_ ocId: String?) -> Void
    ) {
        self.model = model
        self.contextMenuController = contextMenuController
        self.navigationBar = navigationBar
        self.onVisibleMetadataChanged = onVisibleMetadataChanged
        self.onClose = onClose

        super.init()

        self.cancellable = model.$revision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshVisibleCells()
                self?.updateCollectionBackground()
                self?.updateVisibleMetadataTitleForCurrentPage()
            }
    }

    // MARK: - Layout

    /// Updates the paging layout after bounds changes.
    ///
    /// This keeps the selected page centered after rotation, split view resizing,
    /// or iPad floating window resizing.
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

    /// Invalidates the paging layout while preserving the current selected page.
    ///
    /// During bounds changes, the collection view content offset can temporarily be
    /// expressed using the old page width. This method prevents those intermediate
    /// offsets from being interpreted as real page changes.
    ///
    /// - Parameter size: New page size to apply to the flow layout.
    func relayoutAndKeepCurrentIndex(size: CGSize) {
        guard let collectionView else {
            return
        }

        guard size.width > 0,
              size.height > 0 else {
            return
        }

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

    /// Returns the UIKit background color for the given page.
    ///
    /// Audio and video use black because their player surfaces are dark.
    /// Images use the viewer background style unless chrome is hidden.
    private func backgroundColor(for page: NCMediaViewerPageModel?) -> UIColor {
        guard !model.isChromeHidden else {
            return .black
        }

        guard let metadata = page?.metadata else {
            return UIColor.ncViewerBackground(.system)
        }

        switch metadata.classFile {
        case NKTypeClassFile.audio.rawValue,
             NKTypeClassFile.video.rawValue:
            return .black

        default:
            return UIColor.ncViewerBackground(
                ncViewerBackgroundStyle(for: metadata)
            )
        }
    }

    /// Applies the current page background to the collection view.
    func updateCollectionBackground(for index: Int? = nil) {
        let pageIndex = index ?? model.selectedIndex
        let page = model.pageModel(at: pageIndex)
        let color = backgroundColor(for: page)

        collectionView?.backgroundColor = color
    }

    /// Sends the metadata of the currently selected page to the hosting controller title view.
    func updateVisibleMetadataTitleForCurrentPage() {
        updateVisibleMetadataTitle(for: model.selectedIndex)
    }

    /// Sends the metadata of the currently visible page to the hosting controller title view.
    ///
    /// - Parameter index: Page index currently closest to the collection view center.
    private func updateVisibleMetadataTitle(for index: Int) {
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

    /// Scrolls to the initial selected page once.
    ///
    /// - Parameter animated: Whether the scroll should be animated.
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

        let index = model.initialSelectedIndex

        guard index >= 0,
              index < model.numberOfPages else {
            return
        }

        collectionView.scrollToItem(
            at: IndexPath(item: index, section: 0),
            at: .centeredHorizontally,
            animated: animated
        )

        didScrollToInitialIndex = true
        lastVisibleIndex = index
        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()
    }

    /// Scrolls to the current selected index.
    ///
    /// This is used after layout size changes, for example after rotation or
    /// iPad window resizing.
    ///
    /// - Parameter animated: Whether the scroll should be animated.
    func scrollToCurrentIndex(animated: Bool) {
        scrollToIndex(
            model.selectedIndex,
            animated: animated
        )
    }

    /// Scrolls to a specific page index without changing the selected model index.
    ///
    /// - Parameters:
    ///   - index: Page index to center.
    ///   - animated: Whether the scroll should be animated.
    private func scrollToIndex(
        _ index: Int,
        animated: Bool
    ) {
        guard model.numberOfPages > 0 else {
            return
        }

        guard let collectionView else {
            return
        }

        collectionView.layoutIfNeeded()

        guard index >= 0,
              index < model.numberOfPages else {
            return
        }

        collectionView.scrollToItem(
            at: IndexPath(item: index, section: 0),
            at: .centeredHorizontally,
            animated: animated
        )

        lastVisibleIndex = index
        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()
    }

    // MARK: - Visible Cell Refresh

    /// Refreshes currently visible cells using the latest page models and selected index.
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

    /// Moves to the previous or next page using the paging collection view.
    ///
    /// The target page becomes selected only after the scrolling animation finishes.
    /// This keeps programmatic navigation consistent with manual swipe navigation.
    ///
    /// - Parameters:
    ///   - offset: Relative page offset. Use `-1` for previous and `1` for next.
    ///   - shouldAutoPlay: Whether the target page should autoplay after selection.
    private func moveToPage(
        offset: Int,
        shouldAutoPlay: Bool
    ) {
        let targetIndex = model.selectedIndex + offset

        guard targetIndex >= 0,
              targetIndex < model.numberOfPages else {
            return
        }

        guard let collectionView else {
            return
        }

        NotificationCenter.default.post(
            name: .ncMediaViewerStopPlayback,
            object: nil
        )

        if shouldAutoPlay {
            model.requestAutoPlay(at: targetIndex)
        }

        isUserPaging = true
        lastVisibleIndex = targetIndex

        updateCollectionBackground(for: targetIndex)
        updateVisibleMetadataTitle(for: targetIndex)
        refreshVisibleCells()

        collectionView.scrollToItem(
            at: IndexPath(item: targetIndex, section: 0),
            at: .centeredHorizontally,
            animated: true
        )
    }

    /// Configures a paging cell with all callbacks required by the hosted SwiftUI page.
    ///
    /// - Parameters:
    ///   - cell: Cell to configure.
    ///   - page: Page model to render.
    private func configure(
        cell: NCMediaViewerPagingCell,
        page: NCMediaViewerPageModel
    ) {
        let pageBackgroundColor = backgroundColor(for: page)

        cell.configure(
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
            onClose: { [weak self] ocId in
                self?.onClose(ocId)
            },
            onAutoPlayConsumed: { [weak model] in
                model?.clearAutoPlayIfNeeded(for: page.index)
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
        guard !isAdjustingLayout else {
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
        model.setSelectedIndex(index)
        updateCollectionBackground(for: index)
        updateVisibleMetadataTitle(for: index)
        refreshVisibleCells()
    }

    /// Returns the nearest page index for the current horizontal scroll position.
    ///
    /// - Parameter scrollView: Source scroll view.
    /// - Returns: Rounded page index if it is inside the media range.
    private func pageIndex(for scrollView: UIScrollView) -> Int? {
        pageIndex(
            forContentOffsetX: scrollView.contentOffset.x,
            width: scrollView.bounds.width
        )
    }

    /// Returns the nearest page index for the provided horizontal content offset.
    ///
    /// This is used to predict the final page before deceleration finishes.
    ///
    /// - Parameters:
    ///   - contentOffsetX: Horizontal content offset to evaluate.
    ///   - width: Current page width.
    /// - Returns: Rounded page index if it is inside the media range.
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
        guard !isAdjustingLayout else {
            return
        }

        guard let index = pageIndex(for: scrollView) else {
            return
        }

        guard lastVisibleIndex != index else {
            return
        }

        lastVisibleIndex = index
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

    /// Updates the selected page index after paging has settled.
    ///
    /// This is the only place where a finished swipe becomes the real selected page.
    /// During dragging, visible pages are tracked for background updates, but they are not considered selected.
    ///
    /// - Parameter scrollView: Source scroll view.
    private func updateSelectedIndexFromScrollView(_ scrollView: UIScrollView) {
        guard !isAdjustingLayout else {
            return
        }

        guard let index = pageIndex(for: scrollView) else {
            return
        }

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

/// Collection view cell hosting one SwiftUI media viewer page.
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

    /// Configures the cell with a media viewer page.
    ///
    /// - Parameters:
    ///   - page: Page model to render.
    ///   - isSelected: Whether this cell represents the currently selected page.
    ///   - isChromeHidden: Whether viewer chrome is currently hidden.
    ///   - backgroundColor: Background color matching the currently rendered page.
    ///   - canGoPrevious: Whether the page can navigate to a previous item.
    ///   - canGoNext: Whether the page can navigate to a next item.
    ///   - shouldAutoPlay: Whether hosted audio content should start playback automatically.
    ///   - onToggleChrome: Callback used by image pages to show or hide chrome.
    ///   - onPreviousPage: Callback used by inline controls to move to previous page.
    ///   - onNextPage: Callback used by inline controls to move to next page.
    ///   - onClose: Callback used by fullscreen video controllers to close the media viewer with the current media ocId.
    ///   - onAutoPlayConsumed: Callback invoked after the hosted page consumes the auto-play request.
    func configure(
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
        onClose: @escaping (_ ocId: String?) -> Void,
        onAutoPlayConsumed: @escaping () -> Void,
        contextMenuController: NCMainTabBarController?,
        navigationBar: UINavigationBar?
    ) {
        self.backgroundColor = backgroundColor
        contentView.backgroundColor = backgroundColor

        let view = AnyView(
            NCMediaViewerPageView(
                page: page,
                isChromeHidden: isChromeHidden,
                onToggleChrome: onToggleChrome,
                isSelected: isSelected,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                shouldAutoPlay: shouldAutoPlay,
                onPreviousPage: onPreviousPage,
                onNextPage: onNextPage,
                onClose: onClose,
                onAutoPlayConsumed: onAutoPlayConsumed,
                contextMenuController: contextMenuController,
                navigationBar: navigationBar
            )
            .id(page.ocId)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(backgroundColor))
            .ignoresSafeArea()
        )

        if currentOcId != page.ocId {
            hostingController?.view.removeFromSuperview()
            hostingController = nil
            currentOcId = page.ocId
        }

        if let hostingController {
            hostingController.rootView = view
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

    /// Configures the cell as an empty page.
    ///
    /// - Parameter backgroundColor: Background color to apply to the empty page.
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
