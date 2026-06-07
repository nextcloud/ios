// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

// MARK: - Thumbnail Collection View

/// UIKit thumbnail strip used by the media viewer.
struct NCMediaViewerThumbnailCollectionView: UIViewRepresentable {
    @ObservedObject var model: NCMediaViewerModel

    let onSelect: (_ index: Int) -> Void

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
        context.coordinator.model = model
        context.coordinator.onSelect = onSelect
        context.coordinator.syncDisplayedSelectedIndexFromModel()

        context.coordinator.reloadCollectionViewIfNeeded()
        context.coordinator.scrollToSelectedIndexIfNeeded(animated: false)
        context.coordinator.prefetchInitialThumbnailWindow()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            model: model,
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
        var model: NCMediaViewerModel
        var onSelect: (_ index: Int) -> Void

        weak var collectionView: UICollectionView?

        private var lastNumberOfPages: Int?
        private var lastCenteredIndex: Int?
        private var lastPrefetchedCenterIndex: Int?
        private var displayedSelectedIndex: Int?
        private var pendingSelectedIndex: Int?
        private let imageCache = NSCache<NSString, UIImage>()

        init(
            model: NCMediaViewerModel,
            onSelect: @escaping (_ index: Int) -> Void
        ) {
            self.model = model
            self.onSelect = onSelect
            self.displayedSelectedIndex = model.initialSelectedIndex
            super.init()

            imageCache.countLimit = NCMediaViewerThumbnailCollectionLayout.imageCacheLimit
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
            let previousSelectedIndex = displayedSelectedIndex

            pendingSelectedIndex = selectedIndex
            displayedSelectedIndex = selectedIndex
            lastCenteredIndex = nil

            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()

            scrollToSelectedIndexIfNeeded(animated: false)

            if let previousSelectedIndex {
                reloadThumbnailIfVisible(at: previousSelectedIndex)
            }

            reloadThumbnailIfVisible(at: selectedIndex)
            refreshVisibleCells()

            onSelect(selectedIndex)
        }

        // MARK: - UICollectionViewDelegateFlowLayout

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let baseSize = NCMediaViewerThumbnailCollectionLayout.thumbnailSize
            let extraWidth = isDisplayedCurrentThumbnail(at: indexPath.item)
                ? NCMediaViewerThumbnailCollectionLayout.currentExtraWidth
                : 0

            return CGSize(
                width: baseSize + extraWidth,
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

        func syncDisplayedSelectedIndexFromModel() {
            let modelSelectedIndex = model.initialSelectedIndex

            guard modelSelectedIndex >= 0,
                  modelSelectedIndex < model.numberOfPages else {
                return
            }

            if let pendingSelectedIndex {
                if pendingSelectedIndex == modelSelectedIndex {
                    self.pendingSelectedIndex = nil
                    displayedSelectedIndex = modelSelectedIndex
                }

                return
            }

            displayedSelectedIndex = modelSelectedIndex
        }

        func reloadCollectionViewIfNeeded() {
            guard let collectionView else {
                return
            }

            let numberOfPages = model.numberOfPages

            guard lastNumberOfPages != numberOfPages else {
                refreshVisibleCells()
                return
            }

            lastNumberOfPages = numberOfPages
            collectionView.reloadData()
        }

        func scrollToSelectedIndexIfNeeded(animated: Bool) {
            guard let collectionView,
                  model.numberOfPages > 0 else {
                return
            }

            let index = displayedSelectedIndex ?? model.initialSelectedIndex

            guard index >= 0,
                  index < model.numberOfPages else {
                return
            }

            guard lastCenteredIndex != index else {
                refreshVisibleCells()
                return
            }

            let previousCenteredIndex = lastCenteredIndex
            lastCenteredIndex = index

            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()

            let indexPath = IndexPath(
                item: index,
                section: 0
            )

            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredHorizontally,
                animated: animated
            )

            refreshVisibleCells()

            if let previousCenteredIndex {
                reloadThumbnailIfVisible(at: previousCenteredIndex)
            }

            reloadThumbnailIfVisible(at: index)
        }

        func prefetchInitialThumbnailWindow() {
            let selectedIndex = displayedSelectedIndex ?? model.initialSelectedIndex

            guard selectedIndex >= 0,
                  selectedIndex < model.numberOfPages else {
                return
            }

            guard lastPrefetchedCenterIndex != selectedIndex else {
                return
            }

            lastPrefetchedCenterIndex = selectedIndex

            let radius = NCMediaViewerThumbnailCollectionLayout.initialPrefetchRadius
            let lowerBound = max(0, selectedIndex - radius)
            let upperBound = min(model.numberOfPages - 1, selectedIndex + radius)

            guard lowerBound <= upperBound else {
                return
            }

            let indexes = (lowerBound...upperBound)
                .sorted {
                    abs($0 - selectedIndex) < abs($1 - selectedIndex)
                }

            for index in indexes {
                prefetchThumbnail(at: index)
            }
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

        private func reloadThumbnailIfVisible(at index: Int) {
            guard let collectionView else {
                return
            }

            let indexPath = IndexPath(
                item: index,
                section: 0
            )

            guard collectionView.indexPathsForVisibleItems.contains(indexPath) else {
                return
            }

            collectionView.reloadItems(at: [indexPath])
        }

        // MARK: - Cell Configuration

        private func configure(
            _ cell: NCMediaViewerThumbnailUICollectionCell,
            at index: Int
        ) {
            let ocId = model.ocId(at: index)
            let isCurrent = isDisplayedCurrentThumbnail(at: index)
            let isVideo = model.isVideoThumbnail(at: index)
            let previewURL = model.previewURLForThumbnail(at: index)

            let image = image(
                for: previewURL,
                ocId: ocId
            )

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

            return model.isCurrentThumbnail(at: index)
        }

        private func image(
            for previewURL: URL?,
            ocId: String?
        ) -> UIImage? {
            guard let previewURL,
                  let ocId else {
                return nil
            }

            let key = ocId as NSString

            if let cachedImage = imageCache.object(forKey: key) {
                return cachedImage
            }

            guard let image = UIImage(contentsOfFile: previewURL.path) else {
                return nil
            }

            imageCache.setObject(
                image,
                forKey: key
            )

            return image
        }

        // MARK: - Prefetch

        private func prefetchThumbnail(at index: Int) {
            Task { [weak self] in
                guard let self else {
                    return
                }

                await self.model.prefetchThumbnailIfNeeded(index: index)

                await MainActor.run {
                    self.reloadThumbnailIfVisible(at: index)
                }
            }
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

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        imageView.image = nil
        playIconView.isHidden = true
        placeholderView.isHidden = false
        transform = .identity
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

        let thumbnailSize = NCMediaViewerThumbnailCollectionLayout.thumbnailSize
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
        imageView.image = image
        placeholderView.isHidden = image != nil
        playIconView.isHidden = !isVideo

        transform = isCurrent
            ? CGAffineTransform(
                scaleX: NCMediaViewerThumbnailCollectionLayout.currentScale,
                y: NCMediaViewerThumbnailCollectionLayout.currentScale
            )
            : .identity

        layer.zPosition = isCurrent ? 10 : 0
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

// MARK: - Layout

private enum NCMediaViewerThumbnailCollectionLayout {
    static let thumbnailSize: CGFloat = 42
    static let itemContainerHeight: CGFloat = 68
    static let itemSpacing: CGFloat = 7
    static let currentScale: CGFloat = 1.22
    static let currentExtraWidth: CGFloat = 18
    static let cornerRadius: CGFloat = 10
    static let initialPrefetchRadius: Int = 80
    static let imageCacheLimit: Int = 80
}
