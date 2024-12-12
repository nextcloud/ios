//
//  TOPasscodeSettingsKeypadButton.m
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

#import "TOPasscodeSettingsKeypadButton.h"
#import "TOPasscodeButtonLabel.h"

@interface TOPasscodeSettingsKeypadButton ()

@property (nonatomic, strong, readwrite) TOPasscodeButtonLabel *buttonLabel;

@end

@implementation TOPasscodeSettingsKeypadButton

+ (TOPasscodeSettingsKeypadButton *)button
{
    TOPasscodeSettingsKeypadButton *button = [TOPasscodeSettingsKeypadButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0,0,100,60);
    return button;
}

#pragma mark - Lazy Accessor -
- (TOPasscodeButtonLabel *)buttonLabel
{
    if (_buttonLabel) { return _buttonLabel; }

    CGRect frame = self.bounds;
    frame.size.height -= self.bottomInset;

    _buttonLabel = [[TOPasscodeButtonLabel alloc] initWithFrame:frame];
    _buttonLabel.userInteractionEnabled = NO;
    _buttonLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_buttonLabel];

    return _buttonLabel;
}

#pragma mark - Layout Accessor -
- (void)setBottomInset:(CGFloat)bottomInset
{
    _bottomInset = bottomInset;

    CGRect frame = self.bounds;
    frame.size.height -= _bottomInset;
    self.buttonLabel.frame = frame;
    [self setNeedsLayout];
}

#pragma mark - Control Accessor -
- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    self.buttonLabel.alpha = enabled ? 1.0f : 0.5f;
}

#pragma mark - Background Image Accessor -

- (void)setHighlighted:(BOOL)highlighted {
    [self.layer removeAllAnimations];
    [UIView transitionWithView:self
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                                 UIViewAnimationOptionAllowAnimatedContent |
                                 UIViewAnimationOptionAllowUserInteraction
                    animations:^{
        [super setHighlighted:highlighted];
    } completion:nil];
}

- (void)setButtonBackgroundImage:(UIImage *)buttonBackgroundImage
{
    [self setBackgroundImage:buttonBackgroundImage forState:UIControlStateNormal];
}

- (UIImage *)buttonBackgroundImage { return [self backgroundImageForState:UIControlStateNormal]; }

- (void)setButtonTappedBackgroundImage:(UIImage *)buttonTappedBackgroundImage
{
    [self setBackgroundImage:buttonTappedBackgroundImage forState:UIControlStateHighlighted];
}

- (UIImage *)buttonTappedBackgroundImage { return [self backgroundImageForState:UIControlStateHighlighted]; }

@end
