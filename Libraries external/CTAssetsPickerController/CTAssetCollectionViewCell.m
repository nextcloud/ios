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
#import "CTAssetCollectionViewCell.h"
#import "NSBundle+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"
#import "NSNumberFormatter+CTAssetsPickerController.h"



@interface CTAssetCollectionViewCell ()

@property (nonatomic, assign) CGSize thumbnailSize;

@property (nonatomic, strong) CTAssetThumbnailStacks *thumbnailStacks;
@property (nonatomic, strong) UIView *labelsView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;

@property (nonatomic, assign) BOOL didSetupConstraints;

@property (nonatomic, strong) PHAssetCollection *collection;
@property (nonatomic, assign) NSUInteger count;

@end





@implementation CTAssetCollectionViewCell

- (instancetype)initWithThumbnailSize:(CGSize)size reuseIdentifier:(NSString *)reuseIdentifier;
{
    if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])
    {
        _thumbnailSize = size;
        
        _titleTextColor         = CTAssetCollectionViewCellTitleTextColor;
        _selectedTitleTextColor = CTAssetCollectionViewCellTitleTextColor;
        _countTextColor         = CTAssetCollectionViewCellCountTextColor;
        _selectedCountTextColor = CTAssetCollectionViewCellCountTextColor;

        _accessoryColor         = CTAssetCollectionViewCellAccessoryColor;
        _selectedAccessoryColor = CTAssetCollectionViewCellAccessoryColor;

        self.opaque                             = YES;
        self.isAccessibilityElement             = YES;
        self.textLabel.backgroundColor          = self.backgroundColor;
        self.detailTextLabel.backgroundColor    = self.backgroundColor;
        self.accessoryType                      = UITableViewCellAccessoryNone;
        
        [self setupViews];
    }
    
    return self;
}

#pragma mark - Setup

- (void)setupViews
{
    CTAssetThumbnailStacks *thumbnailStacks = [CTAssetThumbnailStacks newAutoLayoutView];
    thumbnailStacks.thumbnailSize = self.thumbnailSize;
    self.thumbnailStacks = thumbnailStacks;
    
    UILabel *titleLabel = [UILabel newAutoLayoutView];
    titleLabel.font = CTAssetCollectionViewCellTitleFont;
    titleLabel.textColor = self.titleTextColor;
    self.titleLabel = titleLabel;
    
    UILabel *countLabel = [UILabel newAutoLayoutView];
    countLabel.font = CTAssetCollectionViewCellCountFont;
    countLabel.textColor = self.countTextColor;
    self.countLabel = countLabel;
    
    UIView *labelsView = [UIView newAutoLayoutView];
    [labelsView addSubview:self.titleLabel];
    [labelsView addSubview:self.countLabel];
    self.labelsView = labelsView;
    
    [self.contentView addSubview:self.thumbnailStacks];
    [self.contentView addSubview:self.labelsView];
    
    UIImage *accessory = [UIImage ctassetsPickerImageNamed:@"DisclosureArrow"];
    accessory = [accessory imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *accessoryView = [[UIImageView alloc] initWithImage:accessory];
    accessoryView.tintColor = self.accessoryColor;
    self.accessoryView = accessoryView;
}

- (void)setupPlaceholderImage
{
    NSString *imageName = [self placeHolderImageNameOfCollectionSubtype:self.collection.assetCollectionSubtype];
    UIImage *image = [UIImage ctassetsPickerImageNamed:imageName];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    for (CTAssetThumbnailView *thumbnailView in self.thumbnailStacks.thumbnailViews)
    {
        [thumbnailView bind:nil assetCollection:nil];
        thumbnailView.backgroundImage = image;
    }
}

- (NSString *)placeHolderImageNameOfCollectionSubtype:(PHAssetCollectionSubtype)subtype
{
    if (subtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary)
        return @"GridEmptyCameraRoll";
    
    else if (subtype == PHAssetCollectionSubtypeSmartAlbumAllHidden)
        return @"GridHiddenAlbum";
    
    else if (subtype == PHAssetCollectionSubtypeAlbumCloudShared)
        return @"GridEmptyAlbumShared";
    
    else
        return @"GridEmptyAlbum";
}


#pragma mark - Apperance

- (UIFont *)titleFont
{
    return self.titleLabel.font;
}

- (void)setTitleFont:(UIFont *)titleFont
{
    UIFont *font = (titleFont) ? titleFont : CTAssetCollectionViewCellTitleFont;
    self.titleLabel.font = font;
}

- (void)setTitleTextColor:(UIColor *)titleTextColor
{
    UIColor *color = (titleTextColor) ? titleTextColor : CTAssetCollectionViewCellTitleTextColor;
    _titleTextColor = color;
}

- (void)setSelectedTitleTextColor:(UIColor *)titleTextColor
{
    UIColor *color = (titleTextColor) ? titleTextColor : CTAssetCollectionViewCellTitleTextColor;
    _selectedTitleTextColor = color;
}

- (UIFont *)countFont
{
    return self.countLabel.font;
}

- (void)setCountFont:(UIFont *)countFont
{
    UIFont *font = (countFont) ? countFont : CTAssetCollectionViewCellCountFont;
    self.countLabel.font = font;
}

- (void)setCountTextColor:(UIColor *)countTextColor
{
    UIColor *color = (countTextColor) ? countTextColor : CTAssetCollectionViewCellCountTextColor;
    _countTextColor = color;
}

- (void)setSelectedCountTextColor:(UIColor *)countTextColor
{
    UIColor *color = (countTextColor) ? countTextColor : CTAssetCollectionViewCellCountTextColor;
    _selectedCountTextColor = color;
}

- (void)setAccessoryColor:(UIColor *)accessoryColor
{
    UIColor *color = (accessoryColor) ? accessoryColor : CTAssetCollectionViewCellAccessoryColor;
    _accessoryColor = color;
}

- (void)setSelectedAccessoryColor:(UIColor *)accessoryColor
{
    UIColor *color = (accessoryColor) ? accessoryColor : CTAssetCollectionViewCellAccessoryColor;
    _selectedAccessoryColor = color;
}

- (UIColor *)selectedBackgroundColor
{
    return self.selectedBackgroundView.backgroundColor;
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    if (!selectedBackgroundColor)
        self.selectedBackgroundView = nil;
    else
    {
        UIView *view = [UIView new];
        view.backgroundColor = selectedBackgroundColor;
        self.selectedBackgroundView = view;
    }
}


#pragma mark - Override highlighted / selected

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self.thumbnailStacks setHighlighted:highlighted];
    
    self.titleLabel.textColor = (highlighted) ? self.selectedTitleTextColor : self.titleTextColor;
    self.countLabel.textColor = (highlighted) ? self.selectedCountTextColor : self.countTextColor;
    self.accessoryView.tintColor = (highlighted) ? self.selectedAccessoryColor : self.accessoryColor;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self.thumbnailStacks setHighlighted:selected];
    
    self.titleLabel.textColor = (selected) ? self.selectedTitleTextColor : self.titleTextColor;
    self.countLabel.textColor = (selected) ? self.selectedCountTextColor : self.countTextColor;
    self.accessoryView.tintColor = (selected) ? self.selectedAccessoryColor : self.accessoryColor;
}

#pragma mark - Update auto layout constraints

- (void)updateConstraints
{
    if (!self.didSetupConstraints)
    {
        CGSize size = self.thumbnailSize;
        CGFloat top = self.thumbnailStacks.edgeInsets.top;
        size.height += top;
        
        [NSLayoutConstraint autoSetPriority:UILayoutPriorityRequired forConstraints:^{
            [self.thumbnailStacks autoSetDimensionsToSize:size];
        }];
                
        [NSLayoutConstraint autoSetPriority:UILayoutPriorityDefaultHigh forConstraints:^{
            [self.thumbnailStacks autoPinEdgesToSuperviewMarginsExcludingEdge:ALEdgeTrailing];
        }];
        
        [self.labelsView autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
        [self.labelsView autoPinEdge:ALEdgeLeading
                              toEdge:ALEdgeTrailing
                              ofView:self.thumbnailStacks
                          withOffset:self.labelsView.layoutMargins.left
                            relation:NSLayoutRelationGreaterThanOrEqual];
        
        [self.titleLabel autoPinEdgesToSuperviewMarginsExcludingEdge:ALEdgeBottom];
        [self.countLabel autoPinEdgesToSuperviewMarginsExcludingEdge:ALEdgeTop];
        [self.countLabel autoPinEdge:ALEdgeTop
                              toEdge:ALEdgeBottom
                              ofView:self.titleLabel
                          withOffset:self.countLabel.layoutMargins.top
                            relation:NSLayoutRelationGreaterThanOrEqual];
        
        self.didSetupConstraints = YES;
    }
    
    [super updateConstraints];
}


#pragma mark - Bind asset collection

- (void)bind:(PHAssetCollection *)collection count:(NSUInteger)count
{
    self.collection = collection;
    self.count      = count;
    
    [self setupPlaceholderImage];

    self.titleLabel.text = collection.localizedTitle;
    
    if (count != NSNotFound)
    {
        NSNumberFormatter *nf = [NSNumberFormatter new];
        self.countLabel.text = [nf ctassetsPickerStringFromAssetsCount:count];
    }
    
    [self setNeedsUpdateConstraints];
    [self updateConstraintsIfNeeded];
}


#pragma mark - Accessibility label

- (NSString *)accessibilityLabel
{
    NSString *title = self.titleLabel.text;
    NSString *count = [NSString stringWithFormat:CTAssetsPickerLocalizedString(@"%@ Photos", nil), self.countLabel.text];
    
    NSArray *labels = @[title, count];
    return [labels componentsJoinedByString:@","];
}

@end