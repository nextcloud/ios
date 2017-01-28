//
//  CCConstant.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 26/01/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class CCConstant: NSObject {
    
    struct GlobalConstants {
        
        // GLOBLE COLOR DEFINE
        
        // [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:1.0]
        
        static let kColor_Seperator: UIColor = UIColor(red: 53.0/255.0, green: 126.0/255.0, blue: 167.0/255.0, alpha: 1.0)
        
        static let kColor_cryptocloud: UIColor = UIColor(red: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0)
        
        static let kColor_NonCompliant: UIColor = UIColor(red: 190.0/255.0, green: 15.0/255.0, blue: 52.0/255.0, alpha: 1.0)

        static let kColor_Compliant: UIColor = UIColor(red: 87.0/255.0, green: 149.0/255.0, blue: 0.0/255.0, alpha: 1.0)

        
        // Response searchList
        
        static let kOrganizationFullName    = "FullName"
    }
}
