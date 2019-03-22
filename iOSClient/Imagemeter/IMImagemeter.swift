//
//  IMImagemeter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/03/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

class IMImagemeterCodable: NSObject {
    
    struct imagemeterAnnotation: Codable {
        
        struct coordinates: Codable {
            let x: Int
            let y: Int
        }
        
        struct end_pt: Codable {
            let coordinates: [coordinates]
        }
        
        struct audio_recording: Codable {
            let recording_filename: String
            let recording_duration_msecs: Int
        }
        
        struct capture_timestamp: Codable {
            let year: Int
            let month: Int
            let day: Int
            let hour: Int
            let minutes: Int
            let seconds: Int
        }
        
        struct image: Codable {
            let title: String
            let filename: String
            let annotated_image_filename: String
            let rotation:Int
        }
        
        struct elements: Codable {
            let id: Int
            let class_: String
            let center: [coordinates]
            let width: Int
            let arrows: [end_pt]
            let text: String
            let audio_recording: [audio_recording]
        }
        
        let version: Int
        let capture_timestamp: capture_timestamp
        let image: image
        let id: String
        let last_modification: Int
        let elements: [elements]
    }
    
    @objc static let sharedInstance: IMImagemeterCodable = {
        let instance = IMImagemeterCodable()
        return instance
    }()
    
    func decoderAnnotetion(_ annotation: Data) -> imagemeterAnnotation? {
        
        let jsonDecoder = JSONDecoder.init()
        
        do {
            
            let decode = try jsonDecoder.decode(imagemeterAnnotation.self, from: annotation)
            return decode
            
        } catch let error {
            print("Serious internal error in decoding metadata ("+error.localizedDescription+")")
            return nil
        }
    }
}
