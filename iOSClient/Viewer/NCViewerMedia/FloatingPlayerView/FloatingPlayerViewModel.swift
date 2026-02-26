// SPDX-FileCopyrightText: STRATO GmbH
// SPDX-FileCopyrightText: 2025 Serhii Kaliberda
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Combine

@MainActor
class FloatingPlayerViewModel: ObservableObject {
    let unkonwnFileName: String = "Unknown"
    @Published var isPlaying: Bool = false
    @Published var fileName: String

    private let mediaCoordinator = NCMediaCoordinator.shared

    init() {
        fileName = mediaCoordinator.fileName
        mediaCoordinator.fileNamePublisher.assign(to: &$fileName)

        isPlaying = mediaCoordinator.isPlaying
        mediaCoordinator.isPlayingPublisher.assign(to: &$isPlaying)
    }

    func play() {
        mediaCoordinator.play()
    }

    func pause() {
        mediaCoordinator.pause()
    }

    func rewind() {
        mediaCoordinator.rewind()
    }

    func forward() {
        mediaCoordinator.forward()
    }

    func closePlayer() {
        mediaCoordinator.finishMediaSession()
    }
}
