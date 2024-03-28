//
//  NCViewerMedia+VisionKit.swift
//  Nextcloud
//
//  Created by Milen on 18.03.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
