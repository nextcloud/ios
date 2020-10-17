//
//  NCViewerQuickLook.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import QuickLook

@objc class NCViewerQuickLook: NSObject, QLPreviewControllerDelegate, QLPreviewControllerDataSource {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let previewController = QLPreviewController()
    var previewItems: [PreviewItem] = []
        
    @objc func quickLook(url: URL) {
                
        URLSession.shared.dataTask(with: url) { data, response, error in
            
            guard let _ = data, error == nil else {
                self.presentAlertController(with: error?.localizedDescription ?? "Failed to look the file")
                return
            }
                        
            //let httpURLResponse = response as? HTTPURLResponse
            //let mimeType = httpURLResponse?.mimeType
            
            var previewURL = url
            previewURL.hasHiddenExtension = true
            let previewItem = PreviewItem()
            previewItem.previewItemURL = previewURL
            self.previewItems.append(previewItem)
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.previewController.delegate = self
                self.previewController.dataSource = self
                self.previewController.currentPreviewItemIndex = 0
                self.appDelegate.window?.rootViewController?.present(self.previewController, animated: true)
            }
            
        }.resume()
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { previewItems[index] }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewItems.count
    }
    
    func presentAlertController(with message: String) {
         // present your alert controller from the main thread
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default))
            self.appDelegate.window?.rootViewController?.present(alert, animated: true)
        }
    }
}

extension URL {
    var hasHiddenExtension: Bool {
        get { (try? resourceValues(forKeys: [.hasHiddenExtensionKey]))?.hasHiddenExtension == true }
        set {
            var resourceValues = URLResourceValues()
            resourceValues.hasHiddenExtension = newValue
            try? setResourceValues(resourceValues)
        }
    }
}

import QuickLook
class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
}
