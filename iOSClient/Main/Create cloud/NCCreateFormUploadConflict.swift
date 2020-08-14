//
//  NCCreateFormUploadConflict.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/03/2020.
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

@objc protocol NCCreateFormUploadConflictDelegate {
    @objc func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?)
}

extension NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {}
}

@objc class NCCreateFormUploadConflict: UIViewController {

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelSubTitle: UILabel!

    @IBOutlet weak var switchNewFiles: UISwitch!
    @IBOutlet weak var switchAlreadyExistingFiles: UISwitch!

    @IBOutlet weak var labelNewFiles: UILabel!
    @IBOutlet weak var labelAlreadyExistingFiles: UILabel!

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var buttonCancel: UIButton!
    @IBOutlet weak var buttonContinue: UIButton!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc var metadatasNOConflict: [tableMetadata]
    @objc var metadatasUploadInConflict: [tableMetadata]
    @objc var metadatasMOV: [tableMetadata]
    @objc var serverUrl: String?
    @objc weak var delegate: NCCreateFormUploadConflictDelegate?
    @objc var alwaysNewFileNameNumber: Bool = false
    @objc var textLabelDetailNewFile: String?
    
    var metadatasConflictNewFiles: [String] = []
    var metadatasConflictAlreadyExistingFiles: [String] = []
    var fileNamesPath: [String: String] = [:]

    // MARK: - Cicle

    @objc required init?(coder aDecoder: NSCoder) {
        self.metadatasNOConflict = []
        self.metadatasMOV = []
        self.metadatasUploadInConflict = []
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.tableFooterView = UIView()
        
        tableView.register(UINib.init(nibName: "NCCreateFormUploadConflictCell", bundle: nil), forCellReuseIdentifier: "Cell")
        
        if metadatasUploadInConflict.count == 1 {
            labelTitle.text = String(metadatasUploadInConflict.count) + " " + NSLocalizedString("_file_conflict_num_", comment: "")
            labelSubTitle.text = NSLocalizedString("_file_conflict_desc_", comment: "")
            labelNewFiles.text = NSLocalizedString("_file_conflict_new_", comment: "")
            labelAlreadyExistingFiles.text = NSLocalizedString("_file_conflict_exists_", comment: "")
        } else {
            labelTitle.text = String(metadatasUploadInConflict.count) + " " + NSLocalizedString("_file_conflicts_num_", comment: "")
            labelSubTitle.text = NSLocalizedString("_file_conflict_desc_", comment: "")
            labelNewFiles.text = NSLocalizedString("_file_conflict_new_", comment: "")
            labelAlreadyExistingFiles.text = NSLocalizedString("_file_conflict_exists_", comment: "")
        }
        
        switchNewFiles.isOn = false
        switchAlreadyExistingFiles.isOn = false
        
        buttonCancel.layer.cornerRadius = 20
        buttonCancel.layer.masksToBounds = true
        buttonCancel.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        buttonCancel.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.5).cgColor
        
        buttonContinue.layer.cornerRadius = 20
        buttonContinue.layer.masksToBounds = true
        buttonContinue.setTitle(NSLocalizedString("_continue_", comment: ""), for: .normal)
        buttonContinue.isEnabled = false
        buttonContinue.setTitleColor(.lightGray, for: .normal)
        buttonContinue.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.5).cgColor
    }
    
    // MARK: - Action

    @IBAction func valueChangedSwitchNewFiles(_ sender: Any) {
        metadatasConflictNewFiles.removeAll()

        if switchNewFiles.isOn {
            for metadata in metadatasUploadInConflict {
                metadatasConflictNewFiles.append(metadata.ocId)
            }
        }
        
       verifySwith()
    }
    
    @IBAction func valueChangedSwitchAlreadyExistingFiles(_ sender: Any) {
        metadatasConflictAlreadyExistingFiles.removeAll()
        
        if switchAlreadyExistingFiles.isOn {
            for metadata in metadatasUploadInConflict {
                metadatasConflictAlreadyExistingFiles.append(metadata.ocId)
            }
        }
        
        verifySwith()
    }
    
    func verifySwith() {
        
        if alwaysNewFileNameNumber && switchNewFiles.isOn {
            metadatasConflictNewFiles.removeAll()
            metadatasConflictAlreadyExistingFiles.removeAll()
            
            for metadata in metadatasUploadInConflict {
                metadatasConflictNewFiles.append(metadata.ocId)
            }
            for metadata in metadatasUploadInConflict {
                metadatasConflictAlreadyExistingFiles.append(metadata.ocId)
            }
            
            switchAlreadyExistingFiles.isOn = true
            NCContentPresenter.shared.messageNotification("_info_", description: "_file_not_rewite_doc_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorInternalError), forced: true)
        }
        
        tableView.reloadData()
        canContinue()
    }
        
    @IBAction func buttonCancelTouch(_ sender: Any) {
        
        delegate?.dismissCreateFormUploadConflict(metadatas: nil)
        dismiss(animated: true)
    }
    
    @IBAction func buttonContinueTouch(_ sender: Any) {
        
        for metadata in metadatasUploadInConflict {
            
            // new filename + num
            if metadatasConflictNewFiles.contains(metadata.ocId) && metadatasConflictAlreadyExistingFiles.contains(metadata.ocId) {
            
                let fileNameMOV = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
                
                let newFileName = NCUtility.shared.createFileName(metadata.fileNameView, serverUrl: metadata.serverUrl, account: metadata.account)
                metadata.ocId = UUID().uuidString
                metadata.fileName = newFileName
                metadata.fileNameView = newFileName
                
                metadatasNOConflict.append(metadata)
                
                // MOV
                for metadataMOV in metadatasMOV {
                    if metadataMOV.fileName == fileNameMOV {
                        
                        let oldPath = CCUtility.getDirectoryProviderStorageOcId(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView)
                        let newFileNameMOV = (newFileName as NSString).deletingPathExtension + ".mov"
                        
                        metadataMOV.ocId = UUID().uuidString
                        metadataMOV.fileName = newFileNameMOV
                        metadataMOV.fileNameView = newFileNameMOV
                        
                        let newPath = CCUtility.getDirectoryProviderStorageOcId(metadataMOV.ocId, fileNameView: newFileNameMOV)
                        CCUtility.moveFile(atPath: oldPath, toPath: newPath)
                        
                        break
                    }
                }
                
            // overwrite
            } else if metadatasConflictNewFiles.contains(metadata.ocId) {
                
                metadatasNOConflict.append(metadata)
            
            // remove (MOV)
            } else if metadatasConflictAlreadyExistingFiles.contains(metadata.ocId) {
                
                let fileNameMOV = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
                var index = 0
                
                for metadataMOV in metadatasMOV {
                    if metadataMOV.fileNameView == fileNameMOV {
                        metadatasMOV.remove(at: index)
                        break
                    }
                    index += 1
                }
                
            } else {
                print("error")
            }
        }
        
        metadatasNOConflict.append(contentsOf: metadatasMOV)
        
        if delegate != nil {
            
            delegate?.dismissCreateFormUploadConflict(metadatas: metadatasNOConflict)
            
        } else {
            
            NCManageDatabase.sharedInstance.addMetadatas(metadatasNOConflict)
            
            appDelegate.networkingAutoUpload.startProcess()
        }
                
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate

extension NCCreateFormUploadConflict: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if metadatasUploadInConflict.count == 1 {
            return 250
        } else {
            return 280
        }
    }
}

// MARK: - UITableViewDataSource

extension NCCreateFormUploadConflict: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return metadatasUploadInConflict.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? NCCreateFormUploadConflictCell {
            
            let metadataNewFile = metadatasUploadInConflict[indexPath.row]

            cell.ocId = metadataNewFile.ocId
            cell.delegate = self
            cell.labelFileName.text = metadataNewFile.fileNameView
            cell.labelDetailAlreadyExistingFile.text = ""
            cell.labelDetailNewFile.text = ""

            // -----> Already Existing File
            
            guard let metadataAlreadyExists = NCUtility.shared.getMetadataConflict(account: metadataNewFile.account, serverUrl: metadataNewFile.serverUrl, fileName: metadataNewFile.fileNameView) else { return UITableViewCell() }
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadataAlreadyExists.ocId, etag: metadataAlreadyExists.etag)) {
                cell.imageAlreadyExistingFile.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadataAlreadyExists.ocId, etag: metadataAlreadyExists.etag))
            } else if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageOcId(metadataAlreadyExists.ocId, fileNameView: metadataAlreadyExists.fileNameView)) && metadataAlreadyExists.contentType == "application/pdf" {
            
                let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataAlreadyExists.ocId, fileNameView: metadataAlreadyExists.fileNameView))
                if let image = NCUtility.shared.pdfThumbnail(url: url) {
                    cell.imageAlreadyExistingFile.image = image
                } else {
                    cell.imageAlreadyExistingFile.image = UIImage.init(named: metadataAlreadyExists.iconName)
                }
            
            } else {
                if metadataAlreadyExists.iconName.count > 0 {
                    cell.imageAlreadyExistingFile.image = UIImage.init(named: metadataAlreadyExists.iconName)
                } else {
                    cell.imageAlreadyExistingFile.image = UIImage.init(named: "file")
                }
            }
            cell.labelDetailAlreadyExistingFile.text = CCUtility.dateDiff(metadataAlreadyExists.date as Date) + "\n" + CCUtility.transformedSize(metadataAlreadyExists.size)
                
            if metadatasConflictAlreadyExistingFiles.contains(metadataNewFile.ocId) {
                cell.switchAlreadyExistingFile.isOn = true
            } else {
                cell.switchAlreadyExistingFile.isOn = false
            }
            
            // -----> New File
            
            if metadataNewFile.iconName.count > 0 {
                cell.imageNewFile.image = UIImage.init(named: metadataNewFile.iconName)
            } else {
                cell.imageNewFile.image = UIImage.init(named: "file")
            }
            let filePathNewFile = CCUtility.getDirectoryProviderStorageOcId(metadataNewFile.ocId, fileNameView: metadataNewFile.fileNameView)!
            if metadataNewFile.assetLocalIdentifier.count > 0 {
                
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [metadataNewFile.assetLocalIdentifier], options: nil)
                let date = result.firstObject!.modificationDate
                let mediaType = result.firstObject!.mediaType
                
                if let fileNamePath = self.fileNamesPath[metadataNewFile.fileNameView] {
                    
                    do {
                        if mediaType == PHAssetMediaType.image {
                            let data = try Data(contentsOf: URL(fileURLWithPath: fileNamePath))
                            if let image = UIImage(data: data) {
                                cell.imageNewFile.image = image
                            }
                        } else if mediaType == PHAssetMediaType.video {
                            if let image = CCGraphics.thumbnailImage(forVideo: URL(fileURLWithPath: fileNamePath), atTime: 1) {
                                cell.imageNewFile.image = image
                            }
                        }
                        
                        let fileDictionary = try FileManager.default.attributesOfItem(atPath: fileNamePath)
                        let fileSize = fileDictionary[FileAttributeKey.size] as! Double
                        
                        cell.labelDetailNewFile.text = CCUtility.dateDiff(date) + "\n" + CCUtility.transformedSize(fileSize)
                        
                    } catch { print("Error: \(error)") }
                    
                } else {
                    
                    CCUtility.extractImageVideoFromAssetLocalIdentifier(forUpload: metadataNewFile, notification: false) { (metadataNew, fileNamePath) in
                        DispatchQueue.main.async {
                            if metadataNew != nil {
                                self.fileNamesPath[metadataNewFile.fileNameView] = fileNamePath!
                                do {
                                    if mediaType == PHAssetMediaType.image {
                                        let data = try Data(contentsOf: URL(fileURLWithPath: fileNamePath!))
                                        if let image = UIImage(data: data) {
                                            DispatchQueue.main.async {
                                                cell.imageNewFile.image = image
                                            }
                                        }
                                    } else if mediaType == PHAssetMediaType.video {
                                        if let image = CCGraphics.thumbnailImage(forVideo: URL(fileURLWithPath: fileNamePath!), atTime: 1) {
                                            DispatchQueue.main.async {
                                                cell.imageNewFile.image = image
                                            }
                                        }
                                    }
                                    
                                    let fileDictionary = try FileManager.default.attributesOfItem(atPath: fileNamePath!)
                                    let fileSize = fileDictionary[FileAttributeKey.size] as! Double
                                    
                                    cell.labelDetailNewFile.text = CCUtility.dateDiff(date) + "\n" + CCUtility.transformedSize(fileSize)
                                    
                                } catch { print("Error: \(error)") }
                            }
                        }
                    }
                }
                      
            } else if FileManager().fileExists(atPath: filePathNewFile) {
                
                do {
                    if metadataNewFile.typeFile == k_metadataTypeFile_image {
                        let data = try Data(contentsOf: URL(fileURLWithPath: filePathNewFile))
                        if let image = UIImage(data: data) {
                            cell.imageNewFile.image = image
                        }
                    }
                    
                    let fileDictionary = try FileManager.default.attributesOfItem(atPath: filePathNewFile)
                    let fileSize = fileDictionary[FileAttributeKey.size] as! Double
                    
                    cell.labelDetailNewFile.text = CCUtility.dateDiff(metadataNewFile.date as Date) + "\n" + CCUtility.transformedSize(fileSize)
                    
                } catch { print("Error: \(error)") }
                
            } else {
                
                CCUtility.dateDiff(metadataNewFile.date as Date)
            }
            
            if metadatasConflictNewFiles.contains(metadataNewFile.ocId) {
                cell.switchNewFile.isOn = true
            } else {
                cell.switchNewFile.isOn = false
            }
        
            // Hide switch if only one
            if metadatasUploadInConflict.count == 1 {
                cell.switchAlreadyExistingFile.isHidden = true
                cell.switchNewFile.isHidden = true
            }
            
            // text label new file
            if textLabelDetailNewFile != nil {
                cell.labelDetailNewFile.text = textLabelDetailNewFile! + "\n"
            }
            
            return cell
        }
        
        return UITableViewCell()
    }
}

// MARK: - NCCreateFormUploadConflictCellDelegate

extension NCCreateFormUploadConflict: NCCreateFormUploadConflictCellDelegate {
    
    func valueChangedSwitchNewFile(with ocId: String, isOn: Bool) {
        if let index = metadatasConflictNewFiles.firstIndex(of: ocId) {
            metadatasConflictNewFiles.remove(at: index)
        }
        if isOn {
            metadatasConflictNewFiles.append(ocId)
        }
        if metadatasConflictNewFiles.count == metadatasUploadInConflict.count {
            switchNewFiles.isOn = true
        } else {
            switchNewFiles.isOn = false
        }
        
        canContinue()
    }
    
    func valueChangedSwitchAlreadyExistingFile(with ocId: String, isOn: Bool) {
        if let index = metadatasConflictAlreadyExistingFiles.firstIndex(of: ocId) {
            metadatasConflictAlreadyExistingFiles.remove(at: index)
        }
        if isOn {
            metadatasConflictAlreadyExistingFiles.append(ocId)
        }
        if metadatasConflictAlreadyExistingFiles.count == metadatasUploadInConflict.count {
            switchAlreadyExistingFiles.isOn = true
        } else {
            switchAlreadyExistingFiles.isOn = false
        }
        
        canContinue()
    }
    
    func canContinue() {
        var result = true
        
        for metadata in metadatasUploadInConflict {
            if !metadatasConflictNewFiles.contains(metadata.ocId) && !metadatasConflictAlreadyExistingFiles.contains(metadata.ocId) {
                result = false
            }
        }
        
        if result {
            buttonContinue.isEnabled = true
            buttonContinue.setTitleColor(.black, for: .normal)
        } else {
            buttonContinue.isEnabled = false
            buttonContinue.setTitleColor(.lightGray, for: .normal)
        }
    }
}

