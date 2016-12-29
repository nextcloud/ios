//
//  DocumentPickerViewController.swift
//  Picker
//
//  Created by Marino Faggiana on 27/12/16.
//  Copyright © 2016 TWS. All rights reserved.
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

import UIKit

class DocumentPickerViewController: UIDocumentPickerExtensionViewController, CCNetworkingDelegate {
    
    // MARK: - Properties
    
    var metadata : CCMetadata?
    var recordsTableMetadata = [TableMetadata]()
    let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: capabilitiesGroups)
    
    var activeAccount : String?
    var activeUrl : String?
    var activeUser : String?
    var activePassword : String?
    var activeUID : String?
    var activeAccessToken : String?
    var directoryUser : String?
    var typeCloud : String?
    var serverUrl : String?
    
    var localServerUrl : String?
    
    lazy var networkingOperationQueue : OperationQueue = {
        
        var queue = OperationQueue()
        queue.name = "it.twsweb.cryptocloud.queue"
        queue.maxConcurrentOperationCount = 1
        
        return queue
    }()
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        let pathDB = dirGroup?.appendingPathComponent(appDatabase).appendingPathComponent("cryptocloud")
        print(pathDB!)
        
        MagicalRecord.setupCoreDataStackWithAutoMigratingSqliteStore(at: pathDB!)
        MagicalRecord.setLoggingLevel(MagicalRecordLoggingLevel.off)
        
        if let record = CCCoreData.getActiveAccount() {
            
            activeAccount = record.account!
            activePassword = record.password!
            activeUrl = record.url!
            activeUser = record.user!
            typeCloud = record.typeCloud!
            localServerUrl = CCUtility.getHomeServerUrlActiveUrl(activeUrl!, typeCloud: typeCloud!)
            directoryUser = CCUtility.getDirectoryActiveUser(activeUser!, activeUrl: activeUrl!)
            
        } else {
            
            // Close error no account return nil
            
            let deadlineTime = DispatchTime.now() + 0.1
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                
                let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_no_active_account_", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                    self.dismissGrantingAccess(to: nil)
                })
                
                self.present(alert, animated: true, completion: nil)
            }

            return
        }
        
        CCNetworking.shared().settingDelegate(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        let directoryID : String? = CCCoreData.getDirectoryID(fromServerUrl: localServerUrl!, activeAccount: activeAccount!)
        let predicate = NSPredicate(format: "(account == %@) AND (directoryID == %@)", activeAccount!, directoryID!)
        
        recordsTableMetadata = CCCoreData.getTableMetadata(with: predicate, fieldOrder: CCUtility.getOrderSettings()!, ascending: CCUtility.getAscendingSettings()) as! [TableMetadata]
        
        tableView.reloadData()
    }
}

// MARK: - Class UITableViewCell

class recordMetadataCell: UITableViewCell {
    
    @IBOutlet weak var fileImageView: UIImageView!
}

// MARK: - UITableViewDataSource

extension DocumentPickerViewController: UITableViewDataSource {
    
    // MARK: - View Life Cycle

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return recordsTableMetadata.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! recordMetadataCell
        
        let recordMetadata = recordsTableMetadata[(indexPath as NSIndexPath).row]
        
        let filePath = directoryUser!+"/"+recordMetadata.fileID!+".ico"
        
        if (FileManager.default.fileExists(atPath: filePath)) {
            
            cell.fileImageView.image = UIImage(contentsOfFile: directoryUser!+"/"+recordMetadata.fileID!+".ico")
            
        } else {
            
        }
        
        //let note = notes[(indexPath as NSIndexPath).row]
        //cell.textLabel?.text = record.fileName
        return cell
    }
}

