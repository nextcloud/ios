// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Shared keypad for authentication, creation, change and removal of the app code.
@MainActor
struct NCPasscodeView: View {
    @StateObject private var model: NCPasscodeModel
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
                            Text(NSLocalizedString(model.message, comment: ""))
                                .accessibilityIdentifier("passcode.error")
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .frame(minHeight: 24)
                        }
                        keypad
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
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
