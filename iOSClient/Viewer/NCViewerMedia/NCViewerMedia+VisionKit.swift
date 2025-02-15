import Foundation
import UIKit
import VisionKit

extension NCViewerMedia {
    @available(iOS 17.0, *)
    func analyzeCurrentImage() {
        if let image = image {
            let interaction = ImageAnalysisInteraction()
            let analyzer = ImageAnalyzer()
            interaction.preferredInteractionTypes = []
            interaction.analysis = nil

            self.imageVideoContainer.addInteraction(interaction)
            let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode, .visualLookUp])

            Task {
                let analysis = try? await analyzer.analyze(image, configuration: configuration)
                if image == self.image {
                    interaction.analysis = analysis
                    interaction.preferredInteractionTypes = .automatic
                }
            }
        }
    }
}
