//
//  TOPasscodeSettingsKeypadView.h
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
#import "TOPasscodeViewControllerConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 A keypad view of 9 buttons that allow numerical input on both iPad and iPhone.
 Designed to match the base system, with a pseudo-skeuomorphical styling.
 */
@interface TOPasscodeSettingsKeypadView : UIView

/* Whether the control is allowing input */
@property (nonatomic, assign) BOOL enabled;

/* Whether the view is currently light mode or dark. */
@property (nonatomic, assign) TOPasscodeSettingsViewStyle style;

/* The color of the separator line */
@property (nonatomic, strong) UIColor *separatorLineColor;

/* Labels in the buttons are laid out horizontally */
@property (nonatomic, assign) BOOL buttonLabelHorizontalLayout;

/* If overridden, the foreground color of the buttons */
@property (nonatomic, assign) CGFloat keypadButtonBorderThickness;

/* Untapped background images */
@property (nonatomic, strong, null_resettable) UIColor *keypadButtonForegroundColor;
@property (nonatomic, strong, null_resettable) UIColor *keypadButtonBorderColor;

/* Tapped background images */
@property (nonatomic, strong, null_resettable) UIColor *keypadButtonTappedForegroundColor;
@property (nonatomic, strong, nullable) UIColor *keypadButtonTappedBorderColor;

/* Button label styling */
@property (nonatomic, strong) UIFont *keypadButtonNumberFont;
@property (nonatomic, strong) UIFont *keypadButtonLetteringFont;
@property (nonatomic, strong) UIColor *keypadButtonLabelTextColor;
@property (nonatomic, assign) CGFloat keypadButtonVerticalSpacing;
@property (nonatomic, assign) CGFloat keypadButtonHorizontalSpacing;
@property (nonatomic, assign) CGFloat keypadButtonLetteringSpacing;

/* Callback handlers */
@property (nonatomic, copy) void (^numberButtonTappedHandler)(NSInteger number);
@property (nonatomic, copy) void (^deleteButtonTappedHandler)(void);

/* In really small sizes, set the keypad labels to horizontal */
- (void)setButtonLabelHorizontalLayout:(BOOL)horizontal animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
