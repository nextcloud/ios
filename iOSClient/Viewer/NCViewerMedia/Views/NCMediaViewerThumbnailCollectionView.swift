// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

// MARK: - Layout

private enum NCMediaViewerThumbnailCollectionLayout {
    /// Real square thumbnail image size for non-selected items.
    static let thumbnailSize: CGFloat = 42

    /// Total vertical lane height for each collection view cell.
    /// The selected thumbnail uses this value as its square image size.
    static let itemContainerHeight: CGFloat = 108

    /// Preferred SwiftUI container height for the thumbnail strip.
    static var preferredHeight: CGFloat {
        itemContainerHeight + 10
    }

    /// Horizontal spacing between thumbnail cells.
    static let itemSpacing: CGFloat = 7

    /// Square thumbnail image size used by the currently selected item.
    static var selectedThumbnailSize: CGFloat {
        itemContainerHeight
    }

    /// Extra horizontal width assigned to the selected item.
    /// This must keep the selected cell wide enough to contain `selectedThumbnailSize`.
    static let selectedExtraWidth: CGFloat = 74

    /// Corner radius used by the thumbnail image and placeholder.
    static let cornerRadius: CGFloat = 10

    /// Number of thumbnail previews prefetched around the selected index and maximum decoded images kept in memory.
    static let thumbnailCacheLimit: Int = 80
}

// MARK: - Thumbnail Collection View

/// UIKit thumbnail strip used by the media viewer.
///
/// The strip intentionally does not observe the whole media viewer model.
/// It receives only the selected index and page count from SwiftUI.
/// Metadata and preview loading are delegated through closures.
struct NCMediaViewerThumbnailCollectionView: UIViewRepresentable, Equatable {
    let selectedIndex: Int
    let numberOfPages: Int
    let metadataProvider: (_ index: Int) -> tableMetadata?
    let metadataResolver: (_ index: Int) async -> tableMetadata?
    let previewURLProvider: (_ metadata: tableMetadata) async -> URL?
    let onSelect: (_ index: Int) -> Void

    static var preferredHeight: CGFloat {
        NCMediaViewerThumbnailCollectionLayout.preferredHeight
    }

    static func == (
        lhs: NCMediaViewerThumbnailCollectionView,
        rhs: NCMediaViewerThumbnailCollectionView
    ) -> Bool {
        lhs.selectedIndex == rhs.selectedIndex &&
        lhs.numberOfPages == rhs.numberOfPages
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = NCMediaViewerThumbnailCollectionLayout.itemSpacing
        layout.minimumInteritemSpacing = NCMediaViewerThumbnailCollectionLayout.itemSpacing
        layout.sectionInset = .zero

        let collectionView = UICollectionView(
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

        return collectionView
    }

    func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        context.coordinator.selectedIndex = selectedIndex
        context.coordinator.numberOfPages = numberOfPages
        context.coordinator.metadataProvider = metadataProvider
        context.coordinator.metadataResolver = metadataResolver
        context.coordinator.previewURLProvider = previewURLProvider
        context.coordinator.onSelect = onSelect
        context.coordinator.syncDisplayedSelectedIndexFromInput()

        context.coordinator.reloadCollectionViewIfNeeded()
        context.coordinator.scrollToSelectedIndexIfNeeded(animated: false)
        context.coordinator.prefetchInitialThumbnailWindow()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedIndex: selectedIndex,
            numberOfPages: numberOfPages,
            metadataProvider: metadataProvider,
            metadataResolver: metadataResolver,
            previewURLProvider: previewURLProvider,
            onSelect: onSelect
        )
    }
}

// MARK: - Coordinator

extension NCMediaViewerThumbnailCollectionView {
    @MainActor
    final class Coordinator: NSObject,
                             UICollectionViewDataSource,
                             UICollectionViewDelegateFlowLayout,
                             UICollectionViewDataSourcePrefetching {
        var selectedIndex: Int
        var numberOfPages: Int
        var metadataProvider: (_ index: Int) -> tableMetadata?
        var metadataResolver: (_ index: Int) async -> tableMetadata?
        var previewURLProvider: (_ metadata: tableMetadata) async -> URL?
        var onSelect: (_ index: Int) -> Void

        weak var collectionView: UICollectionView?

        private var lastNumberOfPages: Int?
        private var lastCenteredIndex: Int?
        private var prefetchedLowerBound: Int?
        private var prefetchedUpperBound: Int?
        private var pendingPrefetchIndexes = Set<Int>()
        private var displayedSelectedIndex: Int?
        private var pendingSelectedIndex: Int?
        private let imageCache = NSCache<NSString, UIImage>()

        init(
            selectedIndex: Int,
            numberOfPages: Int,
            metadataProvider: @escaping (_ index: Int) -> tableMetadata?,
            metadataResolver: @escaping (_ index: Int) async -> tableMetadata?,
            previewURLProvider: @escaping (_ metadata: tableMetadata) async -> URL?,
            onSelect: @escaping (_ index: Int) -> Void
        ) {
            self.selectedIndex = selectedIndex
            self.numberOfPages = numberOfPages
            self.metadataProvider = metadataProvider
            self.metadataResolver = metadataResolver
            self.previewURLProvider = previewURLProvider
            self.onSelect = onSelect
            self.displayedSelectedIndex = selectedIndex
            super.init()

            imageCache.countLimit = NCMediaViewerThumbnailCollectionLayout.thumbnailCacheLimit
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

            pendingSelectedIndex = selectedIndex
            displayedSelectedIndex = selectedIndex
            lastCenteredIndex = nil

            scrollToSelectedIndexIfNeeded(animated: false)
            onSelect(selectedIndex)
        }

        // MARK: - UICollectionViewDelegateFlowLayout

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let baseWidth = NCMediaViewerThumbnailCollectionLayout.thumbnailSize
            let extraWidth = isDisplayedCurrentThumbnail(at: indexPath.item)
                ? NCMediaViewerThumbnailCollectionLayout.selectedExtraWidth
                : 0

            return CGSize(
                width: baseWidth + extraWidth,
                height: NCMediaViewerThumbnailCollectionLayout.itemContainerHeight
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

            if let pendingSelectedIndex {
                if pendingSelectedIndex == selectedIndex {
                    self.pendingSelectedIndex = nil
                    displayedSelectedIndex = selectedIndex
                }

                return
            }

            displayedSelectedIndex = selectedIndex
        }

        func reloadCollectionViewIfNeeded() {
            guard let collectionView else {
                return
            }

            guard lastNumberOfPages != numberOfPages else {
                return
            }

            lastNumberOfPages = numberOfPages
            lastCenteredIndex = nil
            prefetchedLowerBound = nil
            prefetchedUpperBound = nil
            pendingPrefetchIndexes.removeAll()
            imageCache.removeAllObjects()
            collectionView.reloadData()
        }

        func scrollToSelectedIndexIfNeeded(animated: Bool) {
            guard let collectionView,
                  numberOfPages > 0 else {
                return
            }

            let index = displayedSelectedIndex ?? selectedIndex

            guard index >= 0,
                  index < numberOfPages else {
                return
            }

            guard lastCenteredIndex != index else {
                refreshVisibleCells()
                return
            }

            lastCenteredIndex = index

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

            refreshVisibleCells()
        }

        func prefetchInitialThumbnailWindow() {
            let currentIndex = displayedSelectedIndex ?? selectedIndex

            guard currentIndex >= 0,
                  currentIndex < numberOfPages else {
                return
            }

            let radius = NCMediaViewerThumbnailCollectionLayout.thumbnailCacheLimit
            let lowerBound = max(0, currentIndex - radius)
            let upperBound = min(numberOfPages - 1, currentIndex + radius)

            guard lowerBound <= upperBound else {
                return
            }

            if let prefetchedLowerBound,
               let prefetchedUpperBound,
               currentIndex >= prefetchedLowerBound,
               currentIndex <= prefetchedUpperBound {
                return
            }

            prefetchedLowerBound = lowerBound
            prefetchedUpperBound = upperBound

            let indexes = (lowerBound...upperBound)
                .sorted {
                    abs($0 - currentIndex) < abs($1 - currentIndex)
                }

            for index in indexes {
                prefetchThumbnail(at: index)
            }
        }

        // MARK: - Insets

        private func updateContentInsetsIfNeeded() {
            guard let collectionView else {
                return
            }

            let selectedItemWidth = NCMediaViewerThumbnailCollectionLayout.thumbnailSize +
                NCMediaViewerThumbnailCollectionLayout.selectedExtraWidth

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
            let metadata = metadataProvider(index)
            let ocId = metadata?.ocId
            let isCurrent = isDisplayedCurrentThumbnail(at: index)
            let isVideo = metadata?.classFile == NKTypeClassFile.video.rawValue
            let image = image(for: ocId)

            if image == nil {
                if let metadata {
                    loadPreviewIfNeeded(
                        metadata: metadata,
                        index: index
                    )
                } else {
                    resolveMetadataAndLoadPreviewIfNeeded(at: index)
                }
            }

            cell.configure(
                image: image,
                isCurrent: isCurrent,
                isVideo: isVideo
            )
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

        private func prefetchThumbnail(at index: Int) {
            if let metadata = metadataProvider(index) {
                loadPreviewIfNeeded(
                    metadata: metadata,
                    index: index
                )
            } else {
                resolveMetadataAndLoadPreviewIfNeeded(at: index)
            }
        }

        private func resolveMetadataAndLoadPreviewIfNeeded(at index: Int) {
            guard index >= 0,
                  index < numberOfPages else {
                return
            }

            guard !pendingPrefetchIndexes.contains(index) else {
                return
            }

            pendingPrefetchIndexes.insert(index)

            Task { [weak self] in
                guard let self else {
                    return
                }

                guard let metadata = await self.metadataResolver(index) else {
                    await MainActor.run {
                        self.pendingPrefetchIndexes.remove(index)
                        self.refreshThumbnailIfVisible(at: index)
                    }
                    return
                }

                let previewURL = await self.previewURLProvider(metadata)

                await MainActor.run {
                    self.pendingPrefetchIndexes.remove(index)
                    self.storePreviewImageIfPossible(
                        previewURL: previewURL,
                        metadata: metadata
                    )
                    self.refreshThumbnailIfVisible(at: index)
                }
            }
        }

        private func loadPreviewIfNeeded(
            metadata: tableMetadata,
            index: Int
        ) {
            guard index >= 0,
                  index < numberOfPages else {
                return
            }

            guard !metadata.ocId.isEmpty else {
                return
            }

            let cacheKey = metadata.ocId as NSString

            guard imageCache.object(forKey: cacheKey) == nil else {
                return
            }

            guard !pendingPrefetchIndexes.contains(index) else {
                return
            }

            pendingPrefetchIndexes.insert(index)

            Task { [weak self] in
                guard let self else {
                    return
                }

                let previewURL = await self.previewURLProvider(metadata)

                await MainActor.run {
                    self.pendingPrefetchIndexes.remove(index)
                    self.storePreviewImageIfPossible(
                        previewURL: previewURL,
                        metadata: metadata
                    )
                    self.refreshThumbnailIfVisible(at: index)
                }
            }
        }

        private func storePreviewImageIfPossible(
            previewURL: URL?,
            metadata: tableMetadata
        ) {
            guard !metadata.ocId.isEmpty,
                  let previewURL,
                  let image = UIImage(contentsOfFile: previewURL.path) else {
                return
            }

            imageCache.setObject(
                image,
                forKey: metadata.ocId as NSString
            )
        }
    }
}

// MARK: - Cell

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
        playIconView.isHidden = true
        placeholderView.isHidden = false
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
            ? NCMediaViewerThumbnailCollectionLayout.selectedThumbnailSize
            : NCMediaViewerThumbnailCollectionLayout.thumbnailSize

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
        isVideo: Bool
    ) {
        isCurrentThumbnail = isCurrent

        imageView.image = image
        placeholderView.isHidden = image != nil
        playIconView.isHidden = !isVideo
        layer.zPosition = isCurrent ? 10 : 0

        setNeedsLayout()
    }

    private func setupViews() {
        contentView.clipsToBounds = false

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = NCMediaViewerThumbnailCollectionLayout.cornerRadius
        imageView.layer.cornerCurve = .continuous

        placeholderView.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        placeholderView.clipsToBounds = true
        placeholderView.layer.cornerRadius = NCMediaViewerThumbnailCollectionLayout.cornerRadius
        placeholderView.layer.cornerCurve = .continuous

        placeholderIconView.tintColor = UIColor.white.withAlphaComponent(0.75)
        placeholderIconView.contentMode = .center
        placeholderIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 18,
            weight: .medium
        )

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
