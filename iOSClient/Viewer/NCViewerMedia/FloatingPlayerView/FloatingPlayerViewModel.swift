//
//  FloatingPlayerViewModel.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 23.07.2025.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

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
