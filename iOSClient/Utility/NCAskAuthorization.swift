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

class NCAskAuthorization: NSObject {
    @objc static let shared: NCAskAuthorization = {
        let instance = NCAskAuthorization()
        return instance
    }()

    func askAuthorizationAudioRecord(viewController: UIViewController?, completion: @escaping (_ hasPermission: Bool) -> Void) {

        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSession.RecordPermission.granted:
            completion(true)
            break
        case AVAudioSession.RecordPermission.denied:
            let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_err_permission_microphone_", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_open_settings_", comment: ""), style: .default, handler: { _ in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                completion(false)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                completion(false)
            }))
            DispatchQueue.main.async {
                viewController?.present(alert, animated: true, completion: nil)
            }
            break
        case AVAudioSession.RecordPermission.undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
            break
        default:
            completion(false)
            break
        }
    }

    func askAuthorizationPhotoLibrary(viewController: UIViewController?, completion: @escaping (_ hasPermission: Bool) -> Void) {

        switch PHPhotoLibrary.authorizationStatus() {
        case PHAuthorizationStatus.authorized:
            completion(true)
            break
        case PHAuthorizationStatus.denied, PHAuthorizationStatus.limited, PHAuthorizationStatus.restricted:
            let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_err_permission_photolibrary_", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_open_settings_", comment: ""), style: .default, handler: { _ in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                completion(false)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                completion(false)
            }))
            DispatchQueue.main.async {
                viewController?.present(alert, animated: true, completion: nil)
            }
            break
        case PHAuthorizationStatus.notDetermined:
            PHPhotoLibrary.requestAuthorization { allowed in
                DispatchQueue.main.async {
                    if allowed == PHAuthorizationStatus.authorized {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
            break
        default:
            completion(false)
            break
        }
    }

    @objc func askAuthorizationLocationManager(completion: @escaping (_ hasFullPermissions: Bool) -> Void) {

        switch CLLocationManager.authorizationStatus() {
        case CLAuthorizationStatus.authorizedAlways:
            completion(true)
            break
        /*
        case CLAuthorizationStatus.authorizedWhenInUse, CLAuthorizationStatus.denied, CLAuthorizationStatus.restricted:
            DispatchQueue.main.async {
                NCAutoUpload.shared.startSignificantChangeUpdates()
            }
            completion(false)
            break
        case CLAuthorizationStatus.notDetermined:
            DispatchQueue.main.async {
                NCAutoUpload.shared.startSignificantChangeUpdates()
            }
            completion(false)
            break
        */
        default:
            DispatchQueue.main.async {
                NCAutoUpload.shared.startSignificantChangeUpdates()
            }
            completion(false)
            break
        }
    }
}
