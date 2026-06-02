// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCFocusedAutoUploadProgressView: View {
    @Binding var isPresented: Bool
    @Environment(\.scenePhase) private var scenePhase

    let account: String
    let urlBase: String
    let userId: String

    @State private var countdownTask: Task<Void, Never>?
    @State private var isUploadCompleted = false
    @State private var secondsUntilDim = 10
    @State private var isScreenDimmed = false
    @Environment(NCAutoUploadCounter.self) private var autoUploadCounter

    private let dimDelay = 10

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    NCFocusedAutoUploadCloudAnimation()
                        .padding(.bottom, 4)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 36)

                    VStack(spacing: 6) {
                        Text(isUploadCompleted
                             ? NSLocalizedString("_focused_auto_upload_completed_", comment: "")
                             : NSLocalizedString("_focused_auto_upload_backing_up_", comment: ""))
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if autoUploadCounter.isLoaded && !isUploadCompleted {
                            Text(uploadCountMessage)
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }

                        if autoUploadCounter.failedCount > 0 {
                            Text(autoUploadCounter.failedMessage)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                Spacer()

                if !isUploadCompleted {
                    Text(statusMessage)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Text(isUploadCompleted
                         ? NSLocalizedString("_finish_", comment: "")
                         : NSLocalizedString("_stop_focused_auto_upload_", comment: ""))
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background(
                    Capsule()
                        .fill(Color(UIColor.darkGray))
                )
                .padding(.horizontal, 54)
                .padding(.bottom, 34)
            }

            if isScreenDimmed {
                Color.black
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        wakeFocusedScreen()
                    }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(isScreenDimmed)
        .onAppear {
            startFocusedMode()
        }
        .onDisappear {
            stopFocusedMode()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                startFocusedMode()
            } else {
                stopFocusedMode()
            }
        }
        .onChange(of: autoUploadCounter.count) {
            updateFocusedCompletionState()
        }
        .onChange(of: autoUploadCounter.isLoaded) {
            updateFocusedCompletionState()
        }
    }

    private var statusMessage: String {
        return String(format: NSLocalizedString("_focused_auto_upload_countdown_", comment: ""), secondsUntilDim)
    }

    private var uploadCountMessage: String {
        return autoUploadCounter.photosToBackUpMessage
    }

    private func startFocusedMode() {
        guard !isUploadCompleted else {
            return
        }

        countdownTask?.cancel()
        secondsUntilDim = dimDelay
        isScreenDimmed = false

        NCFocusedAutoUploadScreenDimmer.shared.startKeepingScreenAwake()
        updateAutoUploadCounterSubscription()

        countdownTask = Task { @MainActor in
            while secondsUntilDim > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsUntilDim -= 1
            }

            NCFocusedAutoUploadScreenDimmer.shared.dimScreen()
            isScreenDimmed = true
        }
    }

    private func stopFocusedMode() {
        countdownTask?.cancel()
        countdownTask = nil
        stopAutoUploadCounterSubscription()
        isScreenDimmed = false
        NCFocusedAutoUploadScreenDimmer.shared.restoreScreen()
    }

    private func wakeFocusedScreen() {
        stopFocusedMode()
        startFocusedMode()
    }

    private func updateAutoUploadCounterSubscription() {
        autoUploadCounter.start(account: account,
                                urlBase: urlBase,
                                userId: userId,
                                autoUploadStart: true)
        updateFocusedCompletionState()
    }

    private func stopAutoUploadCounterSubscription() {
        autoUploadCounter.stop()
    }

    private func updateFocusedCompletionState() {
        guard autoUploadCounter.isLoaded,
              autoUploadCounter.count == 0 else {
            return
        }

        completeFocusedUpload()
    }

    private func completeFocusedUpload() {
        guard !isUploadCompleted else {
            return
        }

        isUploadCompleted = true
        countdownTask?.cancel()
        countdownTask = nil
        stopAutoUploadCounterSubscription()

        if !isScreenDimmed {
            NCFocusedAutoUploadScreenDimmer.shared.restoreScreen()
        }
    }
}
