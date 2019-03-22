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
            let x: Double
            let y: Double
        }
        
        struct end_pt: Codable {
            let end_pt: coordinates
            
            enum CodingKeys : String, CodingKey {
                case end_pt = "end-pt"
            }
        }
        
        struct audio_recording: Codable {
            let recording_filename: String
            let recording_duration_msecs: Double
            
            enum CodingKeys : String, CodingKey {
                case recording_filename = "recording-filename"
                case recording_duration_msecs = "recording-duration-msecs"
            }
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
            let rotation: Int
            
            enum CodingKeys : String, CodingKey {
                case title
                case filename
                case annotated_image_filename = "annotated-image-filename"
                case rotation
            }
        }
        
        struct elements: Codable {
            let id: Int
            let class_: String
            let center: coordinates
            let width: Double
            let arrows: [end_pt]
            let text: String
            let audio_recording: audio_recording
            
            enum CodingKeys : String, CodingKey {
                case id
                case class_ = "class"
                case center
                case width
                case arrows
                case text
                case audio_recording = "audio-recording"
            }
        }
        
        struct thumbnails: Codable {
            let filename: String
            let width: Int
            let height: Int
        }
        
        let is_example_image: Bool
        let version: Int
        let capture_timestamp: capture_timestamp
        let image: image
        let elements: [elements]
        let id: String
        let thumbnails: [thumbnails]
        let last_modification: Int
        
        enum CodingKeys : String, CodingKey {
            case is_example_image = "is-example-image"
            case version
            case capture_timestamp = "capture-timestamp"
            case image
            case elements
            case id
            case thumbnails
            case last_modification = "last-modification"
        }
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
