//
//  NCPlayerToolBar.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/07/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import CoreMedia
import UIKit
import AVKit
import MediaPlayer
import MobileVLCKit
import FloatingPanel

class NCPlayerToolBar: UIView {

    @IBOutlet weak var playerTopToolBarView: UIStackView!
    @IBOutlet weak var playerToolBarView: UIView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var subtitleButton: UIButton!
    @IBOutlet weak var audioButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var playbackSlider: UISlider!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var labelLeftTime: UILabel!
    @IBOutlet weak var labelCurrentTime: UILabel!
    @IBOutlet weak var volumeSliderConstraintWidth: NSLayoutConstraint!
    @IBOutlet weak var volumeSliderConstraintTrailing: NSLayoutConstraint!

    enum sliderEventType {
        case began
        case ended
        case moved
    }
    var playbackSliderEvent: sliderEventType = .ended

    private var ncplayer: NCPlayer?
    private var metadata: tableMetadata?

    private var subTitleIndex: Int32?
    private var audioIndex: Int32?
    
    private weak var viewerMediaPage: NCViewerMediaPage?

    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()

        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerToolBarView.insertSubview(blurEffectView, at: 0)
        playerTopToolBarView.layer.cornerRadius = 10
        playerTopToolBarView.layer.masksToBounds = true
        playerTopToolBarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapTopToolBarWith(gestureRecognizer:))))

        let blurEffectTopToolBarView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurEffectTopToolBarView.frame = playerTopToolBarView.bounds
        blurEffectTopToolBarView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerTopToolBarView.insertSubview(blurEffectTopToolBarView, at: 0)
        playerToolBarView.layer.cornerRadius = 10
        playerToolBarView.layer.masksToBounds = true
        playerToolBarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapToolBarWith(gestureRecognizer:))))

        playbackSlider.value = 0
        playbackSlider.tintColor = .lightGray

        labelCurrentTime.textColor = .white
        labelLeftTime.textColor = .white

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)

        subtitleButton.setImage(NCUtility.shared.loadImage(named: "captions.bubble", color: .white), for: .normal)
        subtitleButton.isEnabled = false
        
        audioButton.setImage(NCUtility.shared.loadImage(named: "speaker.zzz", color: .white), for: .normal)
        audioButton.isEnabled = false

        backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .white), for: .normal)

        forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .white), for: .normal)

        volumeSliderConstraintWidth.constant = self.frame.size.width / 2
        volumeSliderConstraintTrailing.constant = -(volumeSliderConstraintWidth.constant / 2) + 15
        volumeSlider.value = AVAudioSession.sharedInstance().outputVolume
        volumeSlider.tintColor = .white
        volumeSlider.setThumbImage(UIImage(), for: .normal)
        volumeSlider.maximumValueImage = NCUtility.shared.loadImage(named: "speaker.wave.3", color: .white).rotate(radians: .pi / 2)

        // Normally hide
        self.alpha = 0
        self.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        print("deinit NCPlayerToolBar")
    }

    // MARK: -

    func setBarPlayer(ncplayer: NCPlayer, position: Float, metadata: tableMetadata, viewerMediaPage: NCViewerMediaPage?) {

        self.ncplayer = ncplayer
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0

        playbackSlider.value = position
        playbackSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)

        labelCurrentTime.text = ncplayer.player?.time.stringValue
        labelLeftTime.text = ncplayer.player?.remainingTime?.stringValue

        if CCUtility.getAudioVolume() == 0 {
            ncplayer.setVolumeAudio(0)
        } else {
            ncplayer.setVolumeAudio(100)
        }

        if viewerMediaScreenMode == .normal {
            show()
        } else {
            hide()
        }
    }

    public func update() {

        guard let ncplayer = self.ncplayer,
              let length = ncplayer.player?.media?.length.intValue,
              let position = ncplayer.player?.position
        else { return }
        let positionInSecond = position * Float(length / 1000)

        // SLIDER & TIME
        if playbackSliderEvent == .ended {
            playbackSlider.value = position
        }
        labelCurrentTime.text = ncplayer.player?.time.stringValue
        labelLeftTime.text = ncplayer.player?.remainingTime?.stringValue
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = length / 1000
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = positionInSecond
    }

    public func updateTopToolBar(videoSubTitlesIndexes: [Any], audioTrackIndexes: [Any]) {

        self.subtitleButton.isEnabled = !videoSubTitlesIndexes.isEmpty
        self.audioButton.isEnabled = !audioTrackIndexes.isEmpty
    }

    // MARK: -

    public func show() {

        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 1
        }, completion: { (_: Bool) in
            self.isHidden = false
        })
    }

    func hide() {

        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }, completion: { (_: Bool) in
            self.isHidden = true
        })
    }

    func playButtonPause() {

        playButton.setImage(NCUtility.shared.loadImage(named: "pause.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
    }

    func playButtonPlay() {

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
    }

    // MARK: - Event / Gesture

    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {

        guard let touchEvent = event.allTouches?.first,
              let ncplayer = ncplayer
        else { return }

        let newPosition = playbackSlider.value

        switch touchEvent.phase {
        case .began:
            viewerMediaPage?.timerAutoHide?.invalidate()
            playbackSliderEvent = .began
        case .moved:
            ncplayer.playerPosition(newPosition)
            playbackSliderEvent = .moved
        case .ended:
            ncplayer.playerPosition(newPosition)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.playbackSliderEvent = .ended
                self.viewerMediaPage?.startTimerAutoHide()
            }
        default:
            break
        }
    }

    // MARK: - Action

    @objc func tapTopToolBarWith(gestureRecognizer: UITapGestureRecognizer) { }

    @objc func tapToolBarWith(gestureRecognizer: UITapGestureRecognizer) { }

    @IBAction func tapPlayerPause(_ sender: Any) {
        guard let ncplayer = ncplayer else { return }

        if ncplayer.isPlay() {
            ncplayer.playerPause()
        } else {
            ncplayer.playerPlay()
        }

        self.viewerMediaPage?.startTimerAutoHide()
    }

    @IBAction func tapMute(_ sender: Any) {

        /*
        guard let ncplayer = ncplayer else { return }

        if CCUtility.getAudioVolume() > 0 {
            CCUtility.setAudioVolume(0)
            ncplayer.setVolumeAudio(0)
        } else {
            CCUtility.setAudioVolume(100)
            ncplayer.setVolumeAudio(100)
        }

        self.viewerMediaPage?.startTimerAutoHide()
        */
    }

    @IBAction func tapSubTitle(_ sender: Any) {

        guard let player = ncplayer?.player else { return }

        let spuTracks = player.videoSubTitlesNames
        let spuTrackIndexes = player.videoSubTitlesIndexes
        let count = spuTracks.count

        if count > 1 {
            toggleMenuSubTitle(spuTracks: spuTracks, spuTrackIndexes: spuTrackIndexes)
        }
    }

    @IBAction func tapAudio(_ sender: Any) {

        guard let player = ncplayer?.player else { return }

        let audioTracks = player.audioTrackNames
        let audioTrackIndexes = player.audioTrackIndexes
        let count = audioTracks.count

        if count > 1 {
            toggleMenuAudio(audioTracks: audioTracks, audioTrackIndexes: audioTrackIndexes)
        }
    }

    @IBAction func tapForward(_ sender: Any) {

        guard let ncplayer = ncplayer else { return }

        ncplayer.jumpForward(10)

        self.viewerMediaPage?.startTimerAutoHide()
    }

    @IBAction func tapBack(_ sender: Any) {

        guard let ncplayer = ncplayer else { return }

        ncplayer.jumpBackward(10)

        self.viewerMediaPage?.startTimerAutoHide()
    }
}

extension NCPlayerToolBar {

    func toggleMenuSubTitle(spuTracks: [Any], spuTrackIndexes: [Any]) {

        var actions = [NCMenuAction]()

        if self.subTitleIndex == nil, let idx = ncplayer?.player?.currentVideoSubTitleIndex {
            self.subTitleIndex = idx
        }

        for index in 0...spuTracks.count - 1 {

            guard let title = spuTracks[index] as? String, let idx = spuTrackIndexes[index] as? Int32 else { return }

            actions.append(
                NCMenuAction(
                    title: title,
                    icon: UIImage(),
                    onTitle: title,
                    onIcon: UIImage(),
                    selected: (self.subTitleIndex ?? -9999) == idx,
                    on: (self.subTitleIndex ?? -9999) == idx,
                    action: { _ in
                        self.ncplayer?.player?.currentVideoSubTitleIndex = idx
                        self.subTitleIndex = idx
                    }
                )
            )
        }

        viewerMediaPage?.presentMenu(with: actions, menuColor: .darkGray, textColor: .white)
    }

    func toggleMenuAudio(audioTracks: [Any], audioTrackIndexes: [Any]) {

        var actions = [NCMenuAction]()

        if self.audioIndex == nil, let idx = ncplayer?.player?.currentAudioTrackIndex {
            self.audioIndex = idx
        }

        for index in 0...audioTracks.count - 1 {

            guard let title = audioTracks[index] as? String, let idx = audioTrackIndexes[index] as? Int32 else { return }

            actions.append(
                NCMenuAction(
                    title: title,
                    icon: UIImage(),
                    onTitle: title,
                    onIcon: UIImage(),
                    selected: (self.audioIndex ?? -9999) == idx,
                    on: (self.audioIndex ?? -9999) == idx,
                    action: { _ in
                        self.ncplayer?.player?.currentAudioTrackIndex = idx
                        self.audioIndex = idx
                    }
                )
            )
        }

        viewerMediaPage?.presentMenu(with: actions, menuColor: .darkGray, textColor: .white)
    }
}
