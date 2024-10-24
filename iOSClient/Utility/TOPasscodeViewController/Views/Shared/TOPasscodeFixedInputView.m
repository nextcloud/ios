//
//  TOPasscodeFixedInputView.h
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

#import "TOPasscodeFixedInputView.h"
#import "TOPasscodeCircleView.h"
#import "TOPasscodeCircleImage.h"

@interface TOPasscodeFixedInputView ()

@property (nonatomic, strong, readwrite) NSArray<TOPasscodeCircleView *> *circleViews;
@property (nonatomic, strong) UIImage *circleImage;
@property (nonatomic, strong) UIImage *highlightedCircleImage;

@end

@implementation TOPasscodeFixedInputView

#pragma mark - Object Creation -

- (instancetype)initWithLength:(NSInteger)length
{
    if (self = [self initWithFrame:CGRectZero]) {
        _length = length;
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _circleSpacing = 25.0f;
        _circleDiameter = 16.0f;
        _length = 4;
    }

    return self;
}

#pragma mark - View Configuration -

- (void)sizeToFit
{
    // Resize the view to encompass the circles
    CGRect frame = self.frame;
    frame.size.width = (_circleDiameter * _length) + (_circleSpacing * (_length - 1)) + 2.0f;
    frame.size.height = _circleDiameter + 2.0f;
    self.frame = CGRectIntegral(frame);
}

- (void)layoutSubviews
{
    CGRect frame = CGRectZero;
    frame.size = (CGSize){self.circleDiameter + 2.0f, self.circleDiameter + 2.0f};

    for (TOPasscodeCircleView *circleView in self.circleViews) {
        circleView.frame = frame;
        frame.origin.x += self.circleDiameter + self.circleSpacing;
    }
}

#pragma mark - State Configuration -

- (void)setHighlightedLength:(NSInteger)highlightedLength animated:(BOOL)animated
{
    NSInteger i = 0;
    for (TOPasscodeCircleView *circleView in self.circleViews) {
        [circleView setHighlighted:(i < highlightedLength) animated:animated];
        i++;
    }
}

#pragma mark - Circle View Configuration -

- (void)setCircleViewsForLength:(NSInteger)length
{
    NSMutableArray *circleViews = [NSMutableArray array];
    if (self.circleViews) {
        [circleViews addObjectsFromArray:self.circleViews];
    }

    [UIView performWithoutAnimation:^{
        while (circleViews.count != length) {
            // Remove any extra circle views
            if (circleViews.count > length) {
                TOPasscodeCircleView *lastCircle = circleViews.lastObject;
                [lastCircle removeFromSuperview];
                [circleViews removeLastObject];
                continue;
            }

            // Add any new circle views
            TOPasscodeCircleView *newCircleView = [[TOPasscodeCircleView alloc] init];
            [self setImagesOfCircleView:newCircleView];
            [self addSubview:newCircleView];
            [circleViews addObject:newCircleView];
        }

        self.circleViews = [NSArray arrayWithArray:circleViews];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }];
}

- (void)setCircleImagesForDiameter:(CGFloat)diameter
{
    self.circleImage = [TOPasscodeCircleImage hollowCircleImageOfSize:diameter strokeWidth:1.2f padding:1.0f];
    self.highlightedCircleImage = [TOPasscodeCircleImage circleImageOfSize:diameter inset:0.5f padding:1.0f antialias:YES];

    for (TOPasscodeCircleView *circleView in self.circleViews) {
        [self setImagesOfCircleView:circleView];
    }
}

- (void)setImagesOfCircleView:(TOPasscodeCircleView *)circleView
{
    circleView.circleImage = self.circleImage;
    circleView.highlightedCircleImage = self.highlightedCircleImage;
}

#pragma mark - Accessors -

- (NSArray<TOPasscodeCircleView *> *)circleViews
{
    if (_circleViews) { return _circleViews; }
    _circleViews = [NSArray array];
    [self setCircleViewsForLength:self.length];
    [self setCircleImagesForDiameter:self.circleDiameter];
    return _circleViews;
}

- (void)setCircleDiameter:(CGFloat)circleDiameter
{
    if (circleDiameter == _circleDiameter) { return; }
    _circleDiameter = circleDiameter;
    [self setCircleImagesForDiameter:_circleDiameter];
    [self sizeToFit];
}

- (void)setLength:(NSInteger)length
{
    if (_length == length) { return; }
    _length = length;
    [self setCircleViewsForLength:length];
}

- (void)setHighlightedLength:(NSInteger)highlightedLength
{
    [self setHighlightedLength:highlightedLength animated:NO];
}

@end
