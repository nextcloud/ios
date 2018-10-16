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
#import "CTAssetPlayButton.h"
#import "NSBundle+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"



@interface CTAssetPlayButton ()

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIVisualEffectView *vibrancyView;
@property (nonatomic, strong) UIView *vibrancyFill;

@property (nonatomic, strong) UIView *highlightedView;
@property (nonatomic, strong) UIView *colorView;

@property (nonatomic, strong) UIImageView *glyphMask;
@property (nonatomic, strong) UIImageView *buttonMask;

@property (nonatomic, assign) BOOL didSetupConstraints;

@end





@implementation CTAssetPlayButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        
        [self setupViews];
        [self localize];
    }
    
    return self;
}



#pragma mark - Setup

- (void)setupViews
{
    [self setupEffectViews];
    [self setupHightlightedView];
    [self setupColorView];
    [self setupMaskViews];
}

- (void)setupEffectViews
{
    // Blur effect
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.userInteractionEnabled = NO;
    self.blurView = blurView;
    
    // Vibrancy effect
    UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    UIVisualEffectView *vibrancyView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
    vibrancyView.userInteractionEnabled = NO;
    self.vibrancyView = vibrancyView;
    
    UIView *vibrancyFill = [UIView newAutoLayoutView];
    vibrancyFill.backgroundColor = [UIColor whiteColor];
    vibrancyFill.userInteractionEnabled = NO;
    self.vibrancyFill = vibrancyFill;
    
    // Add fill to the vibrancy view
    [vibrancyView.contentView addSubview:self.vibrancyFill];
    [blurView.contentView addSubview:self.vibrancyView];
    
    [self addSubview:blurView];
}

- (void)setupHightlightedView
{
    UIView *highlightedView = [UIView newAutoLayoutView];
    highlightedView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    highlightedView.userInteractionEnabled = NO;
    highlightedView.hidden = YES;
    self.highlightedView = highlightedView;
    
    [self addSubview:self.highlightedView];
}

- (void)setupColorView
{
    UIView *colorView = [UIView newAutoLayoutView];
    colorView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.8];
    colorView.userInteractionEnabled = NO;
    self.colorView = colorView;
    
    [self addSubview:self.colorView];
}

- (void)setupMaskViews
{
    UIImage *glyphMaskImage = [UIImage ctassetsPickerImageNamed:@"VideoPlayGlyphMask"];
    UIImageView *glyphMask = [[UIImageView alloc] initWithImage:glyphMaskImage];
    glyphMask.userInteractionEnabled = NO;
    self.colorView.maskView = glyphMask;
    
    UIImage *buttonMaskImage = [UIImage ctassetsPickerImageNamed:@"VideoPlayButtonMask"];
    UIImageView *buttonMask = [[UIImageView alloc] initWithImage:buttonMaskImage];
    buttonMask.userInteractionEnabled = NO;
    self.maskView = buttonMask;
}

- (void)localize
{
    self.accessibilityLabel = CTAssetsPickerLocalizedString(@"Play", nil);
}

- (void)updateConstraints
{
    if (!self.didSetupConstraints)
    {
        CGSize size = [UIImage ctassetsPickerImageNamed:@"VideoPlayButtonMask"].size;
        
        [NSLayoutConstraint autoSetPriority:UILayoutPriorityRequired forConstraints:^{
            [self autoSetDimensionsToSize:size];
        }];
        
        [self.blurView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        [self.vibrancyView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        [self.vibrancyFill autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        [self.highlightedView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        [self.colorView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        
        self.didSetupConstraints = YES;        
    }
    
    [super updateConstraints];
}


#pragma mark - States

- (void)setHighlighted:(BOOL)highlighted
{
    super.highlighted = highlighted;
    self.highlightedView.hidden = !highlighted;
}

@end
