// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import VisionKit

// MARK: - Image Zoom View

/// UIKit-backed image zoom view.
///
/// This view uses `UIScrollView` because it provides native, smooth pinch-to-zoom
/// and pan behavior, which is more reliable than SwiftUI `MagnifyGesture` when
/// hosted inside a paging container.
struct NCImageZoomView: UIViewRepresentable {
    let image: UIImage
    let backgroundStyle: NCViewerBackgroundStyle
    let allowsImageAnalysis: Bool

    private let minimumZoomScale: CGFloat = 1
    private let maximumZoomScale: CGFloat = 5
    private let doubleTapZoomScale: CGFloat = 2.5

    /// Creates an image zoom view.
    ///
    /// - Parameters:
    ///   - image: Image rendered inside the zoomable scroll view.
    ///   - backgroundStyle: Viewer background style.
    init(
        image: UIImage,
        backgroundStyle: NCViewerBackgroundStyle = .system,
        allowsImageAnalysis: Bool = true
    ) {
        self.image = image
        self.backgroundStyle = backgroundStyle
        self.allowsImageAnalysis = allowsImageAnalysis
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> NCZoomScrollView {
        let scrollView = NCZoomScrollView()

        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .ncViewerBackground(backgroundStyle)
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.zoomScale = minimumZoomScale
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = true

        let imageView = UIImageView(frame: .zero)
        imageView.image = image
        imageView.backgroundColor = .ncViewerBackground(backgroundStyle)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true

        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.currentImage = image
        context.coordinator.backgroundStyle = backgroundStyle
        context.coordinator.minimumZoomScale = minimumZoomScale
        context.coordinator.maximumZoomScale = maximumZoomScale
        context.coordinator.doubleTapZoomScale = doubleTapZoomScale

        if allowsImageAnalysis {
            analyzeImageIfAvailable(
                image: image,
                imageView: imageView,
                coordinator: context.coordinator
            )
        }

        scrollView.onLayoutSubviews = { [weak coordinator = context.coordinator] in
            coordinator?.layoutImageViewResettingOnBoundsChange()
        }

        let doubleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        return scrollView
    }

    func updateUIView(
        _ scrollView: NCZoomScrollView,
        context: Context
    ) {
        guard let imageView = context.coordinator.imageView else {
            return
        }

        context.coordinator.backgroundStyle = backgroundStyle
        context.coordinator.minimumZoomScale = minimumZoomScale
        context.coordinator.maximumZoomScale = maximumZoomScale
        context.coordinator.doubleTapZoomScale = doubleTapZoomScale

        scrollView.backgroundColor = .ncViewerBackground(backgroundStyle)
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        imageView.backgroundColor = .ncViewerBackground(backgroundStyle)

        let imageChanged = context.coordinator.currentImage !== image

        if imageChanged {
            context.coordinator.currentImage = image
            context.coordinator.resetBoundsTracking()

            scrollView.setZoomScale(minimumZoomScale, animated: false)
            scrollView.contentOffset = .zero
            scrollView.contentInset = .zero

            imageView.image = image
            context.coordinator.layoutImageViewResettingZoom()

            if allowsImageAnalysis {
                analyzeImageIfAvailable(
                    image: image,
                    imageView: imageView,
                    coordinator: context.coordinator
                )
            } else {
                removeImageAnalysisInteractions(from: imageView)
            }
        } else {
            context.coordinator.layoutImageViewResettingOnBoundsChange()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Scroll View

    final class NCZoomScrollView: UIScrollView {
        var onLayoutSubviews: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayoutSubviews?()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var currentImage: UIImage?
        var backgroundStyle: NCViewerBackgroundStyle = .system

        var minimumZoomScale: CGFloat = 1
        var maximumZoomScale: CGFloat = 5
        var doubleTapZoomScale: CGFloat = 2.5

        private var lastBoundsSize: CGSize = .zero

        // MARK: - UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageView()
        }

        // MARK: - Layout

        /// Resets cached bounds tracking so the next layout pass refits the image.
        func resetBoundsTracking() {
            lastBoundsSize = .zero
        }

        /// Lays out the image view and resets zoom to the fitted image.
        func layoutImageViewResettingZoom() {
            guard let scrollView,
                  let imageView,
                  let image = imageView.image else {
                return
            }

            let boundsSize = scrollView.bounds.size

            guard isValidLayout(
                imageSize: image.size,
                boundsSize: boundsSize
            ) else {
                return
            }

            let fittedSize = fittedImageSize(
                imageSize: image.size,
                containerSize: boundsSize
            )

            scrollView.setZoomScale(minimumZoomScale, animated: false)
            scrollView.contentInset = .zero
            scrollView.contentOffset = .zero

            imageView.frame = CGRect(
                origin: .zero,
                size: fittedSize
            )

            scrollView.contentSize = fittedSize
            lastBoundsSize = boundsSize

            centerImageView()
        }

        /// Lays out the image view when the container size changes.
        ///
        /// The zoom is reset on bounds changes because rotation, iPad resizing,
        /// and Stage Manager can otherwise leave stale offsets or invalid content sizes.
        func layoutImageViewResettingOnBoundsChange() {
            guard let scrollView,
                  let imageView,
                  let image = imageView.image else {
                return
            }

            let boundsSize = scrollView.bounds.size

            guard isValidLayout(
                imageSize: image.size,
                boundsSize: boundsSize
            ) else {
                return
            }

            guard boundsSize != lastBoundsSize else {
                centerImageView()
                return
            }

            let fittedSize = fittedImageSize(
                imageSize: image.size,
                containerSize: boundsSize
            )

            scrollView.setZoomScale(minimumZoomScale, animated: false)
            scrollView.contentInset = .zero
            scrollView.contentOffset = .zero

            imageView.frame = CGRect(
                origin: .zero,
                size: fittedSize
            )

            scrollView.contentSize = fittedSize
            lastBoundsSize = boundsSize

            centerImageView()
        }

        /// Centers the image view inside the scroll view when the image is smaller than the viewport.
        private func centerImageView() {
            guard let scrollView,
                  let imageView else {
                return
            }

            let boundsSize = scrollView.bounds.size
            let frameSize = imageView.frame.size

            let horizontalInset = max((boundsSize.width - frameSize.width) * 0.5, 0)
            let verticalInset = max((boundsSize.height - frameSize.height) * 0.5, 0)

            let newInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )

            if scrollView.contentInset != newInset {
                scrollView.contentInset = newInset
            }
        }

        /// Returns whether the current image and container sizes can be used for layout.
        private func isValidLayout(
            imageSize: CGSize,
            boundsSize: CGSize
        ) -> Bool {
            imageSize.width > 0 &&
            imageSize.height > 0 &&
            boundsSize.width > 0 &&
            boundsSize.height > 0
        }

        /// Returns the aspect-fit size of an image inside a container.
        private func fittedImageSize(
            imageSize: CGSize,
            containerSize: CGSize
        ) -> CGSize {
            let widthRatio = containerSize.width / imageSize.width
            let heightRatio = containerSize.height / imageSize.height
            let ratio = min(widthRatio, heightRatio)

            return CGSize(
                width: imageSize.width * ratio,
                height: imageSize.height * ratio
            )
        }

        // MARK: - Gestures

        /// Handles double tap zoom and reset.
        @objc
        func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView,
                  let imageView else {
                return
            }

            if scrollView.zoomScale > minimumZoomScale + 0.01 {
                scrollView.setZoomScale(minimumZoomScale, animated: true)
                return
            }

            let point = gesture.location(in: imageView)
            let targetScale = min(doubleTapZoomScale, maximumZoomScale)

            let zoomRect = zoomRect(
                for: scrollView,
                scale: targetScale,
                center: point
            )

            scrollView.zoom(to: zoomRect, animated: true)
        }

        /// Builds the zoom rect used by double tap.
        private func zoomRect(
            for scrollView: UIScrollView,
            scale: CGFloat,
            center: CGPoint
        ) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale
            )

            return CGRect(
                x: center.x - size.width * 0.5,
                y: center.y - size.height * 0.5,
                width: size.width,
                height: size.height
            )
        }
    }

    // MARK: - Image Analysis

    /// Adds VisionKit image analysis to the displayed image when supported.
    ///
    /// Existing analysis interactions are removed before installing a new one,
    /// so stale analysis results are not reused after an image change.
    ///
    /// - Parameters:
    ///   - image: Image to analyze.
    ///   - imageView: Image view that renders the image.
    ///   - coordinator: Coordinator used to validate that the image is still current.
    @MainActor
    private func analyzeImageIfAvailable(
        image: UIImage,
        imageView: UIImageView,
        coordinator: Coordinator
    ) {
        guard ImageAnalyzer.isSupported else {
            return
        }

        imageView.interactions
            .compactMap { $0 as? ImageAnalysisInteraction }
            .forEach { imageView.removeInteraction($0) }

        let interaction = ImageAnalysisInteraction()
        interaction.preferredInteractionTypes = []
        interaction.analysis = nil

        imageView.addInteraction(interaction)

        let analyzer = ImageAnalyzer()
        let configuration = ImageAnalyzer.Configuration([
            .text,
            .machineReadableCode,
            .visualLookUp
        ])

        Task { @MainActor in
            let analysis = try? await analyzer.analyze(
                image,
                configuration: configuration
            )

            guard coordinator.currentImage === image else {
                return
            }

            guard imageView.image === image else {
                return
            }

            interaction.analysis = analysis
            interaction.preferredInteractionTypes = .automatic
        }
    }

    /// Removes VisionKit image analysis interactions from the image view.
    ///
    /// - Parameter imageView: Image view from which analysis interactions should be removed.
    @MainActor
    private func removeImageAnalysisInteractions(from imageView: UIImageView) {
        imageView.interactions
            .compactMap { $0 as? ImageAnalysisInteraction }
            .forEach { imageView.removeInteraction($0) }
    }
}
