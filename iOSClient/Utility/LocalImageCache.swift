//
//  LocalImageCache.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/07/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

final class LocalImageCache {
    
    static var shared = LocalImageCache()
    
    let cache = NSCache<NSString, UIImage>()
    
    func loadImage(fileID: String, fileNameView: String, completion: @escaping (UIImage?) -> Void) {
        
        if let image = cache.object(forKey: fileID as NSString) {
            completion(image)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            
            let loadedImage = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(fileID, fileNameView: fileNameView))
            
            DispatchQueue.main.async {
                
                if let loadedImage = loadedImage {
                    self?.cache.setObject(loadedImage, forKey: fileID as NSString)
                }
                completion(loadedImage)
                
            }
        }
    }
    
}
