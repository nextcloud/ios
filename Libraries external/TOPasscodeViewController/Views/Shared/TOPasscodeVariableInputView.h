//
//  TOPasscodeVariableInputView.h
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

/**
 A basic content view showing a rounded rectangle containing circles
 that can be used to represent a variable size passcode.
 */
@interface TOPasscodeVariableInputView : UIImageView

/* The thickness of the stroke around the view (Default is 1.5) */
@property (nonatomic, assign) CGFloat outlineThickness;

/* The corner radius of the stroke (Default is 5) */
@property (nonatomic, assign) CGFloat outlineCornerRadius;

/* The size of each circle bullet point representing a passcoded character (Default is 10) */
@property (nonatomic, assign) CGFloat circleDiameter;

/* The spacing between each circle (Default is 15) */
@property (nonatomic, assign) CGFloat circleSpacing;

/* The padding between the circles and the outer outline (Default is {10,10}) */
@property (nonatomic, assign) CGSize outlinePadding;

/* The maximum number of circles to show (This will indicate the view's width) (Default is 12) */
@property (nonatomic, assign) NSInteger maximumVisibleLength;

/* Set the number of characters entered into this view (May be larger than `maximumVisibleLength`) */
@property (nonatomic, assign) NSInteger length;

/* Set the number of characters represented by this field, animated if desired */
- (void)setLength:(NSInteger)length animated:(BOOL)animated;

@end
