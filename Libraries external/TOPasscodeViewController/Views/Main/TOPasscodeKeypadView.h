//
//  TOPasscodeKeypadView.h
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

@class TOPasscodeCircleButton;

/**
 A view encompassing 9 circle buttons, making up a keypad view for entering PIN numbers.
 Can be laid out vertically or horizontally.
 */
@interface TOPasscodeKeypadView : UIView <UIInputViewAudioFeedback>

/** The type of layout for the buttons (Default is vertical) */
@property (nonatomic, assign) BOOL horizontalLayout;

/** The vibrancy effect to be applied to each button background */
@property (nonatomic, strong, nullable) UIVibrancyEffect *vibrancyEffect;

/** The size of each input button */
@property (nonatomic, assign) CGFloat buttonDiameter;

/** The stroke width of the buttons */
@property (nonatomic, assign) CGFloat buttonStrokeWidth;

/** The spacing between the buttons. Default is (CGSize){25,15} */
@property (nonatomic, assign) CGSize buttonSpacing;

/** The font of the number in each button */
@property (nonatomic, strong) UIFont *buttonNumberFont;

/** The font of the lettering label */
@property (nonatomic, strong) UIFont *buttonLetteringFont;

/** The spacing between the lettering and the number label */
@property (nonatomic, assign) CGFloat buttonLabelSpacing;

/** The spacing between the letters in the lettering label */
@property (nonatomic, assign) CGFloat buttonLetteringSpacing;

/** Show the 'ABC' lettering under the numbers */
@property (nonatomic, assign) BOOL showLettering;

/** The spacing in points between the letters */
@property (nonatomic, assign) CGFloat letteringSpacing;

/** The tint color of the button backgrounds */
@property (nonatomic, strong) UIColor *buttonBackgroundColor;

/** The color of the text elements in each button */
@property (nonatomic, strong) UIColor *buttonTextColor;

/** Optionally the color of text when it's tapped. */
@property (nonatomic, strong, nullable) UIColor *buttonHighlightedTextColor;

/** The alpha value of all non-translucent views */
@property (nonatomic, assign) CGFloat contentAlpha;

/** Accessory views placed on either side of the '0' button */
@property (nonatomic, strong, nullable) UIView *leftAccessoryView;
@property (nonatomic, strong, nullable) UIView *rightAccessoryView;

/** The controls making up each of the button views */
@property (nonatomic, readonly) NSArray<TOPasscodeCircleButton *> *keypadButtons;

/** The block that is triggered whenever a user taps one of the buttons */
@property (nonatomic, copy) void (^buttonTappedHandler)(NSInteger buttonNumber);

/*
 Perform an animation to transition to a new layout.

 @param horizontalLayout The content is laid out horizontally.
 @param animated Whether the transition is animated
 @param duration The animation length of the transition.
 */
- (void)setHorizontalLayout:(BOOL)horizontalLayout animated:(BOOL)animated duration:(CGFloat)duration;

@end

NS_ASSUME_NONNULL_END
