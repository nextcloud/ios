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

import UIKit
import QuickLook

@objc class NCViewerQuickLook: QLPreviewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var url: URL?
    var previewItems: [PreviewItem] = []
    var editingMode: Bool
    enum saveModeType{
        case overwrite
        case copy
        case discard
    }
    var saveMode: saveModeType = .discard
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc init(with url: URL, editingMode: Bool) {
        
        self.url = url
        self.editingMode = editingMode
        
        let previewItem = PreviewItem()
        previewItem.previewItemURL = url
        self.previewItems.append(previewItem)

        super.init(nibName: nil, bundle: nil)
        
        self.dataSource = self
        self.delegate = self
        self.currentPreviewItemIndex = 0

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissPreviewController))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if editingMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if #available(iOS 14.0, *) {
                    if self.navigationItem.rightBarButtonItems?.count ?? 0 > 1 {
                        if let buttonItem = self.navigationItem.rightBarButtonItems?.last {
                            _ = buttonItem.target?.perform(buttonItem.action, with: buttonItem)
                        }
                    } else {
                        if let buttonItem = self.navigationItem.rightBarButtonItems?.first {
                            _ = buttonItem.target?.perform(buttonItem.action, with: buttonItem)
                        }
                    }
                } else {
                    if let buttonItem = self.navigationItem.rightBarButtonItems?.filter({$0.customView != nil}).first?.customView as? UIButton {
                        buttonItem.sendActions(for: .touchUpInside)
                    }
                }
            }
        }
    }
    
    @objc func dismissPreviewController() {
        
        if editingMode {
            let alertController = UIAlertController(title: NSLocalizedString("_save_", comment: ""), message: "", preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_overwrite_original_", comment: ""), style: .default) { (action:UIAlertAction) in
                self.saveMode = .overwrite
                self.dismiss(animated: true)
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_save_as_copy_", comment: ""), style: .default) { (action:UIAlertAction) in
                self.saveMode = .copy
                self.dismiss(animated: true)
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive) { (action:UIAlertAction) in
                self.saveMode = .discard
                self.dismiss(animated: true)
            })
            
            self.present(alertController, animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
}

extension NCViewerQuickLook: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewItems.count
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewItems[index]
    }
    
    func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
    }
    
    @available(iOS 13.0, *)
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        if editingMode {
            return .createCopy
        } else {
            return .disabled
        }
    }
    
    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        
        if saveMode == .copy {
            
        } else if saveMode == .overwrite {
            
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
