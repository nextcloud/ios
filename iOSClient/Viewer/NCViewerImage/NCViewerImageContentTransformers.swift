//
//  ContentTransformers.swift
//  Nextcloud
//
//  Created by Suraj Thomas K on 7/17/18 Copyright © 2018 Al Tayer Group LLC..
//  Modify for Nextcloud by Marino Faggiana on 04/03/2020.
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
public typealias NCViewerImageContentTransformer = (_ contentView: UIView, _ position: CGFloat) -> Void

// MARK: - Default Transitions

/// An enumeration to hold default content transformers
public enum NCViewerImageDefaultContentTransformers {

    /**
     Horizontal move-in-out content transformer.

     - Requires:
         * GestureDirection: Horizontal
    */
    public static let horizontalMoveInOut: NCViewerImageContentTransformer = { contentView, position in

        let widthIncludingGap = contentView.bounds.size.width + NCViewerImageContentView.interItemSpacing
        contentView.transform = CGAffineTransform(translationX: widthIncludingGap * position, y: 0.0)
    }

    /**
     Vertical move-in-out content transformer.

     - Requires:
        * GestureDirection: Vertical
     */
    public static let verticalMoveInOut: NCViewerImageContentTransformer = { contentView, position in

        let heightIncludingGap = contentView.bounds.size.height + NCViewerImageContentView.interItemSpacing
        contentView.transform = CGAffineTransform(translationX: 0.0, y: heightIncludingGap * position)
    }

    /**
     Horizontal slide-out content transformer.

     - Requires:
        * GestureDirection: Horizontal
        * DrawOrder: PreviousToNext
     */
    public static let horizontalSlideOut: NCViewerImageContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position < -0.5 {
            scale = 0.9
        } else if -0.5...0.0 ~= Double(position) {
            scale = 1.0 + (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let widthIncludingGap = contentView.bounds.size.width + NCViewerImageContentView.interItemSpacing
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
    public static let verticalSlideOut: NCViewerImageContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position < -0.5 {
            scale = 0.9
        } else if -0.5...0.0 ~= Double(position) {
            scale = 1.0 + (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let heightIncludingGap = contentView.bounds.size.height + NCViewerImageContentView.interItemSpacing
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
    public static let horizontalSlideIn: NCViewerImageContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position > 0.5 {
            scale = 0.9
        } else if 0.0...0.5 ~= Double(position) {
            scale = 1.0 - (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let widthIncludingGap = contentView.bounds.size.width + NCViewerImageContentView.interItemSpacing
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
    public static let verticalSlideIn: NCViewerImageContentTransformer = { contentView, position in

        var scale: CGFloat = 1.0
        if position > 0.5 {
            scale = 0.9
        } else if 0.0...0.5 ~= Double(position) {
            scale = 1.0 - (position * 0.2)
        }
        var transform = CGAffineTransform(scaleX: scale, y: scale)

        let heightIncludingGap = contentView.bounds.size.height + NCViewerImageContentView.interItemSpacing
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
    public static let horizontalZoomInOut: NCViewerImageContentTransformer = { contentView, position in

        let minScale: CGFloat = 0.5
        // Scale factor is used to reduce the scale animation speed.
        let scaleFactor: CGFloat = 0.5
        var scale: CGFloat = CGFloat.maximum(minScale, 1.0 - abs(position * scaleFactor))

        // Actual gap will be scaleFactor * 0.5 times of contentView.bounds.size.width.
        let actualGap = contentView.bounds.size.width * scaleFactor * 0.5
        let gapCorrector = NCViewerImageContentView.interItemSpacing - actualGap

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
    public static let verticalZoomInOut: NCViewerImageContentTransformer = { contentView, position in

        let minScale: CGFloat = 0.5
        // Scale factor is used to reduce the scale animation speed.
        let scaleFactor: CGFloat = 0.5
        let scale: CGFloat = CGFloat.maximum(minScale, 1.0 - abs(position * scaleFactor))

        // Actual gap will be scaleFactor * 0.5 times of contentView.bounds.size.height.
        let actualGap = contentView.bounds.size.height * scaleFactor * 0.5
        let gapCorrector = NCViewerImageContentView.interItemSpacing - actualGap

        let heightIncludingGap = contentView.bounds.size.height + gapCorrector
        let translation = (heightIncludingGap * position)/scale

        var transform = CGAffineTransform(scaleX: scale, y: scale)
        transform = transform.translatedBy(x: 0.0, y: translation)

        contentView.transform = transform
    }
}
