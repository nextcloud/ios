//
//  TOPasscodeButtonLabel.h
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
 A view that manages two label subviews: a larger label showing a single number
 and a smaller label showing lettering as well.
 */
@interface TOPasscodeButtonLabel : UIView

// Draws the lettering label to the side
@property (nonatomic, assign) BOOL horizontalLayout;

// The strings of both labels
@property (nonatomic, copy) NSString *numberString;
@property (nonatomic, copy, nullable) NSString *letteringString;

// The color of both labels
@property (nonatomic, strong) UIColor *textColor;

// The label views
@property (nonatomic, readonly) UILabel *numberLabel;
@property (nonatomic, readonly) UILabel *letteringLabel;

// The fonts for each label (In case they are nil)
@property (nonatomic, strong) UIFont *numberLabelFont;
@property (nonatomic, strong) UIFont *letteringLabelFont;

// Has initial default values   
@property (nonatomic, assign) CGFloat letteringCharacterSpacing;
@property (nonatomic, assign) CGFloat letteringVerticalSpacing;
@property (nonatomic, assign) CGFloat letteringHorizontalSpacing;

// Whether the number label is centered vertically or not (NO by default)
@property (nonatomic, assign) BOOL verticallyCenterNumberLabel;

@end

NS_ASSUME_NONNULL_END
