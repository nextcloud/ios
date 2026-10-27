// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Shared keypad for authentication, creation, change and removal of the app code.
@MainActor
struct NCPasscodeView: View {
    @StateObject private var model: NCPasscodeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private weak var windowScene: UIWindowScene?

    init(model: NCPasscodeModel, windowScene: UIWindowScene? = nil) {
        _model = StateObject(wrappedValue: model)
        self.windowScene = windowScene
    }

    /// SwiftUI callers handle the result and dismiss their sheet in completion.
    init(mode: NCPasscodeModel.Mode = .authenticate, allowCancel: Bool = false,
         windowScene: UIWindowScene? = nil, completion: @escaping @MainActor (NCPasscodeModel.Result) -> Void) {
        _model = StateObject(wrappedValue: {
            let model = NCPasscodeModel(mode: mode, allowCancel: allowCancel)
            model.onCompletion = completion
            return model
        }())
        self.windowScene = windowScene
    }

    /// UIKit callers receive the result after the passcode screen has closed.
    static func present(from presenter: UIViewController, mode: NCPasscodeModel.Mode = .authenticate,
                        allowCancel: Bool = false, completion: @escaping @MainActor (NCPasscodeModel.Result) -> Void) {
        guard !(presenter is UIHostingController<NCPasscodeView>) else { return }
        var top = presenter
        while let presented = top.presentedViewController {
            if presented is UIHostingController<NCPasscodeView> { return }
            top = presented
        }
        let model = NCPasscodeModel(mode: mode, allowCancel: allowCancel)
        let controller = UIHostingController(rootView: NCPasscodeView(model: model, windowScene: top.view.window?.windowScene))
        controller.modalPresentationStyle = allowCancel ? .pageSheet : .fullScreen
        controller.isModalInPresentation = !allowCancel
        model.onCompletion = { [weak controller] result in
            guard let controller else { return }
            if controller.isBeingDismissed || controller.presentingViewController == nil {
                completion(result)
            } else {
                controller.dismiss(animated: allowCancel && controller.view.window?.windowScene?.activationState == .foregroundActive) {
                    completion(result)
                }
            }
        }
        top.present(controller, animated: allowCancel)
    }

    /// Covers an extension's existing panel without presenting another modal or changing its size.
    static func embed(in container: UIViewController,
                      completion: @escaping @MainActor (NCPasscodeModel.Result) -> Void) {
        let navigationController = (container as? UINavigationController) ?? container.navigationController
        let wasNavigationBarHidden = navigationController?.isNavigationBarHidden ?? true
        navigationController?.setNavigationBarHidden(true, animated: false)
        let model = NCPasscodeModel(mode: .authenticate, allowCancel: true)
        let controller = UIHostingController(rootView: NCPasscodeView(model: model,
                                                                      windowScene: container.view.window?.windowScene))
        model.onCompletion = { [weak controller, weak navigationController] result in
            guard let controller else { return }
            // Keep protected content covered while the caller closes the extension on cancellation.
            guard result == .authenticated else {
                completion(result)
                return
            }
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            navigationController?.setNavigationBarHidden(wasNavigationBarHidden, animated: false)
            completion(result)
        }
        container.addChild(controller)
        controller.view.backgroundColor = .systemBackground
        controller.view.accessibilityViewIsModal = true
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: container.view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
        ])
        controller.didMove(toParent: container)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "lock.shield")
                            .font(.largeTitle)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString(model.title, comment: ""))
                            .font(.title2)
                            .accessibilityIdentifier("passcode.title")
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        shakeOnError {
                            HStack(spacing: 16) {
                                ForEach(0..<6) { index in
                                    Image(systemName: index < model.digits.count ? "circle.fill" : "circle")
                                        .font(.body)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(NSLocalizedString("_passcode_digits_entered_", comment: ""))
                            .accessibilityValue("\(model.digits.count) / 6")
                            .accessibilityIdentifier("passcode.progress")
                        }

                        if let deadline = model.lockoutEnd {
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                VStack(spacing: 8) {
                                    Text(NSLocalizedString("_passcode_counter_fail_", comment: ""))
                                    Text("\(max(0, Int(deadline.timeIntervalSince(timeline.date).rounded(.up)))) " + NSLocalizedString("_seconds_", comment: ""))
                                        .accessibilityIdentifier("passcode.lockout.remaining")
                                }
                                .multilineTextAlignment(.center)
                            }
                        } else {
                            shakeOnError {
                                Text(NSLocalizedString(model.message, comment: ""))
                                    .accessibilityIdentifier("passcode.error")
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .frame(minHeight: 24)
                            }
                        }
                        keypad
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if model.allowCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            model.cancel()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel(NSLocalizedString("_close_", comment: ""))
                        .accessibilityIdentifier("passcode.close")
                    }
                }
            }
        }
        .interactiveDismissDisabled(!model.allowCancel)
        .sensoryFeedback(.error, trigger: model.errorFeedback)
        .task {
            if let windowScene, windowScene.activationState != .foregroundActive {
                model.refreshProtection()
            } else {
                await model.start()
            }
        }
        .task(id: model.lockoutEnd) {
            guard let deadline = model.lockoutEnd else { return }
            let remaining = max(0, deadline.timeIntervalSinceNow)
            do {
                try await Task.sleep(for: .seconds(remaining))
                model.refreshProtection()
            } catch { return }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didActivateNotification)) { notification in
            guard let windowScene, (notification.object as? UIScene) === windowScene else { return }
            Task { await model.start() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)) { notification in
            guard let windowScene, (notification.object as? UIScene) === windowScene else { return }
            model.cancelBiometrics()
            // Optional operations cancel themselves; mandatory app authentication stays open.
            model.cancel()
        }
        .onDisappear {
            model.cancelBiometrics()
            model.cancel()
        }
    }

    /// Shake on each new error, including repeated failures with the same message.
    private func shakeOnError<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shouldReduceMotion = reduceMotion
        return content()
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: model.errorFeedback) { content, offset in
                content.offset(x: shouldReduceMotion ? 0 : offset)
            } keyframes: { _ in
                LinearKeyframe(-10, duration: 0.06)
                LinearKeyframe(10, duration: 0.08)
                LinearKeyframe(-8, duration: 0.08)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(0, duration: 0.06)
            }
    }

    private var keypad: some View {
        Grid(horizontalSpacing: 20, verticalSpacing: 12) {
            ForEach(0..<3) { row in
                GridRow {
                    ForEach(1..<4) { column in
                        digitButton(row * 3 + column)
                    }
                }
            }
            GridRow {
                Button {
                    Task { await model.authenticateWithBiometrics() }
                } label: {
                    Image(systemName: model.biometricSymbol ?? "faceid")
                        .font(.title)
                        .frame(minWidth: 80, minHeight: 80)
                }
                .accessibilityLabel(model.biometricSymbol == "touchid" ? "Touch ID" : "Face ID")
                .disabled(!model.canEnterCode || model.biometricSymbol == nil)
                .opacity(model.biometricSymbol == nil ? 0 : 1)
                digitButton(0)
                Button {
                    model.deleteDigit()
                } label: {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .frame(minWidth: 80, minHeight: 80)
                }
                .accessibilityLabel(NSLocalizedString("_delete_", comment: ""))
                .accessibilityIdentifier("passcode.delete")
                .disabled(!model.canEnterCode || model.digits.isEmpty)
            }
        }
        .buttonStyle(.plain)
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            model.append(digit)
        } label: {
            Text(String(digit))
                .font(.largeTitle.monospacedDigit())
                .frame(minWidth: 80, minHeight: 80)
                .background(Color(uiColor: .secondarySystemBackground), in: Circle())
        }
        .accessibilityIdentifier("passcode.digit.\(digit)")
        .disabled(!model.canEnterCode)
    }
}

#if DEBUG
#Preview("Unlock") {
    NCPasscodeView(model: .preview())
}

#Preview("Unlock – Dark") {
    NCPasscodeView(model: .preview())
        .preferredColorScheme(.dark)
}

#Preview("Create passcode") {
    NCPasscodeView(model: .preview(mode: .create))
}

#Preview("Too many attempts") {
    NCPasscodeView(model: .preview(locked: true))
}
#endif
