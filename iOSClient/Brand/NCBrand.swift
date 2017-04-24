//
//  NCBrandColor.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 24/04/17.
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

class NCBrandColor: NSObject {

    static let sharedInstance: NCBrandColor = {
        let instance = NCBrandColor()
        return instance
    }()

    public var brand:                   UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    public var connectionNo:            UIColor = UIColor(red: 204.0/255.0, green: 204.0/255.0, blue: 204.0/255.0, alpha: 1.0)
    public var cryptocloud:             UIColor = UIColor(red: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0)
    public var groupByBar:              UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.2)
    public var groupByBarNoBlur:        UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.3)
    public var navigationBar:           UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    public var navigationBarProgress:   UIColor = .white
    public var navigationBarShare:      UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    public var navigationBarText:       UIColor = .white
    public var nextcloud:               UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    public var menuBackground:          UIColor = .white
    public var messageInfoBackground:   UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    public var moreNormal:              UIColor = .black
    public var moreSettings:            UIColor = .black
    public var refreshControl:          UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    public var selectBackgrond:         UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 0.1)
    public var seperator:               UIColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
    public var tabBar:                  UIColor = .white
    public var tabBarText:              UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    public var tableBackground:         UIColor = .white
    public var transferBackground:      UIColor = UIColor(red: 178.0/255.0, green: 244.0/255.0, blue: 258.0/255.0, alpha: 0.1)
    public var windowTintcolor:         UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
}

class NCBrandImages: NSObject {

    static let sharedInstance: NCBrandImages = {
        let instance = NCBrandImages()
        return instance
    }()
    
    public var login:                   String = "loginLogo"
    public var navigationLogo:          String = "navigationLogo"
    public var navigationLogoOffline:   String = "navigationLogoOffline"
    public var BackgroundDetail:        String = "backgroundDetail"
    public var menuMoreImage:           String = "menuMoreImage"
}


