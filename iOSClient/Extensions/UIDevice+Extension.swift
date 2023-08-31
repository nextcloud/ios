//
//  UIDevice+Extension.swift
//  Nextcloud
//
//  Created by Federico Malagoni on 23/02/22.
//  Copyright © 2022 Federico Malagoni. All rights reserved.
//
//  Author Federico Malagoni <federico.malagoni@astrairidium.com>
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

extension UIDevice {

    var hasNotch: Bool {
        if #available(iOS 11.0, *) {
            if UIApplication.shared.windows.isEmpty { return false }
            let top = UIApplication.shared.windows[0].safeAreaInsets.top
            return top > 20
        } else {
            // Fallback on earlier versions
            return false
        }
    }
}

extension UIDeviceOrientation {
    /// According to Apple... if the device is laid flat the UI is neither portrait nor landscape, so this flag ignores that and checks if the UI is REALLY in landscape. Thanks Apple.
    /// 
    /// Unless you really need to use this, you can instead try `traitCollection.verticalSizeClass` and `traitCollection.horizontalSizeClass`.
    var isLandscapeHardCheck: Bool {
        if UIDevice.current.orientation.isValidInterfaceOrientation {
            return UIDevice.current.orientation.isLandscape
        } else {
            return UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.isLandscape ?? false
        }
    }
}
