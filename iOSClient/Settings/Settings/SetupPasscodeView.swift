// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import LocalAuthentication
import PopupView

struct SetupPasscodeView: UIViewControllerRepresentable {
    var isPasscodeReset: Bool {
        let passcodeCounterFailReset = NCPreferences().passcodeCounterFailReset
        return NCPreferences().resetAppCounterFail && passcodeCounterFailReset >= NCBrandOptions.shared.resetAppPasscodeAttempts
    }

    var isPasscodeCounterFail: Bool {
        let passcodeCounterFail = NCPreferences().passcodeCounterFail
        return passcodeCounterFail > 0 && passcodeCounterFail >= 3
    }

    @Binding var isLockActive: Bool
    weak var controller: NCMainTabBarController?
    var changePasscode: Bool = false

    func makeUIViewController(context: Context) -> UIViewController {
        let laContext = LAContext()
        var error: NSError?
        let viewController: UIViewController

        if !NCPreferences().passcode.isEmptyOrNil, !changePasscode {
            let passcodeVC = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: true)
            passcodeVC.keypadButtonShowLettering = false

            if NCPreferences().touchFaceID, laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error), error == nil {
                switch laContext.biometryType {
                case .faceID:
                    passcodeVC.biometryType = .faceID
                case .touchID:
                    passcodeVC.biometryType = .touchID
                default:
                    print("No Biometric support")
                }
                passcodeVC.allowBiometricValidation = true
                passcodeVC.automaticallyPromptForBiometricValidation = true
            }

            passcodeVC.delegate = context.coordinator
            viewController = passcodeVC
        } else {
            let passcodeSettingsVC = TOPasscodeSettingsViewController()
            passcodeSettingsVC.hideOptionsButton = true
            passcodeSettingsVC.requireCurrentPasscode = changePasscode
            passcodeSettingsVC.passcodeType = .sixDigits
            passcodeSettingsVC.delegate = context.coordinator
            viewController = passcodeSettingsVC
        }

        return PasscodeContainerViewController(child: viewController)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the view controller if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, @MainActor TOPasscodeSettingsViewControllerDelegate, @MainActor TOPasscodeViewControllerDelegate {
        var parent: SetupPasscodeView
        init(_ parent: SetupPasscodeView) {
            self.parent = parent
        }

        func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
            let context = LAContext()
            var error: NSError?

            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, evaluateError in
                    DispatchQueue.main.async {
                        if success {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                                parent.isLockActive = false
                                NCPreferences().passcode = nil

                                passcodeViewController.dismiss(animated: true)
                            }
                        } else if evaluateError != nil {
                            NCPreferences().passcodeCounterFail += 1
                            NCPreferences().passcodeCounterFailReset += 1
                        }
                    }
                }
            }
        }

        // This triggers only for "Change passcode" option
        @MainActor
        func passcodeSettingsViewController(_ passcodeSettingsViewController: TOPasscodeSettingsViewController, didAttemptCurrentPasscode passcode: String) -> Bool {
            if passcode == NCPreferences().passcode {
                return true
            } else {
                NCPreferences().passcodeCounterFail += 1
                NCPreferences().passcodeCounterFailReset += 1
            }

            if parent.isPasscodeCounterFail {
                UIAlertController.failedPasscode(presenter: passcodeSettingsViewController)
            }

            return false
        }

        func passcodeSettingsViewController(_ passcodeSettingsViewController: TOPasscodeSettingsViewController, didChangeToNewPasscode passcode: String, of type: TOPasscodeType) {
            NCPreferences().passcode = passcode
            parent.isLockActive = true
            passcodeSettingsViewController.dismiss(animated: true)
        }

        func didTapCancel(in passcodeViewController: TOPasscodeViewController) {
            passcodeViewController.dismiss(animated: true)
        }

        // This triggers upon pressing "Lock: On"
        @MainActor
        func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode passcode: String) -> Bool {
            if passcode == NCPreferences().passcode {
                parent.isLockActive = false
                NCPreferences().passcode = nil
                return true
            }

            NCPreferences().passcodeCounterFail += 1
            NCPreferences().passcodeCounterFailReset += 1

            if parent.isPasscodeCounterFail {
                UIAlertController.failedPasscode(presenter: passcodeViewController)
            }

            return false
        }
    }
}

private final class PasscodeContainerViewController: UIViewController {
    private let child: UIViewController

    init(child: UIViewController) {
        self.child = child
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(presentFailedPasscodeIfNeeded),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presentFailedPasscodeIfNeeded()
    }

    @objc private func presentFailedPasscodeIfNeeded() {
        guard NCPreferences().passcodeCounterFail >= 3 else { return }

        UIAlertController.failedPasscode(presenter: self)
    }
}
