//
//  NCContentPresenter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/12/2019.
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

import SwiftEntryKit
import UIKit
import CFNetwork
import NextcloudKit

class NCContentPresenter: NSObject {
    @objc static let shared: NCContentPresenter = {
        let instance = NCContentPresenter()
        return instance
    }()

    typealias MainFont = Font.HelveticaNeue
    enum Font {
        enum HelveticaNeue: String {
            case ultraLightItalic = "UltraLightItalic"
            case medium = "Medium"
            case mediumItalic = "MediumItalic"
            case ultraLight = "UltraLight"
            case italic = "Italic"
            case light = "Light"
            case thinItalic = "ThinItalic"
            case lightItalic = "LightItalic"
            case bold = "Bold"
            case thin = "Thin"
            case condensedBlack = "CondensedBlack"
            case condensedBold = "CondensedBold"
            case boldItalic = "BoldItalic"

            func with(size: CGFloat) -> UIFont {
                return UIFont(name: "HelveticaNeue-\(rawValue)", size: size)!
            }
        }
    }

    @objc enum messageType: Int {
        case error
        case success
        case info
    }

    // MARK: - Message

    func showError(error: NKError, priority: EKAttributes.Precedence.Priority = .normal) {
        messageNotification(
            "_error_",
            error: error,
            delay: NCGlobal.shared.dismissAfterSecond,
            type: .error,
            priority: priority)
    }

    func showInfo(error: NKError, priority: EKAttributes.Precedence.Priority = .normal) {
        messageNotification(
            "_info_",
            error: error,
            delay: NCGlobal.shared.dismissAfterSecond,
            type: .info,
            priority: priority)
    }

    func showInfo(title: String = "", description: String = "") {
        self.flatTop(title: NSLocalizedString(title, comment: ""), description: NSLocalizedString(description, comment: ""), delay: NCGlobal.shared.dismissAfterSecond, imageName: nil, type: .info, priority: .normal)
    }

    func showWarning(error: NKError, priority: EKAttributes.Precedence.Priority = .normal) {
        messageNotification(
            "_warning_",
            error: error,
            delay: NCGlobal.shared.dismissAfterSecond,
            type: .info,
            priority: priority)
    }

    @objc func messageNotification(_ title: String, error: NKError, delay: TimeInterval, type: messageType) {
        messageNotification(title, error: error, delay: delay, type: type, priority: .normal, dropEnqueuedEntries: false)
    }

    func messageNotification(_ title: String, error: NKError, delay: TimeInterval, type: messageType, priority: EKAttributes.Precedence.Priority = .normal, dropEnqueuedEntries: Bool = false) {

        // No notification message for:
        if error.errorCode == NSURLErrorCancelled || error.errorCode == NCGlobal.shared.errorRequestExplicityCancelled { return }
        else if error == .success && type == messageType.error { return }

        DispatchQueue.main.async {
            switch error.errorCode {
            case Int(CFNetworkErrors.cfurlErrorNotConnectedToInternet.rawValue):
                let image = UIImage(named: "networkInProgress")!.image(color: .white, size: 20)
                self.noteTop(text: NSLocalizedString(title, comment: ""), image: image, color: .lightGray, delay: delay, priority: .max)
            default:
                var responseMessage = ""
                if let data = error.responseData {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:Any],
                           let message = json["message"] as? String {
                            responseMessage = "\n\n" + message
                        }
                    } catch {
                        print("Something went wrong")
                    }
                }
                if error.errorDescription.trimmingCharacters(in: .whitespacesAndNewlines) == "" { return }
                let description = NSLocalizedString(error.errorDescription, comment: "")
                self.flatTop(title: NSLocalizedString(title, comment: ""), description: description + responseMessage, delay: delay, imageName: nil, type: type, priority: priority, dropEnqueuedEntries: dropEnqueuedEntries)
            }
        }
    }

    // MARK: - Flat message

    private func flatTop(title: String, description: String, delay: TimeInterval, imageName: String?, type: messageType, priority: EKAttributes.Precedence.Priority = .normal, dropEnqueuedEntries: Bool = false) {

        if SwiftEntryKit.isCurrentlyDisplaying(entryNamed: title + description) { return }

        var attributes = EKAttributes.topFloat
        var image: UIImage?

        attributes.windowLevel = .normal
        attributes.displayDuration = delay
        attributes.name = title + description
        attributes.entryBackground = .color(color: EKColor(getBackgroundColorFromType(type)))
        attributes.popBehavior = .animated(animation: .init(translate: .init(duration: 0.3), scale: .init(from: 1, to: 0.7, duration: 0.7)))
        attributes.shadow = .active(with: .init(color: .black, opacity: 0.5, radius: 10, offset: .zero))
        attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .jolt)
        attributes.precedence = .override(priority: priority, dropEnqueuedEntries: dropEnqueuedEntries)

        let title = EKProperty.LabelContent(text: title, style: .init(font: MainFont.bold.with(size: 16), color: .white))
        let description = EKProperty.LabelContent(text: description, style: .init(font: MainFont.medium.with(size: 13), color: .white))

        if imageName == nil {
            image = getImageFromType(type)
        } else {
            image = UIImage(named: imageName!)
        }
        let imageMessage = EKProperty.ImageContent(image: image!, size: CGSize(width: 35, height: 35))

        let simpleMessage = EKSimpleMessage(image: imageMessage, title: title, description: description)
        let notificationMessage = EKNotificationMessage(simpleMessage: simpleMessage)

        let contentView = EKNotificationMessageView(with: notificationMessage)
        DispatchQueue.main.async { SwiftEntryKit.display(entry: contentView, using: attributes) }
    }

    // MARK: -

    func alertAction(image: UIImage, contentModeImage: UIView.ContentMode = .scaleToFill, sizeImage: CGSize = CGSize(width: 34, height: 34), backgroundColor: UIColor, textColor: UIColor, title: String, description: String, textCancelButton: String, textOkButton: String, attributes: EKAttributes, completion: @escaping (_ identifier: String) -> Void) {

        var buttonAttributes: EKAttributes {
            var attributes = attributes
            attributes.hapticFeedbackType = .success
            attributes.displayDuration = .infinity
            attributes.entryBackground = .color(color: EKColor(backgroundColor))
            attributes.shadow = .active(with: .init(color: .black, opacity: 0.3, radius: 8))
            attributes.screenInteraction = .dismiss
            attributes.entryInteraction = .absorbTouches
            attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .jolt)
            attributes.roundCorners = .all(radius: 25)
            attributes.entranceAnimation = .init(translate: .init(duration: 0.7, spring: .init(damping: 1, initialVelocity: 0)), scale: .init(from: 1.05, to: 1, duration: 0.4, spring: .init(damping: 1, initialVelocity: 0)))
            attributes.exitAnimation = .init(translate: .init(duration: 0.2))
            attributes.popBehavior = .animated(animation: .init(translate: .init(duration: 0.2)))
            attributes.positionConstraints.verticalOffset = 20
            attributes.positionConstraints.size = .init(width: .offset(value: 20), height: .intrinsic)
            attributes.positionConstraints.maxSize = .init(width: .constant(value: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)), height: .intrinsic)
            attributes.statusBar = .dark
            return attributes
        }

        let simpleMessage = EKSimpleMessage(image: EKProperty.ImageContent(image: image, size: sizeImage, contentMode: contentModeImage),
                                            title: EKProperty.LabelContent(text: NSLocalizedString(title, comment: ""), style: .init(font: MainFont.medium.with(size: 15), color: EKColor(textColor)), accessibilityIdentifier: "title"),
                                            description: EKProperty.LabelContent(text: NSLocalizedString(description, comment: ""), style: .init( font: MainFont.light.with(size: 13), color: EKColor(textColor)), accessibilityIdentifier: "description"))

        let cancelButton = EKProperty.ButtonContent(
            label: EKProperty.LabelContent(text: NSLocalizedString(textCancelButton, comment: ""), style: EKProperty.LabelStyle(font: MainFont.medium.with(size: 16), color: EKColor(textColor))),
            backgroundColor: .clear,
            highlightedBackgroundColor: EKColor(UIColor.lightGray),
            accessibilityIdentifier: "close") {
                SwiftEntryKit.dismiss()
                completion("close")
            }

        let okButton = EKProperty.ButtonContent(
            label: EKProperty.LabelContent(text: NSLocalizedString(textOkButton, comment: ""),style: EKProperty.LabelStyle(font: MainFont.medium.with(size: 16), color: EKColor(textColor))),
            backgroundColor: .clear,
            highlightedBackgroundColor: EKColor(UIColor.lightGray),
            displayMode: EKAttributes.DisplayMode.inferred,
            accessibilityIdentifier: "ok") {
                SwiftEntryKit.dismiss()
                completion("ok")
            }

        let buttonsBarContent = EKProperty.ButtonBarContent(with: cancelButton, okButton, separatorColor: EKColor(textColor), buttonHeight: 60, expandAnimatedly: true)
        let alertMessage = EKAlertMessage(simpleMessage: simpleMessage, imagePosition: .left, buttonBarContent: buttonsBarContent)
        let contentView = EKAlertMessageView(with: alertMessage)

        SwiftEntryKit.display(entry: contentView, using: buttonAttributes)
    }


    // MARK: - Note Message

    func noteTop(text: String, image: UIImage?, color: UIColor? = nil, type: messageType? = nil, delay: TimeInterval, priority: EKAttributes.Precedence.Priority = .normal, dropEnqueuedEntries: Bool = false) {

        if SwiftEntryKit.isCurrentlyDisplaying(entryNamed: text) { return }

        DispatchQueue.main.async {
            var attributes = EKAttributes.topNote

            attributes.windowLevel = .normal
            attributes.displayDuration = delay
            attributes.name = text
            if let color = color {
                attributes.entryBackground = .color(color: EKColor(color))
            }
            if let type = type {
                attributes.entryBackground = .color(color: EKColor(self.getBackgroundColorFromType(type)))
            }
            attributes.precedence = .override(priority: priority, dropEnqueuedEntries: dropEnqueuedEntries)

            let style = EKProperty.LabelStyle(font: MainFont.light.with(size: 14), color: .white, alignment: .center)
            let labelContent = EKProperty.LabelContent(text: text, style: style)

            if let image = image {
                let imageContent = EKProperty.ImageContent(image: image, size: CGSize(width: 17, height: 17))
                let contentView = EKImageNoteMessageView(with: labelContent, imageContent: imageContent)
                SwiftEntryKit.display(entry: contentView, using: attributes)
            } else {
                let contentView = EKNoteMessageView(with: labelContent)
                SwiftEntryKit.display(entry: contentView, using: attributes)
            }
        }
    }

    func dismiss(after: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + after) {
            SwiftEntryKit.dismiss()
        }
    }

    // MARK: - Private

    private func getBackgroundColorFromType(_ type: messageType) -> UIColor {
        switch type {
        case .info:
            return NCBrandColor.shared.brandElement
        case .error:
            return UIColor(red: 1, green: 0, blue: 0, alpha: 0.9)
        case .success:
            return UIColor(red: 0.588, green: 0.797, blue: 0, alpha: 0.9)
        default:
            return .white
        }
    }

    private func getImageFromType(_ type: messageType) -> UIImage? {
        switch type {
        case .info:
            return UIImage(named: "iconInfo")
        case .error:
            return UIImage(named: "iconError")
        case .success:
            return UIImage(named: "iconSuccess")
        default:
            return nil
        }
    }

}
