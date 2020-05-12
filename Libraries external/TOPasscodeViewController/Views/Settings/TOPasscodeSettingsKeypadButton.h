//
//  TOPasscodeSettingsKeypadButton.h
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

@class TOPasscodeButtonLabel;

/**
 A single button view that is used in a number keypad views styled in
 a pseudo-skeuomorphic style.
 */
@interface TOPasscodeSettingsKeypadButton : UIButton

/** Background Images */
@property (nonatomic, strong) UIImage *buttonBackgroundImage;
@property (nonatomic, strong) UIImage *buttonTappedBackgroundImage;

/* Inset of the label view from the bottom to account for the bevel */
@property (nonatomic, assign) CGFloat bottomInset;

/* The button label containing the number and lettering */
@property (nonatomic, readonly) TOPasscodeButtonLabel *buttonLabel;

+ (TOPasscodeSettingsKeypadButton *)button;

@end
