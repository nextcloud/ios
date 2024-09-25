//
//  TOPasscodeFixedInputView.h
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

@class TOPasscodeCircleView;

/**
 A basic content view showing a row of circles that can be used to represent
 a fixed size passcode.
 */
@interface TOPasscodeFixedInputView : UIView

/* The size of each circle in this view (Default is 16) */
@property (nonatomic, assign) CGFloat circleDiameter;

/* The spacing between each circle (Default is 25.0f) */
@property (nonatomic, assign) CGFloat circleSpacing;

/* The number of circles in this view (Default is 4) */
@property (nonatomic, assign) NSInteger length;

/* The number of highlighted circles */
@property (nonatomic, assign) NSInteger highlightedLength;

/* The circle views managed by this view */
@property (nonatomic, strong, readonly) NSArray<TOPasscodeCircleView *> *circleViews;

/* Init with a set number of circles */
- (instancetype)initWithLength:(NSInteger)length;

/* Set the number of highlighted circles */
- (void)setHighlightedLength:(NSInteger)highlightedLength animated:(BOOL)animated;

@end
