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
    @IBOutlet weak var imgHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressView: UIProgressView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var nameArchiveImagemeter: String = ""
    
    private var pathArchiveImagemeter: String = ""
    
    private var annotation: IMImagemeterCodable.imagemeterAnnotation?
  
    private var audioPlayer = AVAudioPlayer()
    private var timer = Timer()
    
    private var durationPlayer: TimeInterval = 0
    private var counterSecondPlayer: TimeInterval = 0

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
        
        // Progress view
        progressView.progressTintColor = NCBrandColor.sharedInstance.brandElement
        progressView.trackTintColor = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
        progressView.progress = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        do {
            
            let annoPath = (pathArchiveImagemeter + "/anno-" + nameArchiveImagemeter + ".imm").url
            let annoData = try Data(contentsOf: annoPath, options: .mappedIfSafe)
            if let annotation = IMImagemeterCodable.sharedInstance.decoderAnnotetion(annoData) {
                
                self.annotation = annotation
                imgThumbnails()
                imgAudio()
                
            } else {
                appDelegate.messageNotification("_error_", description: "_error_decompressing_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
            }
            
        } catch {
            print("error:\(error)")
        }
    }
    
    @objc func updateTimer() {
        counterSecondPlayer += 1
        progressView.progress = Float(counterSecondPlayer / durationPlayer)
    }
    
    func imgThumbnails() {
        
        guard let annotation = self.annotation else {
            return
        }
        
        if let thumbnailsFilename = annotation.thumbnails.first?.filename {
            if let thumbnailsWidth = annotation.thumbnails.first?.width {
                if let thumbnailsHeight = annotation.thumbnails.first?.height {
                    
                    let factor = Float(thumbnailsWidth) / Float(thumbnailsHeight)
                    let imageWidth = self.view.bounds.size.width
                    
                    imgHeightConstraint.constant = CGFloat((Float(imageWidth) / factor))
                    img.image = UIImage(contentsOfFile: pathArchiveImagemeter + "/" + thumbnailsFilename)
                }
            }
        }
    }
    
    func imgAudio() {
        
        guard let annotation = self.annotation else {
            return
        }
        
        for element in annotation.elements {
            
            let coordinateNormalize =  IMImagemeterCodable.sharedInstance.convertCoordinate(x: element.center.x, y: element.center.y, width: Double(self.view.bounds.width), height: Double(imgHeightConstraint.constant), button: 30)
            let x = coordinateNormalize.x
            let y = coordinateNormalize.y + Double(img.frame.origin.y)
            
            let button = UIButton()
            button.frame = CGRect(x: x, y: y, width: 30, height: 30)
            button.setImage(UIImage(named: "audioPlay"), for: .normal)
            button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
            button.tag = element.id
    
            self.view.addSubview(button)
        }
    }
    
    @objc func buttonAction(sender: UIButton!) {
        
        guard let annotation = self.annotation else {
            return
        }
        
        for element in annotation.elements {
            if element.id == sender.tag {
                let fileNamePath =  pathArchiveImagemeter + "/" + element.audio_recording.recording_filename
                // player
                do {

                    try audioPlayer = AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileNamePath))
                    audioPlayer.delegate = self
                    audioPlayer.prepareToPlay()
                    audioPlayer.play()

                    durationPlayer = TimeInterval(audioPlayer.duration)
                    timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)

                } catch {
                }
            }
        }
    }
    
    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension NCViewerImagemeter: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        updateTimer()
        timer.invalidate()
        counterSecondPlayer = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.progressView.progress = 0
        }
    }
}
