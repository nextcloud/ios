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

    @objc func showGenericError(description: String) {
        messageNotification(
            "_error_", description: description,
            delay: NCGlobal.shared.dismissAfterSecond,
            type: .error,
            errorCode: NCGlobal.shared.errorGeneric)
    }

    @objc func messageNotification(_ title: String, description: String?, delay: TimeInterval, type: messageType, errorCode: Int) {
        messageNotification(title, description: description, delay: delay, type: type, errorCode: errorCode, priority: .normal, dropEnqueuedEntries: false)
    }

    func messageNotification(_ title: String, description: String?, delay: TimeInterval, type: messageType, errorCode: Int, priority: EKAttributes.Precedence.Priority = .normal, dropEnqueuedEntries: Bool = false) {

        // No notification message for:
        if errorCode == -999 { return }         // Cancelled transfer
        else if errorCode == 200 { return }     // Transfer stopped
        else if errorCode == 207 { return }     // WebDAV multistatus
        else if errorCode == NCGlobal.shared.errorNoError && type == messageType.error { return }

        DispatchQueue.main.async {
            switch errorCode {
            case Int(CFNetworkErrors.cfurlErrorNotConnectedToInternet.rawValue):
                let image = UIImage(named: "networkInProgress")!.image(color: .white, size: 20)
                self.noteTop(text: NSLocalizedString(title, comment: ""), image: image, color: .lightGray, delay: delay, priority: .max)
            default:
                guard var description = description else { return }
                if description.trimmingCharacters(in: .whitespacesAndNewlines) == "" { return }
                description = NSLocalizedString(description, comment: "")
                self.flatTop(title: NSLocalizedString(title, comment: ""), description: description, delay: delay, imageName: nil, type: type, priority: priority, dropEnqueuedEntries: dropEnqueuedEntries)
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

    // MARK: - Note Message

    func noteTop(text: String, image: UIImage?, color: UIColor? = nil, type: messageType? = nil, delay: TimeInterval, priority: EKAttributes.Precedence.Priority = .normal, dropEnqueuedEntries: Bool = false) {

        if SwiftEntryKit.isCurrentlyDisplaying(entryNamed: text) { return }

        var attributes = EKAttributes.topNote

        attributes.windowLevel = .normal
        attributes.displayDuration = delay
        attributes.name = text
        if let color = color {
            attributes.entryBackground = .color(color: EKColor(color))
        }
        if let type = type {
            attributes.entryBackground = .color(color: EKColor(getBackgroundColorFromType(type)))
        }
        attributes.precedence = .override(priority: priority, dropEnqueuedEntries: dropEnqueuedEntries)

        let style = EKProperty.LabelStyle(font: MainFont.light.with(size: 14), color: .white, alignment: .center)
        let labelContent = EKProperty.LabelContent(text: text, style: style)

        if let image = image {
            let imageContent = EKProperty.ImageContent(image: image, size: CGSize(width: 17, height: 17))
            let contentView = EKImageNoteMessageView(with: labelContent, imageContent: imageContent)
            DispatchQueue.main.async { SwiftEntryKit.display(entry: contentView, using: attributes) }
        } else {
            let contentView = EKNoteMessageView(with: labelContent)
            DispatchQueue.main.async { SwiftEntryKit.display(entry: contentView, using: attributes) }
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
