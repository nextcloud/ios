//
//  RectangleFeaturesFunnel.swift
//  WeScan
//
//  Created by Boris Emorine on 2/9/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation
import AVFoundation

/// `RectangleFeaturesFunnel` is used to improve the confidence of the detected rectangles.
/// Feed rectangles to a `RectangleFeaturesFunnel` instance, and it will call the completion block with a rectangle whose confidence is high enough to be displayed.
final class RectangleFeaturesFunnel {
    
    /// `RectangleMatch` is a class used to assign matching scores to rectangles.
    private final class RectangleMatch: NSObject {
        /// The rectangle feature object associated to this `RectangleMatch` instance.
        let rectangleFeature: CIRectangleFeature
        
        /// The score to indicate how strongly the rectangle of this instance matches other recently added rectangles.
        /// A higher score indicates that many recently added rectangles are very close to the rectangle of this instance.
        var matchingScore = 0

        init(rectangleFeature: CIRectangleFeature) {
            self.rectangleFeature = rectangleFeature
        }
        
        override var description: String {
            return "Matching score: \(matchingScore) - Rectangle: \(rectangleFeature)"
        }
        
        /// Whether the rectangle of this instance is within the distance of the given rectangle.
        ///
        /// - Parameters:
        ///   - rectangle: The rectangle to compare the rectangle of this instance with.
        ///   - threshold: The distance used to determinate if the rectangles match in pixels.
        /// - Returns: True if both rectangles are within the given distance of each other.
        func matches(_ rectangle: CIRectangleFeature, withThreshold threshold: CGFloat) -> Bool {
            return rectangleFeature.isWithin(threshold, ofRectangleFeature: rectangle)
        }
    }
    
    /// The queue of last added rectangles. The first rectangle is oldest one, and the last rectangle is the most recently added one.
    private var rectangles = [RectangleMatch]()
    
    /// The maximum number of rectangles to compare newly added rectangles with. Determines the maximum size of `rectangles`. Increasing this value will impact performance.
    let maxNumberOfRectangles = 8
    
    /// The minimum number of rectangles needed to start making comparaisons and determining which rectangle to display. This value should always be inferior than `maxNumberOfRectangles`.
    /// A higher value will delay the first time a rectangle is displayed.
    let minNumberOfRectangles = 3
    
    /// The value in pixels used to determine if two rectangle match or not. A higher value will prevent displayed rectangles to be refreshed. On the opposite, a smaller value will make new rectangles be displayed constantly.
    let matchingThreshold: CGFloat = 40.0
    
    /// The minumum number of matching rectangles (within the `rectangle` queue), to be confident enough to display a rectangle.
    let minNumberOfMatches = 2

    /// Add a rectangle to the funnel, and if a new rectangle should be displayed, the completion block will be called.
    /// The algorithm works the following way:
    /// 1. Makes sure that the funnel has been fed enough rectangles
    /// 2. Removes old rectangles if needed
    /// 3. Compares all of the recently added rectangles to find out which one match each other
    /// 4. Within all of the recently added rectangles, finds the "best" one (@see `bestRectangle(withCurrentlyDisplayedRectangle:)`)
    /// 5. If the best rectangle is different than the currently displayed rectangle, informs the listener that a new rectangle should be displayed
    /// - Parameters:
    ///   - rectangleFeature: The rectangle to feed to the funnel.
    ///   - currentRectangle: The currently displayed rectangle. This is used to avoid displaying very close rectangles.
    ///   - completion: The completion block called when a new rectangle should be displayed.
    func add(_ rectangleFeature: CIRectangleFeature, currentlyDisplayedRectangle currentRectangle: CIRectangleFeature?, completion: (CIRectangleFeature) -> Void) {
        let rectangleMatch = RectangleMatch(rectangleFeature: rectangleFeature)
        rectangles.append(rectangleMatch)
        
        guard rectangles.count >= minNumberOfRectangles else {
            return
        }
        
        if rectangles.count > maxNumberOfRectangles {
            rectangles.removeFirst()
        }
        
        updateRectangleMatches()
        
        guard let bestRectangle = bestRectangle(withCurrentlyDisplayedRectangle: currentRectangle) else {
            return
        }
        
        if let previousRectangle = currentRectangle,
            bestRectangle.rectangleFeature.isWithin(matchingThreshold, ofRectangleFeature: previousRectangle) {
        } else if bestRectangle.matchingScore >= minNumberOfMatches {
            completion(bestRectangle.rectangleFeature)
        }
    }
    
    /// Determines which rectangle is best to displayed.
    /// The criteria used to find the best rectangle is its matching score.
    /// If multiple rectangles have the same matching score, we use a tie breaker to find the best rectangle (@see breakTie(forRectangles:)).
    /// Parameters:
    ///   - currentRectangle: The currently displayed rectangle. This is used to avoid displaying very close rectangles.
    /// Returns: The best rectangle to display given the current history.
    private func bestRectangle(withCurrentlyDisplayedRectangle currentRectangle: CIRectangleFeature?) -> RectangleMatch? {
        var bestMatch: RectangleMatch?
        
        rectangles.reversed().forEach { (rectangle) in
            guard let best = bestMatch else {
                bestMatch = rectangle
                return
            }
            
            if rectangle.matchingScore > best.matchingScore {
                bestMatch = rectangle
                return
            } else if rectangle.matchingScore == best.matchingScore {
                guard let currentRectangle = currentRectangle else {
                    return
                }
                
                bestMatch = breakTie(between: best, rect2: rectangle, currentRectangle: currentRectangle)
            }
        }
        
        return bestMatch
    }
    
    /// Breaks a tie between two rectangles to find out which is best to display.
    /// The first passed rectangle is returned if no other criteria could be used to break the tie.
    /// If the first passed rectangle (rect1) is close to the currently displayed rectangle, we pick it.
    /// Otherwise if the second passed rectangle (rect2) is close to the currently displayed rectangle, we pick this one.
    /// Finally, if none of the passed in rectangles are close to the currently displayed rectangle, we arbitrary pick the first one.
    /// - Parameters:
    ///   - rect1: The first rectangle to compare.
    ///   - rect2: The second rectangle to compare.
    ///   - currentRectangle: The currently displayed rectangle. This is used to avoid displaying very close rectangles.
    /// - Returns: The best rectangle to display between two rectangles with the same matching score.
    private func breakTie(between rect1: RectangleMatch, rect2: RectangleMatch, currentRectangle: CIRectangleFeature) -> RectangleMatch {
        if rect1.rectangleFeature.isWithin(matchingThreshold, ofRectangleFeature: currentRectangle) {
            return rect1
        } else if rect2.rectangleFeature.isWithin(matchingThreshold, ofRectangleFeature: currentRectangle) {
            return rect2
        }
        
        return rect1
    }
    
    /// Loops through all of the rectangles of the queue, and gives them a score depending on how many they match. @see `RectangleMatch.matchingScore`
    private func updateRectangleMatches() {
        resetMatchingScores()
        
        for (i, currentRect) in rectangles.enumerated() {
            for (j, rect) in rectangles.enumerated() {
                if j > i && currentRect.matches(rect.rectangleFeature, withThreshold: matchingThreshold) {
                    currentRect.matchingScore += 1
                    rect.matchingScore += 1
                }
            }
        }
    }
    
    /// Resets the matching score of all of the rectangles in the queue to 0
    private func resetMatchingScores() {
        rectangles = rectangles.map { (rectangle) -> RectangleMatch in
            rectangle.matchingScore = 0
            return rectangle
        }
    }
    
}
