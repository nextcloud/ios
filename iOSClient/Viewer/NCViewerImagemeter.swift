//
//  NCViewerImagemeter.swift
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

class NCViewerImagemeter: UIViewController {
    
    @IBOutlet weak var img: UIImageView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var nameArchiveImagemeter: String = ""
    private var pathArchiveImagemeter: String = ""
    var metadata: tableMetadata?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(close))
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        nameArchiveImagemeter = (metadata!.fileNameView as NSString).deletingPathExtension
        pathArchiveImagemeter = CCUtility.getDirectoryProviderStorageFileID(metadata?.fileID) + "/" + nameArchiveImagemeter
        
        self.navigationItem.title = nameArchiveImagemeter
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        do {
            
            let annoPath = (pathArchiveImagemeter + "/anno-" + nameArchiveImagemeter + ".imm").url
            let annoData = try Data(contentsOf: annoPath, options: .mappedIfSafe)
            if let annotation = IMImagemeterCodable.sharedInstance.decoderAnnotetion(annoData) {
                
                if let thumbnailsFilename = annotation.thumbnails.first?.filename {
                    img.image = UIImage(contentsOfFile: pathArchiveImagemeter + "/" + thumbnailsFilename)
                }
                
            } else {
                appDelegate.messageNotification("_error_", description: "_error_decompressing_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
            }
            
        } catch {
            print("error:\(error)")
        }
        
        
        //img.image = UIImage(contentsOfFile: imgPath)
    }
    
    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }
}
