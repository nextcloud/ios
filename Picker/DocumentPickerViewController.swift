//
//  DocumentPickerViewController.swift
//  Picker
//
//  Created by Marino Faggiana on 27/12/16.
//  Copyright © 2016 TWS. All rights reserved.
//

import UIKit

class DocumentPickerViewController: UIDocumentPickerExtensionViewController, CCNetworkingDelegate {
    
    // MARK: - Properties
    
    var metadata : CCMetadata?
    var sectionDataSource = [CCSectionDataSource]()
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
        
        MagicalRecord.setupCoreDataStackWithAutoMigratingSqliteStore(at: pathDB!)
        MagicalRecord.setLoggingLevel(MagicalRecordLoggingLevel.off)
        
        if let record = CCCoreData.getActiveAccount() {
            
            activeAccount = record.account!
            activePassword = record.password!
            activeUrl = record.url!
            typeCloud = record.typeCloud!
            
            localServerUrl = CCUtility.getHomeServerUrlActiveUrl(activeUrl!, typeCloud: typeCloud!)
            
        } else {
            
            // Close return nil
            let deadlineTime = DispatchTime.now() + 0.1
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                
                print("Error close")
                self.dismissGrantingAccess(to: nil)
            }

            return
        }
        
        CCNetworking.shared().settingDelegate(self)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        let directoryID : String? = CCCoreData.getDirectoryID(fromServerUrl: localServerUrl!, activeAccount: activeAccount!)
        let predicate = NSPredicate(format: "(account == %@) AND (directoryID == %@)", activeAccount!, directoryID!)
        
        let recordsTableMetadata = CCCoreData.getTableMetadata(with: predicate, fieldOrder: CCUtility.getOrderSettings()!, ascending: CCUtility.getAscendingSettings())
        
        sectionDataSource = [CCSection.creataDataSourseSectionTableMetadata(recordsTableMetadata, listProgressMetadata: nil, groupByField: "none", replaceDateToExifDate: false, activeAccount: activeAccount)]
        
        tableView.reloadData()
    }

    /*
    @IBAction func openDocument(_ sender: AnyObject?) {
        let documentURL = self.documentStorageURL!.appendingPathComponent("Untitled.txt")
        
        // TODO: if you do not have a corresponding file provider, you must ensure that the URL returned here is backed by a file
        self.dismissGrantingAccess(to: documentURL)
    }
    
    override func prepareForPresentation(in mode: UIDocumentPickerMode) {
        // TODO: present a view controller appropriate for picker mode here
    }
    */
}

/*
// MARK: - UITableViewDataSource
extension DocumentPickerViewController: UITableViewDataSource {
    
    // MARK: - CellIdentifiers
    fileprivate enum CellIdentifier: String {
        case NoteCell = "noteCell"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.NoteCell.rawValue, for: indexPath)
        let note = notes[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = note.title
        return cell
    }
}
*/

