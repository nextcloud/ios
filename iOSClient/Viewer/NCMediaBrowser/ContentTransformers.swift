//
//  ContentTransformers.swift
//  ATGMediaBrowser
//
//  Created by Suraj Thomas K on 7/17/18.
//  Copyright © 2018 Al Tayer Group LLC.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
//  and associated documentation files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

/**
 Content transformer used for transition between media item views.

 - parameter contentView: The content view on which transform corresponding to the position has to be applied.
 - parameter position: Current position for the passed content view.

 - note:
    The trasnform to be applied on the contentView has to be dependent on the position passed.
    The position value can be -ve, 0.0 or positive.

    Try to visualize content views at -1.0[previous]=>0.0[current]=>1.0[next].

    1. When position is -1.0, the content view should be at the place meant for previous view.

    2. When the position is 0.0, the transform applied on the content view should make it visible full screen at origin.

    3. When position is 1.0, the content view should be at the place meant for next view.

    Be mindful of the drawing order, when designing new transitions.
 */
public typealias ContentTransformer = (_ contentView: UIView, _ position: CGFloat) -> Void

// MARK: - Default Transitions

/// An enumeration to hold default content transformers
public enum DefaultContentTransformers {

    /**
     Horizontal move-in-out content transformer.

     - Requires:
         * GestureDirection: Horizontal
    */
    public static let horizontalMoveInOut: ContentTransformer = { contentView, position in

        let widthIncludingGap = contentView.bounds.size.width + MediaContentView.interItemSpacing
        contentView.transform = CGAffineTransform(translationX: widthIncludingGap * position, y: 0.0)
    }

    /**
     Vertical move-in-out content transformer.

     - Requires:
        * GestureDirection: Vertical
     */
    public static let verticalMoveInOut: ContentTransformer = { contentView, position in

        let heightIncludingGap = contentView.bounds.size.height + MediaContentView.interItemSpacing
        contentView.transform = CGAffineTransform(translationX: 0.0, y: heightIncludingGap * position)
    }

    /**
     Horizontal slide-out content transformer.

     - Requires:
        * GestureDirection: Horizontal
        * DrawOrder: PreviousToNext
     */
    public static let horizontalSlideOut: ContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position < -0.5 {
            scale = 0.9
        } else if -0.5...0.0 ~= Double(position) {
            scale = 1.0 + (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let widthIncludingGap = contentView.bounds.size.width + MediaContentView.interItemSpacing
        let x = position >= 0.0 ? widthIncludingGap * position : 0.0
        transform = transform.translatedBy(x: x, y: 0.0)

        contentView.transform = transform

        let margin: CGFloat = 0.0000001
        contentView.isHidden = ((1.0-margin)...(1.0+margin) ~= abs(position))
    }

    /**
     Vertical slide-out content transformer.

     - Requires:
         * GestureDirection: Vertical
         * DrawOrder: PreviousToNext
     */
    public static let verticalSlideOut: ContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position < -0.5 {
            scale = 0.9
        } else if -0.5...0.0 ~= Double(position) {
            scale = 1.0 + (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let heightIncludingGap = contentView.bounds.size.height + MediaContentView.interItemSpacing
        let y = position >= 0.0 ? heightIncludingGap * position : 0.0
        transform = transform.translatedBy(x: 0.0, y: y)

        contentView.transform = transform

        let margin: CGFloat = 0.0000001
        contentView.isHidden = ((1.0-margin)...(1.0+margin) ~= abs(position))
    }

    /**
     Horizontal slide-in content transformer.

     - Requires:
         * GestureDirection: Horizontal
         * DrawOrder: NextToPrevious
     */
    public static let horizontalSlideIn: ContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position > 0.5 {
            scale = 0.9
        } else if 0.0...0.5 ~= Double(position) {
            scale = 1.0 - (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let widthIncludingGap = contentView.bounds.size.width + MediaContentView.interItemSpacing
        let x = position > 0.0 ? 0.0 : widthIncludingGap * position
        transform = transform.translatedBy(x: x, y: 0.0)

        contentView.transform = transform

        let margin: CGFloat = 0.0000001
        contentView.isHidden = ((1.0-margin)...(1.0+margin) ~= abs(position))
    }

    /**
     Vertical slide-in content transformer.

     - Requires:
         * GestureDirection: Vertical
         * DrawOrder: NextToPrevious
     */
    public static let verticalSlideIn: ContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position > 0.5 {
            scale = 0.9
        } else if 0.0...0.5 ~= Double(position) {
            scale = 1.0 - (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let heightIncludingGap = contentView.bounds.size.height + MediaContentView.interItemSpacing
        let y = position > 0.0 ? 0.0 : heightIncludingGap * position
        transform = transform.translatedBy(x: 0.0, y: y)

        contentView.transform = transform

        let margin: CGFloat = 0.0000001
        contentView.isHidden = ((1.0-margin)...(1.0+margin) ~= abs(position))
    }

    /**
     Horizontal zoom-in-out content transformer.

     - Requires:
     * GestureDirection: Horizontal
     */
    public static let horizontalZoomInOut: ContentTransformer = { contentView, position in

        let minScale: CGFloat = 0.5
        // Scale factor is used to reduce the scale animation speed.
        let scaleFactor: CGFloat = 0.5
        var scale: CGFloat = CGFloat.maximum(minScale, 1.0 - abs(position * scaleFactor))

        // Actual gap will be scaleFactor * 0.5 times of contentView.bounds.size.width.
        let actualGap = contentView.bounds.size.width * scaleFactor * 0.5
        let gapCorrector = MediaContentView.interItemSpacing - actualGap

        let widthIncludingGap = contentView.bounds.size.width + gapCorrector
        let translation = (widthIncludingGap * position)/scale

        var transform = CGAffineTransform(scaleX: scale, y: scale)
        transform = transform.translatedBy(x: translation, y: 0.0)

        contentView.transform = transform
    }

    /**
     Vertical zoom-in-out content transformer.

     - Requires:
     * GestureDirection: Vertical
     */
    public static let verticalZoomInOut: ContentTransformer = { contentView, position in

        let minScale: CGFloat = 0.5
        // Scale factor is used to reduce the scale animation speed.
        let scaleFactor: CGFloat = 0.5
        let scale: CGFloat = CGFloat.maximum(minScale, 1.0 - abs(position * scaleFactor))

        // Actual gap will be scaleFactor * 0.5 times of contentView.bounds.size.height.
        let actualGap = contentView.bounds.size.height * scaleFactor * 0.5
        let gapCorrector = MediaContentView.interItemSpacing - actualGap

        let heightIncludingGap = contentView.bounds.size.height + gapCorrector
        let translation = (heightIncludingGap * position)/scale

        var transform = CGAffineTransform(scaleX: scale, y: scale)
        transform = transform.translatedBy(x: 0.0, y: translation)

        contentView.transform = transform
    }
}
