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
#import "CTAssetsPickerAccessDeniedView.h"
#import "NSBundle+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"



@interface CTAssetsPickerAccessDeniedView ()

@property (nonatomic, strong) UIImageView *padlock;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *message;

@property (nonatomic, assign) BOOL didSetupConstraints;

@end;


@implementation CTAssetsPickerAccessDeniedView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self setupViews];
    }
    
    return self;
}

#pragma mark - Setup

- (void)setupViews
{
    UIImageView *padlock = [self padlockImageView];
    self.padlock = padlock;
    
    UILabel *title      = [UILabel new];
    title.textColor     = CTAssetsPikcerAccessDeniedViewTextColor;
    title.font          = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 5;
    title.text          = CTAssetsPickerLocalizedString(@"This app does not have access to your photos or videos.", nil);
    self.title = title;
    
    UILabel *message        = [UILabel new];
    message.textColor       = CTAssetsPikcerAccessDeniedViewTextColor;
    message.font            = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    message.textAlignment   = NSTextAlignmentCenter;
    message.numberOfLines   = 5;
    message.text            = CTAssetsPickerLocalizedString(@"You can enable access in Privacy Settings.", nil);
    self.message = message;
    
    [self addSubview:self.padlock];
    [self addSubview:self.title];
    [self addSubview:self.message];
}

- (UIImageView *)padlockImageView
{
    UIImage *image = [UIImage ctassetsPickerImageNamed:@"AccessDeniedViewLock"];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    UIImageView *padlock = [[UIImageView alloc] initWithImage:image];
    padlock.tintColor    = CTAssetsPikcerAccessDeniedViewTextColor;
    
    return padlock;
}

#pragma mark - Update auto layout constraints

- (void)updateConstraints
{
    if (!self.didSetupConstraints)
    {
        [self autoCenterInSuperview];
        
        // suggested solution for issue #176
        [self autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:self.layoutMargins.top];
        [self autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:self.layoutMargins.bottom];

        [self.padlock autoAlignAxisToSuperviewAxis:ALAxisVertical];
        [self.padlock autoPinEdgeToSuperviewEdge:ALEdgeTop];
        [self.title autoAlignAxis:ALAxisVertical toSameAxisOfView:self.padlock];
        [self.title autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.padlock withOffset:20];
        [self.title autoPinEdgeToSuperviewEdge:ALEdgeLeading];
        [self.title autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
        [self.message autoAlignAxis:ALAxisVertical toSameAxisOfView:self.padlock];
        [self.message autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.title withOffset:10];
        [self.message autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeTop];
        
        self.didSetupConstraints = YES;
    }
    
    [super updateConstraints];
}


@end
