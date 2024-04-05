//
//  NCViewerMedia+VisionKit.swift
//  Nextcloud
//
//  Created by Milen on 18.03.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
import VisionKit

extension NCViewerMedia {
    @available(iOS 16.0, *)
    func analyzeCurrentImage() {
        if let image = image {
            Task {
                let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode, .visualLookUp])
                    let analysis = try? await analyzer.imageAnalyzer?.analyze(image, configuration: configuration)
                    if image == self.image {
                        analyzer.imageInteraction?.analysis = analysis
                        analyzer.imageInteraction?.preferredInteractionTypes = .automatic
                    }
            }
        }
    }
}

// TODO: Remove when min SDK is 16
@MainActor
struct Analyzer {
    private var _imageAnalyzer: Any?
    private var _imageInteraction: Any?

    @available(iOS 16, *)
    var imageAnalyzer: ImageAnalyzer? {
        get { return _imageAnalyzer as? ImageAnalyzer }
        set { _imageAnalyzer = newValue }
    }

    @available(iOS 16, *)
    var imageInteraction: ImageAnalysisInteraction? {
        get { return _imageInteraction as? ImageAnalysisInteraction }
        set { _imageInteraction = newValue }
    }

    init() {
        if #available(iOS 16, *) {
            imageAnalyzer = ImageAnalyzer()
            imageInteraction = ImageAnalysisInteraction()
        }
    }
}
