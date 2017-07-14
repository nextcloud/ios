/*
 
 MIT License (MIT)
 
 Copyright (c) 2013 Clement CN Tsang
 
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
#import "CTAssetsGridSelectedView.h"
#import "CTAssetCheckmark.h"
#import "CTAssetSelectionLabel.h"




@interface CTAssetsGridSelectedView ()

@property (nonatomic, strong) CTAssetCheckmark *checkmark;
@property (nonatomic, strong) CTAssetSelectionLabel *selectionIndexLabel;

@end





@implementation CTAssetsGridSelectedView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self setupViews];
        self.showsSelectionIndex = NO;
    }
    
    return self;
}


#pragma mark - Setup

- (void)setupViews
{
    self.backgroundColor = CTAssetsGridSelectedViewBackgroundColor;
    self.layer.borderColor = CTAssetsGridSelectedViewTintColor.CGColor;
    
    CTAssetCheckmark *checkmark = [CTAssetCheckmark newAutoLayoutView];
    self.checkmark = checkmark;
    [self addSubview:checkmark];
    
    CTAssetSelectionLabel *selectionIndexLabel = [CTAssetSelectionLabel newAutoLayoutView];
    self.selectionIndexLabel = selectionIndexLabel;
    
    [self addSubview:self.selectionIndexLabel];
}


#pragma mark - Accessors

- (void)setShowsSelectionIndex:(BOOL)showsSelectionIndex
{
    _showsSelectionIndex = showsSelectionIndex;
    
    if (showsSelectionIndex)
    {
        self.checkmark.hidden = YES;
        self.selectionIndexLabel.hidden = NO;
    }
    else
    {
        self.checkmark.hidden = NO;
        self.selectionIndexLabel.hidden = YES;
    }
}

- (void)setSelectionIndex:(NSUInteger)selectionIndex
{
    _selectionIndex = selectionIndex;
    self.selectionIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)(selectionIndex + 1)];
}


#pragma mark - Apperance

- (UIColor *)selectedBackgroundColor
{
    return self.backgroundColor;
}

- (void)setSelectedBackgroundColor:(UIColor *)backgroundColor
{
    UIColor *color = (backgroundColor) ? backgroundColor : CTAssetsGridSelectedViewBackgroundColor;
    self.backgroundColor = color;
}

- (CGFloat)borderWidth
{
    return self.layer.borderWidth;
}

- (void)setBorderWidth:(CGFloat)borderWidth
{
    self.layer.borderWidth = borderWidth;
}

- (void)setTintColor:(UIColor *)tintColor
{
    UIColor *color = (tintColor) ? tintColor : CTAssetsGridSelectedViewTintColor;
    self.layer.borderColor = color.CGColor;
}


#pragma mark - Accessibility Label

- (NSString *)accessibilityLabel
{
    return self.selectionIndexLabel.text;
}


@end
