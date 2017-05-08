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

class tableAutomaticUpload: Object {
    
    dynamic var account = ""
    dynamic var assetLocalIdentifier = ""
    dynamic var date = Date()
    dynamic var fileName = ""
    dynamic var lock : Bool = false
    dynamic var priority : Int = 0
    dynamic var selector = ""
    dynamic var selectorPost = ""
    dynamic var serverUrl = ""
    dynamic var session = ""
}

class tableCapabilities: Object {
    
    dynamic var account = ""
    dynamic var themingBackground = ""
    dynamic var themingColor = ""
    dynamic var themingLogo = ""
    dynamic var themingName = ""
    dynamic var themingSlogan = ""
    dynamic var themingUrl = ""
    dynamic var versionMajor : Int = 0
    dynamic var versionMicro : Int = 0
    dynamic var versionMinor : Int = 0
    dynamic var versionString = ""

}

class tableCertificates: Object {
    
    dynamic var certificateLocation = ""
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
