//
//  NCAudioRecorderViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/03/19.
//  Copyright (c) 2019 Marino Faggiana. All rights reserved.
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
//  --------------------------------
//  Based on code of Venkat Kukunuru
//  --------------------------------

import Foundation
import UIKit
import AVFoundation
import QuartzCore

@objc protocol NCAudioRecorderViewControllerDelegate : class {
    func didFinishRecording(_ viewController: NCAudioRecorderViewController, fileName: String)
    func didFinishWithoutRecording(_ viewController: NCAudioRecorderViewController, fileName: String)
}

class NCAudioRecorderViewController: UIViewController , NCAudioRecorderDelegate {
    
    open weak var delegate: NCAudioRecorderViewControllerDelegate?
    var recording: NCAudioRecorder!
    var recordDuration: TimeInterval = 0
    var fileName: String = ""
    
    @IBOutlet weak var contentContainerView: UIView!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var startStopLabel: UILabel!
    @IBOutlet weak var voiceRecordHUD: VoiceRecordHUD!
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        contentContainerView.backgroundColor = UIColor.lightGray
        voiceRecordHUD.update(0.0)
        voiceRecordHUD.fillColor = UIColor.green
        durationLabel.text = ""
        startStopLabel.text = NSLocalizedString("_voice_memo_start_", comment: "")
    }
    
    func createRecorder(fileName: String) {
        
        self.fileName = fileName
        recording = NCAudioRecorder(to: fileName)
        recording.delegate = self

        DispatchQueue.global().async {
            // Background thread
            do {
                try self.recording.prepare()
            } catch {
                print(error)
            }
        }
    }
    
    @IBAction func touchViewController() {
        
        if recording.state == .record {
            startStop()
        } else {
            dismiss(animated: true) {
                self.delegate?.didFinishWithoutRecording(self, fileName: self.fileName)
            }
        }
    }
    
    @IBAction func startStop() {
        
        if recording.state == .record {
        
            recordDuration = 0
            recording.stop()
            voiceRecordHUD.update(0.0)
        
            dismiss(animated: true) {
                self.delegate?.didFinishRecording(self, fileName: self.fileName)
            }
        } else {
            
            recordDuration = 0
            do {
                try recording.record()
                startStopLabel.text = NSLocalizedString("_voice_memo_stop_", comment: "")
            } catch {
                print(error)
            }
        }
    }
    
    func audioMeterDidUpdate(_ db: Float) {
        
        //print("db level: %f", db)
        
        self.recording.recorder?.updateMeters()
        let ALPHA = 0.05
        let peakPower = pow(10, (ALPHA * Double((self.recording.recorder?.peakPower(forChannel: 0))!)))
        var rate: Double = 0.0
        if (peakPower <= 0.2) {
            rate = 0.2
        } else if (peakPower > 0.9) {
            rate = 1.0
        } else {
            rate = peakPower
        }
        
        voiceRecordHUD.update(CGFloat(rate))
        voiceRecordHUD.fillColor = UIColor.green
        recordDuration += 1
        durationLabel.text = NCUtility.shared.formatSecondsToString(recordDuration/60)
    }
}

@objc public protocol NCAudioRecorderDelegate: AVAudioRecorderDelegate {
    @objc optional func audioMeterDidUpdate(_ dB: Float)
}

open class NCAudioRecorder : NSObject {
    
    @objc public enum State: Int {
        case none, record, play
    }
    
    static var directory: String {
        return NSTemporaryDirectory()
    }
    
    open weak var delegate: NCAudioRecorderDelegate?
    open fileprivate(set) var url: URL
    open fileprivate(set) var state: State = .none
    
    open var bitRate = 192000
    open var sampleRate = 44100.0
    open var channels = 1
    
    fileprivate let session = AVAudioSession.sharedInstance()
    var recorder: AVAudioRecorder?
    fileprivate var player: AVAudioPlayer?
    fileprivate var link: CADisplayLink?
    
    var metering: Bool {
        return delegate?.responds(to: #selector(NCAudioRecorderDelegate.audioMeterDidUpdate(_:))) == true
    }
    
    // MARK: - Initializers
    
    public init(to: String) {
        url = URL(fileURLWithPath: NCAudioRecorder.directory).appendingPathComponent(to)
        super.init()
    }
    
    // MARK: - Record
    
    open func prepare() throws {
        let settings: [String: AnyObject] = [
            AVFormatIDKey : NSNumber(value: Int32(kAudioFormatAppleLossless) as Int32),
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue as AnyObject,
            AVEncoderBitRateKey: bitRate as AnyObject,
            AVNumberOfChannelsKey: channels as AnyObject,
            AVSampleRateKey: sampleRate as AnyObject
        ]
        
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.prepareToRecord()
        recorder?.delegate = delegate
        recorder?.isMeteringEnabled = metering
    }
    
    open func record() throws {
        if recorder == nil {
            try prepare()
        }
        
        try session.setCategory(.playAndRecord, mode: .default)
        try session.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        
        recorder?.record()
        state = .record
        
        if metering {
            startMetering()
        }
    }
    
    open func play() throws {
        if recorder == nil {
            try prepare()
        }
        
        try session.setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()

        player?.play()
        state = .play
    }
    
    open func stop() {
        switch state {
        case .play:
            player?.stop()
            player = nil
        case .record:
            recorder?.stop()
            recorder = nil
            stopMetering()
        default:
            break
        }
        
        state = .none
    }
    
    // MARK: - Metering
    
    @objc func updateMeter() {
        guard let recorder = recorder else { return }
        
        recorder.updateMeters()
        
        let dB = recorder.averagePower(forChannel: 0)
        
        delegate?.audioMeterDidUpdate?(dB)
    }
    
    fileprivate func startMetering() {
        link = CADisplayLink(target: self, selector: #selector(NCAudioRecorder.updateMeter))
        link?.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
    }
    
    fileprivate func stopMetering() {
        link?.invalidate()
        link = nil
    }
}

@IBDesignable
class VoiceRecordHUD: UIView {
    @IBInspectable var rate: CGFloat = 0.0
    
    @IBInspectable var fillColor: UIColor = UIColor.green {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var image: UIImage! {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        image = UIImage(named: "microphone")
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        image = UIImage(named: "microphone")
    }
    
    func update(_ rate: CGFloat) {
        self.rate = rate
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0, y: bounds.size.height)
        context?.scaleBy(x: 1, y: -1)
        
        context?.draw(image.cgImage!, in: bounds)
        context?.clip(to: bounds, mask: image.cgImage!)
        
        context?.setFillColor(fillColor.cgColor.components!)
        context?.fill(CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * rate))
    }
    
    override func prepareForInterfaceBuilder() {
        let bundle = Bundle(for: type(of: self))
        image = UIImage(named: "microphone", in: bundle, compatibleWith: self.traitCollection)
    }
}
