//
//  FloatingPlayerViewPresenter.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 05.09.2025.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Combine

class FloatingPlayerViewPresenter {
    static let shared = FloatingPlayerViewPresenter()

    private var floatingWindow: UIWindow?
    private var hostingController: UIHostingController<FloatingPlayerView>?
    private(set) var currentPosition: CGPoint = .zero

    private let windowLevel: UIWindow.Level = .alert + 1

    private let fullViewSize = CGSize(width: 350, height: 115)
    private let compactViewSize = CGSize(width: 50, height: 50)
    private let initialYOffset: CGFloat = 100
    private let initialXOffset: CGFloat = 20

    private var cancellables: Set<AnyCancellable> = []

    private var isCurrentItemSet: Bool = false {
        didSet {
            updateFloatingViewVisibility()
        }
    }
    var isMediaScreenVisible: Bool = false {
        didSet {
            updateFloatingViewVisibility()
        }
    }

    init() {
        NCMediaCoordinator
            .shared
            .metadataSwitchPublisher
            .sink { [weak self] _, newItem in
                self?.isCurrentItemSet = newItem != nil
            }
            .store(in: &cancellables)
    }

    private func updateFloatingViewVisibility() {
        setFloatingView(visible: isCurrentItemSet && !isMediaScreenVisible)
    }

    private func setFloatingView(visible: Bool) {
        if visible && floatingWindow == nil {
            createFloatingWindow()
        } else if !visible && floatingWindow != nil {
            destroyFloatingWindow()
        }
    }

    private func createFloatingWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene else {
            return
        }

        floatingWindow = UIWindow(windowScene: windowScene)
        floatingWindow?.windowLevel = windowLevel
        floatingWindow?.backgroundColor = .clear
        floatingWindow?.isHidden = false

        hostingController = UIHostingController(rootView: FloatingPlayerView())
        hostingController?.view.backgroundColor = .clear

        let screenBounds = screenBounds()
        let initialY = screenBounds.height - initialYOffset
        currentPosition = CGPoint(x: initialXOffset, y: initialY)

        floatingWindow?.frame = CGRect(origin: currentPosition, size: compactViewSize)
        hostingController?.view.frame = CGRect(origin: .zero, size: compactViewSize)
        floatingWindow?.rootViewController = hostingController
    }

    private func destroyFloatingWindow() {
        floatingWindow?.isHidden = true
        floatingWindow = nil
        hostingController = nil
    }

    func updatePosition(_ newPosition: CGPoint) {
        let constrainedPosition = constrainToScreenBounds(newPosition)
        currentPosition = constrainedPosition
        floatingWindow?.frame.origin = constrainedPosition
    }

    private func constrainToScreenBounds(_ position: CGPoint) -> CGPoint {
        let screenBounds = screenBounds()
        let currentSize = floatingWindow?.frame.size ?? compactViewSize

        let minX: CGFloat = 0
        let maxX = screenBounds.width - currentSize.width
        let minY: CGFloat = 0
        let maxY = screenBounds.height - currentSize.height

        let constrainedX = max(minX, min(maxX, position.x))
        let constrainedY = max(minY, min(maxY, position.y))

        return CGPoint(x: constrainedX, y: constrainedY)
    }

    func updateSize(_ isCompact: Bool) {
        let newSize = isCompact ? compactViewSize : fullViewSize
        floatingWindow?.frame.size = newSize
        hostingController?.view.frame.size = newSize

        let newOrigin = self.newOrigin(for: isCompact)
        updatePosition(newOrigin)
    }

    private func newOrigin(for compact: Bool) -> CGPoint {
        if compact {
            return CGPoint(
                x: currentPosition.x,
                y: currentPosition.y + (fullViewSize.height - compactViewSize.height)
            )
        } else {
            return CGPoint(
                x: currentPosition.x,
                y: currentPosition.y - (fullViewSize.height - compactViewSize.height)
            )
        }
    }

    private func screenBounds() -> CGRect {
        return floatingWindow?.windowScene?.screen.bounds ?? UIScreen.main.bounds
    }

}
