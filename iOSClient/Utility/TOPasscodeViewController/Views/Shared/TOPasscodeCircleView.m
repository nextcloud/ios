//
//  TOPasscodeCircleView.m
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

#import "TOPasscodeCircleView.h"

@interface TOPasscodeCircleView ()
@property (nonatomic, strong) UIImageView *bottomView;
@property (nonatomic, strong) UIImageView *topView;
@end

@implementation TOPasscodeCircleView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;

        self.bottomView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.bottomView.userInteractionEnabled = NO;
        self.bottomView.contentMode = UIViewContentModeCenter;
        self.bottomView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.bottomView];

        self.topView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.topView.userInteractionEnabled = NO;
        self.topView.contentMode = UIViewContentModeCenter;
        self.topView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.topView.alpha = 0.0f;
        [self addSubview:self.topView];
    }

    return self;
}

- (void)setIsHighlighted:(BOOL)isHighlighted
{
    [self setHighlighted:isHighlighted animated:NO];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if (highlighted == self.isHighlighted) { return; }

    _isHighlighted = highlighted;

    void (^animationBlock)(void) = ^{
        self.topView.alpha = highlighted ? 1.0f : 0.0f;
    };

    if (!animated) {
        animationBlock();
        return;
    }

    [UIView animateWithDuration:0.45f animations:animationBlock];
}

- (void)setCircleImage:(UIImage *)circleImage
{
    _circleImage = circleImage;
    self.bottomView.image = circleImage;
}

- (void)setHighlightedCircleImage:(UIImage *)highlightedCircleImage
{
    _highlightedCircleImage = highlightedCircleImage;
    self.topView.image = highlightedCircleImage;
}

@end
