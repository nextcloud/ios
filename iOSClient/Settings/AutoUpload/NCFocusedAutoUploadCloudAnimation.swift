// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCFocusedAutoUploadCloudAnimation: View {
    let size: CGFloat
    let cloudColor: Color
    let arrowColor: Color
    let isAnimated: Bool

    init(size: CGFloat = 176,
         cloudColor: Color = .white,
         arrowColor: Color = .black.opacity(0.82),
         isAnimated: Bool = true) {
        self.size = size
        self.cloudColor = cloudColor
        self.arrowColor = arrowColor
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
            Image(systemName: includesMotion ? "icloud.fill" : "icloud")
                .font(.system(size: size * 0.53, weight: .regular))
                .foregroundStyle(cloudColor)
                .scaleEffect(includesMotion ? interpolate(from: 0.96, to: 1.03, progress: progress) : 1)
                .offset(y: includesMotion ? interpolate(from: size * 0.03, to: -size * 0.03, progress: progress) : 0)

            Image(systemName: "arrow.up")
                .font(.system(size: includesMotion ? size * 0.17 : size * 0.22, weight: .bold))
                .foregroundStyle(arrowColor)
                .offset(y: includesMotion ? interpolate(from: -size * 0.02, to: -size * 0.09, progress: progress) : 0)
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

#Preview {
    VStack(spacing: 48) {
        NCFocusedAutoUploadCloudAnimation(size: 80)

        NCFocusedAutoUploadCloudAnimation(size: 80, isAnimated: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
