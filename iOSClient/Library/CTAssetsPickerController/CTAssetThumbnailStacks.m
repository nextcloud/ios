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
#import "CTAssetThumbnailStacks.h"
#import "CTAssetThumbnailView.h"


@interface CTAssetThumbnailStacks ()

@property (nonatomic, copy) NSArray *thumbnailViews;
@property (nonatomic, assign) UIEdgeInsets edgeInsets;

@property (nonatomic, assign) BOOL didSetupConstraints;

@end



@implementation CTAssetThumbnailStacks

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        _edgeInsets = UIEdgeInsetsMake(4.0, 0, 0, 0);
        
        self.opaque                 = YES;
        self.clipsToBounds          = YES;
        self.isAccessibilityElement = NO;
        
        [self setupViews];
    }
    
    return self;
}


#pragma mark - Setup

- (void)setupViews
{
    NSMutableArray *thumbnailViews = [NSMutableArray new];
    
    for (NSUInteger index = 0; index < 3; index++)
    {
        CTAssetThumbnailView *thumbnailView = [CTAssetThumbnailView newAutoLayoutView];
        thumbnailView.showsDuration = NO;
        thumbnailView.layer.borderColor = [UIColor whiteColor].CGColor;
        thumbnailView.layer.borderWidth = 0.5f;
        
        [thumbnailViews addObject:thumbnailView];
        [self insertSubview:thumbnailView atIndex:0];
    }
    
    self.thumbnailViews = [NSArray arrayWithArray:thumbnailViews];
}


#pragma markt - Setters

- (void)setThumbnailSize:(CGSize)thumbnailSize
{
    _thumbnailSize = thumbnailSize;

    [self setNeedsUpdateConstraints];
    [self updateConstraintsIfNeeded];
}


#pragma mark - Update auto layout constraints

- (void)updateConstraints
{
    if (!self.didSetupConstraints)
    {
        for (NSUInteger index = 0; index < self.thumbnailViews.count; index++)
        {
            CTAssetThumbnailView *thumbnailView = [self thumbnailAtIndex:index];
            
            CGFloat delta = self.edgeInsets.top / 2;
            
            CGSize size = self.thumbnailSize;
            size.width  -= index * delta * 2;
            size.height -= index * delta * 2;
            
            CGFloat inset = (index * delta * 3);

            [NSLayoutConstraint autoSetPriority:UILayoutPriorityRequired forConstraints:^{
                [thumbnailView autoSetDimensionsToSize:size];
            }];
            
            [NSLayoutConstraint autoSetPriority:UILayoutPriorityDefaultHigh forConstraints:^{
                [thumbnailView autoAlignAxisToSuperviewAxis:ALAxisVertical];
                [thumbnailView autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:inset];
            }];
        }
        
        self.didSetupConstraints = YES;
    }
    
    [super updateConstraints];
}


- (CTAssetThumbnailView *)thumbnailAtIndex:(NSUInteger)index
{
    return self.thumbnailViews[index];
}

- (void)setHighlighted:(BOOL)highlighted
{
    for (CTAssetThumbnailView *thumbnailView in self.thumbnailViews)
        thumbnailView.backgroundColor = CTAssetsPikcerThumbnailBackgroundColor;
}

@end
