//
//  LMMediaPlayer.m
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/10.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import "LMMediaPlayer.h"
#import "NSArray+LMMediaPlayerShuffle.h"
#import <AudioToolbox/AudioToolbox.h>
#import "LMMediaPlayerHelper.h"

NSString *const LMMediaPlayerPauseNotification = @"LMMediaPlayerPauseNotification";
NSString *const LMMediaPlayerStopNotification = @"LMMediaPlayerStopNotification";

@interface LMMediaPlayer () {
	NSMutableArray *queue_;

	LMMediaPlaybackState playbackState_;
	AVPlayer *player_;
	id playerObserver_;
}

@property (nonatomic, strong) NSMutableArray *currentQueue;

@end

@implementation LMMediaPlayer

@synthesize playbackState = playbackState_;

static LMMediaPlayer *sharedPlayer;

+ (instancetype)sharedPlayer
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlayer = [[self class] new];
	});

	return sharedPlayer;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		player_ = [AVPlayer new];
		queue_ = [NSMutableArray new];
		self.currentQueue = queue_;
		_repeatMode = LMMediaRepeatModeDefault;
		_shuffleMode = YES;

		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		[notificationCenter addObserver:self selector:@selector(pause) name:LMMediaPlayerPauseNotification object:nil];
		[notificationCenter addObserver:self selector:@selector(stop) name:LMMediaPlayerStopNotification object:nil];
	}

	return self;
}

- (void)dealloc
{
	self.delegate = nil;
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:self name:LMMediaPlayerPauseNotification object:nil];
	[notificationCenter removeObserver:self name:LMMediaPlayerStopNotification object:nil];
	[notificationCenter removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
	LM_RELEASE(player_);
	LM_RELEASE(queue_);
	LM_RELEASE(_currentQueue);
	LM_DEALLOC(super);
}

#pragma mark -

- (AVPlayer *)corePlayer
{
	return player_;
}

- (void)pauseOtherPlayer
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:self name:LMMediaPlayerPauseNotification object:nil];
	[notificationCenter postNotificationName:LMMediaPlayerPauseNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(pause) name:LMMediaPlayerPauseNotification object:nil];
}

- (void)stopOtherPlayer
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:self name:LMMediaPlayerStopNotification object:nil];
	[notificationCenter postNotificationName:LMMediaPlayerStopNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(stop) name:LMMediaPlayerStopNotification object:nil];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
	AVPlayerItem *item = notification.object;
	if (player_.currentItem == item) {
		[self playNextMedia];
	}
}

- (void)addMedia:(LMMediaItem *)media
{
	[self.currentQueue addObject:media];
}

- (void)removeMediaAtIndex:(NSUInteger)index
{
	LMMediaItem *item = _currentQueue[index];
	if (item == _nowPlayingItem) {
		_nowPlayingItem = nil;
		[self playNextMedia];
	}
	[self.currentQueue removeObjectAtIndex:index];
}

- (void)replaceMediaAtIndex:(LMMediaItem *)media index:(NSInteger)index
{
	LMMediaItem *item = _currentQueue[index];
	if (item == _nowPlayingItem) {
		_nowPlayingItem = nil;
	}
	[self.currentQueue replaceObjectAtIndex:index withObject:media];
}

- (void)removeAllMediaInQueue
{
	_nowPlayingItem = nil;
	[self stop];
	[self.currentQueue removeAllObjects];
}

- (void)setQueue:(NSArray *)queue
{
	for (LMMediaItem *item in queue) {
		[queue_ addObject:item];
	}
	self.currentQueue = queue_;
}

- (void)updateLockScreenInfo
{
	NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
	[songInfo setObject:[_nowPlayingItem title] ?: @"" forKey:MPMediaItemPropertyTitle];
	[songInfo setObject:[_nowPlayingItem albumTitle] ?: @"" forKey:MPMediaItemPropertyAlbumTitle];
	[songInfo setObject:[_nowPlayingItem artist] ?: @"" forKey:MPMediaItemPropertyArtist];
	[songInfo setObject:@([self currentPlaybackTime]) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
	[songInfo setObject:@([self currentPlaybackDuration]) forKey:MPMediaItemPropertyPlaybackDuration];
	UIImage *artworkImage = [_nowPlayingItem artworkImageWithSize:CGSizeMake(320, 320)];
	if (artworkImage) {
		MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:artworkImage];
		[songInfo setObject:artwork forKey:MPMediaItemPropertyArtwork];
		LM_AUTORELEASE(artwork);
	}
	[[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
	LM_AUTORELEASE(songInfo);
}

- (void)playMedia:(LMMediaItem *)media
{
	[self stop];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
	if ([self.delegate respondsToSelector:@selector(mediaPlayerWillStartPlaying:media:)] == NO || [self.delegate mediaPlayerWillStartPlaying:self media:media] == YES) {
		if (media != nil) {
			NSURL *url = [media assetURL];
			_nowPlayingItem = media;
			[player_ removeTimeObserver:playerObserver_];
			[player_ replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
			[self play];
			if ([self.delegate respondsToSelector:@selector(mediaPlayerDidStartPlaying:media:)]) {
				[self.delegate mediaPlayerDidStartPlaying:self media:media];
			}
			player_.usesExternalPlaybackWhileExternalScreenIsActive = YES;
			__block LMMediaPlayer *bself = self;
			playerObserver_ = [player_ addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
				if ([bself.delegate respondsToSelector:@selector(mediaPlayerDidChangeCurrentTime:)]) {
					[bself.delegate mediaPlayerDidChangeCurrentTime:bself];
				}
			}];
		}
	}
}

- (void)play
{
	if (playbackState_ == LMMediaPlaybackStateStopped) {
		[player_ seekToTime:CMTimeMake(0, 1)];
	}
	if (_nowPlayingItem == nil) {
		[self playMedia:self.currentQueue.firstObject];
	}
	else {
		[player_ play];
	}

	[self setCurrentState:LMMediaPlaybackStatePlaying];
}

- (void)playAtIndex:(NSInteger)index
{
	_index = MAX(0, MIN(index, self.currentQueue.count - 1));
	[self playMedia:self.currentQueue[_index]];
}

- (void)stop
{
	[player_ pause];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
	[self setCurrentState:LMMediaPlaybackStateStopped];
	if ([self.delegate respondsToSelector:@selector(mediaPlayerDidStop:media:)]) {
		[self.delegate mediaPlayerDidStop:self media:_nowPlayingItem];
	}
	_nowPlayingItem = nil;
}

- (void)pause
{
	[player_ pause];
	[self setCurrentState:LMMediaPlaybackStatePaused];
}

- (void)playNextMedia
{
	if ([self.delegate respondsToSelector:@selector(mediaPlayerDidFinishPlaying:media:)]) {
		[self.delegate mediaPlayerDidFinishPlaying:self media:_nowPlayingItem];
	}
	if (self.currentQueue.count) {
		if (_repeatMode == LMMediaRepeatModeDefault) {
			if (_index >= self.currentQueue.count - 1) {
				_index = 0;
				[self stop];
			}
			else {
				_index++;
				[self playMedia:self.currentQueue[_index]];
			}
		}
		else if (_repeatMode == LMMediaRepeatModeAll) {
			if (_index >= self.currentQueue.count - 1) {
				_index = 0;
			}
			else {
				_index++;
			}
			[self playMedia:self.currentQueue[_index]];
		}
		else {
			[self playMedia:self.nowPlayingItem];
		}
	}
	else if (_repeatMode == LMMediaRepeatModeOne || _repeatMode == LMMediaRepeatModeAll) {
		[self playMedia:self.nowPlayingItem];
	}
}

- (void)playPreviousMedia
{
	if ([self.delegate respondsToSelector:@selector(mediaPlayerDidFinishPlaying:media:)]) {
		[self.delegate mediaPlayerDidFinishPlaying:self media:_nowPlayingItem];
	}
	if (self.currentQueue.count) {
		if (_repeatMode == LMMediaRepeatModeDefault) {
			if (_index - 1 < 0) {
				_index = 0;
				[self stop];
			}
			else {
				_index--;
				[self playMedia:self.currentQueue[_index]];
			}
		}
		else if (_repeatMode == LMMediaRepeatModeAll) {
			if (_index - 1 < 0) {
				_index = self.currentQueue.count - 1;
			}
			else {
				_index--;
			}
			[self playMedia:self.currentQueue[_index]];
		}
		else {
			[self playMedia:self.currentQueue[_index]];
		}
	}
	else if (_repeatMode == LMMediaRepeatModeOne || _repeatMode == LMMediaRepeatModeAll) {
		[self playMedia:self.nowPlayingItem];
	}
}

- (NSArray *)queue
{
	NSArray *newArray = [self.currentQueue copy];
	LM_AUTORELEASE(newArray);
	return newArray;
}

- (NSUInteger)numberOfQueue
{
	return self.currentQueue.count;
}

- (NSTimeInterval)currentPlaybackTime
{
	return player_.currentTime.value == 0 ? 0 : player_.currentTime.value / player_.currentTime.timescale;
}

- (NSTimeInterval)currentPlaybackDuration
{
	return CMTimeGetSeconds([[player_.currentItem asset] duration]);
}

- (void)seekTo:(NSTimeInterval)time
{
	[player_ seekToTime:CMTimeMake(time, 1)];
}

- (void)setShuffleEnabled:(BOOL)enabled
{
	_shuffleMode = enabled;
	if ([self numberOfQueue] > 0 && _shuffleMode) {
		NSMutableArray *newArray = [[self.currentQueue lm_shuffledArray] mutableCopy];
		self.currentQueue = newArray;
		LM_RELEASE(newArray);
	}
	else {
		self.currentQueue = queue_;
	}

	if ([self.delegate respondsToSelector:@selector(mediaPlayerDidChangeShuffleMode:player:)]) {
		[self.delegate mediaPlayerDidChangeShuffleMode:enabled player:self];
	}
}

- (void)setRepeatMode:(LMMediaRepeatMode)repeatMode
{
	_repeatMode = repeatMode;
	if ([self.delegate respondsToSelector:@selector(mediaPlayerDidChangeRepeatMode:player:)]) {
		[self.delegate mediaPlayerDidChangeRepeatMode:repeatMode player:self];
	}
}

#pragma mark - private

- (void)setCurrentState:(LMMediaPlaybackState)state
{
	if (state == playbackState_) {
		return;
	}

	if ([self.delegate respondsToSelector:@selector(mediaPlayerWillChangeState:)]) {
		[self.delegate mediaPlayerWillChangeState:state];
	}

	if (state == LMMediaPlaybackStatePlaying) {
		[self updateLockScreenInfo];
		NSError *e = nil;
		AVAudioSession *audioSession = [AVAudioSession sharedInstance];
		[audioSession setCategory:AVAudioSessionCategoryPlayback error:&e];
		[audioSession setActive:YES error:NULL];
	}

	playbackState_ = state;
}

- (UIImage *)thumbnailAtTime:(CGFloat)time
{
	AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:[[player_ currentItem] asset]];
	imageGenerator.appliesPreferredTrackTransform = YES;
	NSError *error = NULL;
	CMTime ctime = CMTimeMake(time, 1);
	CGImageRef imageRef = [imageGenerator copyCGImageAtTime:ctime actualTime:NULL error:&error];
	LM_RELEASE(imageGenerator);
	UIImage *resultImage = [[UIImage alloc] initWithCGImage:imageRef];
	LM_AUTORELEASE(resultImage);
	CGImageRelease(imageRef);

	return resultImage;
}

- (UIImage *)representativeThumbnail
{
	return [self thumbnailAtTime:self.currentPlaybackDuration / 2];
}

- (NSError *)setAudioSessionCategory:(NSString *)category
{
	NSError *e = nil;
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	[audioSession setCategory:category error:&e];

	return e;
}

@end
