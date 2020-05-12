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

#import "TOPasscodeKeypadView.h"
#import "TOPasscodeCircleImage.h"
#import "TOPasscodeCircleButton.h"
#import "TOPasscodeCircleView.h"
#import "TOPasscodeButtonLabel.h"

@interface TOPasscodeKeypadView()

/* Passcode buttons */
@property (nonatomic, strong, readwrite) NSArray<TOPasscodeCircleButton *> *keypadButtons;

/* The '0' button for the different layouts */
@property (nonatomic, strong) TOPasscodeCircleButton *verticalZeroButton;
@property (nonatomic, strong) TOPasscodeCircleButton *horizontalZeroButton;

/* Images */
@property (nonatomic, strong) UIImage *buttonImage;
@property (nonatomic, strong) UIImage *tappedButtonImage;

@end

@implementation TOPasscodeKeypadView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = YES;
        _buttonDiameter = 81.0f;
        _buttonSpacing = (CGSize){25,15};
        _buttonStrokeWidth = 1.5f;
        _showLettering = YES;
        _buttonNumberFont = nil;
        _buttonLetteringFont = nil;
        _buttonLabelSpacing = FLT_MIN;
        _buttonLetteringSpacing = FLT_MIN;
        [self sizeToFit];
    }

    return self;
}

- (TOPasscodeCircleButton *)makeCircleButtonWithNumber:(NSInteger)number letteringString:(NSString *)letteringString
{
    NSString *numberString = [NSString stringWithFormat:@"%ld", (long)number];

    TOPasscodeCircleButton *circleButton = [[TOPasscodeCircleButton alloc] initWithNumberString:numberString letteringString:letteringString];
    circleButton.backgroundImage = self.buttonImage;
    circleButton.hightlightedBackgroundImage = self.tappedButtonImage;
    circleButton.vibrancyEffect = self.vibrancyEffect;

    // Add handler for when button is tapped
    __weak typeof(self) weakSelf = self;
    circleButton.buttonTappedHandler = ^{
        if (weakSelf.buttonTappedHandler) {
            weakSelf.buttonTappedHandler(number);
        }
    };

    return circleButton;
}

- (void)setUpButtons
{
    NSMutableArray *buttons = [NSMutableArray array];

    NSInteger numberOfButtons = 11; // 1-9 are normal, 10 is the vertical '0', 11 is the horizontal '0'
    NSArray *letteredTitles = @[@"ABC", @"DEF", @"GHI", @"JKL",
                                @"MNO", @"PQRS", @"TUV", @"WXYZ"];

    for (NSInteger i = 0; i < numberOfButtons; i++) {
        // Work out the button number text
        NSInteger buttonNumber = i + 1;
        if (buttonNumber == 10 || buttonNumber == 11) { buttonNumber = 0; }

        // Work out the lettering text
        NSString *letteringString = nil;
        if (self.showLettering && i > 0 && i-1 < letteredTitles.count) { // (Skip 1 and 0)
            letteringString = letteredTitles[i-1];
        }

        // Create a new button and add it to this view
        TOPasscodeCircleButton *circleButton = [self makeCircleButtonWithNumber:buttonNumber letteringString:letteringString];
        [self addSubview:circleButton];
        [buttons addObject:circleButton];
        
        if (!self.showLettering) {
            circleButton.buttonLabel.verticallyCenterNumberLabel = YES; // Center the digit in the middle
        }

        // Hang onto the 0 button if it's the vertical one
        // And center the text
        if (i == 9) {
            self.verticalZeroButton = circleButton;

            // Hide the button if it's not vertically laid out
            if (self.horizontalLayout) {
                self.verticalZeroButton.contentAlpha = 0.0f;
                self.verticalZeroButton.hidden = YES;
            }
        }
        else if (i == 10) {
            self.horizontalZeroButton = circleButton;

            // Hide the button if it's not horizontally laid out
            if (!self.horizontalLayout) {
                self.horizontalZeroButton.contentAlpha = 0.0f;
                self.horizontalZeroButton.hidden = YES;
            }
        }
    }

    _keypadButtons = [NSArray arrayWithArray:buttons];
}

- (void)sizeToFit
{
    CGFloat padding = 2.0f;

    CGRect frame = self.frame;
    if (self.horizontalLayout) {
        frame.size.width  = ((self.buttonDiameter + padding) * 4) + (self.buttonSpacing.width * 3);
        frame.size.height = ((self.buttonDiameter + padding) * 3) + (self.buttonSpacing.height * 2);
    }
    else {
        frame.size.width  = ((self.buttonDiameter + padding) * 3) + (self.buttonSpacing.width * 2);
        frame.size.height = ((self.buttonDiameter + padding) * 4) + (self.buttonSpacing.height * 3);
    }
    self.frame = CGRectIntegral(frame);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    NSInteger i = 0;
    CGPoint origin = CGPointZero;
    for (TOPasscodeCircleButton *button in self.keypadButtons) {
        // Set the button frame
        CGRect frame = button.frame;
        frame.origin = origin;
        button.frame = frame;

        // Work out the next offset
        CGFloat horizontalOffset = frame.size.width + self.buttonSpacing.width;
        origin.x += horizontalOffset;

        i++;

        // If we're at the end of the row, move to the next one
        if (i % 3 == 0) {
            origin.x = 0.0f;
            origin.y = origin.y + frame.size.height + self.buttonSpacing.height;
        }
    }

    // Lay out the vertical button
    CGRect frame = self.verticalZeroButton.frame;
    frame.origin.x += (frame.size.width + self.buttonSpacing.width);
    self.verticalZeroButton.frame = frame;

    // Lay out the horizontal button
    frame = self.horizontalZeroButton.frame;
    frame.origin.x = (frame.size.width + self.buttonSpacing.width) * 3.0f;
    frame.origin.y = frame.size.height + self.buttonSpacing.height;
    self.horizontalZeroButton.frame = frame;

    // Layout the accessory buttons
    CGFloat midPointY = CGRectGetMidY(self.verticalZeroButton.frame);

    if (self.leftAccessoryView) {
        CGRect leftButtonFrame = self.keypadButtons.firstObject.frame;
        CGFloat midPointX = CGRectGetMidX(leftButtonFrame);

        [self.leftAccessoryView sizeToFit];
        self.leftAccessoryView.center = (CGPoint){midPointX, midPointY};
    }

    if (self.rightAccessoryView) {
        CGRect rightButtonFrame = self.keypadButtons[2].frame;
        CGFloat midPointX = CGRectGetMidX(rightButtonFrame);

        [self.rightAccessoryView sizeToFit];
        self.rightAccessoryView.center = (CGPoint){midPointX, midPointY};
    }
}

#pragma mark - Style Accessors -
- (void)setVibrancyEffect:(UIVibrancyEffect *)vibrancyEffect
{
    if (vibrancyEffect == _vibrancyEffect) { return; }
    _vibrancyEffect = vibrancyEffect;

    for (TOPasscodeCircleButton *button in self.keypadButtons) {
        button.vibrancyEffect = _vibrancyEffect;
    }
}

#pragma mark - Lazy Getters -
- (UIImage *)buttonImage
{
    if (!_buttonImage) {
        _buttonImage = [TOPasscodeCircleImage hollowCircleImageOfSize:self.buttonDiameter strokeWidth:self.buttonStrokeWidth padding:1.0f];
    }

    return _buttonImage;
}

- (UIImage *)tappedButtonImage
{
    if (!_tappedButtonImage) {
        _tappedButtonImage = [TOPasscodeCircleImage circleImageOfSize:self.buttonDiameter inset:self.buttonStrokeWidth * 0.5f padding:1.0f antialias:YES];
    }

    return _tappedButtonImage;
}

- (NSArray<TOPasscodeCircleButton *> *)keypadButtons
{
    if (_keypadButtons) { return _keypadButtons; }
    [self setUpButtons];
    return _keypadButtons;
}

#pragma mark - Audio Delegate Protocol -
- (BOOL)enableInputClicksWhenVisible
{
    return YES;
}

#pragma mark - Public Layout Setters -

- (void)setHorizontalLayout:(BOOL)horizontalLayout
{
    [self setHorizontalLayout:horizontalLayout animated:NO duration:0.0f];
}

- (void)setHorizontalLayout:(BOOL)horizontalLayout animated:(BOOL)animated duration:(CGFloat)duration
{
    if (horizontalLayout== _horizontalLayout) {
        return;
    }

    _horizontalLayout = horizontalLayout;

    // Resize itself now so the frame value is up to date externally
    [self sizeToFit];

    // Set initial animation state
    self.verticalZeroButton.hidden = NO;
    self.horizontalZeroButton.hidden = NO;

    self.verticalZeroButton.contentAlpha = _horizontalLayout ? 1.0f : 0.0f;
    self.horizontalZeroButton.contentAlpha = _horizontalLayout ? 0.0f : 1.0f;

    void (^animationBlock)(void) = ^{
        self.verticalZeroButton.contentAlpha = self.horizontalLayout ? 0.0f : 1.0f;
        self.horizontalZeroButton.contentAlpha = self.horizontalLayout ? 1.0f : 0.0f;
    };

    void (^completionBlock)(BOOL) = ^(BOOL complete) {
        self.verticalZeroButton.hidden = self.horizontalLayout;
        self.horizontalZeroButton.hidden = self.horizontalLayout;
    };

    // Don't animate if not needed
    if (!animated) {
        animationBlock();
        completionBlock(YES);
        return;
    }

    // Perform animation
    [UIView animateWithDuration:duration animations:animationBlock completion:completionBlock];
}

- (void)updateButtonsForCurrentState
{
    for (TOPasscodeCircleButton *circleButton in self.keypadButtons) {
        circleButton.backgroundImage = self.buttonImage;
        circleButton.hightlightedBackgroundImage = self.tappedButtonImage;
        circleButton.numberFont = self.buttonNumberFont;
        circleButton.letteringFont = self.buttonLetteringFont;
        circleButton.letteringVerticalSpacing = self.buttonLabelSpacing;
        circleButton.letteringCharacterSpacing = self.buttonLetteringSpacing;
        circleButton.tintColor = self.buttonBackgroundColor;
        circleButton.textColor = self.buttonTextColor;
        circleButton.highlightedTextColor = self.buttonHighlightedTextColor;
        if (!_showLettering) {
            circleButton.buttonLabel.letteringLabel.text = nil;
            circleButton.buttonLabel.verticallyCenterNumberLabel = YES;
        }
    }

    [self setNeedsLayout];
}

- (void)setButtonDiameter:(CGFloat)buttonDiameter
{
    if (_buttonDiameter == buttonDiameter) { return; }
    _buttonDiameter = buttonDiameter;
    _tappedButtonImage = nil;
    _buttonImage = nil;
    [self updateButtonsForCurrentState];
}

- (void)setButtonSpacing:(CGSize)buttonSpacing
{
    if (CGSizeEqualToSize(_buttonSpacing, buttonSpacing)) { return; }
    _buttonSpacing = buttonSpacing;
    [self updateButtonsForCurrentState];
}

- (void)setButtonStrokeWidth:(CGFloat)buttonStrokeWidth
{
    if (_buttonStrokeWidth== buttonStrokeWidth) { return; }
    _buttonStrokeWidth = buttonStrokeWidth;
    _tappedButtonImage = nil;
    _buttonImage = nil;
    [self updateButtonsForCurrentState];
}

- (void)setShowLettering:(BOOL)showLettering
{
    if (_showLettering == showLettering) { return; }
    _showLettering = showLettering;
    [self updateButtonsForCurrentState];
}

- (void)setButtonNumberFont:(UIFont *)buttonNumberFont
{
    if (_buttonNumberFont == buttonNumberFont) { return; }
    _buttonNumberFont = buttonNumberFont;
    [self updateButtonsForCurrentState];
}

- (void)setButtonLetteringFont:(UIFont *)buttonLetteringFont
{
    if (buttonLetteringFont == _buttonLetteringFont) { return; }
    _buttonLetteringFont = buttonLetteringFont;
    [self updateButtonsForCurrentState];
}

- (void)setButtonLabelSpacing:(CGFloat)buttonLabelSpacing
{
    if (buttonLabelSpacing == _buttonLabelSpacing) { return; }
    _buttonLabelSpacing = buttonLabelSpacing;
    [self updateButtonsForCurrentState];
}

- (void)setButtonLetteringSpacing:(CGFloat)buttonLetteringSpacing
{
    if (buttonLetteringSpacing == _buttonLetteringSpacing) { return; }
    _buttonLetteringSpacing = buttonLetteringSpacing;
    [self updateButtonsForCurrentState];
}

- (void)setButtonBackgroundColor:(UIColor *)buttonBackgroundColor
{
    if (buttonBackgroundColor == _buttonBackgroundColor) { return; }
    _buttonBackgroundColor = buttonBackgroundColor;
    [self updateButtonsForCurrentState];
}

- (void)setButtonTextColor:(UIColor *)buttonTextColor
{
    if (buttonTextColor == _buttonTextColor) { return; }
    _buttonTextColor = buttonTextColor;
    [self updateButtonsForCurrentState];
}

- (void)setButtonHighlightedTextColor:(UIColor *)buttonHighlightedTextColor
{
    if (buttonHighlightedTextColor == _buttonHighlightedTextColor) { return; }
    _buttonHighlightedTextColor = buttonHighlightedTextColor;
    [self updateButtonsForCurrentState];
}

- (void)setLeftAccessoryView:(UIView *)leftAccessoryView
{
    if (_leftAccessoryView == leftAccessoryView) { return; }
    _leftAccessoryView = leftAccessoryView;
    [self addSubview:_leftAccessoryView];
    [self setNeedsLayout];
}

- (void)setRightAccessoryView:(UIView *)rightAccessoryView
{
    if (_rightAccessoryView == rightAccessoryView) { return; }
    _rightAccessoryView = rightAccessoryView;
    [self addSubview:_rightAccessoryView];
    [self setNeedsLayout];
}

- (void)setContentAlpha:(CGFloat)contentAlpha
{
    _contentAlpha = contentAlpha;

    for (TOPasscodeCircleButton *button in self.keypadButtons) {
        // Skip whichever '0' button is not presently being used
        if ((self.horizontalLayout && button == self.verticalZeroButton) ||
            (!self.horizontalLayout && button == self.horizontalZeroButton))
        {
            continue;
        }

        button.contentAlpha = contentAlpha;
    }
}

@end
