// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// A `UIButton` whose menu is not closed by background updates.
///
/// Use it instead of `UIButton` for any button that shows a menu
/// (`menu` with `showsMenuAsPrimaryAction`, or a long press).
///
/// It does two things:
/// - It reports when its menu opens and closes to `NCMenuPresentationMonitor`,
///   so screens can hold back reloads that would destroy the button.
/// - If `menu` is replaced while the menu is open, UIKit would close it.
///   The button keeps the new menu aside and applies it once the menu has closed.
///
/// `UIButton` is the delegate of its own `UIContextMenuInteraction`; the two
/// `contextMenuInteraction` overrides below are the public `UIControl` hooks
/// for the menu lifecycle.
class NCMenuButton: UIButton {
    /// Called when the menu is about to be shown.
    var onMenuWillShow: (() -> Void)?

    /// Called after the menu has closed and any pending menu has been applied.
    var onMenuDidHide: (() -> Void)?

    /// `true` while the menu of this button is open.
    private(set) var isMenuVisible = false

    /// The menu assigned while the menu was open, applied when it closes.
    /// `.some(nil)` means "remove the menu".
    private var pendingMenu: UIMenu??

    override var menu: UIMenu? {
        get {
            super.menu
        }
        set {
            if isMenuVisible {
                pendingMenu = .some(newValue)
            } else {
                pendingMenu = nil
                super.menu = newValue
            }
        }
    }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                         willDisplayMenuFor configuration: UIContextMenuConfiguration,
                                         animator: UIContextMenuInteractionAnimating?) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)

        isMenuVisible = true
        NCMenuPresentationMonitor.shared.menuWillShow(self)
        onMenuWillShow?()
    }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                         willEndFor configuration: UIContextMenuConfiguration,
                                         animator: UIContextMenuInteractionAnimating?) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)

        // Wait for the dismiss animation, so nothing touches the menu while it is still on screen.
        if let animator {
            animator.addCompletion { [weak self] in
                self?.menuDidHide()
            }
        } else {
            menuDidHide()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        // A button removed from the screen can no longer show its menu.
        if window == nil {
            menuDidHide()
        }
    }

    private func menuDidHide() {
        guard isMenuVisible else {
            return
        }

        isMenuVisible = false

        if let pendingMenu {
            self.pendingMenu = nil
            super.menu = pendingMenu
        }

        NCMenuPresentationMonitor.shared.menuDidHide(self)
        onMenuDidHide?()
    }
}
