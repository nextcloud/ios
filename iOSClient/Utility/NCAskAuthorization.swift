// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import AVFAudio
import Photos

class NCAskAuthorization: NSObject {
    private(set) var isRequesting = false

    func askAuthorizationAudioRecord(controller: UIViewController?, completion: @escaping (_ hasPermission: Bool) -> Void) {
        DispatchQueue.main.async {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                completion(true)
            case .denied:
                let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_err_permission_microphone_", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("_open_settings_", comment: ""), style: .default, handler: { _ in
#if !EXTENSION
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
#endif
                    completion(false)
                }))
                alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                    completion(false)
                }))

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    controller?.present(alert, animated: true, completion: nil)
                }

            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            default:
                completion(false)
            }
        }
    }

    func askAuthorizationPhotoLibrary(controller: UIViewController?, completion: @escaping (_ hasPermission: Bool) -> Void) {
        DispatchQueue.main.async {
            switch PHPhotoLibrary.authorizationStatus() {
            case PHAuthorizationStatus.authorized:
                completion(true)
            case PHAuthorizationStatus.denied, PHAuthorizationStatus.limited, PHAuthorizationStatus.restricted:
                let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_err_permission_photolibrary_", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("_open_settings_", comment: ""), style: .default, handler: { _ in
#if !EXTENSION
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
#endif
                    completion(false)
                }))
                alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                    completion(false)
                }))

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    controller?.present(alert, animated: true, completion: nil)
                }

            case PHAuthorizationStatus.notDetermined:
                self.isRequesting = true
                PHPhotoLibrary.requestAuthorization { allowed in
                    self.isRequesting = false
#if !EXTENSION
                    // DispatchQueue.main.async { NCPasscode.shared.hidePrivacyProtectionWindow() }
#endif

                    if allowed == PHAuthorizationStatus.authorized {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            default:
                completion(false)
            }
        }
    }

#if !EXTENSION
    func checkBackgroundRefreshStatus() {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            print("Background fetch is enabled")
        case .denied:
            print("Background fetch is explicitly disabled")
            // Redirect user to Settings page only once; Respect user's choice is important
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        case .restricted:
            // Should not redirect user to Settings since he / she cannot toggle the settings
            print("Background fetch is restricted, e.g. under parental control")
        default:
            print("Unknown property")
        }
    }
#endif
}
