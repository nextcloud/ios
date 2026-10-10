// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import Nextcloud

@Suite("Adaptive video layout")
@MainActor
struct NCVideoAdaptiveLayoutViewTests {
    @Test("Adaptive navigation belongs to a separate controls view")
    func separateAdaptiveControls() throws {
        let normalControls = NCVideoControlsView()
        let adaptiveControls = NCVideoAdaptiveControlsView(state: normalControls.state)
        let titleView = UIView()
        let moreItem = UIBarButtonItem(title: "More", primaryAction: UIAction { _ in })
        adaptiveControls.configureFoldedNavigation(
            titleView: titleView,
            closeAction: UIAction { _ in },
            moreItem: moreItem
        )

        let item = try #require(adaptiveControls.foldedNavigationBar.topItem)
        #expect(item.titleView === titleView)
        #expect(item.leftBarButtonItem != nil)
        #expect(item.rightBarButtonItem === moreItem)
        #expect(adaptiveControls.foldedNavigationBar.superview === adaptiveControls)
        #expect(!normalControls.subviews.contains { $0 is UINavigationBar })

        normalControls.updateProgress(progress: 0.5, elapsedText: "1:00", remainingText: "−1:00")
        adaptiveControls.updatePlaybackOptions(isRepeatEnabled: true, isAutoAdvanceEnabled: true)
        #expect(adaptiveControls.state.progress == 0.5)
        #expect(normalControls.state.isRepeatEnabled)
        #expect(normalControls.state.isAutoAdvanceEnabled)
        #expect(normalControls.state === adaptiveControls.state)
    }

    @Test("The experimental layout is disabled by default and can be turned off again")
    func experimentalLayoutRequiresEnabling() {
        let videoView = UIView()
        let normalControlsView = UIView()
        let adaptiveControlsView = UIView()
        let view = NCVideoAdaptiveLayoutView(
            videoView: videoView,
            normalControlsView: normalControlsView,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let fold = CGRect(x: 0, y: 280, width: 800, height: 40)
        var modes: [Bool] = []
        view.onLayoutModeChanged = { modes.append($0) }

        #expect(!view.isAdaptiveLayoutEnabled)
        view.layoutIfNeeded()
        view.updateLayout(divisionFrames: [fold])
        #expect(!view.isFoldedLayout)
        #expect(videoView.frame == view.bounds)
        #expect(!normalControlsView.isHidden)
        #expect(adaptiveControlsView.superview == nil)
        #expect(view.subviews.count == 2)
        #expect(!videoView.translatesAutoresizingMaskIntoConstraints)
        #expect(!normalControlsView.translatesAutoresizingMaskIntoConstraints)
        #expect(view.constraints.count == 8)
        #expect(view.constraints.allSatisfy(\.isActive))
        #expect(modes.isEmpty)

        view.isAdaptiveLayoutEnabled = true
        view.updateLayout(divisionFrames: [fold])
        #expect(view.isFoldedLayout)
        #expect(normalControlsView.isHidden)
        #expect(!adaptiveControlsView.isHidden)

        view.isAdaptiveLayoutEnabled = false
        view.layoutIfNeeded()
        view.updateLayout(divisionFrames: [fold])
        #expect(!view.isFoldedLayout)
        #expect(videoView.frame == view.bounds)
        #expect(!normalControlsView.isHidden)
        #expect(adaptiveControlsView.isHidden)
        #expect(modes == [true, false])
    }

    @Test("Disabled mode does not create adaptive controls and preserves normal visibility")
    func disabledModePreservesNormalControls() {
        let videoView = UIView()
        let normalControlsView = UIView()
        var creationCount = 0
        var modes: [Bool] = []
        let view = NCVideoAdaptiveLayoutView(
            videoView: videoView,
            normalControlsView: normalControlsView,
            adaptiveControlsView: {
                creationCount += 1
                return UIView()
            }
        )
        view.onLayoutModeChanged = { modes.append($0) }
        normalControlsView.isHidden = true
        normalControlsView.alpha = 0
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        view.layoutIfNeeded()
        view.updateLayout(divisionFrames: [CGRect(x: 0, y: 280, width: 800, height: 40)])

        #expect(creationCount == 0)
        #expect(modes.isEmpty)
        #expect(normalControlsView.isHidden)
        #expect(normalControlsView.alpha == 0)
        #expect(videoView.frame == view.bounds)
        #expect(normalControlsView.frame == view.bounds)

        normalControlsView.isHidden = false
        normalControlsView.alpha = 1
        view.frame = CGRect(x: 0, y: 0, width: 600, height: 800)
        view.layoutIfNeeded()

        #expect(creationCount == 0)
        #expect(modes.isEmpty)
        #expect(!normalControlsView.isHidden)
        #expect(normalControlsView.alpha == 1)
        #expect(videoView.frame == view.bounds)
        #expect(normalControlsView.frame == view.bounds)
    }

    @Test("Folding and unfolding preserve the video surface and controls")
    func foldingPreservesViews() {
        let videoView = UIView()
        let controlsView = UIView()
        let adaptiveControlsView = UIView()
        let view = NCVideoAdaptiveLayoutView(
            videoView: videoView,
            normalControlsView: controlsView,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.isAdaptiveLayoutEnabled = true
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        var modes: [Bool] = []
        view.onLayoutModeChanged = { modes.append($0) }

        view.updateLayout(divisionFrames: [])
        #expect(videoView.frame == view.bounds)
        #expect(controlsView.frame == view.bounds)

        let fold = CGRect(x: -10, y: 280, width: 820, height: 40)
        view.updateLayout(divisionFrames: [fold])
        #expect(view.isFoldedLayout)
        #expect(videoView.frame == CGRect(x: 0, y: 0, width: 800, height: 280))
        #expect(adaptiveControlsView.frame == CGRect(x: 0, y: 320, width: 800, height: 280))
        #expect(controlsView.isHidden)
        #expect(!adaptiveControlsView.isHidden)

        view.updateLayout(divisionFrames: [fold])
        #expect(modes == [true])

        view.updateLayout(divisionFrames: [])
        #expect(!view.isFoldedLayout)
        #expect(videoView.frame == view.bounds)
        #expect(controlsView.frame == view.bounds)
        #expect(modes == [true, false])
        #expect(!controlsView.isHidden)
        #expect(adaptiveControlsView.isHidden)
        #expect(view.subviews.count == 3)
        #expect(view.subviews[0] === videoView)
        #expect(view.subviews[1] === controlsView)
        #expect(view.subviews[2] === adaptiveControlsView)
    }

    @Test("Other regions retain the normal layout", arguments: [
        CGRect(x: 380, y: 0, width: 40, height: 600),
        CGRect(x: 0, y: 300, width: 800, height: 0),
        CGRect(x: 0, y: 700, width: 800, height: 40),
        CGRect(x: 0, y: 0, width: 800, height: 40),
        CGRect(x: 0, y: 560, width: 800, height: 40),
        CGRect(x: 200, y: 280, width: 100, height: 40)
    ])
    func ignoresNonHorizontalDivisions(frame: CGRect) {
        let videoView = UIView()
        let controlsView = UIView()
        let adaptiveControlsView = UIView()
        let view = NCVideoAdaptiveLayoutView(
            videoView: videoView,
            normalControlsView: controlsView,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.isAdaptiveLayoutEnabled = true
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)

        view.updateLayout(divisionFrames: [frame])

        #expect(!view.isFoldedLayout)
        #expect(videoView.frame == view.bounds)
        #expect(controlsView.frame == view.bounds)
    }

    @Test("The layout follows changing fold geometry and view size")
    func followsFoldGeometry() {
        let videoView = UIView()
        let controlsView = UIView()
        let adaptiveControlsView = UIView()
        let view = NCVideoAdaptiveLayoutView(
            videoView: videoView,
            normalControlsView: controlsView,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.isAdaptiveLayoutEnabled = true
        view.frame = CGRect(x: 0, y: 0, width: 600, height: 800)

        view.updateLayout(divisionFrames: [CGRect(x: 0, y: 370, width: 600, height: 60)])

        #expect(videoView.frame == CGRect(x: 0, y: 0, width: 600, height: 370))
        #expect(adaptiveControlsView.frame == CGRect(x: 0, y: 430, width: 600, height: 370))

        view.updateLayout(divisionFrames: [CGRect(x: 0, y: 350, width: 600, height: 100)])

        #expect(videoView.frame.height == 350)
        #expect(adaptiveControlsView.frame.minY == 450)
        #expect(adaptiveControlsView.frame.height == 350)
    }
}
