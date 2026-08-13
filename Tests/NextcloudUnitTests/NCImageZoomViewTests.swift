// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later
import Testing
import UIKit
@testable import Nextcloud

@Suite("Image zoom view")
@MainActor
struct NCImageZoomViewTests {
    @Test("Replacing an image preserves its zoom scale and focal point")
    func preservesZoomStateWhenImageChanges() throws {
        let (coordinator, scrollView, imageView) = makeZoomView(
            imageSize: CGSize(width: 400, height: 300)
        )

        scrollView.setZoomScale(3, animated: false)
        scrollView.contentOffset = CGPoint(x: 220, y: 70)

        let zoomState = try #require(coordinator.zoomState())

        imageView.image = makeImage(
            size: CGSize(width: 300, height: 400)
        )
        coordinator.layoutImageView(preserving: zoomState)

        let restoredZoomState = try #require(coordinator.zoomState())

        #expect(abs(restoredZoomState.zoomScale - zoomState.zoomScale) < 0.001)
        #expect(abs(restoredZoomState.normalizedCenter.x - zoomState.normalizedCenter.x) < 0.001)
        #expect(abs(restoredZoomState.normalizedCenter.y - zoomState.normalizedCenter.y) < 0.001)
    }

    @Test("Relayout without a saved state resets zoom")
    func resetsZoomWithoutSavedState() {
        let (coordinator, scrollView, imageView) = makeZoomView(
            imageSize: CGSize(width: 400, height: 300)
        )

        scrollView.setZoomScale(3, animated: false)
        imageView.image = makeImage(
            size: CGSize(width: 800, height: 600)
        )

        coordinator.layoutImageViewResettingZoom()

        #expect(scrollView.zoomScale == scrollView.minimumZoomScale)
        #expect(coordinator.zoomState() == nil)
    }

    private func makeZoomView(
        imageSize: CGSize
    ) -> (
        NCImageZoomView.Coordinator,
        NCImageZoomView.NCZoomScrollView,
        UIImageView
    ) {
        let coordinator = NCImageZoomView.Coordinator()
        let scrollView = NCImageZoomView.NCZoomScrollView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        let imageView = UIImageView(
            image: makeImage(size: imageSize)
        )

        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.delegate = coordinator
        scrollView.addSubview(imageView)

        coordinator.minimumZoomScale = 1
        coordinator.maximumZoomScale = 5
        coordinator.scrollView = scrollView
        coordinator.imageView = imageView
        coordinator.layoutImageViewResettingZoom()

        return (coordinator, scrollView, imageView)
    }

    private func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
