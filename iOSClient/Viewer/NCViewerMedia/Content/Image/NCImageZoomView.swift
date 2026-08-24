// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import VisionKit

// MARK: - Image Zoom View
struct NCImageZoomView: UIViewRepresentable {
    static let supportedZoomScaleRange: ClosedRange<CGFloat> = 1...5

    struct ZoomState: Equatable {
        let zoomScale: CGFloat
        let normalizedCenter: CGPoint
    }

    let image: UIImage
    let backgroundStyle: NCViewerBackgroundStyle
    let allowsImageAnalysis: Bool
    let initialZoomState: ZoomState?
    let onZoomChanged: (Bool) -> Void
    let onZoomStateChanged: (ZoomState?) -> Void

    private var minimumZoomScale: CGFloat { Self.supportedZoomScaleRange.lowerBound }
    private var maximumZoomScale: CGFloat { Self.supportedZoomScaleRange.upperBound }
    private let doubleTapZoomScale: CGFloat = 2.5

    init(
        image: UIImage,
        backgroundStyle: NCViewerBackgroundStyle = .system,
        allowsImageAnalysis: Bool = true,
        initialZoomState: ZoomState? = nil,
        onZoomChanged: @escaping (Bool) -> Void = { _ in },
        onZoomStateChanged: @escaping (ZoomState?) -> Void = { _ in }
    ) {
        self.image = image
        self.backgroundStyle = backgroundStyle
        self.allowsImageAnalysis = allowsImageAnalysis
        self.initialZoomState = initialZoomState
        self.onZoomChanged = onZoomChanged
        self.onZoomStateChanged = onZoomStateChanged
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
        context.coordinator.onZoomStateChanged = onZoomStateChanged
        context.coordinator.restorePersistedZoomState(initialZoomState)

        if allowsImageAnalysis {
            analyzeImageIfAvailable(
                image: image,
                imageView: imageView,
                coordinator: context.coordinator
            )
        }

        scrollView.onLayoutSubviews = { [weak coordinator = context.coordinator] in
            coordinator?.layoutImageViewPreservingOnBoundsChange()
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
        context.coordinator.onZoomStateChanged = onZoomStateChanged

        scrollView.backgroundColor = .ncViewerBackground(backgroundStyle)
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        imageView.backgroundColor = .ncViewerBackground(backgroundStyle)

        let imageChanged = context.coordinator.currentImage !== image

        if imageChanged {
            let zoomState = context.coordinator.zoomStateForRelayout()

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
            context.coordinator.layoutImageViewPreservingOnBoundsChange()
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
        var onZoomChanged: (Bool) -> Void = { _ in }
        var onZoomStateChanged: (ZoomState?) -> Void = { _ in }

        private var lastBoundsSize: CGSize = .zero
        private var isRestoringZoomState = false
        private var lastZoomState: ZoomState?

        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageView()

            guard !isRestoringZoomState else {
                return
            }

            if scrollView.pinchGestureRecognizer?.state == .began ||
                scrollView.pinchGestureRecognizer?.state == .changed {
                recordCurrentZoomState()
            }

            onZoomChanged(
                scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
            )
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let isUserDriven = scrollView.panGestureRecognizer.state == .began ||
                scrollView.panGestureRecognizer.state == .changed ||
                scrollView.isDecelerating

            guard !isRestoringZoomState,
                  isUserDriven else {
                return
            }

            recordCurrentZoomState()
        }

        func scrollViewDidEndZooming(
            _ scrollView: UIScrollView,
            with _: UIView?,
            atScale _: CGFloat
        ) {
            guard !isRestoringZoomState else {
                return
            }

            recordCurrentZoomState()
        }

        // MARK: - Layout
        func resetBoundsTracking() {
            lastBoundsSize = .zero
        }

        func layoutImageViewResettingZoom() {
            layoutImageView(preserving: nil)
        }

        func zoomState() -> ZoomState? {
            guard let scrollView else {
                return nil
            }

            guard scrollView.zoomScale.isFinite else {
                return nil
            }

            let clampedZoomScale = min(
                max(scrollView.zoomScale, minimumZoomScale),
                maximumZoomScale
            )

            guard clampedZoomScale > minimumZoomScale + 0.01,
                  scrollView.contentSize.width > 0,
                  scrollView.contentSize.height > 0 else {
                return nil
            }

            let visibleCenter = CGPoint(
                x: scrollView.bounds.midX,
                y: scrollView.bounds.midY
            )

            return ZoomState(
                zoomScale: clampedZoomScale,
                normalizedCenter: CGPoint(
                    x: min(max(visibleCenter.x / scrollView.contentSize.width, 0), 1),
                    y: min(max(visibleCenter.y / scrollView.contentSize.height, 0), 1)
                )
            )
        }

        func zoomStateForRelayout() -> ZoomState? {
            guard let scrollView,
                  scrollView.bounds.size != lastBoundsSize else {
                return zoomState()
            }

            return lastZoomState
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
                updatePersistedZoomState(zoomState ?? self.zoomState())
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

            let contentPoint = CGPoint(
                x: scrollView.contentSize.width * zoomState.normalizedCenter.x,
                y: scrollView.contentSize.height * zoomState.normalizedCenter.y
            )
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

        func layoutImageViewPreservingOnBoundsChange() {
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

            layoutImageView(preserving: lastZoomState)
        }

        func recordCurrentZoomState() {
            guard let scrollView else {
                return
            }

            guard scrollView.bounds.size == lastBoundsSize else {
                return
            }

            updatePersistedZoomState(zoomState())
        }

        func restorePersistedZoomState(_ zoomState: ZoomState?) {
            lastZoomState = zoomState
        }

        private func updatePersistedZoomState(_ zoomState: ZoomState?) {
            lastZoomState = zoomState
            onZoomStateChanged(zoomState)
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
            guard let imageView else {
                return
            }

            toggleZoom(
                at: gesture.location(in: imageView),
                animated: true
            )
        }

        func toggleZoom(at point: CGPoint, animated: Bool) {
            guard let scrollView,
                  let imageView,
                  imageView.bounds.width > 0,
                  imageView.bounds.height > 0 else {
                return
            }

            if scrollView.zoomScale > minimumZoomScale + 0.01 {
                updatePersistedZoomState(nil)
                scrollView.setZoomScale(minimumZoomScale, animated: animated)
                return
            }

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

            updatePersistedZoomState(ZoomState(
                zoomScale: targetScale,
                normalizedCenter: CGPoint(
                    x: min(max(point.x / imageView.bounds.width, 0), 1),
                    y: min(max(point.y / imageView.bounds.height, 0), 1)
                )
            ))
            scrollView.zoom(to: zoomRect, animated: animated)
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
