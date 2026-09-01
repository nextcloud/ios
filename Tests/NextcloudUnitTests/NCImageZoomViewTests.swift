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

    @Test("A full orientation round trip preserves zoom and focal point")
    func preservesZoomStateAfterOrientationRoundTrip() throws {
        let (coordinator, scrollView, _) = makeZoomView(
            imageSize: CGSize(width: 400, height: 300)
        )

        scrollView.setZoomScale(3, animated: false)
        scrollView.contentOffset = CGPoint(x: 0, y: 70)
        coordinator.recordCurrentZoomState()

        let zoomState = try #require(coordinator.zoomState())

        for _ in 0..<3 {
            scrollView.bounds = CGRect(
                origin: scrollView.bounds.origin,
                size: CGSize(width: 480, height: 320)
            )
            coordinator.layoutImageViewPreservingOnBoundsChange()

            // UIKit can deliver automatic scrolling after a rotation finishes.
            scrollView.contentOffset = .zero
            coordinator.scrollViewDidScroll(scrollView)

            scrollView.bounds = CGRect(
                origin: scrollView.bounds.origin,
                size: CGSize(width: 320, height: 480)
            )
            coordinator.layoutImageViewPreservingOnBoundsChange()

            let restoredZoomState = try #require(coordinator.zoomState())
            #expect(abs(restoredZoomState.zoomScale - zoomState.zoomScale) < 0.001)
            #expect(abs(restoredZoomState.normalizedCenter.x - zoomState.normalizedCenter.x) < 0.001)
            #expect(abs(restoredZoomState.normalizedCenter.y - zoomState.normalizedCenter.y) < 0.001)
        }
    }

    @Test("Double-tap zoom survives view recreation and rotation")
    func preservesDoubleTapZoomAfterViewRecreation() throws {
        var persistedZoomState: NCImageZoomView.ZoomState?
        let (firstCoordinator, firstScrollView, firstImageView) = makeZoomView(
            imageSize: CGSize(width: 400, height: 300),
            onZoomStateChanged: { persistedZoomState = $0 }
        )

        firstCoordinator.toggleZoom(
            at: CGPoint(
                x: firstImageView.bounds.midX,
                y: firstImageView.bounds.midY
            ),
            animated: false
        )

        let expectedZoomState = try #require(persistedZoomState)
        #expect(abs(firstScrollView.zoomScale - expectedZoomState.zoomScale) < 0.001)

        let (restoredCoordinator, restoredScrollView, _) = makeZoomView(
            imageSize: CGSize(width: 400, height: 300),
            initialZoomState: expectedZoomState
        )

        restoredScrollView.bounds = CGRect(
            origin: restoredScrollView.bounds.origin,
            size: CGSize(width: 480, height: 320)
        )
        restoredCoordinator.layoutImageViewPreservingOnBoundsChange()

        let restoredZoomState = try #require(restoredCoordinator.zoomState())
        #expect(abs(restoredZoomState.zoomScale - expectedZoomState.zoomScale) < 0.001)
        #expect(abs(restoredZoomState.normalizedCenter.x - expectedZoomState.normalizedCenter.x) < 0.001)
        #expect(abs(restoredZoomState.normalizedCenter.y - expectedZoomState.normalizedCenter.y) < 0.001)
    }

    @Test("Live Photo playback uses the still image zoom and focal point")
    func livePhotoPlaybackPreservesZoomState() {
        let zoomState = NCImageZoomView.ZoomState(
            zoomScale: 3,
            normalizedCenter: CGPoint(x: 0.6, y: 0.55)
        )
        let layout = NCLivePhotoPlaybackLayout(
            containerSize: CGSize(width: 320, height: 480),
            photoSize: CGSize(width: 400, height: 300),
            zoomState: zoomState
        )

        #expect(abs(layout.frame.width - 960) < 0.001)
        #expect(abs(layout.frame.height - 720) < 0.001)
        #expect(abs(
            layout.frame.origin.x + layout.frame.width * zoomState.normalizedCenter.x - 160
        ) < 0.001)
        #expect(abs(
            layout.frame.origin.y + layout.frame.height * zoomState.normalizedCenter.y - 240
        ) < 0.001)
    }

    @Test("Live Photo playback remains aspect-fit without zoom")
    func livePhotoPlaybackUsesAspectFitWithoutZoom() {
        let layout = NCLivePhotoPlaybackLayout(
            containerSize: CGSize(width: 320, height: 480),
            photoSize: CGSize(width: 400, height: 300),
            zoomState: nil
        )

        #expect(layout.frame == CGRect(x: 0, y: 120, width: 320, height: 240))
    }

    @Test("Live Photo playback clamps transient elastic zoom")
    func livePhotoPlaybackClampsElasticZoom() {
        let layout = NCLivePhotoPlaybackLayout(
            containerSize: CGSize(width: 320, height: 480),
            photoSize: CGSize(width: 400, height: 300),
            zoomState: NCImageZoomView.ZoomState(
                zoomScale: 20,
                normalizedCenter: CGPoint(x: 0.5, y: 0.5)
            )
        )

        #expect(layout.frame == CGRect(x: -640, y: -360, width: 1_600, height: 1_200))
    }

    @Test("Persisted zoom state clamps transient elastic zoom")
    func persistedZoomStateClampsElasticZoom() throws {
        var persistedZoomState: NCImageZoomView.ZoomState?
        let (coordinator, scrollView, _) = makeZoomView(
            imageSize: CGSize(width: 400, height: 300),
            onZoomStateChanged: { persistedZoomState = $0 }
        )

        // Allow the test scroll view to reproduce the temporary value that
        // UIScrollView can report while bouncesZoom is active.
        scrollView.maximumZoomScale = 20
        scrollView.setZoomScale(20, animated: false)
        coordinator.scrollViewDidEndZooming(
            scrollView,
            with: nil,
            atScale: scrollView.zoomScale
        )

        let zoomState = try #require(persistedZoomState)

        #expect(zoomState.zoomScale == coordinator.maximumZoomScale)
    }

    private func makeZoomView(
        imageSize: CGSize,
        initialZoomState: NCImageZoomView.ZoomState? = nil,
        onZoomStateChanged: @escaping (NCImageZoomView.ZoomState?) -> Void = { _ in }
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
        coordinator.onZoomStateChanged = onZoomStateChanged
        coordinator.restorePersistedZoomState(initialZoomState)
        coordinator.layoutImageView(preserving: initialZoomState)

        return (coordinator, scrollView, imageView)
    }

    private func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
