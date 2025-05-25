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
import SwiftUI
import NextcloudKit
import Photos

protocol NCCreateFormUploadConflictDelegate: AnyObject {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?)
}

class NCCreateFormUploadConflict: UIViewController {

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

    var account: String
    var metadatasNOConflict: [tableMetadata]
    var metadatasUploadInConflict: [tableMetadata]
    var serverUrl: String?
    var delegate: NCCreateFormUploadConflictDelegate?
    var alwaysNewFileNameNumber: Bool = false
    var textLabelDetailNewFile: String?

    var metadatasConflictNewFiles: [String] = []
    var metadatasConflictAlreadyExistingFiles: [String] = []
    let fileNamesPath = ThreadSafeDictionary<String, String>()
    var blurView: UIVisualEffectView!

    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        self.account = ""
        self.metadatasNOConflict = []
        self.metadatasUploadInConflict = []
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.tableFooterView = UIView()

        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        viewSwitch.backgroundColor = .systemGroupedBackground
        viewButton.backgroundColor = .systemGroupedBackground

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

        switchNewFiles.onTintColor = NCBrandColor.shared.getElement(account: account)
        switchNewFiles.isOn = false
        switchAlreadyExistingFiles.onTintColor = NCBrandColor.shared.getElement(account: account)
        switchAlreadyExistingFiles.isOn = false

        buttonCancel.layer.cornerRadius = 20
        buttonCancel.layer.masksToBounds = true
        buttonCancel.layer.borderWidth = 0.5
        buttonCancel.layer.borderColor = UIColor.darkGray.cgColor
        buttonCancel.backgroundColor = .systemGray5
        buttonCancel.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        buttonCancel.setTitleColor(NCBrandColor.shared.textColor, for: .normal)

        buttonContinue.layer.cornerRadius = 20
        buttonContinue.layer.masksToBounds = true
        buttonContinue.backgroundColor = NCBrandColor.shared.getElement(account: account)
        buttonContinue.setTitle(NSLocalizedString("_continue_", comment: ""), for: .normal)
        buttonContinue.isEnabled = false
        buttonContinue.setTitleColor(.white, for: .normal)

        let blurEffect = UIBlurEffect(style: .light)
        blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.conflictDialog(fileCount: self.metadatasUploadInConflict.count)
        }
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

        // KEEP BOTH
        conflictAlert.addAction(UIAlertAction(title: titleKeep, style: .default, handler: { action in

            for metadata in self.metadatasUploadInConflict {
                self.metadatasConflictNewFiles.append(metadata.ocId)
                self.metadatasConflictAlreadyExistingFiles.append(metadata.ocId)
            }

            self.buttonContinueTouch(action)
        }))

        // REPLACE
        conflictAlert.addAction(UIAlertAction(title: titleReplace, style: .default, handler: { action in
            for metadata in self.metadatasUploadInConflict {
                self.metadatasNOConflict.append(metadata)
            }
            self.buttonContinueTouch(action)
        }))

        // MORE
        conflictAlert.addAction(UIAlertAction(title: NSLocalizedString("_more_action_title_", comment: ""), style: .default, handler: { _ in
            self.blurView.removeFromSuperview()
        }))

        // CANCEL
        conflictAlert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_keep_existing_action_title_", comment: ""), style: .cancel, handler: { _ in
            self.dismiss(animated: true) {
                self.delegate?.dismissCreateFormUploadConflict(metadatas: nil)
            }
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
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_file_not_rewite_doc_")
            NCContentPresenter().showInfo(error: error)
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

                var fileName = metadata.fileNameView
                let fileNameExtension = (fileName as NSString).pathExtension.lowercased()
                let fileNameNoExtension = (fileName as NSString).deletingPathExtension
                if fileNameExtension == "heic" && !metadata.nativeFormat {
                    fileName = fileNameNoExtension + ".jpg"
                }
                let oldPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
                let newFileName = utilityFileSystem.createFileName(fileName, serverUrl: metadata.serverUrl, account: metadata.account)

                metadata.ocId = UUID().uuidString
                metadata.fileName = newFileName
                metadata.fileNameView = newFileName

                // This is not an asset - [file]
                if metadata.assetLocalIdentifier.isEmpty || metadata.isExtractFile {
                    let newPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: newFileName)
                    utilityFileSystem.moveFile(atPath: oldPath, toPath: newPath)
                }

                metadatasNOConflict.append(metadata)

            // overwrite
            } else if metadatasConflictNewFiles.contains(metadata.ocId) {

                metadatasNOConflict.append(metadata)

            } else {
                // used UIAlert (replace all)
            }
        }

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
            let metadataNewFile = tableMetadata.init(value: metadatasUploadInConflict[indexPath.row])

            cell.backgroundColor = tableView.backgroundColor
            cell.switchNewFile.onTintColor = NCBrandColor.shared.getElement(account: metadataNewFile.account)
            cell.switchAlreadyExistingFile.onTintColor = NCBrandColor.shared.getElement(account: metadataNewFile.account)
            cell.ocId = metadataNewFile.ocId
            cell.delegate = self
            cell.labelFileName.text = metadataNewFile.fileNameView
            cell.labelDetailAlreadyExistingFile.text = ""
            cell.labelDetailNewFile.text = ""

            // -----> Already Existing File

            guard let metadataAlreadyExists = NCManageDatabase.shared.getMetadataConflict(account: metadataNewFile.account, serverUrl: metadataNewFile.serverUrl, fileNameView: metadataNewFile.fileNameView, nativeFormat: metadataNewFile.nativeFormat) else { return UITableViewCell() }
            if utility.existsImage(ocId: metadataAlreadyExists.ocId, etag: metadataAlreadyExists.etag, ext: self.global.previewExt512) {
                cell.imageAlreadyExistingFile.image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageImageOcId(metadataAlreadyExists.ocId, etag: metadataAlreadyExists.etag, ext: self.global.previewExt512))
            } else if FileManager().fileExists(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataAlreadyExists.ocId, fileNameView: metadataAlreadyExists.fileNameView)) && metadataAlreadyExists.contentType == "application/pdf" {

                let url = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataAlreadyExists.ocId, fileNameView: metadataAlreadyExists.fileNameView))
                if let image = utility.pdfThumbnail(url: url) {
                    cell.imageAlreadyExistingFile.image = image
                } else {
                    cell.imageAlreadyExistingFile.image = UIImage(named: metadataAlreadyExists.iconName)
                }

            } else {
                if metadataAlreadyExists.iconName.isEmpty {
                    cell.imageAlreadyExistingFile.image = NCImageCache.shared.getImageFile()
                } else {
                    cell.imageAlreadyExistingFile.image = UIImage(named: metadataAlreadyExists.iconName)
                }
            }
            cell.labelDetailAlreadyExistingFile.text = utility.getRelativeDateTitle(metadataAlreadyExists.date as Date) + "\n" + utilityFileSystem.transformedSize(metadataAlreadyExists.size)

            if metadatasConflictAlreadyExistingFiles.contains(metadataNewFile.ocId) {
                cell.switchAlreadyExistingFile.isOn = true
            } else {
                cell.switchAlreadyExistingFile.isOn = false
            }

            // -----> New File

            if metadataNewFile.iconName.isEmpty {
                cell.imageNewFile.image = NCImageCache.shared.getImageFile()
            } else {
                cell.imageNewFile.image = UIImage(named: metadataNewFile.iconName)
            }
            let filePathNewFile = utilityFileSystem.getDirectoryProviderStorageOcId(metadataNewFile.ocId, fileNameView: metadataNewFile.fileNameView)
            if !metadataNewFile.assetLocalIdentifier.isEmpty {

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
                            if let image = utility.imageFromVideo(url: URL(fileURLWithPath: fileNamePath), at: 0) {
                                cell.imageNewFile.image = image
                            }
                        }

                        let fileDictionary = try FileManager.default.attributesOfItem(atPath: fileNamePath)
                        let fileSize = fileDictionary[FileAttributeKey.size] as? Int64 ?? 0

                        cell.labelDetailNewFile.text = utility.getRelativeDateTitle(date) + "\n" + utilityFileSystem.transformedSize(fileSize)

                    } catch { print("Error: \(error)") }

                } else {

                    // PREVIEW
                    let cameraRoll = NCCameraRoll()
                    cameraRoll.extractImageVideoFromAssetLocalIdentifier(metadata: metadataNewFile, modifyMetadataForUpload: false) { _, fileNamePath, error in
                        if !error {
                            self.fileNamesPath[metadataNewFile.fileNameView] = fileNamePath!
                            do {
                                let fileDictionary = try FileManager.default.attributesOfItem(atPath: fileNamePath!)
                                let fileSize = fileDictionary[FileAttributeKey.size] as? Int64 ?? 0
                                if mediaType == PHAssetMediaType.image {
                                    let data = try Data(contentsOf: URL(fileURLWithPath: fileNamePath!))
                                    if let image = UIImage(data: data) {
                                        DispatchQueue.main.async { cell.imageNewFile.image = image }
                                    }
                                } else if mediaType == PHAssetMediaType.video {
                                    if let image = self.utility.imageFromVideo(url: URL(fileURLWithPath: fileNamePath!), at: 0) {
                                        DispatchQueue.main.async { cell.imageNewFile.image = image }
                                    }
                                }
                                DispatchQueue.main.async { cell.labelDetailNewFile.text = self.utility.getRelativeDateTitle(date) + "\n" + self.utilityFileSystem.transformedSize(fileSize) }
                            } catch { print("Error: \(error)") }
                        }
                    }
                }

            } else if FileManager().fileExists(atPath: filePathNewFile) {

                do {
                    if metadataNewFile.classFile == NKCommon.TypeClassFile.image.rawValue {
                        // preserver memory especially for very large files in Share extension
                        if let image = UIImage.downsample(imageAt: URL(fileURLWithPath: filePathNewFile), to: cell.imageNewFile.frame.size) {
                            cell.imageNewFile.image = image
                        }
                    }

                    let fileDictionary = try FileManager.default.attributesOfItem(atPath: filePathNewFile)
                    let fileSize = fileDictionary[FileAttributeKey.size] as? Int64 ?? 0

                    cell.labelDetailNewFile.text = utility.getRelativeDateTitle(metadataNewFile.date as Date) + "\n" + utilityFileSystem.transformedSize(fileSize)

                } catch { print("Error: \(error)") }

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
            buttonContinue.setTitleColor(NCBrandColor.shared.textColor, for: .normal)
        } else {
            buttonContinue.isEnabled = false
            buttonContinue.setTitleColor(NCBrandColor.shared.textColor2, for: .normal)
        }
    }
}

// MARK: - UIViewControllerRepresentable

struct UploadConflictView: UIViewControllerRepresentable {

    typealias UIViewControllerType = NCCreateFormUploadConflict
    var delegate: NCCreateFormUploadConflictDelegate
    var serverUrl: String
    var metadatasUploadInConflict: [tableMetadata]
    var metadatasNOConflict: [tableMetadata]

    func makeUIViewController(context: Context) -> UIViewControllerType {

        let storyboard = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil)
        let viewController = storyboard.instantiateInitialViewController() as? NCCreateFormUploadConflict

        viewController?.delegate = delegate
        viewController?.textLabelDetailNewFile = NSLocalizedString("_now_", comment: "")
        viewController?.serverUrl = serverUrl
        viewController?.metadatasUploadInConflict = metadatasUploadInConflict
        viewController?.metadatasNOConflict = metadatasNOConflict

        return viewController!
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
}
