//
//  NCUtility+Image.swift
//  Nextcloud
//
//  Created by Henrik Storch on 17.03.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import UIKit
import SVGKit
import NCCommunication

extension NCUtility {
    func getImageMetadata(_ metadata: tableMetadata, for size: CGFloat) -> UIImage? {

        if let image = getImage(metadata: metadata) {
            return image
        }

        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue && !metadata.hasPreview {
            NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
        }

        if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
            if let imagePreviewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag) {
                return UIImage(contentsOfFile: imagePreviewPath)
            }
        }

        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            return UIImage(named: "noPreviewVideo")?.image(color: .gray, size: size)
        } else if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            return UIImage(named: "noPreviewAudio")?.image(color: .gray, size: size)
        } else {
            return UIImage(named: "noPreview")?.image(color: .gray, size: size)
        }
    }

    func getImage(metadata: tableMetadata) -> UIImage? {
        let ext = CCUtility.getExtension(metadata.fileNameView)
        var image: UIImage?

        if CCUtility.fileProviderStorageExists(metadata) && metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue {

            let previewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

            if ext == "GIF" {
                if !FileManager().fileExists(atPath: previewPath) {
                    NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                }
                image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: imagePath))
            } else if ext == "SVG" {
                if let svgImage = SVGKImage(contentsOfFile: imagePath) {
                    svgImage.size = CGSize(width: NCGlobal.shared.sizePreview, height: NCGlobal.shared.sizePreview)
                    if let image = svgImage.uiImage {
                        if !FileManager().fileExists(atPath: previewPath) {
                            do {
                                try image.pngData()?.write(to: URL(fileURLWithPath: previewPath), options: .atomic)
                            } catch { }
                        }
                        return image
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            } else {
                NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                image = UIImage(contentsOfFile: imagePath)
            }
        }
        return image
    }
}
