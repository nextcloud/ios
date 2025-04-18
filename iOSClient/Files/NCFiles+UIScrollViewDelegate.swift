// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

extension NCFiles {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentOffsetY = scrollView.contentOffset.y
        let currentTime = CACurrentMediaTime()
        let deltaY = currentOffsetY - lastOffsetY
        let deltaTime = currentTime - lastScrollTime
        let velocity = deltaTime > 0 ? deltaY / CGFloat(deltaTime) : 0

        if deltaY > 0 {
            // Scroll down → accumulate

            accumulatedScrollDown += deltaY
            if accumulatedScrollDown > 150 {             // threshold before decreasing alpha
                UIView.animate(withDuration: 0.2) {
                    self.plusButton.alpha = max(0.4, self.plusButton.alpha - 0.02)
                }
            }
        } else if deltaY < 0 {
            // Scroll up → reset and maybe increase alpha

            accumulatedScrollDown = 0
            if abs(velocity) > 700 {                    // speed before increasing alpha
                UIView.animate(withDuration: 0.2) {
                    self.plusButton.alpha = min(1.0, self.plusButton.alpha + 0.1)
                }
            }
        }

        lastOffsetY = currentOffsetY
        lastScrollTime = currentTime
    }
}
