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

class DocumentPickerViewController: UIDocumentPickerExtensionViewController, CCNetworkingDelegate, OCNetworkingDelegate, BKPasscodeViewControllerDelegate {
    
    // MARK: - Properties
    
    var providerDB : providerSessionDB?
    
    lazy var fileCoordinator: NSFileCoordinator = {
    
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.purposeIdentifier = self.parameterProviderIdentifier
        return fileCoordinator
        
    }()
    
    var parameterMode : UIDocumentPickerMode?
    var parameterOriginalURL: URL?
    var parameterProviderIdentifier: String!
    var parameterPasscodeCorrect: Bool? = false
    var parameterEncrypted: Bool? = false

    var metadata : CCMetadata?
    var recordsTableMetadata : [TableMetadata]?
    var titleFolder : String?
    
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
    var thumbnailInLoading = [String: IndexPath]()
    var destinationURL : URL?
    
    var failedAttempts : UInt?
    var lockUntilDate : Date?
    
    lazy var networkingOperationQueue : OperationQueue = {
        
        var queue = OperationQueue()
        queue.name = netQueueName
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
        
        providerDB = providerSessionDB.sharedInstance
        
        if let record = CCCoreData.getActiveAccount() {
            
            activeAccount = record.account!
            activePassword = record.password!
            activeUrl = record.url!
            activeUser = record.user!
            typeCloud = record.typeCloud!
            directoryUser = CCUtility.getDirectoryActiveUser(activeUser, activeUrl: activeUrl)
            
            if (localServerUrl == nil) {
            
                localServerUrl = CCUtility.getHomeServerUrlActiveUrl(activeUrl, typeCloud: typeCloud)
                
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
        
        // COLOR_SEPARATOR_TABLE
        self.tableView.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)
        
        // (save) mode of presentation -> pass variable for pushViewController
        if parameterMode != nil {
            prepareForPresentation(in: parameterMode!)
        }
        
        // Encrypted mode
        encryptedButton.image = UIImage(named:image_shareExtEncrypt)?.withRenderingMode(.automatic)

        // Color Button
        if parameterEncrypted == true {
            encryptedButton.tintColor = UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1)
        } else {
            encryptedButton.tintColor = self.view.tintColor
            
        }
        saveButton.tintColor = encryptedButton.tintColor
        
        readFolder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        if CCUtility.getBlockCode().characters.count > 0 && CCUtility.getOnlyLockDir() == false && parameterPasscodeCorrect == false {
            openBKPasscode()
        }
    }
    
    // MARK: - Overridden Instance Methods
    
    override func prepareForPresentation(in mode: UIDocumentPickerMode) {
        
        // ------------------> Settings parameter ----------------
        if parameterMode == nil {
            parameterMode = mode
        }
        
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
        metadataNet.serverUrl = localServerUrl
        metadataNet.selector = selectorReadFolder
        
        let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, withTypeCloud: typeCloud, activityIndicator: false)
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
    
    func readFolderSuccess(_ metadataNet: CCMetadataNet!, permissions: String!, rev: String!, metadatas: [Any]!) {
        
        // remove all record
        let predicate = NSPredicate(format: "(account == '\(activeAccount!)') AND (directoryID == '\(metadataNet.directoryID!)') AND ((session == NULL) OR (session == ''))")
        CCCoreData.deleteMetadata(with: predicate)
        
        for metadata in metadatas as! [CCMetadata] {
            
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
                
                for completeMetadata in metadatas as! [CCMetadata] {
                    
                    if completeMetadata.fileName == CCUtility.trasformedFileNamePlist(inCrypto: metadata.fileName) {
                        
                        isCryptoComplete = true
                    }
                }

                if isCryptoComplete == false {
                    
                    continue
                }
            }
            
            // Add record
            CCCoreData.add(metadata, activeAccount: activeAccount, activeUrl: activeUrl, typeCloud: typeCloud, context: nil)
            
            // if plist do not exists, download it
            if CCUtility.isCryptoPlistString(metadata.fileName) && FileManager.default.fileExists(atPath: "\(directoryUser!)/\(metadata.fileName!)") == false {
                
                let metadataNet = CCMetadataNet.init(account: activeAccount)!
                
                metadataNet.action = actionDownloadFile
                metadataNet.metadata = metadata
                metadataNet.downloadData = false
                metadataNet.downloadPlist = true
                metadataNet.selector = selectorLoadPlist
                metadataNet.serverUrl = localServerUrl
                metadataNet.session = download_session_foreground
                metadataNet.taskStatus = Int(taskStatusResume)
                
                let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, withTypeCloud: typeCloud, activityIndicator: false)
                networkingOperationQueue.addOperation(ocNetworking)
            }
        }
        
        // Get Datasource
        recordsTableMetadata = CCCoreData.getTableMetadata(with: NSPredicate(format: "(account == '\(activeAccount!)') AND (directoryID == '\(metadataNet.directoryID!)')"), fieldOrder: "fileName", ascending: true) as? [TableMetadata]
        
        tableView.reloadData()
        
        hud.hideHud()
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
                //self.dismissGrantingAccess(to: nil)
                NSLog("[LOG] Download Error \(fileID) \(message) (error \(errorCode))");
            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }

    func downloadFileSuccess(_ fileID: String!, serverUrl: String!, selector: String!, selectorPost: String!) {
        
        hud.hideHud()
        
        let metadata = CCCoreData.getMetadataWithPreficate(NSPredicate(format: "(account == '\(activeAccount!)') AND (fileID == '\(fileID!)')"), context: nil)
        
        switch selector {
            
        case selectorLoadFileView :
                
            do {
                
                try FileManager.default.moveItem(atPath: "\(directoryUser!)/\(fileID!)", toPath: "\(directoryUser!)/\(metadata!.fileNamePrint!)")
                    
            } catch let error as NSError {
        
                print(error)
            }
                
            let url = URL(string: "file://\(directoryUser!)/\(metadata!.fileNamePrint!)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
            self.dismissGrantingAccess(to: url)
            
        case selectorLoadPlist :
            
            CCCoreData.downloadFilePlist(metadata, activeAccount: activeAccount, activeUrl: activeUrl, typeCloud: typeCloud, directoryUser: directoryUser)
            tableView.reloadData()
            
        default :
            
            print("selector : \(selector!)")
            tableView.reloadData()
            
        }
    }
 
    //  MARK: - Upload
    
    func uploadFileFailure(_ fileID: String!, serverUrl: String!, selector: String!, message: String!, errorCode: Int) {
        
        hud.hideHud()
        
        // remove file
        CCCoreData.deleteMetadata(with: NSPredicate(format: "(account == '\(activeAccount!)') AND (fileID == '\(fileID!)')"))
        
        if errorCode != -999 {
            
            let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                //self.dismissGrantingAccess(to: nil)
                NSLog("[LOG] Download Error \(fileID) \(message) (error \(errorCode))");
            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func uploadFileSuccess(_ fileID: String!, serverUrl: String!, selector: String!, selectorPost: String!) {
        
        hud.hideHud()
        
        dismissGrantingAccess(to: self.destinationURL)
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
    
    func downloadThumbnail(_ metadata : CCMetadata) {
    
        let metadataNet = CCMetadataNet.init(account: activeAccount)!
        
        metadataNet.action = actionDownloadThumbnail
        metadataNet.fileID = metadata.fileID
        metadataNet.fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: localServerUrl, activeUrl: activeUrl, typeCloud: typeCloud)
        metadataNet.fileNameLocal = metadata.fileID;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.options = "m";
        metadataNet.selector = selectorDownloadThumbnail;
        metadataNet.serverUrl = localServerUrl

        let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, withTypeCloud: typeCloud, activityIndicator: false)
        networkingOperationQueue.addOperation(ocNetworking)
    }
}

// MARK: - IBActions

extension DocumentPickerViewController {
    
    @IBAction func encryptedButtonTapped(_ sender: AnyObject) {

        parameterEncrypted = !parameterEncrypted!
        
        if parameterEncrypted == true {
            encryptedButton.tintColor = UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1)
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
            
            guard let destinationURLDirectoryUser = URL(string: "file://\(directoryUser!)/\(fileName)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!) else {
                
                return
            }
            
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
                    metadataNet.serverUrl = self!.localServerUrl
                    metadataNet.session = upload_session_foreground
                    metadataNet.taskStatus = Int(taskStatusResume)
                    
                    let ocNetworking : OCnetworking = OCnetworking.init(delegate: self!, metadataNet: metadataNet, withUser: self!.activeUser, withPassword: self!.activePassword, withUrl: self!.activeUrl, withTypeCloud: self!.typeCloud, activityIndicator: false)
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
            .containerURL(forSecurityApplicationGroupIdentifier: capabilitiesGroups) else {
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
    
    func openBKPasscode() {
        
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
        
        let touchIDManager = BKTouchIDManager.init(keychainServiceName: BKPasscodeKeychainServiceName)
        touchIDManager?.promptText = NSLocalizedString("_scan_fingerprint_", comment: "")
        viewController.touchIDManager = touchIDManager
        
#if CC
        viewController.title = "Crypto Cloud"
#endif

#if NC
        viewController.title = "Nextcloud"
#endif
        
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(passcodeViewCloseButtonPressed(sender:)))
        viewController.navigationItem.leftBarButtonItem?.tintColor = UIColor(colorLiteralRed: 241.0/255.0, green: 90.0/255.0, blue: 34.0/255.0, alpha: 1.0) // COLOR_ENCRYPTED
        
        let navController = UINavigationController.init(rootViewController: viewController)
        self.present(navController, animated: true, completion: nil)
    }

    func passcodeViewControllerNumber(ofFailedAttempts aViewController: BKPasscodeViewController!) -> UInt {
        return 0
    }
    
    func passcodeViewControllerLock(untilDate aViewController: BKPasscodeViewController!) -> Date! {
        return nil
    }
    
    func passcodeViewCloseButtonPressed(sender :Any) {
        dismiss(animated: true, completion: {
            self.dismissGrantingAccess(to: nil)
        })
    }
    
    func passcodeViewController(_ aViewController: BKPasscodeViewController!, authenticatePasscode aPasscode: String!, resultHandler aResultHandler: ((Bool) -> Void)!) {
        if aPasscode == CCUtility.getBlockCode() {
            lockUntilDate = nil
            failedAttempts = 0
            aResultHandler(true)
        } else {
            aResultHandler(false)
        }
    }
    
    public func passcodeViewController(_ aViewController: BKPasscodeViewController!, didFinishWithPasscode aPasscode: String!) {
        parameterPasscodeCorrect = true
        aViewController.dismiss(animated: true, completion: nil)
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
        
        if (recordsTableMetadata == nil) {
            
            return 0
            
        } else {
            
            return recordsTableMetadata!.count
        }
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! recordMetadataCell
        
        cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0)
        
        let recordTableMetadata = recordsTableMetadata?[(indexPath as NSIndexPath).row]
        let metadata = CCCoreData.insertEntity(in: recordTableMetadata)!
        
        // File Image View
        let filePath = "\(directoryUser!)/\(metadata.fileID!).ico"
        
        if FileManager.default.fileExists(atPath: filePath) {
            
            cell.fileImageView.image = UIImage(contentsOfFile: filePath)
            
        } else {
            
            cell.fileImageView.image = UIImage(named: metadata.iconName!)
            
            if metadata.thumbnailExists && metadata.directory == false {
                
                downloadThumbnail(metadata)
                thumbnailInLoading[metadata.fileID] = indexPath
            }
        }
        
        // File Name
        cell.FileName.text = metadata.fileNamePrint
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let recordTableMetadata = recordsTableMetadata?[(indexPath as NSIndexPath).row]

        tableView.deselectRow(at: indexPath, animated: true)
        
        if recordTableMetadata!.directory == 0 {
            
            let metadata = CCCoreData.insertEntity(in: recordTableMetadata)!
            
            if FileManager.default.fileExists(atPath: "\(directoryUser!)/\(metadata.fileID!)") {
                
                downloadFileSuccess(metadata.fileID!, serverUrl: localServerUrl!, selector: selectorLoadFileView, selectorPost: nil)
                
            } else {
            
                // Download file
                let metadataNet = CCMetadataNet.init(account: activeAccount)!
            
                metadataNet.action = actionDownloadFile
                metadataNet.downloadData = true
                metadataNet.downloadPlist = false
                metadataNet.metadata = metadata
                metadataNet.selector = selectorLoadFileView
                metadataNet.serverUrl = localServerUrl
                metadataNet.session = download_session_foreground
                metadataNet.taskStatus = Int(taskStatusResume)
            
                let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, withTypeCloud: typeCloud, activityIndicator: false)
                networkingOperationQueue.addOperation(ocNetworking)
                
                hud.visibleHudTitle(NSLocalizedString("_loading_", comment: ""), mode: MBProgressHUDMode.determinateHorizontalBar, color: self.navigationController?.view.tintColor)
                hud.addButtonCancel(withTarget: self, selector: "cancelTransfer")
            }
            
        } else {
            
            var dir : String! = recordTableMetadata!.fileName
            let nextViewController = self.storyboard?.instantiateViewController(withIdentifier: "DocumentPickerViewController") as! DocumentPickerViewController
        
            if recordTableMetadata?.cryptated == 1 {
                
                dir = CCUtility.trasformedFileNamePlist(inCrypto: recordTableMetadata!.fileName)
            }
        
            nextViewController.parameterMode = parameterMode
            nextViewController.parameterOriginalURL = parameterOriginalURL
            nextViewController.parameterProviderIdentifier = parameterProviderIdentifier
            nextViewController.parameterPasscodeCorrect = parameterPasscodeCorrect
            nextViewController.parameterEncrypted = parameterEncrypted
            nextViewController.localServerUrl = CCUtility.stringAppendServerUrl(localServerUrl!, addServerUrl: dir)
            nextViewController.titleFolder = recordTableMetadata?.fileNamePrint
        
            self.navigationController?.pushViewController(nextViewController, animated: true)
        }
    }
}

// MARK: - Class UITableViewCell

class recordMetadataCell: UITableViewCell {
    
    @IBOutlet weak var fileImageView: UIImageView!
    @IBOutlet weak var FileName : UILabel!
}

// MARK: - Class providerSession

class providerSessionDB {
    
    class var sharedInstance : providerSessionDB {
        
        struct Static {
            
            static let instance = providerSessionDB()
        }
        
        return Static.instance
    }
    
    private init() {
    
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: capabilitiesGroups)
        let pathDB = dirGroup?.appendingPathComponent(appDatabase).appendingPathComponent("cryptocloud")
        
        MagicalRecord.setupCoreDataStackWithAutoMigratingSqliteStore(at: pathDB!)
        MagicalRecord.setLoggingLevel(MagicalRecordLoggingLevel.off)
    }
}
