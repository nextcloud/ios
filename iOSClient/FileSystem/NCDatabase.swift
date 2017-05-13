//
//  NCDatabase.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 TWS. All rights reserved.
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

import RealmSwift

class tableAccount: Object {

    dynamic var account = ""
    dynamic var active : Bool = false
    dynamic var address = ""
    dynamic var cameraUpload : Bool = false
    dynamic var cameraUploadBackground : Bool = false
    dynamic var cameraUploadCreateSubfolder : Bool = false
    dynamic var cameraUploadDatePhoto = NSDate()
    dynamic var cameraUploadDateVideo = NSDate()
    dynamic var cameraUploadFolderName = ""
    dynamic var cameraUploadFolderPath = ""
    dynamic var cameraUploadFull : Bool = false
    dynamic var cameraUploadPhoto : Bool = false
    dynamic var cameraUploadSaveAlbum : Bool = false
    dynamic var cameraUploadVideo : Bool = false
    dynamic var cameraUploadWWAnPhoto : Bool = false
    dynamic var cameraUploadWWAnVideo : Bool = false
    dynamic var displayName = ""
    dynamic var email = ""
    dynamic var enabled : Bool = false
    dynamic var optimization = NSDate()
    dynamic var password = ""
    dynamic var phone = ""
    dynamic var quota : Double = 0
    dynamic var quotaFree : Double = 0
    dynamic var quotaRelative : Double = 0
    dynamic var quotaTotal : Double = 0
    dynamic var quotaUsed : Double = 0
    dynamic var twitter = ""
    dynamic var url = ""
    dynamic var user = ""
    dynamic var webpage = ""
}

class tableActivity: Object {
    
    dynamic var account = ""
    dynamic var action = "Activity"
    dynamic var date = NSDate()
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
    dynamic var date = NSDate()
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

class tableExternalSites: Object {
    
    dynamic var account = ""
    dynamic var icon = ""
    dynamic var idExternalSite : Int = 0
    dynamic var lang = ""
    dynamic var name = ""
    dynamic var type = ""
    dynamic var url = ""
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

class tableShare: Object {
    
    dynamic var account = ""
    dynamic var fileName = ""
    dynamic var serverUrl = ""
    dynamic var shareLink = ""
    dynamic var shareUserAndGroup = ""
}
