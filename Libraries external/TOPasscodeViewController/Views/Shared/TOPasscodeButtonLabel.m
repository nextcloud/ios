//
//  TOPasscodeButtonLabel.m
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

#import "TOPasscodeButtonLabel.h"

@interface TOPasscodeButtonLabel ()

@property (nonatomic, strong, readwrite) UILabel *numberLabel;
@property (nonatomic, strong, readwrite) UILabel *letteringLabel;

@end

@implementation TOPasscodeButtonLabel

#pragma mark - View Setup -

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _letteringVerticalSpacing = 6.0f;
        _letteringCharacterSpacing = 3.0f;
        _letteringHorizontalSpacing = 5.0f;
        _numberLabelFont = [UIFont systemFontOfSize:37.5f weight:UIFontWeightThin];
        _letteringLabelFont = [UIFont systemFontOfSize:9.0f weight:UIFontWeightThin];
        [self setUpViews];
    }

    return self;
}

- (void)setUpViews
{
    if (!self.numberLabel) {
        self.numberLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.numberLabel.text = self.numberString;
        self.numberLabel.textColor = self.textColor;
        self.numberLabel.font = self.numberLabelFont;
        [self.numberLabel sizeToFit];
        [self addSubview:self.numberLabel];
    }

    // Create the lettering string only if we have a lettering value for it
    if (!self.letteringLabel && self.letteringString.length > 0) {
        self.letteringLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.letteringLabel.textColor = self.textColor;
        self.letteringLabel.font = self.letteringLabelFont;
        [self.letteringLabel sizeToFit];
        [self addSubview:self.letteringLabel];
        [self updateLetteringLabelText];
    }
}

#pragma mark - View Layout -

- (void)updateLetteringLabelText
{
    if (self.letteringString.length == 0) {
        return;
    }

    NSMutableAttributedString* attrStr = [[NSMutableAttributedString alloc] initWithString:self.letteringString];
    [attrStr addAttribute:NSKernAttributeName value:@(_letteringCharacterSpacing) range:NSMakeRange(0, attrStr.length-1)];
    self.letteringLabel.attributedText = attrStr;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGSize viewSize = self.bounds.size;

    [self.numberLabel sizeToFit];
    [self.letteringLabel sizeToFit];

    CGFloat numberVerticalHeight = self.numberLabelFont.capHeight;
    CGFloat letteringVerticalHeight = self.letteringLabelFont.capHeight;
    CGFloat textTotalHeight = (numberVerticalHeight+2.0f) + self.letteringVerticalSpacing + (letteringVerticalHeight+2.0f);

    CGRect frame = self.numberLabel.frame;
    frame.size.height = ceil(numberVerticalHeight) + 2.0f;
    frame.origin.x = ceilf((viewSize.width - frame.size.width) * 0.5f);

    if (!self.horizontalLayout && !self.verticallyCenterNumberLabel) {
        frame.origin.y = floorf((viewSize.height - textTotalHeight) * 0.5f);
    }
    else {
        frame.origin.y = floorf((viewSize.height - frame.size.height) * 0.5f);
    }
    self.numberLabel.frame = CGRectIntegral(frame);

    if (self.letteringLabel) {
        CGFloat y = CGRectGetMaxY(frame);
        y += self.letteringVerticalSpacing;

        frame = self.letteringLabel.frame;
        frame.size.height = ceil(letteringVerticalHeight) + 2.0f;

        if (!self.horizontalLayout) {
            frame.origin.y = floorf(y);
            frame.origin.x = (viewSize.width - frame.size.width) * 0.5f;
        }
        else {
            frame.origin.y = floorf((viewSize.height - frame.size.height) * 0.5f);
            frame.origin.x = CGRectGetMaxX(self.numberLabel.frame) + self.letteringHorizontalSpacing;
        }

        self.letteringLabel.frame = CGRectIntegral(frame);
    }
}

#pragma mark - Accessors -

- (void)setTextColor:(UIColor *)textColor
{
    if (textColor == _textColor) { return; }
    _textColor = textColor;

    self.numberLabel.textColor = _textColor;
    self.letteringLabel.textColor = _textColor;
}
/***********************************************************/

- (void)setNumberString:(NSString *)numberString
{
    self.numberLabel.text = numberString;
    [self setNeedsLayout];
}

- (NSString *)numberString { return self.numberLabel.text; }

/***********************************************************/

- (void)setLetteringString:(NSString *)letteringString
{
    _letteringString = [letteringString copy];
    [self setUpViews];
    [self updateLetteringLabelText];
    [self setNeedsLayout];
}

/***********************************************************/

- (void)setLetteringCharacterSpacing:(CGFloat)letteringCharacterSpacing
{
    _letteringCharacterSpacing = letteringCharacterSpacing;
    [self updateLetteringLabelText];
}

/***********************************************************/

- (void)setNumberLabelFont:(UIFont *)numberLabelFont
{
    if (_numberLabelFont == numberLabelFont) { return; }
    _numberLabelFont = numberLabelFont;
    self.numberLabel.font = _numberLabelFont;
}

/***********************************************************/

- (void)setLetteringLabelFont:(UIFont *)letteringLabelFont
{
    if (_letteringLabelFont == letteringLabelFont) { return; }
    _letteringLabelFont = letteringLabelFont;
    self.letteringLabel.font = letteringLabelFont;
}

@end
