// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

// MARK: - Layout

private enum NCMediaViewerThumbnailLayout {
    /// Real square thumbnail image size for non-selected items.
    static let thumbnailSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 45 : 30

    /// Total vertical lane height for each collection view cell.
    /// The selected thumbnail uses this value as its square image size.
    static let itemContainerHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 60 : 45

    /// Preferred SwiftUI container height for the thumbnail strip.
    static var preferredHeight: CGFloat {
        itemContainerHeight + 10
    }

    /// Horizontal spacing between thumbnail cells.
    static let itemSpacing: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 6 : 3

    /// Square thumbnail image size used by the currently selected item.
    static var selectedThumbnailSize: CGFloat {
        itemContainerHeight
    }

    /// Extra horizontal width assigned to the selected item.
    static let selectedExtraWidth: CGFloat = 30

    /// Corner radius used by the thumbnail image and placeholder.
    static let cornerRadius: CGFloat = 10

    /// Maximum number of decoded preview images kept in memory.
    static let thumbnailCacheLimit: Int = 80

    /// Number of thumbnails prefetched before and after the current centered item.
    static let prefetchRadius: Int = UIDevice.current.userInterfaceIdiom == .pad ? 80 : 20
}

// MARK: - Thumbnail

struct NCMediaViewerThumbnail: UIViewRepresentable, Equatable {
    let selectedIndex: Int
    let numberOfPages: Int
    let reloadRevision: Int
    let metadataProvider: (_ index: Int) -> tableMetadata?
    let metadataResolver: (_ index: Int) async -> tableMetadata?
    let previewURLProvider: (_ metadata: tableMetadata) async -> URL?
    let audioLoadProvider: (_ index: Int) async -> Void
    let isDeletedProvider: (_ index: Int) -> Bool
    let onSelect: (_ index: Int) -> Void

    static var preferredHeight: CGFloat {
        NCMediaViewerThumbnailLayout.preferredHeight
    }

    static func == (
        lhs: NCMediaViewerThumbnail,
        rhs: NCMediaViewerThumbnail
    ) -> Bool {
        lhs.selectedIndex == rhs.selectedIndex &&
        lhs.numberOfPages == rhs.numberOfPages &&
        lhs.reloadRevision == rhs.reloadRevision
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = NCMediaViewerThumbnailLayout.itemSpacing
        layout.minimumInteritemSpacing = NCMediaViewerThumbnailLayout.itemSpacing
        layout.sectionInset = .zero

        let collectionView = NCMediaViewerThumbnailCollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.clipsToBounds = false
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.prefetchDataSource = context.coordinator

        collectionView.register(
            NCMediaViewerThumbnailUICollectionCell.self,
            forCellWithReuseIdentifier: NCMediaViewerThumbnailUICollectionCell.reuseIdentifier
        )

        context.coordinator.collectionView = collectionView
        collectionView.onBoundsSizeChanged = { [weak coordinator = context.coordinator] size in
            coordinator?.collectionViewBoundsDidChange(size)
        }

        return collectionView
    }

    func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        context.coordinator.selectedIndex = selectedIndex
        context.coordinator.numberOfPages = numberOfPages
        context.coordinator.reloadRevision = reloadRevision
        context.coordinator.metadataProvider = metadataProvider
        context.coordinator.metadataResolver = metadataResolver
        context.coordinator.previewURLProvider = previewURLProvider
        context.coordinator.audioLoadProvider = audioLoadProvider
        context.coordinator.isDeletedProvider = isDeletedProvider
        context.coordinator.onSelect = onSelect
        context.coordinator.syncDisplayedSelectedIndexFromInput()

        context.coordinator.reloadCollectionViewIfNeeded()
        context.coordinator.scrollToSelectedIndexIfNeeded(animated: false)
        context.coordinator.performInitialDeferredCenteringIfNeeded()
        context.coordinator.prefetchAroundDisplayedSelectedIndexIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedIndex: selectedIndex,
            numberOfPages: numberOfPages,
            reloadRevision: reloadRevision,
            metadataProvider: metadataProvider,
            metadataResolver: metadataResolver,
            previewURLProvider: previewURLProvider,
            audioLoadProvider: audioLoadProvider,
            isDeletedProvider: isDeletedProvider,
            onSelect: onSelect
        )
    }
}

// MARK: - Coordinator

extension NCMediaViewerThumbnail {
    @MainActor
    final class Coordinator: NSObject,
                             UICollectionViewDataSource,
                             UICollectionViewDelegateFlowLayout,
                             UICollectionViewDataSourcePrefetching {
        var selectedIndex: Int
        var numberOfPages: Int
        var reloadRevision: Int
        var metadataProvider: (_ index: Int) -> tableMetadata?
        var metadataResolver: (_ index: Int) async -> tableMetadata?
        var previewURLProvider: (_ metadata: tableMetadata) async -> URL?
        var audioLoadProvider: (_ index: Int) async -> Void
        var isDeletedProvider: (_ index: Int) -> Bool
        var onSelect: (_ index: Int) -> Void

        weak var collectionView: UICollectionView?

        private var lastNumberOfPages: Int?
        private var lastReloadRevision: Int?
        private var lastCenteredIndex: Int?
        private var lastCenteredBoundsSize: CGSize = .zero
        private var didPerformInitialDeferredCentering = false
        private var pendingPrefetchIndexes = Set<Int>()
        private var loadedAudioIndexes = Set<Int>()
        private var indexesWithoutPreview = Set<Int>()
        private var displayedSelectedIndex: Int?
        private var isUserScrollingThumbnails = false
        private var shouldEmphasizeSelectedThumbnail = true
        private var lastSentSelectedIndex: Int?
        private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        private let imageCache = NSCache<NSString, UIImage>()

        init(
            selectedIndex: Int,
            numberOfPages: Int,
            reloadRevision: Int,
            metadataProvider: @escaping (_ index: Int) -> tableMetadata?,
            metadataResolver: @escaping (_ index: Int) async -> tableMetadata?,
            previewURLProvider: @escaping (_ metadata: tableMetadata) async -> URL?,
            audioLoadProvider: @escaping (_ index: Int) async -> Void,
            isDeletedProvider: @escaping (_ index: Int) -> Bool,
            onSelect: @escaping (_ index: Int) -> Void
        ) {
            self.selectedIndex = selectedIndex
            self.numberOfPages = numberOfPages
            self.reloadRevision = reloadRevision
            self.lastReloadRevision = reloadRevision
            self.metadataProvider = metadataProvider
            self.metadataResolver = metadataResolver
            self.previewURLProvider = previewURLProvider
            self.audioLoadProvider = audioLoadProvider
            self.isDeletedProvider = isDeletedProvider
            self.onSelect = onSelect
            self.displayedSelectedIndex = selectedIndex
            self.lastSentSelectedIndex = selectedIndex
            super.init()

            imageCache.countLimit = NCMediaViewerThumbnailLayout.thumbnailCacheLimit
        }

        // MARK: - UICollectionViewDataSource

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            numberOfPages
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: NCMediaViewerThumbnailUICollectionCell.reuseIdentifier,
                for: indexPath
            ) as? NCMediaViewerThumbnailUICollectionCell else {
                return UICollectionViewCell()
            }

            configure(
                cell,
                at: indexPath.item
            )

            return cell
        }

        // MARK: - UICollectionViewDelegate

        func collectionView(
            _ collectionView: UICollectionView,
            didSelectItemAt indexPath: IndexPath
        ) {
            let selectedIndex = indexPath.item

            shouldEmphasizeSelectedThumbnail = true
            displayedSelectedIndex = selectedIndex
            lastCenteredIndex = nil
            lastSentSelectedIndex = selectedIndex

            collectionView.collectionViewLayout.invalidateLayout()
            scrollToSelectedIndexIfNeeded(animated: false)
            prefetchThumbnailsAround(selectedIndex)
            onSelect(selectedIndex)
        }

        // MARK: - UIScrollViewDelegate

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserScrollingThumbnails = true
            shouldEmphasizeSelectedThumbnail = false
            selectionFeedbackGenerator.prepare()

            collectionView?.collectionViewLayout.invalidateLayout()
            refreshVisibleCells()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard isUserScrollingThumbnails else {
                return
            }

            selectCenteredThumbnailDuringScrollIfNeeded()
        }

        func scrollViewDidEndDragging(
            _ scrollView: UIScrollView,
            willDecelerate decelerate: Bool
        ) {
            guard !decelerate else {
                return
            }

            finishUserThumbnailScroll()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            finishUserThumbnailScroll()
        }

        // MARK: - UICollectionViewDelegateFlowLayout

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let baseWidth = NCMediaViewerThumbnailLayout.thumbnailSize
            let extraWidth = shouldEmphasizeSelectedThumbnail && isDisplayedCurrentThumbnail(at: indexPath.item)
                ? NCMediaViewerThumbnailLayout.selectedExtraWidth
                : 0

            return CGSize(
                width: baseWidth + extraWidth,
                height: NCMediaViewerThumbnailLayout.itemContainerHeight
            )
        }

        // MARK: - UICollectionViewDataSourcePrefetching

        func collectionView(
            _ collectionView: UICollectionView,
            prefetchItemsAt indexPaths: [IndexPath]
        ) {
            for indexPath in indexPaths {
                prefetchThumbnail(at: indexPath.item)
            }
        }

        // MARK: - Public Coordinator Updates

        func syncDisplayedSelectedIndexFromInput() {
            guard selectedIndex >= 0,
                  selectedIndex < numberOfPages else {
                return
            }

            guard !isUserScrollingThumbnails else {
                return
            }

            displayedSelectedIndex = selectedIndex
            lastSentSelectedIndex = selectedIndex
        }

        func reloadCollectionViewIfNeeded() {
            guard let collectionView else {
                return
            }

            let didChangeReloadRevision = lastReloadRevision != reloadRevision

            if didChangeReloadRevision {
                lastReloadRevision = reloadRevision
                pendingPrefetchIndexes.removeAll()
                loadedAudioIndexes.removeAll()
                indexesWithoutPreview.removeAll()
                imageCache.removeAllObjects()
                refreshVisibleCells()
                prefetchAroundDisplayedSelectedIndexIfNeeded()
            }

            guard lastNumberOfPages != numberOfPages else {
                return
            }

            lastNumberOfPages = numberOfPages
            lastCenteredIndex = nil
            lastCenteredBoundsSize = .zero
            didPerformInitialDeferredCentering = false
            pendingPrefetchIndexes.removeAll()
            loadedAudioIndexes.removeAll()
            indexesWithoutPreview.removeAll()
            imageCache.removeAllObjects()
            collectionView.reloadData()
        }

        func performInitialDeferredCenteringIfNeeded() {
            guard !didPerformInitialDeferredCentering else {
                return
            }

            didPerformInitialDeferredCentering = true

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.lastCenteredIndex = nil
                self.lastCenteredBoundsSize = .zero
                self.scrollToSelectedIndexIfNeeded(animated: false)
                self.prefetchAroundDisplayedSelectedIndexIfNeeded()
            }
        }

        func prefetchAroundDisplayedSelectedIndexIfNeeded() {
            guard numberOfPages > 0 else {
                return
            }

            let index = displayedSelectedIndex ?? selectedIndex

            guard index >= 0,
                  index < numberOfPages else {
                return
            }

            prefetchThumbnailsAround(index)
        }

        func collectionViewBoundsDidChange(_ size: CGSize) {
            guard size.width > 0,
                  size.height > 0 else {
                return
            }

            guard !isUserScrollingThumbnails else {
                return
            }

            lastCenteredIndex = nil
            lastCenteredBoundsSize = .zero
            collectionView?.collectionViewLayout.invalidateLayout()
            scrollToSelectedIndexIfNeeded(animated: false)
        }

        func scrollToSelectedIndexIfNeeded(animated: Bool) {
            guard let collectionView,
                  numberOfPages > 0 else {
                return
            }

            guard !isUserScrollingThumbnails else {
                return
            }

            let index = displayedSelectedIndex ?? selectedIndex

            guard index >= 0,
                  index < numberOfPages else {
                return
            }

            let boundsSize = collectionView.bounds.size

            guard boundsSize.width > 0,
                  boundsSize.height > 0 else {
                lastCenteredIndex = nil
                lastCenteredBoundsSize = .zero
                return
            }

            if lastCenteredIndex == index,
               lastCenteredBoundsSize == boundsSize {
                refreshVisibleCells()
                return
            }

            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
            updateContentInsetsIfNeeded()

            let indexPath = IndexPath(
                item: index,
                section: 0
            )

            guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
                collectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredHorizontally,
                    animated: animated
                )

                lastCenteredIndex = index
                lastCenteredBoundsSize = boundsSize

                refreshVisibleCells()
                return
            }

            let targetOffsetX = attributes.center.x - collectionView.bounds.width / 2
            let minOffsetX = -collectionView.adjustedContentInset.left
            let maxOffsetX = max(
                minOffsetX,
                collectionView.contentSize.width - collectionView.bounds.width + collectionView.adjustedContentInset.right
            )

            let clampedOffsetX = min(
                max(targetOffsetX, minOffsetX),
                maxOffsetX
            )

            collectionView.setContentOffset(
                CGPoint(
                    x: clampedOffsetX,
                    y: 0
                ),
                animated: animated
            )

            lastCenteredIndex = index
            lastCenteredBoundsSize = boundsSize

            refreshVisibleCells()
        }

        // MARK: - Thumbnail Scroll Selection

        private func selectCenteredThumbnailDuringScrollIfNeeded() {
            guard let centeredIndex = centeredThumbnailIndex() else {
                return
            }

            guard centeredIndex >= 0,
                  centeredIndex < numberOfPages else {
                return
            }

            guard lastSentSelectedIndex != centeredIndex else {
                return
            }

            displayedSelectedIndex = centeredIndex
            lastCenteredIndex = nil
            lastSentSelectedIndex = centeredIndex
            selectionFeedbackGenerator.selectionChanged()
            selectionFeedbackGenerator.prepare()

            prefetchThumbnailsAround(centeredIndex)
            onSelect(centeredIndex)
        }

        private func finishUserThumbnailScroll() {
            guard isUserScrollingThumbnails else {
                return
            }

            isUserScrollingThumbnails = false
            shouldEmphasizeSelectedThumbnail = true
            lastCenteredIndex = nil

            collectionView?.collectionViewLayout.invalidateLayout()
            scrollToSelectedIndexIfNeeded(animated: true)
        }

        private func centeredThumbnailIndex() -> Int? {
            guard let collectionView else {
                return nil
            }

            let visibleRect = CGRect(
                origin: collectionView.contentOffset,
                size: collectionView.bounds.size
            )

            let centerPoint = CGPoint(
                x: visibleRect.midX,
                y: visibleRect.midY
            )

            if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
                return indexPath.item
            }

            let visibleIndexPaths = collectionView.indexPathsForVisibleItems

            guard !visibleIndexPaths.isEmpty else {
                return nil
            }

            return visibleIndexPaths
                .compactMap { indexPath -> (index: Int, distance: CGFloat)? in
                    guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
                        return nil
                    }

                    return (
                        index: indexPath.item,
                        distance: abs(attributes.center.x - centerPoint.x)
                    )
                }
                .min { $0.distance < $1.distance }?
                .index
        }

        // MARK: - Insets

        private func updateContentInsetsIfNeeded() {
            guard let collectionView else {
                return
            }

            let selectedItemWidth = NCMediaViewerThumbnailLayout.thumbnailSize + NCMediaViewerThumbnailLayout.selectedExtraWidth

            let horizontalInset = max(
                0,
                (collectionView.bounds.width - selectedItemWidth) / 2
            )

            let contentInset = UIEdgeInsets(
                top: 0,
                left: horizontalInset,
                bottom: 0,
                right: horizontalInset
            )

            guard collectionView.contentInset != contentInset else {
                return
            }

            collectionView.contentInset = contentInset
            collectionView.scrollIndicatorInsets = contentInset
        }

        // MARK: - Cell Refresh

        private func refreshVisibleCells() {
            guard let collectionView else {
                return
            }

            for indexPath in collectionView.indexPathsForVisibleItems {
                guard let cell = collectionView.cellForItem(at: indexPath) as? NCMediaViewerThumbnailUICollectionCell else {
                    continue
                }

                configure(
                    cell,
                    at: indexPath.item
                )
            }
        }

        private func refreshThumbnailIfVisible(at index: Int) {
            guard let collectionView else {
                return
            }

            let indexPath = IndexPath(
                item: index,
                section: 0
            )

            guard collectionView.indexPathsForVisibleItems.contains(indexPath),
                  let cell = collectionView.cellForItem(at: indexPath) as? NCMediaViewerThumbnailUICollectionCell else {
                return
            }

            configure(
                cell,
                at: index
            )
        }

        // MARK: - Cell Configuration

        private func configure(
            _ cell: NCMediaViewerThumbnailUICollectionCell,
            at index: Int
        ) {
            let isDeleted = isDeletedProvider(index)
            let metadata = isDeleted ? nil : metadataProvider(index)
            let ocId = metadata?.ocId
            let isCurrent = shouldEmphasizeSelectedThumbnail && isDisplayedCurrentThumbnail(at: index)
            let isVideo = !isDeleted && metadata?.classFile == NKTypeClassFile.video.rawValue
            let isAudio = !isDeleted && metadata?.classFile == NKTypeClassFile.audio.rawValue
            let isMetadataResolved = metadata != nil
            let image = isDeleted ? nil : image(for: ocId)
            let shouldShowPlaceholder = isDeleted || (
                image == nil &&
                indexesWithoutPreview.contains(index)
            )

            if !isDeleted, isAudio {
                loadAudioIfNeeded(at: index)
            } else if !isDeleted, image == nil {
                loadThumbnailIfNeeded(
                    index: index,
                    metadata: metadata
                )
            }

            cell.configure(
                image: image,
                isCurrent: isCurrent,
                isVideo: isVideo,
                isAudio: isAudio,
                isMetadataResolved: isMetadataResolved,
                shouldShowPlaceholder: shouldShowPlaceholder,
                isDeleted: isDeleted
            )
        }

        private func loadAudioIfNeeded(at index: Int) {
            guard index >= 0,
                  index < numberOfPages,
                  !isDeletedProvider(index),
                  !loadedAudioIndexes.contains(index),
                  !pendingPrefetchIndexes.contains(index) else {
                return
            }

            pendingPrefetchIndexes.insert(index)

            Task { [weak self] in
                guard let self else {
                    return
                }

                let metadata: tableMetadata?

                if let cachedMetadata = self.metadataProvider(index) {
                    metadata = cachedMetadata
                } else {
                    metadata = await self.metadataResolver(index)
                }

                // Let the normal viewer pipeline resolve/download the audio first.
                // It can trigger a SwiftUI update that clears this thumbnail cache.
                await self.audioLoadProvider(index)

                guard let metadata,
                      !metadata.ocId.isEmpty,
                      !self.isDeletedProvider(index) else {
                    _ = self.pendingPrefetchIndexes.remove(index)
                    return
                }

                guard let previewURL = await self.previewURLProvider(metadata),
                      let image = await Self.makeImage(from: previewURL) else {
                    _ = self.pendingPrefetchIndexes.remove(index)
                    self.loadedAudioIndexes.insert(index)
                    self.indexesWithoutPreview.insert(index)
                    self.refreshThumbnailIfVisible(at: index)
                    return
                }

                _ = self.pendingPrefetchIndexes.remove(index)
                self.loadedAudioIndexes.insert(index)
                self.indexesWithoutPreview.remove(index)

                guard !self.isDeletedProvider(index) else {
                    return
                }

                self.imageCache.setObject(
                    image,
                    forKey: metadata.ocId as NSString
                )
                self.refreshThumbnailIfVisible(at: index)
            }
        }

        private func isDisplayedCurrentThumbnail(at index: Int) -> Bool {
            if let displayedSelectedIndex {
                return displayedSelectedIndex == index
            }

            return selectedIndex == index
        }

        private func image(for ocId: String?) -> UIImage? {
            guard let ocId,
                  !ocId.isEmpty else {
                return nil
            }

            return imageCache.object(forKey: ocId as NSString)
        }

        // MARK: - Preview Loading

        private func prefetchThumbnailsAround(_ index: Int) {
            guard numberOfPages > 0 else {
                return
            }

            let radius = NCMediaViewerThumbnailLayout.prefetchRadius
            let lowerBound = max(0, index - radius)
            let upperBound = min(numberOfPages - 1, index + radius)

            guard lowerBound <= upperBound else {
                return
            }

            let indexes = (lowerBound...upperBound)
                .sorted {
                    abs($0 - index) < abs($1 - index)
                }

            for targetIndex in indexes {
                prefetchThumbnail(at: targetIndex)
            }
        }

        private func prefetchThumbnail(at index: Int) {
            guard !isDeletedProvider(index) else {
                return
            }

            let metadata = metadataProvider(index)

            if metadata?.classFile == NKTypeClassFile.audio.rawValue {
                loadAudioIfNeeded(at: index)
            } else {
                loadThumbnailIfNeeded(
                    index: index,
                    metadata: metadata
                )
            }
        }

        private func loadThumbnailIfNeeded(
            index: Int,
            metadata initialMetadata: tableMetadata?
        ) {
            guard index >= 0,
                  index < numberOfPages,
                  !isDeletedProvider(index),
                  !indexesWithoutPreview.contains(index),
                  !pendingPrefetchIndexes.contains(index) else {
                return
            }

            if let ocId = initialMetadata?.ocId,
               !ocId.isEmpty,
               imageCache.object(forKey: ocId as NSString) != nil {
                refreshThumbnailIfVisible(at: index)
                return
            }

            pendingPrefetchIndexes.insert(index)

            Task { [weak self] in
                guard let self else {
                    return
                }

                let metadata = if let initialMetadata {
                    initialMetadata
                } else {
                    await self.metadataResolver(index)
                }

                guard let metadata,
                      !metadata.ocId.isEmpty else {
                    await MainActor.run {
                        _ = self.pendingPrefetchIndexes.remove(index)
                    }
                    return
                }

                guard !self.isDeletedProvider(index) else {
                    await MainActor.run {
                        _ = self.pendingPrefetchIndexes.remove(index)
                    }
                    return
                }

                guard metadata.classFile != NKTypeClassFile.audio.rawValue else {
                    await MainActor.run {
                        _ = self.pendingPrefetchIndexes.remove(index)
                        self.loadAudioIfNeeded(at: index)
                        self.refreshThumbnailIfVisible(at: index)
                    }
                    return
                }

                guard let previewURL = await self.previewURLProvider(metadata) else {
                    await MainActor.run {
                        self.indexesWithoutPreview.insert(index)
                        _ = self.pendingPrefetchIndexes.remove(index)
                        self.refreshThumbnailIfVisible(at: index)
                    }
                    return
                }

                guard let image = await Self.makeImage(from: previewURL) else {
                    await MainActor.run {
                        self.indexesWithoutPreview.insert(index)
                        _ = self.pendingPrefetchIndexes.remove(index)
                        self.refreshThumbnailIfVisible(at: index)
                    }
                    return
                }

                await MainActor.run {
                    self.indexesWithoutPreview.remove(index)
                    _ = self.pendingPrefetchIndexes.remove(index)

                    guard !self.isDeletedProvider(index) else {
                        return
                    }

                    self.imageCache.setObject(
                        image,
                        forKey: metadata.ocId as NSString
                    )

                    self.refreshThumbnailIfVisible(at: index)
                }
            }
        }

        private static func makeImage(from previewURL: URL?) async -> UIImage? {
            guard let previewURL else {
                return nil
            }

            return await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: previewURL.path)
            }.value
        }
    }
}

// MARK: - Collection View

private final class NCMediaViewerThumbnailCollectionView: UICollectionView {
    var onBoundsSizeChanged: ((CGSize) -> Void)?

    private var lastBoundsSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()

        let currentBoundsSize = bounds.size

        guard currentBoundsSize != lastBoundsSize else {
            return
        }

        lastBoundsSize = currentBoundsSize
        onBoundsSizeChanged?(currentBoundsSize)
    }
}

private final class NCMediaViewerThumbnailUICollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "NCMediaViewerThumbnailUICollectionCell"

    private let imageView = UIImageView()
    private let placeholderView = UIView()
    private let placeholderIconView = UIImageView(image: UIImage(systemName: "photo"))
    private let playIconView = UIImageView(image: UIImage(systemName: "play.fill"))

    private var isCurrentThumbnail = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        isCurrentThumbnail = false
        imageView.image = nil
        placeholderIconView.image = UIImage(systemName: "photo")
        playIconView.isHidden = true
        placeholderView.isHidden = true
        layer.zPosition = 0
        isSelected = false
        isHighlighted = false
    }

    override var isSelected: Bool {
        didSet {
            super.isSelected = false
        }
    }

    override var isHighlighted: Bool {
        didSet {
            super.isHighlighted = false
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let thumbnailSize = isCurrentThumbnail
            ? NCMediaViewerThumbnailLayout.selectedThumbnailSize
            : NCMediaViewerThumbnailLayout.thumbnailSize

        let thumbnailFrame = CGRect(
            x: (contentView.bounds.width - thumbnailSize) / 2,
            y: (contentView.bounds.height - thumbnailSize) / 2,
            width: thumbnailSize,
            height: thumbnailSize
        )

        imageView.frame = thumbnailFrame
        placeholderView.frame = thumbnailFrame

        placeholderIconView.center = CGPoint(
            x: placeholderView.bounds.midX,
            y: placeholderView.bounds.midY
        )

        playIconView.center = CGPoint(
            x: thumbnailFrame.midX,
            y: thumbnailFrame.midY
        )
    }

    func configure(
        image: UIImage?,
        isCurrent: Bool,
        isVideo: Bool,
        isAudio: Bool,
        isMetadataResolved: Bool,
        shouldShowPlaceholder: Bool,
        isDeleted: Bool
    ) {
        isCurrentThumbnail = isCurrent
        imageView.image = isDeleted ? nil : image
        placeholderView.isHidden = !shouldShowPlaceholder

        let placeholderSymbol: String

        if isDeleted {
            placeholderSymbol = "trash"
        } else if !isMetadataResolved {
            placeholderSymbol = "ellipsis"
        } else if isAudio {
            placeholderSymbol = "waveform"
        } else if isVideo {
            placeholderSymbol = "play.rectangle"
        } else {
            placeholderSymbol = "photo"
        }
        let placeholderPointSize = isCurrent
            ? NCMediaViewerThumbnailLayout.selectedThumbnailSize * 0.32
            : NCMediaViewerThumbnailLayout.thumbnailSize * 0.38

        placeholderView.backgroundColor = UIColor.secondarySystemFill
        placeholderIconView.tintColor = .label

        let placeholderConfiguration = UIImage.SymbolConfiguration(
            pointSize: placeholderPointSize,
            weight: .medium
        )

        placeholderIconView.image = UIImage(
            systemName: placeholderSymbol,
            withConfiguration: placeholderConfiguration
        )?.withRenderingMode(.alwaysTemplate)
        placeholderIconView.bounds.size = CGSize(
            width: placeholderPointSize,
            height: placeholderPointSize
        )
        playIconView.image = playIconView.image?.withRenderingMode(.alwaysTemplate)
        playIconView.tintColor = .systemGray
        playIconView.isHidden = isDeleted || !isVideo || imageView.image == nil
        layer.zPosition = isCurrent ? 10 : 0

        setNeedsLayout()
        layoutIfNeeded()
    }

    private func setupViews() {
        contentView.clipsToBounds = false

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = NCMediaViewerThumbnailLayout.cornerRadius
        imageView.layer.cornerCurve = .continuous

        placeholderView.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        placeholderView.clipsToBounds = true
        placeholderView.layer.cornerRadius = NCMediaViewerThumbnailLayout.cornerRadius
        placeholderView.layer.cornerCurve = .continuous

        placeholderIconView.tintColor = UIColor.white.withAlphaComponent(0.75)
        placeholderIconView.contentMode = .center

        playIconView.tintColor = .white
        playIconView.contentMode = .center
        playIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 14,
            weight: .semibold
        )
        playIconView.layer.shadowColor = UIColor.black.cgColor
        playIconView.layer.shadowOpacity = 0.35
        playIconView.layer.shadowRadius = 4
        playIconView.layer.shadowOffset = CGSize(
            width: 0,
            height: 2
        )

        contentView.addSubview(imageView)
        contentView.addSubview(placeholderView)
        placeholderView.addSubview(placeholderIconView)
        contentView.addSubview(playIconView)
    }
}
