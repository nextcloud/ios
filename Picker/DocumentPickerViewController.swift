//
//  DocumentPickerViewController.swift
//  Picker
//
//  Created by Marino Faggiana on 27/12/16.
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


import UIKit

class DocumentPickerViewController: UIDocumentPickerExtensionViewController, CCNetworkingDelegate, OCNetworkingDelegate, BKPasscodeViewControllerDelegate {
    
    // MARK: - Properties
    
    lazy var fileCoordinator: NSFileCoordinator = {
    
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.purposeIdentifier = self.parameterProviderIdentifier
        return fileCoordinator
        
    }()
    
    var parameterMode: UIDocumentPickerMode?
    var parameterOriginalURL: URL?
    var parameterProviderIdentifier: String!
    var parameterPasscodeCorrect: Bool? = false
    var parameterEncrypted: Bool? = false
    var isCryptoCloudMode: Bool? = false
    
    var metadata: tableMetadata?
    var recordsTableMetadata: [tableMetadata]?
    var titleFolder: String?
    
    var activeAccount: String?
    var activeUrl: String?
    var activeUser: String?
    var activePassword: String?
    var directoryUser: String?
    
    var serverUrl: String?
    var thumbnailInLoading = [String: IndexPath]()
    var destinationURL: URL?
    
    var passcodeFailedAttempts: UInt = 0
    var passcodeLockUntilDate: Date? = nil
    var passcodeIsPush: Bool? = false
    var serverUrlPush: String?
    
    
    lazy var networkingOperationQueue: OperationQueue = {
        
        var queue = OperationQueue()
        queue.name = k_queue
        queue.maxConcurrentOperationCount = 10
        
        return queue
    }()
    
    var hud : CCHud!
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var encryptedButton: UIBarButtonItem!

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if let record = NCManageDatabase.sharedInstance.getAccountActive() {
            
            activeAccount = record.account
            activePassword = record.password
            activeUrl = record.url
            activeUser = record.user
            directoryUser = CCUtility.getDirectoryActiveUser(activeUser, activeUrl: activeUrl)
            
            if (self.serverUrl == nil) {
            
                self.serverUrl = CCUtility.getHomeServerUrlActiveUrl(activeUrl)
                                
            } else {
                
                self.navigationItem.title = titleFolder
            }
            
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
        
        //  MARK: - init Object
        CCNetworking.shared().settingDelegate(self)
        hud = CCHud.init(view: self.navigationController?.view)
        
        // Theming
        let tableCapabilities = NCManageDatabase.sharedInstance.getCapabilites()
        if (tableCapabilities != nil && NCBrandOptions.sharedInstance.use_themingColor == true) {
            if ((tableCapabilities?.themingColor.characters.count)! > 0) {
                NCBrandColor.sharedInstance.brand = CCGraphics.color(fromHexString: tableCapabilities?.themingColor)
            }
        }
        
        // COLOR
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: NCBrandColor.sharedInstance.navigationBarText]
        
        self.tableView.separatorColor = NCBrandColor.sharedInstance.seperator
        self.tableView.tableFooterView = UIView()
        
        // Get Crypto Cloud Mode
        let password = CCUtility.getKeyChainPasscode(forUUID: CCUtility.getUUID())
        
        if password?.characters.count == 0 {
            
            isCryptoCloudMode = false
            
        } else {
            
            isCryptoCloudMode = true
        }
        
        // Managed Crypto Cloud Mode
        if isCryptoCloudMode == true {
            
            // Encrypted mode
            encryptedButton.image = UIImage(named:"shareExtEncrypt")?.withRenderingMode(.automatic)
            
            // Color Button
            if parameterEncrypted == true {
                encryptedButton.tintColor = NCBrandColor.sharedInstance.cryptocloud
            } else {
                encryptedButton.tintColor = self.view.tintColor
                
            }
            
            saveButton.tintColor = encryptedButton.tintColor
            
        } else {
            
            encryptedButton.isEnabled = false
            encryptedButton.tintColor = UIColor.clear
        }
        
        readFolder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
    
        // BUGFIX 2.17 - Change user Nextcloud App
        CCNetworking.shared().settingAccount()
        
        // (save) mode of presentation -> pass variable for pushViewController
        prepareForPresentation(in: parameterMode!)
    
        // String is nil or empty
        guard let passcode = CCUtility.getBlockCode(), !passcode.isEmpty else {
            return
        }
        
        if CCUtility.getOnlyLockDir() == false && parameterPasscodeCorrect == false {
            openBKPasscode(NCBrandOptions.sharedInstance.brand)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        // remove all networking operation
        networkingOperationQueue.cancelAllOperations()
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: - Overridden Instance Methods
    
    override func prepareForPresentation(in mode: UIDocumentPickerMode) {
        
        // ------------------> Settings parameter ----------------
        if parameterMode == nil {
            parameterMode = mode
        }
        
        // Variable for exportToService or moveToService
        if parameterOriginalURL == nil && originalURL != nil {
            parameterOriginalURL = originalURL
        }
        
        if parameterProviderIdentifier == nil {
            parameterProviderIdentifier = providerIdentifier
        }
        // -------------------------------------------------------
        
        switch mode {
            
        case .exportToService:
            
            print("Document Picker Mode : exportToService")
            saveButton.title = NSLocalizedString("_save_document_picker_", comment: "") // Save in this position
            
        case .moveToService:
            
            //Show confirmation button
            print("Document Picker Mode : moveToService")
            saveButton.title = NSLocalizedString("_save_document_picker_", comment: "") // Save in this position
            
        case .open:
            
            print("Document Picker Mode : open")
            saveButton.tintColor = UIColor.clear
            encryptedButton.tintColor = UIColor.clear
            
        case .import:
            
            print("Document Picker Mode : import")
            saveButton.tintColor = UIColor.clear
            encryptedButton.tintColor = UIColor.clear
        }
    }

    //  MARK: - Read folder
    
    func readFolder() {
        
        let metadataNet = CCMetadataNet.init(account: activeAccount)!

        metadataNet.action = actionReadFolder
        metadataNet.serverUrl = self.serverUrl
        metadataNet.selector = selectorReadFolder
        
        let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, isCryptoCloudMode: isCryptoCloudMode!)
        networkingOperationQueue.addOperation(ocNetworking)
        
        hud.visibleIndeterminateHud()
    }
    
    func readFolderFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        hud.hideHud()
        
        let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
            self.dismissGrantingAccess(to: nil)
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func readFolderSuccess(_ metadataNet: CCMetadataNet!, metadataFolder: tableMetadata?, metadatas: [Any]!) {
        
        // remove all record
        var predicate = NSPredicate(format: "account = %@ AND directoryID = %@ AND session = ''", activeAccount!, metadataNet.directoryID!)
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: predicate, clearDateReadDirectoryID: metadataNet.directoryID!)
        
        for metadata in metadatas as! [tableMetadata] {
            
            // do not insert crypto file
            if CCUtility.isCryptoString(metadata.fileName) {
                
                continue
            }
            
            // Only Directory ?
            if (parameterMode == .moveToService || parameterMode == .exportToService) && metadata.directory == false {
                
                continue
            }
            
            // plist + crypto = completed ?
            if CCUtility.isCryptoPlistString(metadata.fileName) && metadata.directory == false {
                
                var isCryptoComplete = false
                
                for completeMetadata in metadatas as! [tableMetadata] {
                    
                    if completeMetadata.fileName == CCUtility.trasformedFileNamePlist(inCrypto: metadata.fileName) {
                        
                        isCryptoComplete = true
                    }
                }

                if isCryptoComplete == false {
                    
                    continue
                }
            }
            
            // Add record
            let fileID = metadata.fileID
            let fileName = metadata.fileName
            _ = NCManageDatabase.sharedInstance.addMetadata(metadata, activeUrl: activeUrl!, serverUrl: metadataNet.serverUrl)
            
            // if plist do not exists, download it
            if CCUtility.isCryptoPlistString(fileName) && FileManager.default.fileExists(atPath: "\(directoryUser!)/\(fileName)") == false {
                
                let metadataNet = CCMetadataNet.init(account: activeAccount)!
                
                metadataNet.action = actionDownloadFile
                metadataNet.downloadData = false
                metadataNet.downloadPlist = true
                metadataNet.fileID = fileID
                metadataNet.selector = selectorLoadPlist
                metadataNet.serverUrl = self.serverUrl
                metadataNet.session = k_download_session_foreground
                metadataNet.taskStatus = Int(k_taskStatusResume)
                
                let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, isCryptoCloudMode: isCryptoCloudMode!)
                networkingOperationQueue.addOperation(ocNetworking)
            }
        }
        
        // Get Datasource
        //recordsTableMetadata = CCCoreData.getTableMetadata(with: NSPredicate(format: "(account == '\(activeAccount!)') AND (directoryID == '\(metadataNet.directoryID!)')"), fieldOrder: "fileName", ascending: true) as? [TableMetadata]
        
        predicate = NSPredicate(format: "account = %@ AND directoryID == %@", activeAccount!, metadataNet.directoryID!)
        recordsTableMetadata = NCManageDatabase.sharedInstance.getMetadatas(predicate: predicate, sorted: "fileName", ascending: true)
        
        tableView.reloadData()
        
        hud.hideHud()
    }
    
    //  MARK: - Download Thumbnail
    
    func downloadThumbnailFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        NSLog("[LOG] Thumbnail Error \(metadataNet.fileName) \(message) (error \(errorCode))");
    }
    
    func downloadThumbnailSuccess(_ metadataNet: CCMetadataNet!) {
        
        if let indexPath = thumbnailInLoading[metadataNet.fileID] {
            
            let path = "\(directoryUser!)/\(metadataNet.fileID!).ico"
            
            if FileManager.default.fileExists(atPath: path) {
                
                if let cell = tableView.cellForRow(at: indexPath) as? recordMetadataCell {
                    
                    cell.fileImageView.image = UIImage(contentsOfFile: path)
                }
            }
        }
    }
    
    func downloadThumbnail(_ metadata : tableMetadata) {
        
        let metadataNet = CCMetadataNet.init(account: activeAccount)!
        
        metadataNet.action = actionDownloadThumbnail
        metadataNet.fileID = metadata.fileID
        metadataNet.fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: self.serverUrl, activeUrl: activeUrl)
        metadataNet.fileNameLocal = metadata.fileID;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.options = "m";
        metadataNet.selector = selectorDownloadThumbnail;
        metadataNet.serverUrl = self.serverUrl
        
        let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, isCryptoCloudMode: isCryptoCloudMode!)
        networkingOperationQueue.addOperation(ocNetworking)
    }

    //  MARK: - Download / Upload
    
    func progressTask(_ fileID: String!, serverUrl: String!, cryptated: Bool, progress: Float) {
        
        hud.progress(progress)
    }
    
    func cancelTransfer() {
        
        networkingOperationQueue.cancelAllOperations()
    }

    //  MARK: - Download

    func downloadFileFailure(_ fileID: String!, serverUrl: String!, selector: String!, message: String!, errorCode: Int) {
        
        hud.hideHud()
        
        if selector == selectorLoadFileView && errorCode != -999 {
            
            let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                NSLog("[LOG] Download Error \(fileID) \(message) (error \(errorCode))");
            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }

    func downloadFileSuccess(_ fileID: String!, serverUrl: String!, selector: String!, selectorPost: String!) {
        
        hud.hideHud()
        
        let predicate = NSPredicate(format: "account = %@ AND fileID == %@", activeAccount!, fileID!)
        metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: predicate)
        
        //let metadata = CCCoreData.getMetadataWithPreficate(NSPredicate(format: "(account == '\(activeAccount!)') AND (fileID == '\(fileID!)')"), context: nil)
        
        switch selector {
            
        case selectorLoadFileView :
            
            let sourceUrl = URL(string: "file://\(directoryUser!)/\(fileID!)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)!
            let destinationUrl : URL! = appGroupContainerURL()?.appendingPathComponent(metadata!.fileNamePrint)
            
            // Destination Provider

            do {
                try FileManager.default.removeItem(at: destinationUrl)
            } catch _ {
                print("file do not exists")
            }

            do {
                try FileManager.default.copyItem(at: sourceUrl, to: destinationUrl)
            } catch let error as NSError {
                print(error)
            }
            
            // Dismiss
            
            self.dismissGrantingAccess(to: destinationUrl)
            
        case selectorLoadPlist :
            
            var metadata : tableMetadata? = CCUtility.insertInformationPlist(self.metadata, directoryUser: directoryUser)!
            metadata = NCManageDatabase.sharedInstance.updateMetadata(metadata!, activeUrl: activeUrl!)
            
            if metadata != nil {
                if metadata!.type == k_metadataType_template {
                    NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata!.fileID, date: metadata!.date, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, fileNamePrint: metadata!.fileNamePrint)
                }
            }
            tableView.reloadData()
            
        default :
            
            print("selector : \(selector!)")
            tableView.reloadData()
        }
    }
 
    //  MARK: - Upload
    
    func uploadFileFailure(_ metadataNet: CCMetadataNet, fileID: String, serverUrl: String, selector: String, message: String, errorCode: NSInteger){
        
        hud.hideHud()
        
        // remove file
        let predicate = NSPredicate(format: "account = %@ AND fileID == %@", activeAccount!, fileID)
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: predicate, clearDateReadDirectoryID: nil)
        
        if errorCode != -999 {
            
            let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                //self.dismissGrantingAccess(to: nil)
                NSLog("[LOG] Download Error \(fileID) \(message) (error \(errorCode))");
            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func uploadFileSuccess(_ metadataNet: CCMetadataNet, fileID: String, serverUrl: String, selector: String, selectorPost: String) {
        
        hud.hideHud()
                
        dismissGrantingAccess(to: self.destinationURL)
    }
}

// MARK: - IBActions

extension DocumentPickerViewController {
    
    @IBAction func encryptedButtonTapped(_ sender: AnyObject) {

        parameterEncrypted = !parameterEncrypted!
        
        if parameterEncrypted == true {
            encryptedButton.tintColor = NCBrandColor.sharedInstance.cryptocloud
        } else {
            encryptedButton.tintColor = self.view.tintColor
        }
        
        saveButton.tintColor = encryptedButton.tintColor
    }
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        
        guard let sourceURL = parameterOriginalURL else {
            return
        }
        
        switch parameterMode! {
            
        case .moveToService, .exportToService:
            
            let fileName = sourceURL.lastPathComponent
            let destinationURLDirectoryUser = URL(string: "file://\(directoryUser!)/\(fileName)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)!
            
            //let fileSize = (try! FileManager.default.attributesOfItem(atPath: sourceURL.path)[FileAttributeKey.size] as! NSNumber).uint64Value
            
            self.destinationURL = appGroupContainerURL()?.appendingPathComponent(fileName)
            
            // copy sourceURL on directoryUser
            do {
                try FileManager.default.removeItem(at: destinationURLDirectoryUser)
            } catch _ {
                print("file do not exists")
            }
            
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURLDirectoryUser)
            } catch _ {
                print("file do not exists")
                return
            }
            
            fileCoordinator.coordinate(readingItemAt: sourceURL, options: .withoutChanges, error: nil, byAccessor: { [weak self] newURL in
                
                do {
                    try FileManager.default.removeItem(at: (self?.destinationURL)!)
                } catch _ {
                    print("file do not exists")
                }
                
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: (self?.destinationURL)!)
                    
                    // Upload fileName to Cloud
                    
                    let metadataNet = CCMetadataNet.init(account: self!.activeAccount)!
                    
                    metadataNet.action = actionUploadFile
                    metadataNet.cryptated = self!.parameterEncrypted!
                    metadataNet.fileName = fileName
                    metadataNet.fileNamePrint = fileName
                    metadataNet.serverUrl = self!.serverUrl
                    metadataNet.session = k_upload_session_foreground
                    metadataNet.taskStatus = Int(k_taskStatusResume)
                    
                    let ocNetworking : OCnetworking = OCnetworking.init(delegate: self!, metadataNet: metadataNet, withUser: self!.activeUser, withPassword: self!.activePassword, withUrl: self!.activeUrl, isCryptoCloudMode: self!.isCryptoCloudMode!)
                    self!.networkingOperationQueue.addOperation(ocNetworking)
                    
                    self!.hud.visibleHudTitle(NSLocalizedString("_uploading_", comment: ""), mode: MBProgressHUDMode.determinateHorizontalBar, color: self!.navigationController?.view.tintColor)
                    self!.hud.addButtonCancel(withTarget: self, selector: "cancelTransfer")
                    
                } catch _ {
                    
                    print("error copying file")
                }
            })
        
        default:
            dismiss(animated: true, completion: nil)
        }
    }
    
    func appGroupContainerURL() -> URL? {
        
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups) else {
                return nil
        }
        
        let storagePathUrl = groupURL.appendingPathComponent("File Provider Storage")
        let storagePath = storagePathUrl.path
        
        if !FileManager.default.fileExists(atPath: storagePath) {
            do {
                try FileManager.default.createDirectory(atPath: storagePath, withIntermediateDirectories: false, attributes: nil)
            } catch let error {
                print("error creating filepath: \(error)")
                return nil
            }
        }
        
        return storagePathUrl
    }
    
    // MARK: - Passcode
    
    func openBKPasscode(_ title : String?) {
        
        let viewController = CCBKPasscode.init()
        
        viewController.delegate = self
        viewController.type = BKPasscodeViewControllerCheckPasscodeType
        viewController.inputViewTitlePassword = true
        
        if CCUtility.getSimplyBlockCode() {
            
            viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle
            viewController.passcodeInputView.maximumLength = 6
            
        } else {
            
            viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle
            viewController.passcodeInputView.maximumLength = 64
        }
        
        let touchIDManager = BKTouchIDManager.init(keychainServiceName: k_serviceShareKeyChain)
        touchIDManager?.promptText = NSLocalizedString("_scan_fingerprint_", comment: "")
        viewController.touchIDManager = touchIDManager
        viewController.title = title
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(passcodeViewCloseButtonPressed(sender:)))
        viewController.navigationItem.leftBarButtonItem?.tintColor = NCBrandColor.sharedInstance.cryptocloud
        
        let navController = UINavigationController.init(rootViewController: viewController)
        self.present(navController, animated: true, completion: nil)
    }

    func passcodeViewControllerNumber(ofFailedAttempts aViewController: BKPasscodeViewController!) -> UInt {
        
        return passcodeFailedAttempts
    }
    
    func passcodeViewControllerLock(untilDate aViewController: BKPasscodeViewController!) -> Date! {
        
        return passcodeLockUntilDate
    }
    
    func passcodeViewControllerDidFailAttempt(_ aViewController: BKPasscodeViewController!) {
        
        passcodeFailedAttempts += 1
        
        if passcodeFailedAttempts > 5 {
            
            var timeInterval: TimeInterval = 60
            
            if passcodeFailedAttempts > 6 {
                
                let multiplier = passcodeFailedAttempts - 6
                
                timeInterval = TimeInterval(5 * 60 * multiplier)
                
                if timeInterval > 3600 * 24 {
                    timeInterval = 3600 * 24
                }
            }
            
            passcodeLockUntilDate = Date.init(timeIntervalSinceNow: timeInterval)
        }
    }
    
    func passcodeViewController(_ aViewController: BKPasscodeViewController!, authenticatePasscode aPasscode: String!, resultHandler aResultHandler: ((Bool) -> Void)!) {
        
        if aPasscode == CCUtility.getBlockCode() {
            passcodeLockUntilDate = nil
            passcodeFailedAttempts = 0
            aResultHandler(true)
        } else {
            aResultHandler(false)
        }
    }
    
    public func passcodeViewController(_ aViewController: BKPasscodeViewController!, didFinishWithPasscode aPasscode: String!) {
        
        parameterPasscodeCorrect = true
        aViewController.dismiss(animated: true, completion: nil)
        
        if self.passcodeIsPush == true {
            performSegue()
        }
    }
    
    func passcodeViewCloseButtonPressed(sender :Any) {
        
        dismiss(animated: true, completion: {
            if self.passcodeIsPush == false {
                self.dismissGrantingAccess(to: nil)
            }
        })
    }
}

// MARK: - UITableViewDelegate

extension DocumentPickerViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
         return 50
    }
}

// MARK: - UITableViewDataSource

extension DocumentPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
       return recordsTableMetadata?.count ?? 0
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! recordMetadataCell
        
        cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0)
        
        let metadata = recordsTableMetadata?[(indexPath as NSIndexPath).row]
        //let metadata = CCCoreData.insertEntity(in: recordTableMetadata)!
        
        // File Image View
        let filePath = "\(directoryUser!)/\(metadata!.fileID)).ico"
        
        if FileManager.default.fileExists(atPath: filePath) {
            
            cell.fileImageView.image = UIImage(contentsOfFile: filePath)
            
        } else {
            
            if metadata!.directory {
                
                cell.fileImageView.image = CCGraphics.changeThemingColorImage(UIImage(named: metadata!.iconName), color: NCBrandColor.sharedInstance.brand)
                
            } else {
                
                cell.fileImageView.image = UIImage(named: (metadata?.iconName)!)
                if (metadata?.thumbnailExists)! {
                    
                    downloadThumbnail(metadata!)
                    thumbnailInLoading[metadata!.fileID] = indexPath
                }
            }
        }
        
        // File Name
        cell.fileName.text = metadata!.fileNamePrint
        
        // Status Image View
        let lockServerUrl = CCUtility.stringAppendServerUrl(self.serverUrl!, addFileName: metadata!.fileNameData)
        
        var passcode: String? = CCUtility.getBlockCode()
        if passcode == nil {
            passcode = ""
        }
        
        let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate:NSPredicate(format: "account = %@ AND serverUrl = %@", activeAccount!, lockServerUrl!))
        if tableDirectory != nil {
            if metadata!.directory &&  (tableDirectory?.lock)! && (passcode?.characters.count)! > 0 {
                cell.StatusImageView.image = UIImage(named: "passcode")
            } else {
                cell.StatusImageView.image = nil
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let metadata = recordsTableMetadata?[(indexPath as NSIndexPath).row]

        tableView.deselectRow(at: indexPath, animated: true)
        
        // Error passcode ?
        if metadata!.errorPasscode {
            return
        }
        
        self.metadata = metadata!

        if metadata!.directory == false {
            
            if FileManager.default.fileExists(atPath: "\(directoryUser!)/\(String(describing: self.metadata?.fileID))") {
                
                downloadFileSuccess(self.metadata?.fileID, serverUrl: self.serverUrl!, selector: selectorLoadFileView, selectorPost: nil)
                
            } else {
            
                // Download file
                let metadataNet = CCMetadataNet.init(account: activeAccount)!
            
                metadataNet.action = actionDownloadFile
                metadataNet.downloadData = true
                metadataNet.downloadPlist = false
                metadataNet.fileID = metadata?.fileID
                metadataNet.selector = selectorLoadFileView
                metadataNet.serverUrl = self.serverUrl
                metadataNet.session = k_download_session_foreground
                metadataNet.taskStatus = Int(k_taskStatusResume)
            
                let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, isCryptoCloudMode: self.isCryptoCloudMode!)
                networkingOperationQueue.addOperation(ocNetworking)
                
                hud.visibleHudTitle(NSLocalizedString("_loading_", comment: ""), mode: MBProgressHUDMode.determinateHorizontalBar, color: self.navigationController?.view.tintColor)
                hud.addButtonCancel(withTarget: self, selector: "cancelTransfer")
            }
            
        } else {
            
            var dir : String! = self.metadata?.fileName
            
            if (self.metadata?.cryptated)! {
                
                dir = CCUtility.trasformedFileNamePlist(inCrypto: self.metadata?.fileName)
            }
            
            serverUrlPush = CCUtility.stringAppendServerUrl(self.serverUrl!, addFileName: dir)

            var passcode: String? = CCUtility.getBlockCode()
            if passcode == nil {
                passcode = ""
            }
            
            let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate:NSPredicate(format: "account = %@ AND serverUrl = %@", activeAccount!, serverUrlPush!))

            if tableDirectory != nil {
                
                if (tableDirectory?.lock)! && (passcode?.characters.count)! > 0 {
                    
                    self.passcodeIsPush = true
                    openBKPasscode(self.metadata?.fileNamePrint)
                    
                } else {
                    
                    performSegue()
                }
                
            } else {
                
                performSegue()
            }
        }
    }
    
    func performSegue() {
        
        let nextViewController = self.storyboard?.instantiateViewController(withIdentifier: "DocumentPickerViewController") as! DocumentPickerViewController
        
        nextViewController.parameterMode = parameterMode
        nextViewController.parameterOriginalURL = parameterOriginalURL
        nextViewController.parameterProviderIdentifier = parameterProviderIdentifier
        nextViewController.parameterPasscodeCorrect = parameterPasscodeCorrect
        nextViewController.parameterEncrypted = parameterEncrypted
        nextViewController.serverUrl = serverUrlPush
        nextViewController.titleFolder = self.metadata?.fileNamePrint
        
        self.navigationController?.pushViewController(nextViewController, animated: true)
    }

}

// MARK: - Class UITableViewCell

class recordMetadataCell: UITableViewCell {
    
    @IBOutlet weak var fileImageView: UIImageView!
    @IBOutlet weak var StatusImageView: UIImageView!
    @IBOutlet weak var fileName : UILabel!
}
