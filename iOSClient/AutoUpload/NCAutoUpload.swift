//
//  NCAutoUpload.swift
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

import Foundation
import CoreLocation
import NCCommunication

class NCAutoUpload: NSObject {
    @objc static let shared: NCAutoUpload = {
        let instance = NCAutoUpload()
        return instance
    }()
    
    func initStateAutoUpload() {
        
        if let account = NCManageDatabase.shared.getAccountActive() {
            if account.autoUpload {
                // [self setupAutoUpload];
                
                if account.autoUploadBackground {
                    // [self checkIfLocationIsEnabled];
                }
            }
        } else {
            NCManageLocation.shared.stopSignificantChangeUpdates()
        }
    }
}

//MARK: -

//- (void)statusAuthorizationLocationChanged;
//- (void)changedLocation;

class NCManageLocation: NSObject, CLLocationManagerDelegate {
    @objc static let shared: NCManageLocation = {
        let instance = NCManageLocation()
        return instance
    }()
    
    public var locationManager: CLLocationManager?
    @objc public var firstChangeAuthorizationDone: Bool = false
    
    @objc public func startSignificantChangeUpdates() {
        
        if locationManager == nil {
            
            locationManager = CLLocationManager.init()
            locationManager?.delegate = self
            locationManager?.requestAlwaysAuthorization()
        }
        
        locationManager?.startMonitoringSignificantLocationChanges()        
    }
    
    @objc public func stopSignificantChangeUpdates() {
        
        locationManager?.stopMonitoringSignificantLocationChanges()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let location = locations.last
        let latitude = String(describing: location?.coordinate.latitude)
        let longitude = String(describing: location?.coordinate.longitude)
        
        NCCommunicationCommon.shared.writeLog("update location manager: latitude " + latitude + ", longitude " + longitude)
        
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterChangedLocation)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationStatusAuthorizationChangedLocation)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationStatusAuthorizationChangedLocation)
    }
}
