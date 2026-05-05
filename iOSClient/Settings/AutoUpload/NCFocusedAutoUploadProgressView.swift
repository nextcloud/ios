// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

@MainActor
struct NCFocusedAutoUploadProgressView: View {
    @Binding var isPresented: Bool
    @Environment(\.scenePhase) private var scenePhase

    @State private var countdownTask: Task<Void, Never>?
    @State private var secondsUntilDim = 10
    @State private var isScreenDimmed = false
    @State private var isCloudAnimating = false

    private let dimDelay = 10

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    focusedUploadAnimation
                        .padding(.bottom, 4)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 36)

                    Text(NSLocalizedString("_focused_auto_upload_backing_up_", comment: ""))
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Text(statusMessage)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Text(NSLocalizedString("_stop_focused_auto_upload_", comment: ""))
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
            isCloudAnimating = true
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
    }

    private var statusMessage: String {
        return String(format: NSLocalizedString("_focused_auto_upload_countdown_", comment: ""), secondsUntilDim)
    }

    private var focusedUploadAnimation: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)
                .frame(width: 148, height: 148)
                .scaleEffect(isCloudAnimating ? 1.08 : 0.88)
                .opacity(isCloudAnimating ? 0.1 : 0.36)

            Image(systemName: "icloud.fill")
                .font(.system(size: 94, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(isCloudAnimating ? 0.22 : 0.08), radius: 18)
                .offset(y: isCloudAnimating ? -5 : 5)

            Image(systemName: "arrow.up")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black.opacity(0.82))
                .offset(y: isCloudAnimating ? -16 : -4)
        }
        .frame(width: 176, height: 144)
        .animation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true), value: isCloudAnimating)
        .accessibilityHidden(true)
    }

    private func startFocusedMode() {
        countdownTask?.cancel()
        secondsUntilDim = dimDelay
        isScreenDimmed = false

        NCFocusedAutoUploadScreenDimmer.shared.startKeepingScreenAwake()

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
        isScreenDimmed = false
        NCFocusedAutoUploadScreenDimmer.shared.restoreScreen()
    }

    private func wakeFocusedScreen() {
        stopFocusedMode()
        startFocusedMode()
    }
}
