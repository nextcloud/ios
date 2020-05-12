//
//  TOPasscodeCircleImage.h
//
//  Copyright 2017 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A subclass of `UIImage` that can procedurally generate both hollow and full circle graphics at any size.
 These are used for the 'normal' and 'tapped' states of the passcode circle buttons.
 */
@interface TOPasscodeCircleImage : UIImage

/**
 Generates and returns a `UIImage` of a filled circle at the specified size.

 @param size     The diameter of the final circle image
 @param inset    An inset value that will shrink the size of the circle. This is so it can be overlaid on a hollow circle
                    without interfering with the anti-aliasing on the outer border.
 @param padding  External padding around the circle to ensure it won't be clipped by the edge of the layer.
                    Setting this value will increase the dimensions of the final `UIImage`.
 @param antialias Whether the circle boundary will be antialiased (Since antialiasing is unnecessary if this circle will overlay another.)
 */
+ (UIImage *)circleImageOfSize:(CGFloat)size inset:(CGFloat)inset padding:(CGFloat)padding antialias:(BOOL)antialias;

/**
 Generates and returns a `UIImage` of a hollow circle at the specified size.

 @param size        The diameter of the final circle image
 @param strokeWidth The thickness, in points, of the stroke making up the circle image.
 @param padding     External padding around the circle to ensure it won't be clipped by the edge of the layer.
                      Setting this value will increase the dimensions of the final `UIImage`.
 */
+ (UIImage *)hollowCircleImageOfSize:(CGFloat)size strokeWidth:(CGFloat)strokeWidth padding:(CGFloat)padding;

@end

NS_ASSUME_NONNULL_END
