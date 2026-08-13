// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import VisionKit

// MARK: - Image Zoom View
struct NCImageZoomView: UIViewRepresentable {
    let image: UIImage
    let backgroundStyle: NCViewerBackgroundStyle
    let allowsImageAnalysis: Bool
    let onZoomChanged: (Bool) -> Void

    private let minimumZoomScale: CGFloat = 1
    private let maximumZoomScale: CGFloat = 5
    private let doubleTapZoomScale: CGFloat = 2.5

    init(
        image: UIImage,
        backgroundStyle: NCViewerBackgroundStyle = .system,
        allowsImageAnalysis: Bool = true,
        onZoomChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.image = image
        self.backgroundStyle = backgroundStyle
        self.allowsImageAnalysis = allowsImageAnalysis
        self.onZoomChanged = onZoomChanged
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
        context.coordinator.onZoomChanged = onZoomChanged

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
        context.coordinator.onZoomChanged = onZoomChanged

        scrollView.backgroundColor = .ncViewerBackground(backgroundStyle)
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        imageView.backgroundColor = .ncViewerBackground(backgroundStyle)

        let imageChanged = context.coordinator.currentImage !== image

        if imageChanged {
            let zoomState = context.coordinator.zoomState()

            context.coordinator.currentImage = image
            context.coordinator.resetBoundsTracking()

            imageView.image = image
            context.coordinator.layoutImageView(preserving: zoomState)

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
        struct ZoomState: Equatable {
            let zoomScale: CGFloat
            let normalizedCenter: CGPoint
        }

        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var currentImage: UIImage?
        var backgroundStyle: NCViewerBackgroundStyle = .system

        var minimumZoomScale: CGFloat = 1
        var maximumZoomScale: CGFloat = 5
        var doubleTapZoomScale: CGFloat = 2.5
        var onZoomChanged: (Bool) -> Void = { _ in }

        private var lastBoundsSize: CGSize = .zero
        private var isRestoringZoomState = false

        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageView()

            guard !isRestoringZoomState else {
                return
            }

            onZoomChanged(
                scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
            )
        }

        // MARK: - Layout
        func resetBoundsTracking() {
            lastBoundsSize = .zero
        }

        func layoutImageViewResettingZoom() {
            layoutImageView(preserving: nil)
        }

        func zoomState() -> ZoomState? {
            guard let scrollView,
                  let imageView,
                  scrollView.zoomScale > minimumZoomScale + 0.01,
                  imageView.bounds.width > 0,
                  imageView.bounds.height > 0 else {
                return nil
            }

            let visibleCenter = CGPoint(
                x: scrollView.bounds.midX,
                y: scrollView.bounds.midY
            )
            let imageCenter = imageView.convert(
                visibleCenter,
                from: scrollView
            )

            return ZoomState(
                zoomScale: scrollView.zoomScale,
                normalizedCenter: CGPoint(
                    x: min(max(imageCenter.x / imageView.bounds.width, 0), 1),
                    y: min(max(imageCenter.y / imageView.bounds.height, 0), 1)
                )
            )
        }

        func layoutImageView(preserving zoomState: ZoomState?) {
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

            isRestoringZoomState = true
            defer {
                isRestoringZoomState = false
                onZoomChanged(
                    scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
                )
            }

            layoutImageViewAtMinimumZoom(
                imageSize: image.size,
                boundsSize: boundsSize
            )

            guard let zoomState else {
                return
            }

            let restoredZoomScale = min(
                max(zoomState.zoomScale, minimumZoomScale),
                maximumZoomScale
            )
            scrollView.setZoomScale(restoredZoomScale, animated: false)
            centerImageView()

            let imagePoint = CGPoint(
                x: imageView.bounds.width * zoomState.normalizedCenter.x,
                y: imageView.bounds.height * zoomState.normalizedCenter.y
            )
            let contentPoint = imageView.convert(imagePoint, to: scrollView)
            let proposedContentOffset = CGPoint(
                x: contentPoint.x - boundsSize.width * 0.5,
                y: contentPoint.y - boundsSize.height * 0.5
            )

            scrollView.contentOffset = clampedContentOffset(
                proposedContentOffset,
                in: scrollView
            )
        }

        private func layoutImageViewAtMinimumZoom(
            imageSize: CGSize,
            boundsSize: CGSize
        ) {
            guard let scrollView,
                  let imageView else {
                return
            }

            let fittedSize = fittedImageSize(
                imageSize: imageSize,
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

        // Reset zoom on size changes to avoid stale offsets.
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

            layoutImageViewResettingZoom()
        }

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

        private func isValidLayout(
            imageSize: CGSize,
            boundsSize: CGSize
        ) -> Bool {
            imageSize.width > 0 &&
            imageSize.height > 0 &&
            boundsSize.width > 0 &&
            boundsSize.height > 0
        }

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

        private func clampedContentOffset(
            _ proposedContentOffset: CGPoint,
            in scrollView: UIScrollView
        ) -> CGPoint {
            let minimumX = -scrollView.contentInset.left
            let minimumY = -scrollView.contentInset.top
            let maximumX = max(
                minimumX,
                scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right
            )
            let maximumY = max(
                minimumY,
                scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
            )

            return CGPoint(
                x: min(max(proposedContentOffset.x, minimumX), maximumX),
                y: min(max(proposedContentOffset.y, minimumY), maximumY)
            )
        }

        // MARK: - Gestures
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

            let zoomSize = CGSize(
                width: scrollView.bounds.width / targetScale,
                height: scrollView.bounds.height / targetScale
            )

            let zoomRect = CGRect(
                x: point.x - zoomSize.width * 0.5,
                y: point.y - zoomSize.height * 0.5,
                width: zoomSize.width,
                height: zoomSize.height
            )

            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    // MARK: - Image Analysis
    // Rebuild analysis to avoid stale VisionKit results after image changes.
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

    @MainActor
    private func removeImageAnalysisInteractions(from imageView: UIImageView) {
        imageView.interactions
            .compactMap { $0 as? ImageAnalysisInteraction }
            .forEach { imageView.removeInteraction($0) }
    }
}
