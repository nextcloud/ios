//
//  NCBrand-IONOS.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 26.06.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

@objc class NCBrandOptionsIONOS: NCBrandOptions {
    
    override init() {
        super.init()
        
        brand = "IONOS"
        loginBaseUrl = "https://nextcloud-aio.iocaste45.de"

        disable_intro = true
        disable_request_login_url = true

        capabilitiesGroup = "group.com.viseven.ionos.easystorage"
    }
}
