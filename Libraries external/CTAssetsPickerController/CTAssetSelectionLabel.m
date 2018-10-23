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
#import "CTAssetSelectionLabel.h"
#import "CTAssetsPickerDefines.h"


/**
 *  The label to show selection index.
 */
@interface CTAssetSelectionLabel ()

#pragma mark Managing Auto Layout

/**
 *  The constraints of the size of the label.
 */
@property (nonatomic, strong) NSArray *sizeConstraints;

/**
 *  The constraint for pinning the label to vertical edge.
 */
@property (nonatomic, strong) NSLayoutConstraint *verticalConstraint;

/**
 *  The constraint for pinning the label to horizontal edge.
 */
@property (nonatomic, strong) NSLayoutConstraint *horizontalConstraint;

/**
 *  Determines whether or not the constraints have been set up.
 */
@property (nonatomic, assign) BOOL didSetupConstraints;

@end


@implementation CTAssetSelectionLabel

#pragma mark Initializing a Label Object

/**
 *  Designated Initializer
 *
 *  @return an initialized label object
 */
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        self.textAlignment = NSTextAlignmentCenter;
        self.font = CTAssetLabelFont;
        self.textColor = CTAssetLabelTextColor;
        self.backgroundColor = CTAssetLabelBackgroundColor;
        self.layer.borderColor = CTAssetLabelBorderColor.CGColor;
        self.layer.masksToBounds = YES;
        self.isAccessibilityElement = NO;
    }
    
    return self;
}


#pragma mark Customizing Appearance

/**
 *  The width of the label's border
 */
- (CGFloat)borderWidth
{
    return self.layer.borderWidth;
}

- (void)setBorderWidth:(CGFloat)borderWidth
{
    self.layer.borderWidth = borderWidth;
}

/**
 *  The color of the label's border
 */

- (UIColor *)borderColor
{
    return [UIColor colorWithCGColor:self.layer.borderColor];
}

- (void)setBorderColor:(UIColor *)borderColor
{
    UIColor *color = (borderColor) ? borderColor : CTAssetLabelBorderColor;
    self.layer.borderColor = color.CGColor;
}

/**
 *  To set the size of label.
 *
 *  @param size The size of the label.
 */
- (void)setSize:(CGSize)size
{
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        size = CTAssetLabelSize;
    }

    [self removeConstraints:self.sizeConstraints];
    
    [NSLayoutConstraint autoSetPriority:UILayoutPriorityRequired forConstraints:^{
        self.sizeConstraints = [self autoSetDimensionsToSize:size];
    }];
}

/**
 *  To set the size of label.
 *
 *  @param cornerRadius The radius to use when drawing rounded corners for the label’s background.
 */
- (void)setCornerRadius:(CGFloat)cornerRadius
{
    self.layer.cornerRadius = cornerRadius;
}

/**
 *  To set margin of the label from the edges.
 *
 *  @param margin The margin from the edges.
 *
 *  @see setMargin:forVerticalEdge:horizontalEdge:
 */
- (void)setMargin:(CGFloat)margin
{
    [self setMargin:margin forVerticalEdge:NSLayoutAttributeRight horizontalEdge:NSLayoutAttributeBottom];
}

/**
 *  To set margin of the label from specific edges.
 *
 *  @param margin The margin from the edges.
 *  @param edgeX  The layout attribute respresents vertical edge that the label pins to. Either `NSLayoutAttributeLeft` or `NSLayoutAttributeRight`.
 *  @param edgeY  The layout attribute respresents horizontal edge that the label pins to. Either `NSLayoutAttributeTop` or `NSLayoutAttributeBottom`.
 *
 *  @see setMargin:
 */
- (void)setMargin:(CGFloat)margin forVerticalEdge:(NSLayoutAttribute)edgeX horizontalEdge:(NSLayoutAttribute)edgeY
{
    NSAssert(edgeX == NSLayoutAttributeLeft || edgeX == NSLayoutAttributeRight,
             @"Vertical edge must be NSLayoutAttributeLeft or NSLayoutAttributeRight");

    NSAssert(edgeY == NSLayoutAttributeTop || edgeY == NSLayoutAttributeBottom,
             @"Horizontal edge must be NSLayoutAttributeTop or NSLayoutAttributeBottom");

    [self.superview removeConstraints:@[self.verticalConstraint, self.horizontalConstraint]];
    self.verticalConstraint   = [self autoPinEdgeToSuperviewEdge:(ALEdge)edgeX withInset:margin];
    self.horizontalConstraint = [self autoPinEdgeToSuperviewEdge:(ALEdge)edgeY withInset:margin];
}

/**
 *  To set the text attributes to display the label.
 *
 *  Currently only supports attributes `NSFontAttributeName`, `NSForegroundColorAttributeName` and `NSBackgroundColorAttributeName`.
 *
 *  @param textAttributes The text attributes used to display the label.
 */
- (void)setTextAttributes:(NSDictionary *)textAttributes
{
    self.font  = (textAttributes) ? textAttributes[NSFontAttributeName] : CTAssetLabelFont;
    self.textColor = (textAttributes) ? textAttributes[NSForegroundColorAttributeName] : CTAssetLabelTextColor;
    self.backgroundColor = (textAttributes) ? textAttributes[NSBackgroundColorAttributeName] : CTAssetLabelBackgroundColor;
}


#pragma mark Triggering Auto Layout

/**
 *  Updates constraints of the label.
 */
- (void)updateConstraints
{
    if (!self.didSetupConstraints)
    {
        [NSLayoutConstraint autoSetPriority:UILayoutPriorityRequired forConstraints:^{
            self.sizeConstraints = [self autoSetDimensionsToSize:CTAssetLabelSize];
        }];

        self.verticalConstraint   = [self autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
        self.horizontalConstraint = [self autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:0];
        
        self.didSetupConstraints = YES;
    }
    
    [super updateConstraints];
}

@end
