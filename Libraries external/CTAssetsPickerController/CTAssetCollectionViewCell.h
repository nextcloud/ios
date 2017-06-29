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

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "CTAssetThumbnailStacks.h"

NS_ASSUME_NONNULL_BEGIN

@interface CTAssetCollectionViewCell : UITableViewCell

@property (nonatomic, strong, readonly, nonnull) CTAssetThumbnailStacks *thumbnailStacks;

@property (nonatomic, weak, nullable) UIFont *titleFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong, nullable) UIColor *titleTextColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong, nullable) UIColor *selectedTitleTextColor UI_APPEARANCE_SELECTOR;

@property (nonatomic, weak, nullable) UIFont *countFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong, nullable) UIColor *countTextColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong, nullable) UIColor *selectedCountTextColor UI_APPEARANCE_SELECTOR;

@property (nonatomic, strong, nullable) UIColor *accessoryColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong, nullable) UIColor *selectedAccessoryColor UI_APPEARANCE_SELECTOR;

@property (nonatomic, weak, nullable) UIColor *selectedBackgroundColor UI_APPEARANCE_SELECTOR;


- (instancetype)initWithThumbnailSize:(CGSize)size reuseIdentifier:(nullable NSString *)reuseIdentifier;
- (void)bind:(nonnull PHAssetCollection *)collection count:(NSUInteger)count;

@end

NS_ASSUME_NONNULL_END