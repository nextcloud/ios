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

class NCViewerImagemeter: NSObject {
    
    private var imagemeterView: IMImagemeterView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var annotation: IMImagemeterCodable.imagemeterAnnotation?
    
    private var immFileNamePath: String = ""
    private var bundleDirectory: String = ""
    
    private var audioPlayer = AVAudioPlayer()
    private var timer = Timer()
    
    private var durationPlayer: TimeInterval = 0
    private var counterSecondPlayer: TimeInterval = 0

    private var metadata: tableMetadata!
    private var detail: CCDetail!

    private var safeAreaBottom: Int = 0
    private let dimButton: CGFloat = 30.0
    
    @objc public init(metadata: tableMetadata, detail: CCDetail) {
        super.init()
        
        self.metadata = metadata
        self.detail = detail
    }
    
    @objc public func viewImagemeter() {
        
        guard let rootView = UIApplication.shared.keyWindow else {
            return
        }
        if #available(iOS 11.0, *) {
            safeAreaBottom = Int(rootView.safeAreaInsets.bottom)
        }
        
        for view in self.detail.view.subviews {
            if view is IMImagemeterView {
                view.removeFromSuperview()
            }
        }
        
        let bundleDirectory = IMImagemeter.sharedInstance.getBundleDirectory(metadata: metadata)
        self.bundleDirectory = bundleDirectory.bundleDirectory
        self.immFileNamePath = bundleDirectory.immPath

        self.imagemeterView = IMImagemeterView.instanceFromNib() as? IMImagemeterView
        self.imagemeterView.frame = CGRect(x: 0, y: 0, width: Int(detail.view.frame.width), height: Int(detail.view.frame.height) - Int(k_detail_Toolbar_Height) - safeAreaBottom - 1)
        
        detail.view.addSubview(imagemeterView)
        
        do {
            
            let annoData = try Data(contentsOf: NSURL(fileURLWithPath: immFileNamePath) as URL, options: .mappedIfSafe)
            if let annotation = IMImagemeterCodable.sharedInstance.decoderAnnotetion(annoData) {
                
                self.annotation = annotation
                imageImagemeter()
                audioImagemeter()
                
            } else {
                appDelegate.messageNotification("_error_", description: "_error_json_decoding_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
            }
            
        } catch {
            print("error:\(error)")
        }
    }

    private func imageImagemeter() {
        
        guard let annotation = self.annotation else {
            return
        }
        
        let imageFilename = annotation.image.filename
        if let image = UIImage(contentsOfFile: bundleDirectory + "/" + imageFilename) {
            
            let factor = image.size.width / image.size.height
            
            imagemeterView.imageHeightConstraint.constant = imagemeterView.bounds.size.width / factor
            imagemeterView.image.image = NCUtility.sharedInstance.resizeImage(image: image, newWidth: imagemeterView.bounds.size.width)
        }
    }
    
    private func audioImagemeter() {
        
        guard let annotation = self.annotation else {
            return
        }
        
        if annotation.elements != nil {
            for element in annotation.elements! {
                
                if element.audio_recording == nil {
                    continue
                }
                
                let center = IMImagemeterCodable.sharedInstance.convertCoordinate(x: element.center?.x ?? 0, y: element.center?.y ?? 0, width: imagemeterView.bounds.width, height: imagemeterView.imageHeightConstraint.constant)
                
                let button = UIButton()
                button.frame = CGRect(x: center.x - dimButton/2, y: center.y - dimButton/2, width: dimButton, height: dimButton)
                button.setImage(UIImage(named: "audioPlayFull"), for: .normal)
                button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
                button.tag = element.id
        
                imagemeterView.image.addSubview(button)
                
                if element.arrows != nil {
                    for arrow in element.arrows! {
                        let endPt = IMImagemeterCodable.sharedInstance.convertCoordinate(x: arrow.end_pt.x, y: arrow.end_pt.y, width: imagemeterView.bounds.width, height: imagemeterView.imageHeightConstraint.constant)
                        imagemeterView.image.image = drawLineOnImage(startingImage: imagemeterView.image.image!, x: center.x, y: center.y, endX: endPt.x, endY: endPt.y, color: .yellow, size: 1.5)
                    }
                }
            }
        }
    }
    
    private func drawLineOnImage(startingImage: UIImage, x: CGFloat, y: CGFloat, endX:CGFloat, endY:CGFloat, color: UIColor, size: CGFloat) -> UIImage {
        
        // Create a context of the starting image size and set it as the current one
        UIGraphicsBeginImageContext(startingImage.size)
        
        // Draw the starting image in the current context as background
        startingImage.draw(at: CGPoint.zero)
        
        // Get the current context
        let context = UIGraphicsGetCurrentContext()!
        
        // Draw a red line
        context.setLineWidth(size)
        context.setStrokeColor(color.cgColor)
        context.move(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: endX, y: endY))
        context.strokePath()
        
        // Save the context as a new UIImage
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image!
    }
    
    @objc private func buttonAction(sender: UIButton!) {
        
        guard let annotation = self.annotation else {
            return
        }
        
        for element in annotation.elements! {
            if element.id == sender.tag {
                do {

                    let fileNamePath =  bundleDirectory + "/" + element.audio_recording!.recording_filename
                    try audioPlayer = AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileNamePath))
                    audioPlayer.delegate = self
                    audioPlayer.prepareToPlay()
                    audioPlayer.play()

                    durationPlayer = TimeInterval(audioPlayer.duration)
                    counterSecondPlayer = 0
                    timer.invalidate()
                    timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)

                } catch {
                    
                }
            }
        }
    }
    
    @objc private func updateTimer() {
        counterSecondPlayer += 1
        imagemeterView.progressView.progress = Float(counterSecondPlayer / durationPlayer)
    }
}

extension NCViewerImagemeter: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        updateTimer()
        timer.invalidate()
        counterSecondPlayer = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.imagemeterView.progressView.progress = 0
        }
    }
}

class IMImagemeterView: UIView {
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressView: UIProgressView!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "IMImagemeterView", bundle: nil).instantiate(withOwner: nil, options: nil)[0] as! UIView
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        image.isUserInteractionEnabled = true
        
        progressView.progressTintColor = NCBrandColor.sharedInstance.brandElement
        progressView.trackTintColor = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
        progressView.progress = 0
    }
}
