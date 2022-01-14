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

import UIKit
import NCCommunication

@objc protocol NCCreateFormUploadConflictDelegate {
    @objc func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?)
}

extension NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {}
}

@objc class NCCreateFormUploadConflict: UIViewController {

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelSubTitle: UILabel!

    @IBOutlet weak var viewSwitch: UIView!
    @IBOutlet weak var switchNewFiles: UISwitch!
    @IBOutlet weak var switchAlreadyExistingFiles: UISwitch!

    @IBOutlet weak var labelNewFiles: UILabel!
    @IBOutlet weak var labelAlreadyExistingFiles: UILabel!

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var viewButton: UIView!
    @IBOutlet weak var buttonCancel: UIButton!
    @IBOutlet weak var buttonContinue: UIButton!

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
    var blurView: UIVisualEffectView!

    // MARK: - View Life Cycle

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

        tableView.register(UINib(nibName: "NCCreateFormUploadConflictCell", bundle: nil), forCellReuseIdentifier: "Cell")

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

        buttonContinue.layer.cornerRadius = 20
        buttonContinue.layer.masksToBounds = true
        buttonContinue.setTitle(NSLocalizedString("_continue_", comment: ""), for: .normal)
        buttonContinue.isEnabled = false
        buttonContinue.setTitleColor(NCBrandColor.shared.gray, for: .normal)

        let blurEffect = UIBlurEffect(style: .light)
        blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)

        changeTheming()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.conflictDialog(fileCount: self.metadatasUploadInConflict.count)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        changeTheming()
    }

    // MARK: - Theming

    func changeTheming() {

        view.backgroundColor = NCBrandColor.shared.systemGroupedBackground
        tableView.backgroundColor = NCBrandColor.shared.systemGroupedBackground
        viewSwitch.backgroundColor = NCBrandColor.shared.systemGroupedBackground
        viewButton.backgroundColor = NCBrandColor.shared.systemGroupedBackground
    }

    // MARK: - ConflictDialog

    func conflictDialog(fileCount: Int) {

        var tile = ""
        var titleReplace = ""
        var titleKeep = ""

        if fileCount == 1 {
            tile = NSLocalizedString("_single_file_conflict_title_", comment: "")
            titleReplace = NSLocalizedString("_replace_action_title_", comment: "")
            titleKeep = NSLocalizedString("_keep_both_action_title_", comment: "")
        } else {
            tile = String.localizedStringWithFormat(NSLocalizedString("_multi_file_conflict_title_", comment: ""), String(fileCount))
            titleReplace = NSLocalizedString("_replace_all_action_title_", comment: "")
            titleKeep = NSLocalizedString("_keep_both_for_all_action_title_", comment: "")
        }

        let conflictAlert = UIAlertController(title: tile, message: "", preferredStyle: .alert)

        // REPLACE
        conflictAlert.addAction(UIAlertAction(title: titleReplace, style: .default, handler: { action in

            for metadata in self.metadatasUploadInConflict {
                self.metadatasNOConflict.append(metadata)
            }

            self.buttonContinueTouch(action)
        }))

        // KEEP BOTH
        conflictAlert.addAction(UIAlertAction(title: titleKeep, style: .default, handler: { action in

            for metadata in self.metadatasUploadInConflict {
                self.metadatasConflictNewFiles.append(metadata.ocId)
                self.metadatasConflictAlreadyExistingFiles.append(metadata.ocId)
            }

            self.buttonContinueTouch(action)
        }))

        conflictAlert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_keep_existing_action_title_", comment: ""), style: .cancel, handler: { _ in
            self.dismiss(animated: true) {
                self.delegate?.dismissCreateFormUploadConflict(metadatas: nil)
            }
        }))

        conflictAlert.addAction(UIAlertAction(title: NSLocalizedString("_more_action_title_", comment: ""), style: .default, handler: { _ in
            self.blurView.removeFromSuperview()
        }))

        self.present(conflictAlert, animated: true, completion: nil)
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
            NCContentPresenter.shared.messageNotification("_info_", description: "_file_not_rewite_doc_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorInternalError)
        }

        tableView.reloadData()
        canContinue()
    }

    @IBAction func buttonCancelTouch(_ sender: Any) {
        dismiss(animated: true) {
            self.delegate?.dismissCreateFormUploadConflict(metadatas: nil)
        }
    }

    @IBAction func buttonContinueTouch(_ sender: Any) {

        for metadata in metadatasUploadInConflict {

            // keep both
            if metadatasConflictNewFiles.contains(metadata.ocId) && metadatasConflictAlreadyExistingFiles.contains(metadata.ocId) {

                let fileNameMOV = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
                var fileName = metadata.fileNameView
                let fileNameExtension = (fileName as NSString).pathExtension.lowercased()
                let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
                if fileNameExtension == "heic" && CCUtility.getFormatCompatibility() {
                    fileName = fileNameWithoutExtension + ".jpg"
                }
                let oldPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
                let newFileName = NCUtilityFileSystem.shared.createFileName(fileName, serverUrl: metadata.serverUrl, account: metadata.account)

                metadata.ocId = UUID().uuidString
                metadata.fileName = newFileName
                metadata.fileNameView = newFileName

                // This is not an asset - [file]
                if metadata.assetLocalIdentifier == "" {
                    let newPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: newFileName)
                    CCUtility.moveFile(atPath: oldPath, toPath: newPath)
                }

                metadatasNOConflict.append(metadata)

                // MOV (Live Photo)
                if let metadataMOV = self.metadatasMOV.first(where: { $0.fileName == fileNameMOV }) {

                    let oldPath = CCUtility.getDirectoryProviderStorageOcId(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView)
                    let newFileNameMOV = (newFileName as NSString).deletingPathExtension + ".mov"

                    metadataMOV.ocId = UUID().uuidString
                    metadataMOV.fileName = newFileNameMOV
                    metadataMOV.fileNameView = newFileNameMOV

                    let newPath = CCUtility.getDirectoryProviderStorageOcId(metadataMOV.ocId, fileNameView: newFileNameMOV)
                    CCUtility.moveFile(atPath: oldPath, toPath: newPath)
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
                // used UIAlert (replace all)
            }
        }

        metadatasNOConflict.append(contentsOf: metadatasMOV)

        dismiss(animated: true) {
            self.delegate?.dismissCreateFormUploadConflict(metadatas: self.metadatasNOConflict)
        }
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

            cell.backgroundColor = tableView.backgroundColor

            let metadataNewFile = metadatasUploadInConflict[indexPath.row]

            cell.ocId = metadataNewFile.ocId
            cell.delegate = self
            cell.labelFileName.text = metadataNewFile.fileNameView
            cell.labelDetailAlreadyExistingFile.text = ""
            cell.labelDetailNewFile.text = ""

            // -----> Already Existing File

            guard let metadataAlreadyExists = NCManageDatabase.shared.getMetadataConflict(account: metadataNewFile.account, serverUrl: metadataNewFile.serverUrl, fileName: metadataNewFile.fileNameView) else { return UITableViewCell() }
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadataAlreadyExists.ocId, etag: metadataAlreadyExists.etag)) {
                cell.imageAlreadyExistingFile.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadataAlreadyExists.ocId, etag: metadataAlreadyExists.etag))
            } else if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageOcId(metadataAlreadyExists.ocId, fileNameView: metadataAlreadyExists.fileNameView)) && metadataAlreadyExists.contentType == "application/pdf" {

                let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataAlreadyExists.ocId, fileNameView: metadataAlreadyExists.fileNameView))
                if let image = NCUtility.shared.pdfThumbnail(url: url) {
                    cell.imageAlreadyExistingFile.image = image
                } else {
                    cell.imageAlreadyExistingFile.image = UIImage(named: metadataAlreadyExists.iconName)
                }

            } else {
                if metadataAlreadyExists.iconName.count > 0 {
                    cell.imageAlreadyExistingFile.image = UIImage(named: metadataAlreadyExists.iconName)
                } else {
                    cell.imageAlreadyExistingFile.image = UIImage(named: "file")
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
                cell.imageNewFile.image = UIImage(named: metadataNewFile.iconName)
            } else {
                cell.imageNewFile.image = UIImage(named: "file")
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
                            if let image = NCUtility.shared.imageFromVideo(url: URL(fileURLWithPath: fileNamePath), at: 0) {
                                cell.imageNewFile.image = image
                            }
                        }

                        let fileDictionary = try FileManager.default.attributesOfItem(atPath: fileNamePath)
                        let fileSize = fileDictionary[FileAttributeKey.size] as! Int64

                        cell.labelDetailNewFile.text = CCUtility.dateDiff(date) + "\n" + CCUtility.transformedSize(fileSize)

                    } catch { print("Error: \(error)") }

                } else {

                    CCUtility.extractImageVideoFromAssetLocalIdentifier(forUpload: metadataNewFile, notification: false) { metadataNew, fileNamePath in

                        if metadataNew != nil {
                            self.fileNamesPath[metadataNewFile.fileNameView] = fileNamePath!

                            do {

                                let fileDictionary = try FileManager.default.attributesOfItem(atPath: fileNamePath!)
                                let fileSize = fileDictionary[FileAttributeKey.size] as! Int64

                                if mediaType == PHAssetMediaType.image {
                                    let data = try Data(contentsOf: URL(fileURLWithPath: fileNamePath!))
                                    if let image = UIImage(data: data) {
                                        cell.imageNewFile.image = image
                                    }
                                } else if mediaType == PHAssetMediaType.video {
                                    if let image = NCUtility.shared.imageFromVideo(url: URL(fileURLWithPath: fileNamePath!), at: 0) {
                                        cell.imageNewFile.image = image
                                    }
                                }

                                cell.labelDetailNewFile.text = CCUtility.dateDiff(date) + "\n" + CCUtility.transformedSize(fileSize)

                            } catch { print("Error: \(error)") }
                        }
                    }
                }

            } else if FileManager().fileExists(atPath: filePathNewFile) {

                do {
                    if metadataNewFile.classFile ==  NCCommunicationCommon.typeClassFile.image.rawValue {
                        // preserver memory especially for very large files in Share extension
                        if let image = UIImage.downsample(imageAt: URL(fileURLWithPath: filePathNewFile), to: cell.imageNewFile.frame.size) {
                            cell.imageNewFile.image = image
                        }
                    }

                    let fileDictionary = try FileManager.default.attributesOfItem(atPath: filePathNewFile)
                    let fileSize = fileDictionary[FileAttributeKey.size] as! Int64

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
            buttonContinue.setTitleColor(NCBrandColor.shared.label, for: .normal)
        } else {
            buttonContinue.isEnabled = false
            buttonContinue.setTitleColor(NCBrandColor.shared.gray, for: .normal)
        }
    }
}
