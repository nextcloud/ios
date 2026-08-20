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
    private final class ZoomStateStore {
        var value: NCImageZoomView.ZoomState?

        init(_ value: NCImageZoomView.ZoomState?) {
            self.value = value
        }
    }

    let identifier: String
    let previewURL: URL?
    let fullURL: URL?
    let videoURL: URL?
    let backgroundStyle: NCViewerBackgroundStyle
    let topOverlayInset: CGFloat
    let initialZoomState: NCImageZoomView.ZoomState?
    let onZoomChanged: (Bool) -> Void
    let onZoomStateChanged: (NCImageZoomView.ZoomState?) -> Void
    let requestResources: @MainActor () async -> (imageURL: URL, videoURL: URL)?
    let cancelResourceDownload: @MainActor () -> Void

    @State private var livePhoto: PHLivePhoto?
    @State private var isPlayingLivePhoto = false
    @State private var isPlaybackRequested = false
    @State private var isLoadingResources = false
    @State private var resourceLoadingTask: Task<Void, Never>?
    @State private var loadedTaskIdentifier: String?
    @State private var zoomStateStore: ZoomStateStore
    @State private var playbackZoomState: NCImageZoomView.ZoomState?

    init(
        identifier: String,
        previewURL: URL?,
        fullURL: URL?,
        videoURL: URL?,
        backgroundStyle: NCViewerBackgroundStyle = .system,
        topOverlayInset: CGFloat = 0,
        initialZoomState: NCImageZoomView.ZoomState? = nil,
        onZoomChanged: @escaping (Bool) -> Void = { _ in },
        onZoomStateChanged: @escaping (NCImageZoomView.ZoomState?) -> Void = { _ in },
        requestResources: @escaping @MainActor () async -> (imageURL: URL, videoURL: URL)? = { nil },
        cancelResourceDownload: @escaping @MainActor () -> Void = { }
    ) {
        self.identifier = identifier
        self.previewURL = previewURL
        self.fullURL = fullURL
        self.videoURL = videoURL
        self.backgroundStyle = backgroundStyle
        self.topOverlayInset = topOverlayInset
        self.initialZoomState = initialZoomState
        self.onZoomChanged = onZoomChanged
        self.onZoomStateChanged = onZoomStateChanged
        self.requestResources = requestResources
        self.cancelResourceDownload = cancelResourceDownload
        self._zoomStateStore = State(initialValue: ZoomStateStore(initialZoomState))
        self._playbackZoomState = State(initialValue: nil)
    }

    var body: some View {
        ZStack {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()

            stillImageView

            if isPlayingLivePhoto, let livePhoto {
                GeometryReader { proxy in
                    let layout = NCLivePhotoPlaybackLayout(
                        containerSize: proxy.size,
                        photoSize: livePhoto.size,
                        zoomState: playbackZoomState
                    )

                    NCLivePhotoViewRepresentable(
                        livePhoto: livePhoto,
                        backgroundStyle: backgroundStyle,
                        isPlaying: $isPlayingLivePhoto
                    )
                    .frame(
                        width: layout.frame.width,
                        height: layout.frame.height
                    )
                    .position(
                        x: layout.frame.midX,
                        y: layout.frame.midY
                    )
                }
                .clipped()
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
                    requestLivePhotoPlayback()
                }
        )
        // Stop Live Photo playback when the media viewer requests a global playback stop.
        .onReceive(NotificationCenter.default.publisher(for: .ncMediaViewerStopPlayback)) { _ in
            stopLivePhotoPlayback()
        }
        .onChange(of: identifier) { _, _ in
            cancelResourceLoadingIfNeeded()
            stopLivePhotoPlayback()
            zoomStateStore.value = initialZoomState
        }
        .onChange(of: taskIdentifier) { _, _ in
            stopLivePhotoPlayback()
        }
        .onChange(of: isPlayingLivePhoto) { _, isPlaying in
            if !isPlaying {
                playbackZoomState = nil
            }
        }
        .onDisappear {
            cancelResourceLoadingIfNeeded()
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
            initialZoomState: zoomStateStore.value,
            onZoomChanged: onZoomChanged,
            onZoomStateChanged: { updatedZoomState in
                zoomStateStore.value = updatedZoomState
                onZoomStateChanged(updatedZoomState)
            }
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
                        if isLoadingResources {
                            ProgressView()
                                .controlSize(.small)
                                .tint(livePhotoBadgeForeground)
                        } else {
                            Image(systemName: "livephoto")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(livePhotoBadgeForeground)
                        }

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
        resourceIdentifier(
            imageURL: fullURL,
            videoURL: videoURL
        )
    }

    private var playbackViewIdentifier: String {
        "\(taskIdentifier)|playback"
    }

    // MARK: - Loading

    // Keep the still image visible when Live Photo resources are missing.
    @MainActor
    private func loadLivePhotoIfNeeded() async {
        guard !isLoadingResources else {
            return
        }

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

        isLoadingResources = true
        defer {
            isLoadingResources = false
        }

        await loadLivePhoto(
            imageURL: fullURL,
            videoURL: videoURL
        )
    }

    @MainActor
    private func requestLivePhotoPlayback() {
        isPlaybackRequested = true

        if livePhoto != nil {
            isPlaybackRequested = false
            startLivePhotoPlayback()
            return
        }

        guard !isLoadingResources else {
            return
        }

        isLoadingResources = true

        resourceLoadingTask = Task { @MainActor in
            defer {
                isLoadingResources = false
                resourceLoadingTask = nil
            }

            let resourceURLs: (imageURL: URL, videoURL: URL)?

            if let fullURL,
               let videoURL {
                resourceURLs = (fullURL, videoURL)
            } else {
                resourceURLs = await requestResources()
            }

            guard !Task.isCancelled,
                  let resourceURLs else {
                isPlaybackRequested = false
                return
            }

            await loadLivePhoto(
                imageURL: resourceURLs.imageURL,
                videoURL: resourceURLs.videoURL
            )
        }
    }

    @MainActor
    private func loadLivePhoto(
        imageURL: URL,
        videoURL: URL
    ) async {
        let expectedIdentifier = resourceIdentifier(
            imageURL: imageURL,
            videoURL: videoURL
        )

        if loadedTaskIdentifier != expectedIdentifier {
            livePhoto = nil
            isPlayingLivePhoto = false
            loadedTaskIdentifier = expectedIdentifier
        }

        guard livePhoto == nil else {
            if isPlaybackRequested {
                isPlaybackRequested = false
                startLivePhotoPlayback()
            }
            return
        }

        guard FileManager.default.fileExists(atPath: imageURL.path),
              FileManager.default.fileExists(atPath: videoURL.path) else {
            isPlaybackRequested = false
            return
        }

        let resourceURLs = [
            imageURL,
            videoURL
        ]

        let loadedLivePhoto = await requestLivePhoto(resourceURLs: resourceURLs)

        guard !Task.isCancelled else {
            return
        }

        guard loadedTaskIdentifier == expectedIdentifier else {
            return
        }

        guard let loadedLivePhoto else {
            isPlaybackRequested = false
            return
        }

        livePhoto = loadedLivePhoto

        if isPlaybackRequested {
            isPlaybackRequested = false
            startLivePhotoPlayback()
        }
    }

    private func resourceIdentifier(
        imageURL: URL?,
        videoURL: URL?
    ) -> String {
        "\(identifier)|\(imageURL?.absoluteString ?? "")|\(videoURL?.absoluteString ?? "")"
    }

    @MainActor
    private func cancelResourceLoadingIfNeeded() {
        guard let resourceLoadingTask else {
            return
        }

        resourceLoadingTask.cancel()
        self.resourceLoadingTask = nil
        isLoadingResources = false
        isPlaybackRequested = false
        cancelResourceDownload()
    }

    @MainActor
    private func startLivePhotoPlayback() {
        playbackZoomState = zoomStateStore.value
        isPlayingLivePhoto = true
    }

    @MainActor
    private func stopLivePhotoPlayback() {
        isPlaybackRequested = false
        isPlayingLivePhoto = false
        playbackZoomState = nil
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

// MARK: - Live Photo Playback Layout

struct NCLivePhotoPlaybackLayout {
    let frame: CGRect

    init(
        containerSize: CGSize,
        photoSize: CGSize,
        zoomState: NCImageZoomView.ZoomState?
    ) {
        guard containerSize.width > 0,
              containerSize.height > 0,
              photoSize.width > 0,
              photoSize.height > 0 else {
            self.frame = CGRect(origin: .zero, size: containerSize)
            return
        }

        let fitScale = min(
            containerSize.width / photoSize.width,
            containerSize.height / photoSize.height
        )
        let zoomScale = min(
            max(
                zoomState?.zoomScale ?? NCImageZoomView.supportedZoomScaleRange.lowerBound,
                NCImageZoomView.supportedZoomScaleRange.lowerBound
            ),
            NCImageZoomView.supportedZoomScaleRange.upperBound
        )
        let contentSize = CGSize(
            width: photoSize.width * fitScale * zoomScale,
            height: photoSize.height * fitScale * zoomScale
        )
        let normalizedCenter = zoomState?.normalizedCenter ?? CGPoint(x: 0.5, y: 0.5)

        self.frame = CGRect(
            origin: CGPoint(
                x: Self.contentOrigin(
                    containerLength: containerSize.width,
                    contentLength: contentSize.width,
                    normalizedCenter: normalizedCenter.x
                ),
                y: Self.contentOrigin(
                    containerLength: containerSize.height,
                    contentLength: contentSize.height,
                    normalizedCenter: normalizedCenter.y
                )
            ),
            size: contentSize
        )
    }

    private static func contentOrigin(
        containerLength: CGFloat,
        contentLength: CGFloat,
        normalizedCenter: CGFloat
    ) -> CGFloat {
        guard contentLength > containerLength else {
            return (containerLength - contentLength) * 0.5
        }

        let clampedCenter = min(max(normalizedCenter, 0), 1)
        let proposedOrigin = containerLength * 0.5 - contentLength * clampedCenter

        return min(max(proposedOrigin, containerLength - contentLength), 0)
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
