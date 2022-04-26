//
//  NCPlayer+MFFFDelegate
//  Nextcloud
//
//  Created by Marino Faggiana on 31/12/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import NCCommunication
import UIKit
import AVFoundation
import MediaPlayer
import Alamofire
import RealmSwift
import ffmpegkit

extension NCPlayer: MFFFDelegate {

    // MARK: - NCPlayer
    @objc func convertVideoDidFinish(_ notification: Notification) {
        guard let mfffResponse = notification.object as? MFFFResponse,
              let mfffResponseocId = mfffResponse.ocId else {
            return
        }
        let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        if MFFF.shared.existsMFFFSession(url: url) {
            MFFF.shared.removeMFFFSession(url: url)
        }
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: mfffResponseocId), object: nil)

        func updatePlayer() {
            if mfffResponse.returnCode?.isValueSuccess() ?? false,
               let urlVideo = mfffResponse.url {

                self.url = urlVideo
                self.isProxy = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.openAVPlayer()
                }

            } else if mfffResponse.returnCode?.isValueCancel() ?? false {
                print("cancel")
                self.openAVPlayer()
            } else {
                MFFF.shared.showMessage(title: "_error_",
                                      description: "_error_something_wrong_",
                                      backgroundColor: NCBrandColor.shared.brand,
                                      color: NCBrandColor.shared.brandText,
                                      dismissAfterSeconds: NCGlobal.shared.dismissAfterSecond,
                                      view: viewController?.view)
            }
        }

        if let currentTopViewController = UIApplication.topViewController() as? NCViewerMediaPage {
            if let responseOcId = mfffResponse.ocId {
                let ocId = currentTopViewController.currentViewController.metadata.ocId

                if responseOcId == ocId {
                    updatePlayer()
                }
            }
        }
    }

    func convertVideo(withAlert: Bool) {

        let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        let urlOut = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: NCGlobal.shared.fileNameVideoEncoded))
        let tableVideo = NCManageDatabase.shared.getVideo(metadata: metadata)
        let view: UIView? = viewController?.view

        func MFFFConvertVideo() {
            MFFF.shared.convertVideo(url: url,
                                   urlOut: urlOut,
                                   serverUrl: self.metadata.serverUrl,
                                   fileName: self.metadata.fileNameView,
                                   contentType: self.metadata.contentType,
                                   ocId: self.metadata.ocId,
                                   codecNameVideo: tableVideo?.codecNameVideo,
                                   codecNameAudio: tableVideo?.codecNameAudio,
                                   channelLayout: tableVideo?.codecAudioChannelLayout,
                                   languageAudio: tableVideo?.codecAudioLanguage,
                                   maxCompatibility: tableVideo?.codecMaxCompatibility ?? false,
                                   codecQuality: tableVideo?.codecQuality,
                                   verifyAlreadyCodec: false)

        }

        if !(MFFF.shared.existsMFFFSession(url: url)) {

            if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {

                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""),
                                                        message: NSLocalizedString("_video_must_download_", comment: ""),
                                                        preferredStyle: .alert)

                alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                    self.downloadVideo(requiredConvert: true)
                }))

                alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in
                    MFFF.shared.showMessage(description: "_conversion_available_",
                                          backgroundColor: NCBrandColor.shared.brand,
                                          color: NCBrandColor.shared.brandText,
                                          image: UIImage(named: "iconInfo"),
                                          dismissAfterSeconds: NCGlobal.shared.dismissAfterSecond,
                                          view: view)
                }))

                appDelegate.window?.rootViewController?.present(alertController, animated: true)

            } else {

                if withAlert {

                    let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""),
                                                            message: NSLocalizedString("_video_format_not_recognized_", comment: ""),
                                                            preferredStyle: .alert)

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                        MFFFConvertVideo()
                    }))

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in
                        MFFF.shared.showMessage(description: "_conversion_available_",
                                              backgroundColor: NCBrandColor.shared.brand,
                                              color: NCBrandColor.shared.brandText,
                                              image: UIImage(named: "iconInfo"),
                                              dismissAfterSeconds: NCGlobal.shared.dismissAfterSecond,
                                              view: view)
                    }))

                    appDelegate.window?.rootViewController?.present(alertController, animated: true)

                } else {
                    MFFFConvertVideo()
                }
            }
        }
    }

    // MARK: - MFFFDelegate

    func sessionStarted(url: URL, ocId: String?, traces: [MFFFTrace]?) {

        self.playerToolBar?.hide()
    }

    func sessionProgress(url: URL, ocId: String?, traces: [MFFFTrace]?, progress: Float) {

        guard self.metadata.ocId == ocId, let traces = traces, self.viewController is NCViewerMedia else { return }

        self.playerToolBar?.hide()

        var description = NSLocalizedString("_stay_app_foreground_", value: "Stay with the app in the foreground…", comment: "")

        if (traces.filter { $0.conversion == true }).isEmpty == false {
            description = NSLocalizedString("_stay_app_foreground_", value: "Stay with the app in the foreground…", comment: "") + "\n" + NSLocalizedString("_reuired_conversion_", value: "This video takes a long time to convert.", comment: "")
        }

        MFFF.shared.messageProgress(title: "_video_being_processed_",
                                  description: description,
                                  descriptionBottomAutoHidden: "_video_tap_for_close_",
                                  backgroundColor: NCBrandColor.shared.brand,
                                  color: NCBrandColor.shared.brandText,
                                  view: viewController!.view,
                                  progress: progress)
    }

    func sessionEnded(url: URL, ocId: String?, returnCode: Int?, traces: [MFFFTrace]?, maxCompatibility: Bool, codecQuality: String?) {

        if self.metadata.ocId == ocId {
            MFFF.shared.dismissMessage()
            self.playerToolBar?.show()
        }

        if returnCode == 0, let traces = traces, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            let traceVideo = traces.filter { $0.codecType == "video" }.first
            let traceAudio = traces.filter { $0.codecType == "audio" }.first

            NCManageDatabase.shared.addVideoCodec(metadata: metadata,
                                                  codecNameVideo: traceVideo?.codecName,
                                                  codecNameAudio: traceAudio?.codecName,
                                                  codecAudioChannelLayout: traceAudio?.channelLayout,
                                                  codecAudioLanguage: traceAudio?.language,
                                                  codecMaxCompatibility: maxCompatibility,
                                                  codecQuality: codecQuality)
        }
    }
}
