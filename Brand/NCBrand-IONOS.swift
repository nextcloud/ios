//
//  NCBrand-IONOS.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 26.06.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//


@objc class NCBrandOptionsIONOS: NCBrandOptions {
    
    override init() {
        super.init()
        
        brand = "IONOS"
        loginBaseUrl = "https://nextcloud.iocaste45.de"

        disable_intro = true
        disable_request_login_url = true

        capabilitiesGroups = "group.com.viseven.ionos.easystorage"
    }
}
