// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 feather2222
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// A tappable container view that dims while touched, giving immediate visual
/// feedback for the gesture-recognizer based "buttons" in the share extension
/// (upload, create folder) which previously appeared unresponsive.
final class NCHighlightableView: UIView {
    private var normalBackgroundColor: UIColor?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        setHighlighted(true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        setHighlighted(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        setHighlighted(false)
    }

    private func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            normalBackgroundColor = backgroundColor
            UIView.animate(withDuration: 0.1) {
                self.backgroundColor = UIColor.systemFill
            }
        } else {
            UIView.animate(withDuration: 0.2) {
                self.backgroundColor = self.normalBackgroundColor
            }
        }
    }
}
