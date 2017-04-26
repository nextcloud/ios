//
//  LMMediaPlayer.h
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/10.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "LMMediaItem.h"

@class LMMediaPlayer;

typedef NS_ENUM(NSUInteger, LMMediaPlaybackState) {
	LMMediaPlaybackStateStopped,
	LMMediaPlaybackStatePlaying,
	LMMediaPlaybackStatePaused
};

typedef NS_ENUM(NSUInteger, LMMediaRepeatMode) {
	LMMediaRepeatModeDefault,
	LMMediaRepeatModeOne,
	LMMediaRepeatModeAll,
	LMMediaRepeatModeNone = LMMediaRepeatModeDefault
};

extern NSString *const LMMediaPlayerPauseNotification;
extern NSString *const LMMediaPlayerStopNotification;

@protocol LMMediaPlayerDelegate <NSObject>

@required
- (BOOL)mediaPlayerWillStartPlaying:(LMMediaPlayer *)player media:(LMMediaItem *)media;

@optional
- (void)mediaPlayerWillChangeState:(LMMediaPlaybackState)state;
- (void)mediaPlayerDidStartPlaying:(LMMediaPlayer *)player media:(LMMediaItem *)media;
- (void)mediaPlayerDidFinishPlaying:(LMMediaPlayer *)player media:(LMMediaItem *)media;
- (void)mediaPlayerDidStop:(LMMediaPlayer *)player media:(LMMediaItem *)media;
- (void)mediaPlayerDidChangeCurrentTime:(LMMediaPlayer *)player;
- (void)mediaPlayerDidChangeRepeatMode:(LMMediaRepeatMode)mode player:(LMMediaPlayer *)player;
- (void)mediaPlayerDidChangeShuffleMode:(BOOL)enabled player:(LMMediaPlayer *)player;

@end

@interface LMMediaPlayer : NSObject

@property (nonatomic, assign) id<LMMediaPlayerDelegate> delegate;
@property (nonatomic, readonly) LMMediaItem *nowPlayingItem;
@property (nonatomic, readonly) LMMediaPlaybackState playbackState;
@property (nonatomic, assign) LMMediaRepeatMode repeatMode;
@property (nonatomic, readonly) BOOL shuffleMode;
@property (nonatomic, readonly) NSInteger index;

+ (instancetype)sharedPlayer;
- (AVPlayer *)corePlayer;
- (void)pauseOtherPlayer;
- (void)stopOtherPlayer;
- (void)addMedia:(LMMediaItem *)media;
- (void)removeMediaAtIndex:(NSUInteger)index;
- (void)replaceMediaAtIndex:(LMMediaItem *)media index:(NSInteger)index;
- (void)removeAllMediaInQueue;
- (void)setQueue:(NSArray *)queue;
- (void)playMedia:(LMMediaItem *)media;
- (void)play;
- (void)playAtIndex:(NSInteger)index;
- (void)stop;
- (void)pause;
- (void)playNextMedia;
- (void)playPreviousMedia;
- (NSArray *)queue;
- (NSUInteger)numberOfQueue;
- (NSTimeInterval)currentPlaybackTime;
- (NSTimeInterval)currentPlaybackDuration;
- (void)seekTo:(NSTimeInterval)time;
- (void)setShuffleEnabled:(BOOL)enabled;
- (UIImage *)thumbnailAtTime:(CGFloat)time;
- (UIImage *)representativeThumbnail;
- (NSError *)setAudioSessionCategory:(NSString *)category;

@end
