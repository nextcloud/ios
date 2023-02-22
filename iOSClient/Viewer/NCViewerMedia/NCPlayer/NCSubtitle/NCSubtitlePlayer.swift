//
//  NCSubtitlePlayer.swift
//  Nextcloud
//
//  Created by Federico Malagoni on 18/02/22.
//  Copyright © 2022 Federico Malagoni. All rights reserved.
//  Copyright © 2022 Marino Faggiana All rights reserved.
//
//  Author Federico Malagoni <federico.malagoni@astrairidium.com>
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
import AVKit
import NextcloudKit

extension NCPlayer {

    private struct AssociatedKeys {
        static var FontKey = "FontKey"
        static var ColorKey = "FontKey"
        static var SubtitleKey = "SubtitleKey"
        static var SubtitleContainerViewKey = "SubtitleContainerViewKey"
        static var SubtitleContainerViewHeightKey = "SubtitleContainerViewHeightKey"
        static var SubtitleHeightKey = "SubtitleHeightKey"
        static var SubtitleWidthKey = "SubtitleWidthKey"
        static var SubtitleContainerViewWidthKey = "SubtitleContainerViewWidthKey"
        static var SubtitleBottomKey = "SubtitleBottomKey"
        static var PayloadKey = "PayloadKey"
    }

    private var widthProportion: CGFloat {
        return 0.9
    }

    private var bottomConstantPortrait: CGFloat {
        get {
            if UIDevice.current.hasNotch {
                return -60
            } else {
                return -40
            }
        } set {
            _ = newValue
        }
    }

    private var bottomConstantLandscape: CGFloat {
        get {
            if UIDevice.current.hasNotch {
                return -120
            } else {
                return -100
            }
        } set {
            _ = newValue
        }
    }

    var subtitleContainerView: UIView? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleContainerViewKey) as? UIView }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleContainerViewKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }

    var subtitleLabel: UILabel? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleKey) as? UILabel }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var subtitleLabelHeightConstraint: NSLayoutConstraint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleHeightKey) as? NSLayoutConstraint }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleHeightKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var subtitleContainerViewHeightConstraint: NSLayoutConstraint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleContainerViewHeightKey) as? NSLayoutConstraint }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleContainerViewHeightKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var subtitleLabelBottomConstraint: NSLayoutConstraint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleBottomKey) as? NSLayoutConstraint }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleBottomKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var subtitleLabelWidthConstraint: NSLayoutConstraint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleWidthKey) as? NSLayoutConstraint }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleWidthKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    fileprivate var subtitleContainerViewWidthConstraint: NSLayoutConstraint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleContainerViewWidthKey) as? NSLayoutConstraint }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleContainerViewWidthKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var parsedPayload: NSDictionary? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.PayloadKey) as? NSDictionary }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.PayloadKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func setUpForSubtitle() {
        self.subtitleUrls.removeAll()
        if let url = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) {
            let enumerator = FileManager.default.enumerator(atPath: url)
            let filePaths = (enumerator?.allObjects as? [String])
            if let filePaths = filePaths {
                let txtFilePaths = (filePaths.filter { $0.contains(".srt") }).sorted {
                    guard let str1LastChar = $0.dropLast(4).last, let str2LastChar = $1.dropLast(4).last else {
                        return false
                    }
                    return str1LastChar < str2LastChar
                }
                for txtFilePath in txtFilePaths {
                    let subtitleUrl = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: txtFilePath))
                    self.subtitleUrls.append(subtitleUrl)
                }
            }
        }
        let (all, existing) = NCManageDatabase.shared.getSubtitles(account: metadata.account, serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        if !existing.isEmpty {
            for subtitle in existing {
                let subtitleUrl = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(subtitle.ocId, fileNameView: subtitle.fileName))
                self.subtitleUrls.append(subtitleUrl)
            }
        }
        if all.count != existing.count {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_subtitle_not_dowloaded_")
            NCContentPresenter.shared.showInfo(error: error)
        }
        self.setSubtitleToolbarIcon(subtitleUrls: subtitleUrls)
        self.hideSubtitle()
    }

    func setSubtitleToolbarIcon(subtitleUrls: [URL]) {
        if subtitleUrls.isEmpty {
            playerToolBar?.subtitleButton.isHidden = true
        } else {
            playerToolBar?.subtitleButton.isHidden = false
        }
    }

    func addSubtitlesTo(_ vc: UIViewController, _ playerToolBar: NCPlayerToolBar?) {
        addSubtitleLabel(vc, playerToolBar)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRotated(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    func loadText(filePath: URL, _ completion: @escaping (_ contents: String?) -> Void) {
        DispatchQueue.global().async {
            guard let data = try? Data(contentsOf: filePath),
                  let encoding = NCUtility.shared.getEncondingDataType(data: data) else {
                return
            }
            if let decodedString = String(data: data, encoding: encoding) {
                completion(decodedString)
            } else {
                completion(nil)
            }
         }
    }

    func open(fileFromLocal url: URL) {

        subtitleLabel?.text = ""

        self.loadText(filePath: url) { contents in
            guard let contents = contents else {
                return
            }
            DispatchQueue.main.async {
                self.subtitleLabel?.text = ""
                self.show(subtitles: contents)
            }
        }
    }

    @objc public func hideSubtitle() {
        self.subtitleLabel?.isHidden = true
        self.subtitleContainerView?.isHidden = true
        self.currentSubtitle = nil
    }

    @objc public func showSubtitle(url: URL) {
        self.subtitleLabel?.isHidden = false
        self.subtitleContainerView?.isHidden = false
        self.currentSubtitle = url
    }

    private func show(subtitles string: String) {
        parsedPayload = try? NCSubtitles.parseSubRip(string)
        if let parsedPayload = parsedPayload {
            addPeriodicNotification(parsedPayload: parsedPayload)
        }
    }

    private func showByDictionary(dictionaryContent: NSMutableDictionary) {
        parsedPayload = dictionaryContent
        if let parsedPayload = parsedPayload {
            addPeriodicNotification(parsedPayload: parsedPayload)
        }
    }

    func addPeriodicNotification(parsedPayload: NSDictionary) {
        // Add periodic notifications
        let interval = CMTimeMake(value: 1, timescale: 60)
        self.player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let strongSelf = self, let label = strongSelf.subtitleLabel, let containerView = strongSelf.subtitleContainerView else {
                return
            }
            DispatchQueue.main.async {
                label.text = NCSubtitles.searchSubtitles(strongSelf.parsedPayload, time.seconds)
                strongSelf.adjustViewWidth(containerView: containerView)
                strongSelf.adjustLabelHeight(label: label)
            }
        }
    }

    @objc private func deviceRotated(_ notification: Notification) {
        guard let label = self.subtitleLabel,
              let containerView = self.subtitleContainerView else { return }
        DispatchQueue.main.async {
            self.adjustViewWidth(containerView: containerView)
            self.adjustLabelHeight(label: label)
            self.adjustLabelBottom(label: label)
            containerView.layoutIfNeeded()
            label.layoutIfNeeded()
        }
    }

    private func adjustLabelHeight(label: UILabel) {
        let baseSize = CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)
        let rect = label.sizeThatFits(baseSize)
        if label.text != nil {
            self.subtitleLabelHeightConstraint?.constant = rect.height + 5.0
        } else {
            self.subtitleLabelHeightConstraint?.constant = rect.height
        }
    }

    private func adjustLabelBottom(label: UILabel) {
        var bottomConstant: CGFloat = bottomConstantPortrait

        switch UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
        case .portrait:
            bottomConstant = bottomConstantLandscape
        case .landscapeLeft, .landscapeRight, .portraitUpsideDown:
            bottomConstant = bottomConstantPortrait
        default:
            ()
        }
        subtitleLabelBottomConstraint?.constant = bottomConstant
    }

    private func adjustViewWidth(containerView: UIView) {
        let widthConstant: CGFloat = UIScreen.main.bounds.width * widthProportion
        subtitleContainerViewWidthConstraint!.constant = widthConstant
        subtitleLabel?.preferredMaxLayoutWidth = (widthConstant - 20)
    }

    fileprivate func addSubtitleLabel(_ vc: UIViewController, _ playerToolBar: NCPlayerToolBar?) {
        guard subtitleLabel == nil,
              subtitleContainerView == nil else {
                  return
              }
        subtitleContainerView = UIView()
        subtitleLabel = UILabel()

        subtitleContainerView?.translatesAutoresizingMaskIntoConstraints = false
        subtitleContainerView?.layer.cornerRadius = 5.0
        subtitleContainerView?.layer.masksToBounds = true
        subtitleContainerView?.layer.shouldRasterize = true
        subtitleContainerView?.layer.rasterizationScale = UIScreen.main.scale
        subtitleContainerView?.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        subtitleLabel?.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel?.textAlignment = .center
        subtitleLabel?.numberOfLines = 0
        let fontSize = UIDevice.current.userInterfaceIdiom == .pad ? 38.0 : 20.0
        subtitleLabel?.font = UIFont.incosolataMedium(size: fontSize)
        subtitleLabel?.lineBreakMode = .byWordWrapping
        subtitleLabel?.textColor = .white
        subtitleLabel?.backgroundColor = .clear

        subtitleContainerView?.addSubview(subtitleLabel!)

        var isFound = false

        for v in vc.view.subviews where v is UIScrollView {
            if let scrollView = v as? UIScrollView {
                for subView in scrollView.subviews where subView is imageVideoContainerView {
                    subView.addSubview(subtitleContainerView!)
                    isFound = true
                    break
                }
            }
        }

        if !isFound {
            vc.view.addSubview(subtitleContainerView!)
        }

        NSLayoutConstraint.activate([
            subtitleLabel!.centerXAnchor.constraint(equalTo: subtitleContainerView!.centerXAnchor),
            subtitleLabel!.centerYAnchor.constraint(equalTo: subtitleContainerView!.centerYAnchor)
        ])

        subtitleContainerViewHeightConstraint = NSLayoutConstraint(item: subtitleContainerView!, attribute: .height, relatedBy: .equal, toItem: subtitleLabel!, attribute: .height, multiplier: 1.0, constant: 0.0)
        vc.view?.addConstraint(subtitleContainerViewHeightConstraint!)

        var bottomConstant: CGFloat = bottomConstantPortrait

        switch UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
        case .portrait, .portraitUpsideDown:
            bottomConstant = bottomConstantLandscape
        case .landscapeLeft, .landscapeRight:
            bottomConstant = bottomConstantPortrait
        default:
            ()
        }

        let widthConstant: CGFloat = UIScreen.main.bounds.width * widthProportion

        NSLayoutConstraint.activate([
            subtitleContainerView!.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor)
        ])

        subtitleContainerViewWidthConstraint = NSLayoutConstraint(item: subtitleContainerView!, attribute: .width, relatedBy: .lessThanOrEqual, toItem: nil,
                                                                  attribute: .width, multiplier: 1, constant: widthConstant)

        // setting default width == 0 because there is no text inside of the label
        subtitleLabelWidthConstraint = NSLayoutConstraint(item: subtitleLabel!, attribute: .width, relatedBy: .equal, toItem: subtitleContainerView,
                                                          attribute: .width, multiplier: 1, constant: -20)

        subtitleLabelBottomConstraint = NSLayoutConstraint(item: subtitleContainerView!, attribute: .bottom, relatedBy: .equal, toItem: vc.view, attribute:
                                                                .bottom, multiplier: 1, constant: bottomConstant)

        vc.view?.addConstraint(subtitleContainerViewWidthConstraint!)
        vc.view?.addConstraint(subtitleLabelWidthConstraint!)
        vc.view?.addConstraint(subtitleLabelBottomConstraint!)
    }

    internal func showAlertSubtitles() {

        let alert = UIAlertController(title: nil, message: NSLocalizedString("_subtitle_", comment: ""), preferredStyle: .actionSheet)

        for url in subtitleUrls {

            print("Play Subtitle at:\n\(url.path)")

            let videoUrlTitle = self.metadata.fileName.alphanumeric.dropLast(3)
            let subtitleUrlTitle = url.lastPathComponent.alphanumeric.dropLast(3)

            var titleSubtitle = String(subtitleUrlTitle.dropFirst(videoUrlTitle.count))
            if titleSubtitle.isEmpty {
                titleSubtitle = NSLocalizedString("_subtitle_", comment: "")
            }

            let action = UIAlertAction(title: titleSubtitle, style: .default, handler: { [self] _ in

                if NCUtilityFileSystem.shared.getFileSize(filePath: url.path) > 0 {

                    self.open(fileFromLocal: url)
                    if let viewController = viewController {
                        self.addSubtitlesTo(viewController, self.playerToolBar)
                        self.showSubtitle(url: url)
                    }

                } else {

                    let alertError = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_subtitle_not_found_", comment: ""), preferredStyle: .alert)
                    alertError.addAction(UIKit.UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: nil))

                    viewController?.present(alertError, animated: true, completion: nil)
                }
            })
            alert.addAction(action)
            if currentSubtitle == url {
                action.setValue(true, forKey: "checked")
            }
        }

        let disable = UIAlertAction(title: NSLocalizedString("_disable_", comment: ""), style: .default, handler: { _ in
            self.hideSubtitle()
        })
        alert.addAction(disable)
        if currentSubtitle == nil {
            disable.setValue(true, forKey: "checked")
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
        }))

        alert.popoverPresentationController?.sourceView = self.viewController?.view

        self.viewController?.present(alert, animated: true, completion: nil)
    }
}
