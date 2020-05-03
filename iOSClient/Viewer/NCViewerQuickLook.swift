//
//  NCViewerQuickLook.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation
import QuickLook

@objc class NCViewerQuickLook: NSObject, QLPreviewControllerDelegate, QLPreviewControllerDataSource {

    let previewController = QLPreviewController()
    var previewItems: [PreviewItem] = []
    var viewController: UIViewController?
        
    @objc func quickLook(url: URL, viewController: UIViewController) {
        
        self.viewController = viewController
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            
            guard let data = data, error == nil else {
                self.presentAlertController(with: error?.localizedDescription ?? "Failed to download the pdf!!!")
                return
            }
                        
            let httpURLResponse = response as? HTTPURLResponse
            //let mimeType = httpURLResponse?.mimeType
            
            do {
                // rename the temporary file or save it to the document or library directory if you want to keep the file
                let suggestedFilename = httpURLResponse?.suggestedFilename ?? "quicklook.pdf"
                var previewURL = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
                try data.write(to: previewURL, options: .atomic)   // atomic option overwrites it if needed
                previewURL.hasHiddenExtension = true
                let previewItem = PreviewItem()
                previewItem.previewItemURL = previewURL
                self.previewItems.append(previewItem)
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.previewController.delegate = self
                    self.previewController.dataSource = self
                    self.previewController.currentPreviewItemIndex = 0
                    self.viewController?.present(self.previewController, animated: true)
                 }
            } catch {
                print(error)
                return
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
            self.viewController?.present(alert, animated: true)
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
