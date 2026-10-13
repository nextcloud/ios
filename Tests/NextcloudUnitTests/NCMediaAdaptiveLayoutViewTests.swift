// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
import NextcloudKit
@testable import Nextcloud

@Suite("Adaptive media layout")
@MainActor
struct NCMediaAdaptiveLayoutViewTests {
    @Test("Adaptive controls share playback state without adding a navigation bar")
    func separateAdaptiveControls() throws {
        let normalControls = NCVideoControlsView()
        let adaptiveControls = NCVideoAdaptiveControlsView(state: normalControls.state)
        adaptiveControls.configureAdaptiveActions(closeAction: UIAction { _ in }, moreButton: UIButton(type: .system))
        #expect(adaptiveControls.actionsContainerView.superview === adaptiveControls)
        #expect(!adaptiveControls.subviews.contains { $0 is UINavigationBar })
        #expect(!normalControls.subviews.contains { $0 is UINavigationBar })

        normalControls.updateProgress(progress: 0.5, elapsedText: "1:00", remainingText: "−1:00")
        adaptiveControls.updatePlaybackOptions(isRepeatEnabled: true, isAutoAdvanceEnabled: true)
        #expect(adaptiveControls.state.progress == 0.5)
        #expect(normalControls.state.isRepeatEnabled)
        #expect(normalControls.state.isAutoAdvanceEnabled)
        #expect(normalControls.state === adaptiveControls.state)
    }

    @Test("Standalone adaptive buttons preserve Close and Info actions")
    func adaptiveButtonsInvokeActions() throws {
        var closed = false
        var informationRequested = false
        let moreButton = UIButton(type: .system)
        let actions = NCMediaAdaptiveActionsView(
            closeAction: UIAction { _ in closed = true },
            moreButton: moreButton,
            infoAction: UIAction { _ in informationRequested = true }
        )
        let closeButton = try #require(actions.arrangedSubviews.first as? UIButton)
        let informationButton = try #require(actions.informationButton)
        closeButton.sendActions(for: .touchUpInside)
        informationButton.sendActions(for: .touchUpInside)
        #expect(closed)
        #expect(informationRequested)
        #expect(actions.arrangedSubviews.last === moreButton)
        #expect(!actions.arrangedSubviews.contains { $0 is UINavigationBar })
    }

    @Test("Reused or neighboring video covers cannot remove the selected cover actions")
    func videoCoverActionsKeepTheirOwner() throws {
        let state = NCMediaAdaptiveControlsState()
        let oldOwner = UUID()
        let currentOwner = UUID()
        let neighborOwner = UUID()
        var played: [String] = []
        var cancelled = false
        let oldControls = NCVideoPlaybackCoverPresentation(
            isPlayEnabled: true,
            isLoading: false,
            isLaunchingPlayback: false,
            statusMessage: nil,
            onCancel: nil,
            onPlay: { played.append("old") }
        )
        let currentControls = NCVideoPlaybackCoverPresentation(
            isPlayEnabled: false,
            isLoading: true,
            isLaunchingPlayback: false,
            statusMessage: "Downloading",
            onCancel: { cancelled = true },
            onPlay: { played.append("current") }
        )
        state.setVideoCoverControls(oldControls, for: "selected", owner: oldOwner)
        state.setVideoCoverControls(currentControls, for: "selected", owner: currentOwner)
        state.setVideoCoverControls(oldControls, for: "neighbor", owner: neighborOwner)
        state.removeVideoCoverControls(for: "selected", owner: oldOwner)
        state.removeVideoCoverControls(for: "neighbor", owner: neighborOwner)

        let controls = try #require(state.videoCoverControls(for: "selected"))
        #expect(controls.isLoading)
        #expect(!controls.isPlayEnabled)
        #expect(controls.statusMessage == "Downloading")
        controls.onPlay()
        controls.onCancel?()
        #expect(played == ["current"])
        #expect(cancelled)
        #expect(state.videoCoverControls(for: "neighbor") == nil)

        state.removeVideoCoverControls(for: "selected", owner: currentOwner)
        #expect(state.videoCoverControls(for: "selected") == nil)
    }

    @Test("Image folding retains the paging host and uses independent controls")
    func imageFoldingPreservesPagingHost() throws {
        let metadata = tableMetadata()
        metadata.ocId = "image"
        metadata.classFile = NKTypeClassFile.image.rawValue
        let model = NCMediaViewerModel(
            currentMetadata: metadata,
            ocIds: [metadata.ocId],
            session: NCSession().getSession(account: ""),
            loader: NCMediaViewerLoader()
        )
        let state = NCMediaAdaptiveControlsState()
        let controller = NCMediaAdaptiveLayoutController(
            mediaView: NCMediaViewerPagingView(
                model: model,
                contextMenuController: nil,
                navigationBar: nil,
                onVisibleMetadataChanged: { _, _ in },
                onZoomChanged: { _ in },
                onClose: { _ in }
            ),
            normalControlsView: NCImageControlsView(model: model),
            adaptiveControlsView: NCMediaAdaptiveControlsView(
                model: model,
                state: state,
                makeActionsView: { UIView() }
            ),
            onLayoutModeChanged: { _ in }
        )
        controller.loadViewIfNeeded()
        let view = controller.layoutView
        view.isLayoutEnabled = false
        let mediaView = try #require(controller.mediaController.view)
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        view.layoutIfNeeded()
        #expect(!view.isLayoutEnabled)
        #expect(controller.adaptiveControlsController == nil)

        view.isLayoutEnabled = true
        view.updateLayout(divisionFrames: [CGRect(x: 0, y: 280, width: 800, height: 40)])
        let adaptiveController = try #require(controller.adaptiveControlsController)
        #expect(adaptiveController.rootView.state === state)
        #expect(adaptiveController.parent === controller)
        #expect(mediaView.frame.height == 280)
        #expect(controller.normalControlsController.view.superview?.isHidden == true)

        // Updating the lower presentation must reach the retained host, not create a new one.
        let updatedState = NCMediaAdaptiveControlsState()
        controller.adaptiveControlsView = NCMediaAdaptiveControlsView(
            model: model,
            state: updatedState,
            makeActionsView: { UIView() }
        )
        #expect(adaptiveController.rootView.state === updatedState)
        #expect(controller.adaptiveControlsController === adaptiveController)

        view.updateLayout(divisionFrames: [])
        #expect(controller.mediaController.view === mediaView)
        #expect(mediaView.frame == view.bounds)
        #expect(controller.adaptiveControlsController === adaptiveController)
        #expect(adaptiveController.view.isHidden)
        #expect(controller.normalControlsController.view.superview?.isHidden == false)
    }

    @Test("A disabled container can be enabled and turned off again")
    func experimentalLayoutRequiresEnabling() {
        let videoView = UIView()
        let normalControlsView = UIView()
        let adaptiveControlsView = UIView()
        let view = NCMediaAdaptiveLayoutView(
            mediaView: videoView,
            normalControlsView: normalControlsView,
            isLayoutEnabled: false,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let fold = CGRect(x: 0, y: 280, width: 800, height: 40)
        var modes: [Bool] = []
        view.onLayoutModeChanged = { modes.append($0) }

        #expect(!view.isLayoutEnabled)
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

        view.isLayoutEnabled = true
        view.updateLayout(divisionFrames: [fold])
        #expect(view.isFoldedLayout)
        #expect(normalControlsView.isHidden)
        #expect(!adaptiveControlsView.isHidden)

        view.isLayoutEnabled = false
        view.layoutIfNeeded()
        view.updateLayout(divisionFrames: [fold])
        #expect(!view.isFoldedLayout)
        #expect(videoView.frame == view.bounds)
        #expect(!normalControlsView.isHidden)
        #expect(adaptiveControlsView.isHidden)
        #expect(modes == [true, false])
    }

    @Test("A container can start enabled without activating normal layout constraints")
    func startsWithAdaptiveLayoutEnabled() {
        let mediaView = UIView()
        let normalControlsView = UIView()
        let adaptiveControlsView = UIView()
        let view = NCMediaAdaptiveLayoutView(
            mediaView: mediaView,
            normalControlsView: normalControlsView,
            isLayoutEnabled: true,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        #expect(mediaView.translatesAutoresizingMaskIntoConstraints)
        #expect(normalControlsView.translatesAutoresizingMaskIntoConstraints)
        #expect(view.constraints.isEmpty)

        view.updateLayout(divisionFrames: [CGRect(x: 0, y: 280, width: 800, height: 40)])
        #expect(view.isFoldedLayout)
        #expect(mediaView.frame.height == 280)
        #expect(adaptiveControlsView.frame.minY == 320)

        view.isLayoutEnabled = false
        view.layoutIfNeeded()
        #expect(view.constraints.count == 8)
        #expect(view.constraints.allSatisfy(\.isActive))
        #expect(!view.isFoldedLayout)
        #expect(mediaView.frame == view.bounds)
    }

    @Test("Disabled mode does not create adaptive controls and preserves normal visibility")
    func disabledModePreservesNormalControls() {
        let videoView = UIView()
        let normalControlsView = UIView()
        var creationCount = 0
        var modes: [Bool] = []
        let view = NCMediaAdaptiveLayoutView(
            mediaView: videoView,
            normalControlsView: normalControlsView,
            isLayoutEnabled: false,
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
        let view = NCMediaAdaptiveLayoutView(
            mediaView: videoView,
            normalControlsView: controlsView,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.isLayoutEnabled = true
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

    @Test("An enabled experiment creates lower controls only when a fold becomes active")
    func unfoldedExperimentDoesNotCreateLowerControls() {
        var creationCount = 0
        let lowerControls = UIView()
        let normalControls = UIView()
        let view = NCMediaAdaptiveLayoutView(
            mediaView: UIView(),
            normalControlsView: normalControls,
            isLayoutEnabled: true,
            adaptiveControlsView: {
                creationCount += 1
                return lowerControls
            }
        )
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        view.updateLayout(divisionFrames: [])
        view.updateLayout(divisionFrames: [CGRect(x: 380, y: 0, width: 40, height: 600)])
        #expect(creationCount == 0)
        #expect(!normalControls.isHidden)

        let fold = CGRect(x: 0, y: 280, width: 800, height: 40)
        view.updateLayout(divisionFrames: [fold])
        view.updateLayout(divisionFrames: [])
        view.updateLayout(divisionFrames: [fold])
        #expect(creationCount == 1)
        #expect(view.isFoldedLayout)
        #expect(lowerControls.superview === view)
    }

    @Test("Enabled mode without a fold preserves normal chrome while resizing", arguments: [
        CGSize(width: 390, height: 844),
        CGSize(width: 844, height: 390),
        CGSize(width: 1024, height: 1366),
        CGSize(width: 420, height: 600)
    ])
    func resizingWithoutFoldPreservesNormalChrome(size: CGSize) {
        let mediaView = UIView()
        let normalControls = UIView()
        normalControls.isHidden = true
        var creationCount = 0
        var modes: [Bool] = []
        let view = NCMediaAdaptiveLayoutView(
            mediaView: mediaView,
            normalControlsView: normalControls,
            isLayoutEnabled: true,
            adaptiveControlsView: {
                creationCount += 1
                return UIView()
            }
        )
        view.onLayoutModeChanged = { modes.append($0) }

        for boundsSize in [CGSize(width: 800, height: 600), size, CGSize(width: 800, height: 600)] {
            view.frame = CGRect(origin: .zero, size: boundsSize)
            view.updateLayout(divisionFrames: [])
            #expect(mediaView.frame == view.bounds)
            #expect(normalControls.frame == view.bounds)
            #expect(normalControls.isHidden)
            #expect(!view.isFoldedLayout)
        }

        #expect(creationCount == 0)
        #expect(modes.isEmpty)
        #expect(mediaView.superview === view)
        #expect(normalControls.superview === view)
    }

    @Test("Unavailable adaptive controls preserve the normal layout and can recover")
    func unavailableLowerControlsKeepNormalLayout() {
        let mediaView = UIView()
        let normalControls = UIView()
        let lowerControls = UIView()
        var available = false
        var modes: [Bool] = []
        let view = NCMediaAdaptiveLayoutView(
            mediaView: mediaView,
            normalControlsView: normalControls,
            isLayoutEnabled: true,
            adaptiveControlsView: { available ? lowerControls : nil }
        )
        view.onLayoutModeChanged = { modes.append($0) }
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let fold = CGRect(x: 0, y: 280, width: 800, height: 40)
        view.updateLayout(divisionFrames: [fold])
        #expect(!view.isFoldedLayout)
        #expect(mediaView.frame == view.bounds)
        #expect(!normalControls.isHidden)
        #expect(modes.isEmpty)

        available = true
        view.updateLayout(divisionFrames: [fold])
        #expect(view.isFoldedLayout)
        #expect(mediaView.frame.height == 280)
        #expect(!lowerControls.isHidden)
        #expect(normalControls.isHidden)
        #expect(modes == [true])
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
        let view = NCMediaAdaptiveLayoutView(
            mediaView: videoView,
            normalControlsView: controlsView,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.isLayoutEnabled = true
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
        let view = NCMediaAdaptiveLayoutView(
            mediaView: videoView,
            normalControlsView: controlsView,
            adaptiveControlsView: { adaptiveControlsView }
        )
        view.isLayoutEnabled = true
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
