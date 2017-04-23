//
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/10.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LMMediaPlayer.h"

extern NSString *const LMMediaPlayerViewPlayButtonImageKey;
extern NSString *const LMMediaPlayerViewPlayButtonSelectedImageKey;
extern NSString *const LMMediaPlayerViewStopButtonImageKey;
extern NSString *const LMMediaPlayerViewStopButtonSelectedImageKey;
extern NSString *const LMMediaPlayerViewFullscreenButtonImageKey;
extern NSString *const LMMediaPlayerViewFullscreenButtonSelectedImageKey;
extern NSString *const LMMediaPlayerViewUnfullscreenButtonImageKey;
extern NSString *const LMMediaPlayerViewUnfullscreenButtonSelectedImageKey;
extern NSString *const LMMediaPlayerViewShuffleButtonShuffledImageKey;
extern NSString *const LMMediaPlayerViewShuffleButtonShuffledSelectedImageKey;
extern NSString *const LMMediaPlayerViewShuffleButtonUnshuffledImageKey;
extern NSString *const LMMediaPlayerViewShuffleButtonUnshuffledSelectedImageKey;
extern NSString *const LMMediaPlayerViewRepeatButtonRepeatOneImageKey;
extern NSString *const LMMediaPlayerViewRepeatButtonRepeatOneSelectedImageKey;
extern NSString *const LMMediaPlayerViewRepeatButtonRepeatAllImageKey;
extern NSString *const LMMediaPlayerViewRepeatButtonRepeatAllSelectedImageKey;
extern NSString *const LMMediaPlayerViewRepeatButtonRepeatNoneImageKey;
extern NSString *const LMMediaPlayerViewRepeatButtonRepeatNoneSelectedImageKey;
extern NSString *const LMMediaPlayerViewActionButtonImageKey;

@class LMMediaPlayerView;

@protocol LMMediaPlayerViewDelegate <NSObject>

@required
- (BOOL)mediaPlayerViewWillStartPlaying:(LMMediaPlayerView *)playerView media:(LMMediaItem *)media;

@optional
- (void)mediaPlayerViewWillChangeState:(LMMediaPlayerView *)playerView state:(LMMediaPlaybackState)state;
- (void)mediaPlayerViewDidStartPlaying:(LMMediaPlayerView *)playerView media:(LMMediaItem *)media;
- (void)mediaPlayerViewDidFinishPlaying:(LMMediaPlayerView *)playerView media:(LMMediaItem *)media;
- (void)mediaPlayerViewDidChangeCurrentTime:(LMMediaPlayerView *)playerView;
- (void)mediaPlayerViewDidChangeRepeatMode:(LMMediaRepeatMode)mode playerView:(LMMediaPlayerView *)playerView;
- (void)mediaPlayerViewDidChangeShuffleMode:(BOOL)enabled playerView:(LMMediaPlayerView *)playerView;
- (void)mediaPlayerViewWillChangeFullscreenMode:(BOOL)fullscreen;
- (void)mediaPlayerViewDidChangeFullscreenMode:(BOOL)fullscreen;

@end

@interface LMMediaPlayerView : UIView <LMMediaPlayerDelegate>

@property (nonatomic, assign) id<LMMediaPlayerViewDelegate> delegate;
@property (nonatomic, readonly) LMMediaPlayer *mediaPlayer;
@property (nonatomic, unsafe_unretained) IBOutlet UISlider *currentTimeSlider;
@property (nonatomic, unsafe_unretained) IBOutlet UILabel *titleLabel;
@property (nonatomic, readonly) BOOL isFullscreen;
@property (nonatomic, unsafe_unretained) IBOutlet UIButton *nextButton;
@property (nonatomic, unsafe_unretained) IBOutlet UIButton *fullscreenButton_;
@property (nonatomic, unsafe_unretained) IBOutlet UIButton *previousButton;
@property (nonatomic, readonly) UIButton *actionButton;
@property (nonatomic, assign) BOOL userInterfaceHidden;
@property (nonatomic, readonly) BOOL bluredUserInterface;

+ (instancetype)sharedPlayerView;
+ (instancetype)create;
- (void)setHeaderViewHidden:(BOOL)hidden;
- (void)setFooterViewHidden:(BOOL)hidden;
- (void)setFullscreen:(BOOL)fullscreen animated:(BOOL)animated;
- (void)setFullscreen:(BOOL)fullscreen;
- (void)setButtonImages:(NSDictionary *)info;
- (void)setBluredUserInterface:(BOOL)bluredUserInterface visualEffect:(UIVisualEffect *)effect;

@end
