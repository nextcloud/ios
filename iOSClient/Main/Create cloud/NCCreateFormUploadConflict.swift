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
    @objc func dismissCreateFormUploadConflict(metadatas: [tableMetadata])
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
    
    @objc var metadatas: [tableMetadata]
    @objc var metadatasMOV: [tableMetadata]
    @objc var metadatasConflict: [tableMetadata]
    @objc weak var delegate: NCCreateFormUploadConflictDelegate?
    
    var metadatasConflictNewFiles = [String]()
    var metadatasConflictAlreadyExistingFiles = [String]()

    // MARK: - Cicle

    @objc required init?(coder aDecoder: NSCoder) {
        self.metadatas = [tableMetadata]()
        self.metadatasMOV = [tableMetadata]()
        self.metadatasConflict = [tableMetadata]()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.tableFooterView = UIView()
        
        tableView.register(UINib.init(nibName: "NCCreateFormUploadConflictCell", bundle: nil), forCellReuseIdentifier: "Cell")
        
        if metadatasConflict.count == 1 {
            labelTitle.text = String(metadatasConflict.count) + " " + NSLocalizedString("_file_conflict_num_", comment: "")
        } else {
            labelTitle.text = String(metadatasConflict.count) + " " + NSLocalizedString("_file_conflicts_num_", comment: "")
        }
        labelSubTitle.text = NSLocalizedString("_file_conflict_desc_", comment: "")
        labelNewFiles.text = NSLocalizedString("_file_conflict_new_", comment: "")
        labelAlreadyExistingFiles.text = NSLocalizedString("_file_conflict_exists_", comment: "")
        
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
    
    @IBAction func valueChangedSwitchNewFiles(_ sender: Any) {
        metadatasConflictNewFiles.removeAll()

        if switchNewFiles.isOn {
            for metadata in metadatasConflict {
                metadatasConflictNewFiles.append(metadata.ocId)
            }
        }
        
        tableView.reloadData()
        
        canContinue()
    }
    
    @IBAction func valueChangedSwitchAlreadyExistingFiles(_ sender: Any) {
        metadatasConflictAlreadyExistingFiles.removeAll()
        
        if switchAlreadyExistingFiles.isOn {
            for metadata in metadatasConflict {
                metadatasConflictAlreadyExistingFiles.append(metadata.ocId)
            }
        }
        
        tableView.reloadData()
        
        canContinue()
    }
    
    @IBAction func buttonCancelTouch(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func buttonContinueTouch(_ sender: Any) {
        
        for metadata in metadatasConflict {
            
            // new filename + num
            if metadatasConflictNewFiles.contains(metadata.ocId) && metadatasConflictAlreadyExistingFiles.contains(metadata.ocId) {
            
                let fileNameMOV = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
                
                let newFileName = NCUtility.sharedInstance.createFileName(metadata.fileNameView, serverUrl: metadata.serverUrl, account: metadata.account)
                let ocId = CCUtility.createMetadataID(fromAccount: metadata.account, serverUrl: metadata.serverUrl, fileNameView: newFileName, directory: false)!
                metadata.ocId = ocId
                metadata.fileName = newFileName
                metadata.fileNameView = newFileName
                
                metadatas.append(metadata)
                
                // MOV
                for metadataMOV in metadatasMOV {
                    if metadataMOV.fileName == fileNameMOV {
                        
                        let oldPath = CCUtility.getDirectoryProviderStorageOcId(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView)
                        let newFileNameMOV = (newFileName as NSString).deletingPathExtension + ".mov"
                        
                        let ocId = CCUtility.createMetadataID(fromAccount: metadataMOV.account, serverUrl: metadataMOV.serverUrl, fileNameView: newFileNameMOV, directory: false)!
                        metadataMOV.ocId = ocId
                        metadataMOV.fileName = newFileNameMOV
                        metadataMOV.fileNameView = newFileNameMOV
                        
                        let newPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: newFileNameMOV)
                        CCUtility.moveFile(atPath: oldPath, toPath: newPath)
                        
                        break
                    }
                }
                
            // overwrite
            } else if metadatasConflictNewFiles.contains(metadata.ocId) {
                
                metadatas.append(metadata)
            
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
        
        metadatas.append(contentsOf: metadatasMOV)
        
        delegate?.dismissCreateFormUploadConflict(metadatas: metadatas)
        
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate

extension NCCreateFormUploadConflict: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 180
    }
}

// MARK: - UITableViewDataSource

extension NCCreateFormUploadConflict: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return metadatasConflict.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? NCCreateFormUploadConflictCell {
            
            let metadata = metadatasConflict[indexPath.row]
            let fileNameExtension = (metadata.fileNameView as NSString).pathExtension.lowercased()
            let fileNameWithoutExtension = (metadata.fileNameView as NSString).deletingPathExtension
            var fileNameConflict = metadata.fileNameView

            if fileNameExtension == "heic" && CCUtility.getFormatCompatibility() {
                fileNameConflict = fileNameWithoutExtension + ".jpg"
            }

            guard let metadataInConflict = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", metadata.account, metadata.serverUrl, fileNameConflict)) else { return UITableViewCell() }
            
            cell.ocId = metadata.ocId
            cell.delegate = self
            
            cell.labelFileName.text = metadata.fileNameView
            cell.labelDetail.text = ""
            cell.labelDetailNew.text = ""

            // Image New
            if metadata.iconName.count > 0 {
                cell.imageFileNew.image = UIImage.init(named: metadata.iconName)
            } else {
                cell.imageFileNew.image = UIImage.init(named: "file")
            }
            // Image New < Preview >
            if metadata.assetLocalIdentifier.count > 0 {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)
                if result.count == 1 {
                    PHImageManager.default().requestImage(for: result.firstObject!, targetSize: CGSize(width: 200, height: 200), contentMode: PHImageContentMode.aspectFill, options: nil) { (image, info) in
                        cell.imageFileNew.image = image
                    }
                    
                    let resource = PHAssetResource.assetResources(for: result.firstObject!)
                    let size = resource.first?.value(forKey: "fileSize") as! Double
                    let date = result.firstObject!.modificationDate
                    
                    cell.labelDetail.text = CCUtility.dateDiff(date) + "\n" + CCUtility.transformedSize(size)
                }                
            }
        
            // Image
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadataInConflict.ocId, fileNameView: metadataInConflict.fileNameView)) {
                NCUtility.sharedInstance.loadImage(ocId: metadataInConflict.ocId, fileNameView: metadataInConflict.fileNameView) { (image) in
                    cell.imageFile.image = image
                }
            } else {
                if metadataInConflict.iconName.count > 0 {
                    cell.imageFile.image = UIImage.init(named: metadataInConflict.iconName)
                } else {
                    cell.imageFile.image = UIImage.init(named: "file")
                }
            }
            
            cell.labelDetailNew.text = CCUtility.dateDiff(metadataInConflict.date as Date) + "\n" + CCUtility.transformedSize(metadataInConflict.size)
                        
            if metadatasConflictNewFiles.contains(metadata.ocId) {
                cell.switchNewFile.isOn = true
            } else {
                cell.switchNewFile.isOn = false
            }
            
            if metadatasConflictAlreadyExistingFiles.contains(metadata.ocId) {
                cell.switchAlreadyExistingFile.isOn = true
            } else {
                cell.switchAlreadyExistingFile.isOn = false
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
        if metadatasConflictNewFiles.count == metadatasConflict.count {
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
        if metadatasConflictAlreadyExistingFiles.count == metadatasConflict.count {
            switchAlreadyExistingFiles.isOn = true
        } else {
            switchAlreadyExistingFiles.isOn = false
        }
        
        canContinue()
    }
    
    func canContinue() {
        var result = true
        
        for metadata in metadatasConflict {
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

