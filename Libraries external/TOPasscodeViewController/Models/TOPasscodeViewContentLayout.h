//
//  TOPasscodeViewContentLayout.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 Depending on the width of the application window, all of the content views in
 the passcode view need to be resized in order to fit in the available space.

 This means that not only does the spacing and sizing of views need to be changed, but
 image assets need to be regenerated and font sizes need to change as well.

 This class assumes there will be three major screen sizes, and provides layout
 sizes, spacing, and styles in order to resize the passcode view for each one.

 The three screen styles it supports are:

 * Small Screens - iPhone 5/ or iPad 9.7" in 1/4 split screen mode
 * Medium Screens - iPhone 6/ or iPad 12.9" in 1/4 split screen mode
 * Large Screens - iPhone 6 Plus and all iPads when not in split screen mode.

 */
@interface TOPasscodeViewContentLayout : NSObject

/* The width of the PIN view in which this layout object is sizing the content to fit. */
@property (nonatomic, assign) CGFloat viewWidth;

/* Extra padding at the bottom in order to shift the content slightly up */
@property (nonatomic, assign) CGFloat bottomPadding;

/* The title view at the very top */
@property (nonatomic, assign) CGFloat titleViewBottomSpacing;   // Space from the bottom of the title view to the title label

/* The Title Label Explaining the Passcode View */
@property (nonatomic, assign) CGFloat titleLabelBottomSpacing;    // Space from the title label to the input view

@property (nonatomic, strong) UIFont *titleLabelFont;             // The font of the title label

/* Title Label properties when the view is laid out horizontally */
@property (nonatomic, assign) CGFloat titleHorizontalLayoutWidth;   // When laid out horizontally, the width of the title view
@property (nonatomic, assign) CGFloat titleHorizontalLayoutSpacing; // The amount of spacing between the title label and the passcode keypad
@property (nonatomic, assign) CGFloat titleViewHorizontalBottomSpacing; // Space from the bottom of the title view when iPhone is horizontal
@property (nonatomic, assign) CGFloat titleLabelHorizontalBottomSpacing; // Spacing from the title label to input view in horizontal mode

/* Circle Row Configuration */
@property (nonatomic, assign) CGFloat circleRowDiameter; // The diameter of each circle representing a PIN number
@property (nonatomic, assign) CGFloat circleRowSpacing;  // The spacing between each circle
@property (nonatomic, assign) CGFloat circleRowBottomSpacing; // Space between the view used to indicate input

/* Text Field Configuration */
@property (nonatomic, assign) CGFloat textFieldBorderThickness; // The thickness of the border stroke
@property (nonatomic, assign) CGFloat textFieldBorderRadius;    // The corner radius of the border
@property (nonatomic, assign) CGFloat textFieldCircleDiameter;  // The size of the circles in the passcode field
@property (nonatomic, assign) CGFloat textFieldCircleSpacing;   // The amount of spacing between each circle
@property (nonatomic, assign) CGSize textFieldBorderPadding;   // The amount of padding between the circles and the border
@property (nonatomic, assign) NSInteger textFieldNumericCharacterLength; // The amount of circles to have in this field when set to numeric
@property (nonatomic, assign) NSInteger textFieldAlphanumericCharacterLength; // The amount of circles to have in this field when set to alphanumeric
@property (nonatomic, assign) CGFloat submitButtonFontSize;     // The font size of the 'OK' button
@property (nonatomic, assign) CGFloat submitButtonSpacing;      // The spacing of the 'OK' button from the input

/* Circle Button Shape and Layout */
@property (nonatomic, assign) CGFloat circleButtonDiameter;     // The size of each PIN button
@property (nonatomic, assign) CGSize  circleButtonSpacing;      // The vertical/horizontal spacing between buttons
@property (nonatomic, assign) CGFloat circleButtonStrokeWidth;  // The thickness of the border line

/* Circle Button Label */
@property (nonatomic, strong) UIFont *circleButtonTitleLabelFont;       // The font used for the '1' number labels
@property (nonatomic, strong) UIFont *circleButtonLetteringLabelFont;   // The font used for the 'ABC' labels
@property (nonatomic, assign) CGFloat circleButtonLabelSpacing;         // The vertical spacing between the number and lettering labels
@property (nonatomic, assign) CGFloat circleButtonLetteringSpacing;     // The spacing between the 'ABC' characters

/* Default layout configurations for the various sizes */
+ (TOPasscodeViewContentLayout *)defaultScreenContentLayout;       /* Default layout values. Designed for iPhone 6 Plus and above. */
+ (TOPasscodeViewContentLayout *)mediumScreenContentLayout;        /* For medium screen sizes, like iPhone 6, or 1/4 view on iPad Pro. */
+ (TOPasscodeViewContentLayout *)smallScreenContentLayout;         /* For the smallest screens, like iPhone SE, and 1/4 on standard size iPads/ */

@end
