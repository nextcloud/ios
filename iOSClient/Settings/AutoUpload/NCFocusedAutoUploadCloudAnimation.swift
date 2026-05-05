// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCFocusedAutoUploadCloudAnimation: View {
    let size: CGFloat
    let cloudColor: Color
    let arrowColor: Color
    let ringColor: Color
    let showsRing: Bool
    let isAnimated: Bool

    init(size: CGFloat = 176,
         cloudColor: Color = .white,
         arrowColor: Color = .black.opacity(0.82),
         ringColor: Color = .white,
         showsRing: Bool = true,
         isAnimated: Bool = true) {
        self.size = size
        self.cloudColor = cloudColor
        self.arrowColor = arrowColor
        self.ringColor = ringColor
        self.showsRing = showsRing
        self.isAnimated = isAnimated
    }

    var body: some View {
        if isAnimated {
            animatedCloud
        } else {
            staticCloud
        }
    }

    private var animatedCloud: some View {
        TimelineView(.animation) { timeline in
            cloud(progress: animationProgress(at: timeline.date), includesMotion: true)
        }
        .frame(width: size, height: size * 0.82)
        .accessibilityHidden(true)
    }

    private var staticCloud: some View {
        cloud(progress: 0, includesMotion: false)
            .frame(width: size, height: size * 0.82)
            .accessibilityHidden(true)
    }

    private func cloud(progress: Double, includesMotion: Bool) -> some View {
        ZStack {
            if showsRing {
                Circle()
                    .stroke(ringColor.opacity(0.75), lineWidth: max(2, size * 0.018))
                    .frame(width: size * 0.84, height: size * 0.84)
                    .scaleEffect(interpolate(from: 0.88, to: 1.08, progress: progress))
                    .opacity(interpolate(from: 0.85, to: 0.45, progress: progress))
            }

            Image(systemName: "icloud.fill")
                .font(.system(size: size * 0.53, weight: .regular))
                .foregroundStyle(cloudColor)
                .shadow(color: ringColor.opacity(includesMotion ? interpolate(from: 0.12, to: 0.28, progress: progress) : 0),
                        radius: includesMotion && showsRing ? size * 0.1 : 0)
                .offset(y: includesMotion ? interpolate(from: size * 0.03, to: -size * 0.03, progress: progress) : 0)

            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.17, weight: .bold))
                .foregroundStyle(arrowColor)
                .offset(y: includesMotion ? interpolate(from: -size * 0.02, to: -size * 0.09, progress: progress) : -size * 0.055)
        }
    }

    private func animationProgress(at date: Date) -> Double {
        let duration = 1.45
        let cycleDuration = duration * 2
        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
        let linearProgress = elapsed <= duration ? elapsed / duration : (cycleDuration - elapsed) / duration

        return (1 - cos(linearProgress * .pi)) / 2
    }

    private func interpolate(from start: CGFloat, to end: CGFloat, progress: Double) -> CGFloat {
        start + (end - start) * CGFloat(progress)
    }
}
