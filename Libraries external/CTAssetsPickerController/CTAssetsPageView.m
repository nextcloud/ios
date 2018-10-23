/*
 
 MIT License (MIT)
 
 Copyright (c) 2015 Clement CN Tsang
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#import <PureLayout/PureLayout.h>
#import "CTAssetsPickerDefines.h"
#import "CTAssetsPageView.h"

@interface CTAssetsPageView ()

@property (nonatomic, assign) BOOL didSetupConstraints;

@end



@implementation CTAssetsPageView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        _pageBackgroundColor = CTAssetsPageViewPageBackgroundColor;
        _fullscreenBackgroundColor = CTAssetsPageViewFullscreenBackgroundColor;
        [self setupViews];
    }
    
    return self;
}


#pragma mark - Setup

- (void)setupViews
{
    self.backgroundColor = self.pageBackgroundColor;
}


#pragma mark - Apperance

- (void)setPageBackgroundColor:(UIColor *)backgroundColor
{
    UIColor *color = (backgroundColor) ? backgroundColor : CTAssetsPageViewPageBackgroundColor;
    _pageBackgroundColor = color;
    self.backgroundColor = color;
}

- (void)setFullscreenBackgroundColor:(UIColor *)fullscreenBackgroundColor
{
    UIColor *color = (fullscreenBackgroundColor) ? fullscreenBackgroundColor : CTAssetsPageViewFullscreenBackgroundColor;
    _fullscreenBackgroundColor = color;
}


#pragma mark - Update auto layout constraints

- (void)updateConstraints
{
    if (!self.didSetupConstraints)
    {
        [self autoPinEdgesToSuperviewEdges];
        self.didSetupConstraints = YES;
    }
    
    [super updateConstraints];
}


#pragma mark - Fading views

- (void)enterFullscreen
{
    [UIView animateWithDuration:0.2
                     animations:^{
                         self.backgroundColor = self.fullscreenBackgroundColor;
                     }];
}

- (void)exitFullscreen
{
    [UIView animateWithDuration:0.2
                     animations:^{
                         self.backgroundColor = self.pageBackgroundColor;
                     }];
}


@end
