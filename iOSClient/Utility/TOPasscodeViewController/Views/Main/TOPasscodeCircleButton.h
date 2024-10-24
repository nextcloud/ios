//
//  TOPasscodeCircleButton.h
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
@class TOPasscodeButtonLabel;

NS_ASSUME_NONNULL_BEGIN

/**
 A UI control representing a single PIN code button for the keypad,
 including the number, lettering (eg 'ABC'), and circle border.
 */
@interface TOPasscodeCircleButton : UIControl

// Alpha value that properly controls the necessary subviews
@property (nonatomic, assign) CGFloat contentAlpha;

// Required to be set before this view can be properly rendered
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) UIImage *hightlightedBackgroundImage;
@property (nonatomic, strong) UIVibrancyEffect *vibrancyEffect;

// Properties with default values
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong, nullable) UIColor *highlightedTextColor;
@property (nonatomic, strong) UIFont *numberFont;
@property (nonatomic, strong) UIFont *letteringFont;
@property (nonatomic, assign) CGFloat letteringCharacterSpacing;
@property (nonatomic, assign) CGFloat letteringVerticalSpacing;

@property (nonatomic, readonly) NSString *numberString;
@property (nonatomic, readonly) NSString *letteringString;

// The internal views
@property (nonatomic, readonly) TOPasscodeButtonLabel *buttonLabel;
@property (nonatomic, readonly) TOPasscodeCircleView *circleView;
@property (nonatomic, readonly) UIVisualEffectView *vibrancyView;

// Callback handler
@property (nonatomic, copy) void (^buttonTappedHandler)(void);

/**
 Create a new instance of the class with the supplied number and lettering string

 @param numberString The string of the number to display in this button (eg '1').
 @param letteringString The string of the lettering to display underneath.
 */
- (instancetype)initWithNumberString:(NSString *)numberString letteringString:(NSString *)letteringString;

/**
 Set the background of the button to be the filled circle instead of hollow.

 @param highlighted When YES, the circle is full, when NO, it is hollow.
 @param animated When animated, the transition is a crossfade.
 */
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
