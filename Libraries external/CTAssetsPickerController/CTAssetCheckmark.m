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
#import "CTAssetCheckmark.h"
#import "NSBundle+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"


/**
 *  The check mark to show selected asset.
 */
@interface CTAssetCheckmark ()


#pragma mark Managing Subviews

/**
 *  The image view of the check mark shadow.
 */
@property (nonatomic, strong) UIImageView *shadowImageView;

/**
 *  The image view of the check mark.
 */
@property (nonatomic, strong) UIImageView *checkmarkImageView;


#pragma mark Managing Auto Layout

/**
 *  The constraint for pinning the check mark to vertical edge.
 */
@property (nonatomic, strong) NSLayoutConstraint *verticalConstraint;

/**
 *  The constraint for pinning the check mark to horizontal edge.
 */
@property (nonatomic, strong) NSLayoutConstraint *horizontalConstraint;

/**
 *  Determines whether or not the constraints have been set up.
 */
@property (nonatomic, assign) BOOL didSetupConstraints;

@end


@implementation CTAssetCheckmark

#pragma mark Initializing a Check Mark Object

/**
 *  Designated Initializer
 *
 *  @return an initialized check mark object
 */
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = NO;
        [self setupViews];
    }
    
    return self;
}


#pragma mark Setting up Subviews

/**
 *  To setup subviews.
 */
- (void)setupViews
{
    UIImage *shadowImage = [UIImage ctassetsPickerImageNamed:@"CheckmarkShadow"];
    UIImageView *shadowImageView = [[UIImageView alloc] initWithImage:shadowImage];
    shadowImageView.userInteractionEnabled = NO;
    self.shadowImageView = shadowImageView;
    [self addSubview:self.shadowImageView];
    
    UIImage *checkmarkImage = [UIImage ctassetsPickerImageNamed:@"Checkmark"];
    checkmarkImage = [checkmarkImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *checkmarkImageView = [[UIImageView alloc] initWithImage:checkmarkImage];
    checkmarkImageView.userInteractionEnabled = NO;
    self.checkmarkImageView = checkmarkImageView;
    [self addSubview:self.checkmarkImageView];
}


#pragma mark Customizing Appearance

/**
 *  To set margin of the check mark from specific edges.
 *
 *  @param margin The margin from the edges.
 *  @param edgeX  The layout attribute respresents vertical edge that the check mark pins to. Either `NSLayoutAttributeLeft` or `NSLayoutAttributeRight`.
 *  @param edgeY  The layout attribute respresents horizontal edge that the check mark pins to. Either `NSLayoutAttributeTop` or `NSLayoutAttributeBottom`.
 */
- (void)setMargin:(CGFloat)margin forVerticalEdge:(NSLayoutAttribute)edgeX horizontalEdge:(NSLayoutAttribute)edgeY
{
    NSAssert(edgeX == NSLayoutAttributeLeft || edgeX == NSLayoutAttributeRight, @"Vertical edge must be NSLayoutAttributeLeft or NSLayoutAttributeRight");
    NSAssert(edgeY == NSLayoutAttributeTop || edgeY == NSLayoutAttributeBottom, @"Horizontal edge must be NSLayoutAttributeTop or NSLayoutAttributeBottom");
    
    [self.superview removeConstraints:@[self.verticalConstraint, self.horizontalConstraint]];
    self.verticalConstraint   = [self autoPinEdgeToSuperviewEdge:(ALEdge)edgeX withInset:margin];
    self.horizontalConstraint = [self autoPinEdgeToSuperviewEdge:(ALEdge)edgeY withInset:margin];
}


#pragma mark Triggering Auto Layout

/**
 *  Updates constraints of the check mark.
 */
- (void)updateConstraints
{
    if (!self.didSetupConstraints)
    {
        CGSize size = [UIImage ctassetsPickerImageNamed:@"CheckmarkShadow"].size;
        
        [NSLayoutConstraint autoSetPriority:UILayoutPriorityRequired forConstraints:^{
            [self autoSetDimensionsToSize:size];
        }];
        
        [self.shadowImageView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        [self.checkmarkImageView autoCenterInSuperview];
        
        self.verticalConstraint   = [self autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:0];
        self.horizontalConstraint = [self autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
        
        self.didSetupConstraints = YES;
    }
    
    [super updateConstraints];
}

@end
