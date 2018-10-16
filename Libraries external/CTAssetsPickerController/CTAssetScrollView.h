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
#import "CTAssetItemViewController.h"
#import "CTAssetPlayButton.h"
#import "CTAssetSelectionButton.h"


NS_ASSUME_NONNULL_BEGIN

extern NSString * const CTAssetScrollViewDidTapNotification;
extern NSString * const CTAssetScrollViewPlayerWillPlayNotification;
extern NSString * const CTAssetScrollViewPlayerWillPauseNotification;


@interface CTAssetScrollView : UIScrollView

@property (nonatomic, assign) BOOL allowsSelection;

@property (nonatomic, strong, readonly, nullable) UIImage *image;
@property (nonatomic, strong, readonly, nullable) AVPlayer *player;

@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, readonly) CTAssetPlayButton *playButton;
@property (nonatomic, strong, readonly) CTAssetSelectionButton *selectionButton;


- (void)startActivityAnimating;
- (void)stopActivityAnimating;

- (void)setProgress:(CGFloat)progress;

- (void)bind:(PHAsset *)asset image:(nullable UIImage *)image requestInfo:(nullable NSDictionary<NSString*, id> *)info;
- (void)bind:(AVPlayerItem *)playerItem requestInfo:(nullable NSDictionary *)info;

- (void)updateZoomScalesAndZoom:(BOOL)zoom;

- (void)playVideo;
- (void)pauseVideo;

@end

NS_ASSUME_NONNULL_END