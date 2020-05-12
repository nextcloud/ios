//
//  TOSettingsKeypadImage.h
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
 A subclass of `UIImage` that procedurally generates images for `TOPasscodeSettingsKeypadView`.
 This includes background images for each keypad button, and a delete icon for the bottom right corner
 of the keypad.
 */
@interface TOSettingsKeypadImage : UIImage

/**
 Generates and returns an image of button background with a raised border in a pseudo-skeuomorphic style.

 @param radius The rounded radius of the button image's corners
 @param foregroundColor The fill color of the primary section of the button
 @param edgeColor The color of the raised border edge along the bottom.
 @param thickness The size of the border running along the bottom
 */
+ (UIImage *)buttonImageWithCornerRadius:(CGFloat)radius
                         foregroundColor:(UIColor *)foregroundColor
                               edgeColor:(UIColor *)edgeColor
                           edgeThickness:(CGFloat)thickness;

/**
Generates and returns a tintable delete icon.
 */
+ (UIImage *)deleteIcon;

@end

NS_ASSUME_NONNULL_END
