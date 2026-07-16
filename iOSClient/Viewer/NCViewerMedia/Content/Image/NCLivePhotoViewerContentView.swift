// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import Photos
import PhotosUI
import NextcloudKit

// MARK: - Live Photo Viewer Content View

struct NCLivePhotoViewerContentView: View {
    let identifier: String
    let previewURL: URL?
    let fullURL: URL?
    let videoURL: URL?
    let backgroundStyle: NCViewerBackgroundStyle
    let topOverlayInset: CGFloat
    let onZoomChanged: (Bool) -> Void

    @State private var livePhoto: PHLivePhoto?
    @State private var isPlayingLivePhoto = false
    @State private var loadedTaskIdentifier: String?

    init(
        identifier: String,
        previewURL: URL?,
        fullURL: URL?,
        videoURL: URL?,
        backgroundStyle: NCViewerBackgroundStyle = .system,
        topOverlayInset: CGFloat = 0,
        onZoomChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.identifier = identifier
        self.previewURL = previewURL
        self.fullURL = fullURL
        self.videoURL = videoURL
        self.backgroundStyle = backgroundStyle
        self.topOverlayInset = topOverlayInset
        self.onZoomChanged = onZoomChanged
    }

    var body: some View {
        ZStack {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()

            stillImageView

            if isPlayingLivePhoto, let livePhoto {
                NCLivePhotoViewRepresentable(
                    livePhoto: livePhoto,
                    backgroundStyle: backgroundStyle,
                    isPlaying: $isPlayingLivePhoto
                )
                .id(playbackViewIdentifier)
                .ignoresSafeArea()
            }

            livePhotoBadge
        }
        .background(Color.ncViewerBackground(backgroundStyle))
        .task(id: taskIdentifier) {
            await loadLivePhotoIfNeeded()
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onEnded { _ in
                    guard livePhoto != nil else {
                        return
                    }

                    isPlayingLivePhoto = true
                }
        )
        // Stop Live Photo playback when the media viewer requests a global playback stop.
        .onReceive(NotificationCenter.default.publisher(for: .ncMediaViewerStopPlayback)) { _ in
            stopLivePhotoPlayback()
        }
        .onChange(of: identifier) { _, _ in
            stopLivePhotoPlayback()
        }
        .onChange(of: taskIdentifier) { _, _ in
            stopLivePhotoPlayback()
        }
        .onDisappear {
            stopLivePhotoPlayback()
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var stillImageView: some View {
        NCImageViewerContentView(
            identifier: identifier,
            previewURL: previewURL,
            fullURL: fullURL,
            backgroundStyle: backgroundStyle,
            allowsImageAnalysis: false,
            onZoomChanged: onZoomChanged
        )
    }

    private var livePhotoBadgeBackground: Color {
        switch backgroundStyle {
        case .black:
            return .gray.opacity(0.32)

        case .system,
             .white,
             .custom:
            return .white.opacity(0.72)
        }
    }

    private var livePhotoBadgeForeground: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.88)

        case .system,
             .white,
             .custom:
            return .gray
        }
    }

    private var livePhotoBadgeStroke: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.16)

        case .system,
             .white,
             .custom:
            return .gray.opacity(0.22)
        }
    }

    private var livePhotoBadge: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let topInset = isLandscape && !isPad ? max(topOverlayInset, 76) : topOverlayInset

            VStack {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "livephoto")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(livePhotoBadgeForeground)

                        Text("LIVE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(livePhotoBadgeForeground)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(livePhotoBadgeBackground)
                    .overlay(
                        Capsule()
                            .stroke(livePhotoBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                    .padding(.leading, 12)
                    .padding(.top, topInset)

                    Spacer()
                }

                Spacer()
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Identifiers

    private var taskIdentifier: String {
        "\(identifier)|\(fullURL?.absoluteString ?? "")|\(videoURL?.absoluteString ?? "")"
    }

    private var playbackViewIdentifier: String {
        "\(taskIdentifier)|playback"
    }

    // MARK: - Loading

    // Keep the still image visible when Live Photo resources are missing.
    @MainActor
    private func loadLivePhotoIfNeeded() async {
        if loadedTaskIdentifier != taskIdentifier {
            livePhoto = nil
            isPlayingLivePhoto = false
            loadedTaskIdentifier = taskIdentifier
        }

        guard livePhoto == nil else {
            return
        }

        guard let fullURL,
              let videoURL else {
            return
        }

        guard FileManager.default.fileExists(atPath: fullURL.path),
              FileManager.default.fileExists(atPath: videoURL.path) else {
            return
        }

        let resourceURLs = [
            fullURL,
            videoURL
        ]

        let loadedLivePhoto = await requestLivePhoto(resourceURLs: resourceURLs)

        guard !Task.isCancelled else {
            return
        }

        guard loadedTaskIdentifier == taskIdentifier else {
            return
        }

        guard let loadedLivePhoto else {
            return
        }

        livePhoto = loadedLivePhoto
    }

    @MainActor
    private func stopLivePhotoPlayback() {
        isPlayingLivePhoto = false
    }

    // Photos may call the handler more than once; resume only once.
    @MainActor
    private func requestLivePhoto(resourceURLs: [URL]) async -> PHLivePhoto? {
        guard resourceURLs.count >= 2 else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            final class ResumeBox {
                private var didResume = false
                private let lock = NSLock()

                func resumeOnce(
                    _ continuation: CheckedContinuation<PHLivePhoto?, Never>,
                    returning livePhoto: PHLivePhoto?
                ) {
                    lock.lock()
                    defer { lock.unlock() }

                    guard !didResume else {
                        return
                    }

                    didResume = true
                    continuation.resume(returning: livePhoto)
                }
            }

            let resumeBox = ResumeBox()

            PHLivePhoto.request(
                withResourceFileURLs: resourceURLs,
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                if let cancelled = info[PHLivePhotoInfoCancelledKey] as? Bool,
                   cancelled {
                    resumeBox.resumeOnce(
                        continuation,
                        returning: nil
                    )
                    return
                }

                if info[PHLivePhotoInfoErrorKey] != nil {
                    resumeBox.resumeOnce(
                        continuation,
                        returning: nil
                    )
                    return
                }

                let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) == true

                if isDegraded {
                    return
                }

                guard let livePhoto else {
                    return
                }

                resumeBox.resumeOnce(
                    continuation,
                    returning: livePhoto
                )
            }
        }
    }
}

// MARK: - Live Photo View Representable

private struct NCLivePhotoViewRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    let backgroundStyle: NCViewerBackgroundStyle
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()

        view.backgroundColor = .ncViewerBackground(backgroundStyle)
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.livePhoto = livePhoto
        view.isMuted = false
        view.delegate = context.coordinator

        context.coordinator.livePhotoView = view
        context.coordinator.isPlaying = $isPlaying

        DispatchQueue.main.async {
            guard context.coordinator.livePhotoView === view else {
                return
            }

            guard isPlaying else {
                return
            }

            view.startPlayback(with: .full)
        }

        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.backgroundColor = .ncViewerBackground(backgroundStyle)

        context.coordinator.livePhotoView = view
        context.coordinator.isPlaying = $isPlaying
        view.delegate = context.coordinator

        if view.livePhoto !== livePhoto {
            view.stopPlayback()
            view.livePhoto = livePhoto
        }

        if isPlaying {
            view.startPlayback(with: .full)
        } else {
            view.stopPlayback()
        }
    }

    static func dismantleUIView(
        _ view: PHLivePhotoView,
        coordinator: Coordinator
    ) {
        view.stopPlayback()
        view.delegate = nil
        view.livePhoto = nil

        coordinator.livePhotoView = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPlaying: $isPlaying)
    }

    final class Coordinator: NSObject, PHLivePhotoViewDelegate {
        weak var livePhotoView: PHLivePhotoView?
        var isPlaying: Binding<Bool>

        init(isPlaying: Binding<Bool>) {
            self.isPlaying = isPlaying
        }

        func livePhotoView(
            _ livePhotoView: PHLivePhotoView,
            didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle
        ) {
            isPlaying.wrappedValue = false
        }
    }
}
