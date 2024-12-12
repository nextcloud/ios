//
//  TOPasscodeCircleButton.m
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

#import "TOPasscodeCircleButton.h"
#import "TOPasscodeCircleView.h"
#import "TOPasscodeButtonLabel.h"

@interface TOPasscodeCircleButton ()

@property (nonatomic, strong, readwrite) TOPasscodeButtonLabel *buttonLabel;
@property (nonatomic, strong, readwrite) TOPasscodeCircleView *circleView;
@property (nonatomic, strong, readwrite) UIVisualEffectView *vibrancyView;

@property (nonatomic, readwrite, copy) NSString *numberString;
@property (nonatomic, readwrite, copy) NSString *letteringString;

@end

@implementation TOPasscodeCircleButton

- (instancetype)initWithNumberString:(NSString *)numberString letteringString:(NSString *)letteringString
{
    if (self = [super init]) {
        _numberString = numberString;
        _letteringString = letteringString;
        _contentAlpha = 1.0f;
        [self setUp];
    }

    return self;
}

- (void)setUp
{
    self.userInteractionEnabled = YES;
    
    _textColor = [UIColor whiteColor];

    [self setUpSubviews];
    [self setUpViewInteraction];
}

- (void)setUpSubviews
{
    if (!self.circleView) {
        self.circleView = [[TOPasscodeCircleView alloc] initWithFrame:self.bounds];
        [self addSubview:self.circleView];
    }

    if (!self.buttonLabel) {
        self.buttonLabel = [[TOPasscodeButtonLabel alloc] initWithFrame:self.bounds];
        self.buttonLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.buttonLabel.userInteractionEnabled = NO;
        self.buttonLabel.textColor = self.textColor;
        self.buttonLabel.numberString = self.numberString;
        self.buttonLabel.letteringString = self.letteringString;
        [self addSubview:self.buttonLabel];
    }

    if (!self.vibrancyView) {
        self.vibrancyView = [[UIVisualEffectView alloc] initWithEffect:nil];
        self.vibrancyView.userInteractionEnabled = NO;
        [self.vibrancyView.contentView addSubview:self.circleView];
        [self addSubview:self.vibrancyView];
    }
}

- (void)setUpViewInteraction
{
    if (self.allTargets.count) { return; }

    [self addTarget:self action:@selector(buttonDidTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(buttonDidTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(buttonDidDragInside:) forControlEvents:UIControlEventTouchDragEnter];
    [self addTarget:self action:@selector(buttonDidDragOutside:) forControlEvents:UIControlEventTouchDragExit];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.vibrancyView.frame = self.bounds;
    self.circleView.frame = self.vibrancyView ? self.vibrancyView.bounds : self.bounds;
    self.buttonLabel.frame = self.bounds;
    [self bringSubviewToFront:self.buttonLabel];
}

#pragma mark - User Interaction -

- (void)buttonDidTouchDown:(id)sender
{
    if (self.buttonTappedHandler) { self.buttonTappedHandler(); }
    [self setHighlighted:YES animated:NO];
}

- (void)buttonDidTouchUpInside:(id)sender { [self setHighlighted:NO animated:YES]; }
- (void)buttonDidDragInside:(id)sender    { [self setHighlighted:YES animated:NO]; }
- (void)buttonDidDragOutside:(id)sender   { [self setHighlighted:NO animated:YES]; }

#pragma mark - Animated Accessors -

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [self.circleView setHighlighted:highlighted animated:animated];

    if (!self.highlightedTextColor) { return; }

    void (^textFadeBlock)(void) = ^{
        self.buttonLabel.textColor = highlighted ? self.highlightedTextColor : self.textColor;
    };

    if (!animated) {
        textFadeBlock();
        return;
    }

    [UIView transitionWithView:self.buttonLabel
                      duration:0.6f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:textFadeBlock
                    completion:nil];
}

#pragma mark - Accessors -

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    self.circleView.circleImage = backgroundImage;
    CGRect frame = self.frame;
    frame.size = backgroundImage.size;
    self.frame = CGRectIntegral(frame);
}

- (UIImage *)backgroundImage { return self.circleView.circleImage; }

/***********************************************************/

- (void)setVibrancyEffect:(UIVibrancyEffect *)vibrancyEffect
{
    if (_vibrancyEffect == vibrancyEffect) { return; }
    _vibrancyEffect = vibrancyEffect;
    self.vibrancyView.effect = _vibrancyEffect;
}

/***********************************************************/

- (void)setHightlightedBackgroundImage:(UIImage *)hightlightedBackgroundImage
{
    self.circleView.highlightedCircleImage = hightlightedBackgroundImage;
}

- (UIImage *)hightlightedBackgroundImage { return self.circleView.highlightedCircleImage; }

/***********************************************************/

- (void)setNumberFont:(UIFont *)numberFont
{
    self.buttonLabel.numberLabelFont = numberFont;
    [self setNeedsLayout];
}

- (UIFont *)numberFont { return self.buttonLabel.numberLabelFont; }

/***********************************************************/

- (void)setLetteringFont:(UIFont *)letteringFont
{
    self.buttonLabel.letteringLabelFont = letteringFont;
    [self setNeedsLayout];
}

- (UIFont *)letteringFont { return self.buttonLabel.letteringLabelFont; }

/***********************************************************/

- (void)setLetteringVerticalSpacing:(CGFloat)letteringVerticalSpacing
{
    self.buttonLabel.letteringVerticalSpacing = letteringVerticalSpacing;
    [self.buttonLabel setNeedsLayout];
}

- (CGFloat)letteringVerticalSpacing { return self.buttonLabel.letteringVerticalSpacing; }

/***********************************************************/

- (void)setLetteringCharacterSpacing:(CGFloat)letteringCharacterSpacing
{
    self.buttonLabel.letteringCharacterSpacing = letteringCharacterSpacing;
}

- (CGFloat)letteringCharacterSpacing { return self.buttonLabel.letteringCharacterSpacing; }

/***********************************************************/

- (void)setTextColor:(UIColor *)textColor
{
    if (textColor == _textColor) { return; }
    _textColor = textColor;

    self.buttonLabel.textColor = _textColor;
}

/***********************************************************/

- (void)setContentAlpha:(CGFloat)contentAlpha
{
    if (_contentAlpha == contentAlpha) {
        return;
    }

    _contentAlpha = contentAlpha;

    self.buttonLabel.alpha = contentAlpha;
    self.circleView.alpha = contentAlpha;
}

@end
