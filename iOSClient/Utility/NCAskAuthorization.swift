//
//  NCAskAuthorization.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/01/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
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
