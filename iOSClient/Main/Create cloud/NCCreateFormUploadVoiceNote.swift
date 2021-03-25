//
//  NCCreateFormUploadVoiceNote.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 9/03/2019.
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
import NCCommunication

class NCCreateFormUploadVoiceNote: XLFormViewController, NCSelectDelegate, AVAudioPlayerDelegate, NCCreateFormUploadConflictDelegate {
    
    @IBOutlet weak var buttonPlayStop: UIButton!
    @IBOutlet weak var labelTimer: UILabel!
    @IBOutlet weak var labelDuration: UILabel!
    @IBOutlet weak var progressView: UIProgressView!

    private var serverUrl = ""
    private var titleServerUrl = ""
    private var fileName = ""
    private var fileNamePath = ""
    private var durationPlayer: TimeInterval = 0
    private var counterSecondPlayer: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer!
    private var timer = Timer()

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    public func setup(serverUrl: String, fileNamePath: String, fileName: String) {
    
        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) {
            titleServerUrl = "/"
        } else {
            titleServerUrl = (serverUrl as NSString).lastPathComponent
        }
    
        self.fileName = fileName
        self.serverUrl = serverUrl
        self.fileNamePath = fileNamePath
        
        // player
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileNamePath))
            audioPlayer.prepareToPlay()
            audioPlayer.delegate = self
            durationPlayer = TimeInterval(audioPlayer.duration)
        } catch {
            buttonPlayStop.isEnabled = false
        }
    }
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancel))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(save))
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        
        // title
        self.title = NSLocalizedString("_voice_memo_title_", comment: "")
        
        // Button Play Stop
        buttonPlayStop.setImage(UIImage(named: "audioPlay")!.image(color: NCBrandColor.shared.icon, size: 100), for: .normal)
        
        // Progress view
        progressView.progress = 0
        progressView.progressTintColor = .green
        progressView.trackTintColor = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)

        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateTimerUI()
    }
    
    @objc func changeTheming() {
        view.backgroundColor = NCBrandColor.shared.backgroundForm
        tableView.backgroundColor = NCBrandColor.shared.backgroundForm
        tableView.reloadData()
                
        labelTimer.textColor = NCBrandColor.shared.textView
        labelDuration.textColor = NCBrandColor.shared.textView
        
        initializeForm()
    }
    
    //MARK: XLForm

    func initializeForm() {
        
        let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
        
        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor
        
        // Section: Destination Folder
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_save_path_", comment: "").uppercased())
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: self.titleServerUrl)
        row.action.formSelector = #selector(changeDestinationFolder(_:))
        row.cellConfig["backgroundColor"] = NCBrandColor.shared.backgroundForm

        row.cellConfig["imageView.image"] =  UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: 25)
        
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.shared.textView
        
        section.addFormRow(row)
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_filename_", comment: "").uppercased())
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.value = self.fileName
        row.cellConfig["backgroundColor"] = NCBrandColor.shared.backgroundForm

        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.shared.textView

        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textColor"] = NCBrandColor.shared.textView
        
        section.addFormRow(row)

        self.form = form
    }
        
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "fileName" {
            
            self.form.delegate = nil
            
            if let fileNameNew = formRow.value {
                self.fileName = CCUtility.removeForbiddenCharactersServer(fileNameNew as? String)
            }
            
            formRow.value = self.fileName
            self.updateFormRow(formRow)
            
            self.form.delegate = self
        }
    }
    
    //MARK: TableViewDelegate

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 13.0)
        header.textLabel?.textColor = .gray
        header.tintColor = NCBrandColor.shared.backgroundForm
    }
    
    // MARK: - Action
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], buttonType: String, overwrite: Bool) {
        
        if serverUrl != nil {
            
            self.serverUrl = serverUrl!
            
            if serverUrl == NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) {
                self.titleServerUrl = "/"
            } else {
                self.titleServerUrl = (serverUrl! as NSString).lastPathComponent
            }
            
            // Update
            let row : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
            row.title = self.titleServerUrl
            self.updateFormRow(row)
        }
    }
    
    @objc func save() {
        
        let rowFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "fileName")!
        guard let name = rowFileName.value else {
            return
        }
        let ext = (name as! NSString).pathExtension.uppercased()
        var fileNameSave = ""
                   
        if (ext == "") {
            fileNameSave = name as! String + ".m4a"
        } else {
            fileNameSave = (name as! NSString).deletingPathExtension + ".m4a"
        }
        
        let metadataForUpload = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, fileName: fileNameSave, fileNameView: fileNameSave, ocId: UUID().uuidString, serverUrl: self.serverUrl, urlBase: self.appDelegate.urlBase ,url: "", contentType: "", livePhoto: false, chunk: false)
        
        metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
        metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
        metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
        
        if NCManageDatabase.shared.getMetadataConflict(account: appDelegate.account, serverUrl: serverUrl, fileName: fileNameSave) != nil {
                        
            guard let conflictViewController = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict else { return }
            conflictViewController.textLabelDetailNewFile = NSLocalizedString("_now_", comment: "")
            conflictViewController.serverUrl = serverUrl
            conflictViewController.metadatasUploadInConflict = [metadataForUpload]
            conflictViewController.delegate = self
            
            self.present(conflictViewController, animated: true, completion: nil)
            
        } else {
                            
            dismissAndUpload(metadataForUpload)
        }
    }
    
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        
        if metadatas != nil && metadatas!.count > 0 {
                                
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.dismissAndUpload(metadatas![0])
            }
        }
    }
    
    func dismissAndUpload(_ metadata: tableMetadata) {
        
        CCUtility.copyFile(atPath: self.fileNamePath, toPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
                   
        appDelegate.networkingProcessUpload?.createProcessUploads(metadatas: [metadata])

        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func cancel() {
        
        try? FileManager.default.removeItem(atPath: fileNamePath)
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func changeDestinationFolder(_ sender: XLFormRowDescriptor) {
        
        self.deselectFormRow(sender)
        
        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        let viewController = navigationController.topViewController as! NCSelect
        
        viewController.delegate = self
        viewController.hideButtonCreateFolder = false
        viewController.includeDirectoryE2EEncryption = true
        viewController.includeImages = false
        viewController.selectFile = false
        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
        viewController.type = ""
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        self.present(navigationController, animated: true, completion: nil)
    }
    
    //MARK: Player - Timer

    func updateTimerUI() {
        labelTimer.text =  String.init().formatSecondsToString(counterSecondPlayer)
        labelDuration.text = String.init().formatSecondsToString(durationPlayer)
        progressView.progress = Float(counterSecondPlayer / durationPlayer)
    }
    
    @objc func updateTimer() {
        counterSecondPlayer += 1
        updateTimerUI()
    }
    
    @IBAction func playStop(_ sender: Any) {

        if audioPlayer.isPlaying {
            
            audioPlayer.currentTime = 0.0
            audioPlayer.stop()
            
            timer.invalidate()
            counterSecondPlayer = 0
            progressView.progress = 0
            updateTimerUI()
            
            buttonPlayStop.setImage(UIImage(named: "audioPlay")!.image(color: NCBrandColor.shared.icon, size: 100), for: .normal)
            
        } else {
            
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            
            buttonPlayStop.setImage(UIImage(named: "stop")!.image(color: NCBrandColor.shared.icon, size: 100), for: .normal)
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        timer.invalidate()
        counterSecondPlayer = 0
        progressView.progress = 0
        updateTimerUI()
        
        buttonPlayStop.setImage(UIImage(named: "audioPlay")!.image(color: NCBrandColor.shared.icon, size: 100), for: .normal)
    }
}

