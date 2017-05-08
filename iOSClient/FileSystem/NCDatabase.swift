//
//  NCDatabase.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import RealmSwift

class tableActivity: Object {
    
    dynamic var account = ""
    dynamic var action = "Activity"
    dynamic var date = Date()
    dynamic var file = ""
    dynamic var fileID = ""
    dynamic var idActivity : Double = 0
    dynamic var link = ""
    dynamic var note = ""
    dynamic var selector = ""
    dynamic var type = ""
    dynamic var verbose : Bool = false
}

class tableGPS: Object {
    
    dynamic var latitude = ""
    dynamic var location = ""
    dynamic var longitude = ""
    dynamic var placemarkAdministrativeArea = ""
    dynamic var placemarkCountry = ""
    dynamic var placemarkLocality = ""
    dynamic var placemarkPostalCode = ""
    dynamic var placemarkThoroughfare = ""
}
