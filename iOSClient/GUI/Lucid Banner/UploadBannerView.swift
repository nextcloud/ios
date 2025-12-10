// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct UploadBannerView: View {
    @ObservedObject var state: LucidBannerState
    @State var trigger = true
    let onButtonTap: (() -> Void)?
    let allowMinimizeOnTap: Bool

    init(state: LucidBannerState,
         allowMinimizeOnTap: Bool = false,
         onButtonTap: (() -> Void)? = nil) {
        self.state = state
        self.allowMinimizeOnTap = allowMinimizeOnTap
        self.onButtonTap = onButtonTap
    }

    var body: some View {
        let showTitle = !(state.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        let isSuccess = (state.typedStage == .success)
        let isError = (state.typedStage == .error)
        let isButton = (state.typedStage == .init(rawValue: "button"))

        containerView(state: state) {
            if state.isMinimized {
                Image(systemName: state.systemImage ?? "arrow.up.circle")
                    .font(.title3)
                if let p = state.progress {
                    Text("\(Int(p * 100))%")
                        .font(.footnote.monospacedDigit())
                }
            } else if isSuccess {
                 HStack(alignment: .center, spacing: 10) {
                     if #available(iOS 26, *) {
                         Image(systemName: "checkmark")
                             .font(.system(size: 60, weight: .regular))
                             .foregroundStyle(.green)
                             .symbolEffect(.drawOn, isActive: trigger)
                             .task {
                                 try? await Task.sleep(for: .seconds(0.1))
                                 trigger = false
                             }
                     } else {
                         Image(systemName: "checkmark")
                             .font(.system(size: 80, weight: .regular))
                             .foregroundStyle(.green)
                     }
                 }
                 .padding(.horizontal, 20)
                 .padding(.vertical, 20)
            } else if isError {
                VStack(spacing: 15) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("_error_")
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.9)
                                .foregroundStyle(.primary)
                            if showSubtitle, let subtitle = state.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 15) {
                    HStack(alignment: .center, spacing: 10) {
                        if let systemImage = state.systemImage {
                            Image(systemName: systemImage)
                                .applyBannerAnimation(state.imageAnimation)
                                .font(.system(size: 30, weight: .regular))
                                .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            if showTitle, let title = state.title {
                                Text(title)
                                    .font(.subheadline.weight(.bold))
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.9)
                                    .foregroundStyle(.primary)
                            }
                            if showSubtitle, let subtitle = state.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                            }
                            if showFootnote, let footnote = state.footnote {
                                Text(footnote)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    ProgressView(value: state.progress ?? 0)
                        .tint(.accentColor)
                        .opacity(state.progress == nil ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: state.progress == nil)

                    if isButton {
                        VStack {
                            Button("_cancel_") {
                                onButtonTap?()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(15)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Container

    @ViewBuilder
    func containerView<Content: View>(state: LucidBannerState, @ViewBuilder _ content: () -> Content) -> some View {
        let isError = (state.typedStage == .error)
        let cornerRadius: CGFloat = 22

        let contentBase = content()
            .contentShape(Rectangle())
            .onTapGesture {
                guard allowMinimizeOnTap else { return }
                UploadBannerCoordinator.shared.handleTap(state)
            }
            .onDisappear {
                UploadBannerCoordinator.shared.clear()
            }

        if #available(iOS 26, *) {
            if isError {
                contentBase
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.red.opacity(1))
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                contentBase
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        } else {
            let colorBg = isError ? Color.red.opacity(0.9) : Color.white.opacity(0.9)

            contentBase
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colorBg, lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        }
    }
}

public extension View {
    @ViewBuilder
    func applyBannerAnimation(_ style: LucidBanner.LucidBannerAnimationStyle) -> some View {
        switch style {

        // ---- iOS 18+ effects ----
        case .rotate, .pulse, .pulsebyLayer, .breathe, .bounce, .wiggle, .scale, .scaleUpbyLayer:
            if #available(iOS 18, *) {
                switch style {
                case .rotate:
                    self.symbolEffect(.rotate, options: .repeat(.continuous))
                case .pulse:
                    self.symbolEffect(.pulse, options: .repeat(.continuous))
                case .pulsebyLayer:
                    self.symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
                case .breathe:
                    self.symbolEffect(.breathe, options: .repeat(.continuous))
                case .bounce:
                    self.symbolEffect(.bounce, options: .repeat(.continuous))
                case .wiggle:
                    self.symbolEffect(.wiggle, options: .repeat(.continuous))
                case .scale:
                    self.symbolEffect(.scale, options: .repeat(.continuous))
                case .scaleUpbyLayer:
                    self.symbolEffect(.scale.up.byLayer, options: .repeat(.continuous))
                default:
                    self
                }
            } else {
                self
            }

        // ---- iOS 26+ effect: drawOn ----
        case .drawOn:
            if #available(iOS 26, *) {
                self
            } else {
                self
            }

        // ---- no animation ----
        case .none:
            self
        }
    }
}

@MainActor
func showUploadBanner(scene: UIWindowScene?,
                      vPosition: LucidBanner.VerticalPosition = .center,
                      hAlignment: LucidBanner.HorizontalAlignment = .center,
                      verticalMargin: CGFloat = 0,
                      blocksTouches: Bool = false,
                      draggable: Bool = false,
                      stage: LucidBanner.Stage? = nil,
                      policy: LucidBanner.ShowPolicy = .drop,
                      allowMinimizeOnTap: Bool = false,
                      minimizePoint: CGPoint? = nil,
                      onButtonTap: (() -> Void)? = nil) -> Int {
    let token = LucidBanner.shared.show(
        scene: scene,
        vPosition: vPosition,
        hAlignment: hAlignment,
        verticalMargin: verticalMargin,
        blocksTouches: blocksTouches,
        draggable: draggable,
        stage: stage,
        policy: policy
    ) { state in
        UploadBannerView(state: state,
                         allowMinimizeOnTap: allowMinimizeOnTap,
                         onButtonTap: onButtonTap)
    }

    UploadBannerCoordinator.shared.setMinimizePoint(minimizePoint)
    UploadBannerCoordinator.shared.register(token: token)
    return token
}

@MainActor
final class UploadBannerCoordinator {
    static let shared = UploadBannerCoordinator()

    private var currentToken: Int?
    private var originalCenter: CGPoint?
    private var minimizePoint: CGPoint?

    func register(token: Int) {
        currentToken = token
    }

    func clear() {
        currentToken = nil
        originalCenter = nil
        minimizePoint = nil
    }

    func setMinimizePoint(_ point: CGPoint?) {
        minimizePoint = point
    }

    func handleTap(_ state: LucidBannerState) {
        guard let token = currentToken else {
            return
        }

        guard LucidBanner.shared.isAlive(token) else {
            clear()
            return
        }

        if state.isMinimized {
            maximize(state: state, token: token)
        } else {
            minimize(state: state, token: token)
        }
    }

    private func minimize(state: LucidBannerState, token: Int) {
        if let frame = LucidBanner.shared.currentFrameInWindow(for: token) {
            originalCenter = CGPoint(x: frame.midX, y: frame.midY)
        }
        state.isMinimized = true

        LucidBanner.shared.setDraggingEnabled(false, for: token)
        LucidBanner.shared.requestRelayout(animated: true)

        if let target = minimizePoint {
            LucidBanner.shared.move(
                toX: target.x,
                y: target.y,
                for: token,
                animated: true
            )
        }
    }

    private func maximize(state: LucidBannerState, token: Int) {
        state.isMinimized = false

        LucidBanner.shared.setDraggingEnabled(true, for: token)
        LucidBanner.shared.requestRelayout(animated: true)

        // Restore
        if let center = originalCenter {
            LucidBanner.shared.move(
                toX: center.x,
                y: center.y,
                for: token,
                animated: true
            )
        } else {
            LucidBanner.shared.resetPosition(for: token, animated: true)
        }

        originalCenter = nil
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [.white, .gray.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )

        UploadBannerView(
            state: LucidBannerState(
                title: "Downloading …",
                subtitle: "Keep application active until the transfers are completed …",
                systemImage: "gearshape.arrow.triangle.2.circlepath",
                imageAnimation: .rotate,
                progress: 0.4,
                stage: "button")
        )
        .padding()
    }
}
