//
//  LMMediaPlayerView.m
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/10.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import "LMMediaPlayerView.h"
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import "LMMediaPlayerHelper.h"

static CGFloat const kFullscreenTransitionDuration = 0.2;
static CGFloat const kActionButtonDefaultEdgeLength = 35;
static CGFloat const kActionButtonDefaultRightMergin = 8;

NSString *const LMMediaPlayerViewPlayButtonImageKey = @"playButtonImageKey";
NSString *const LMMediaPlayerViewPlayButtonSelectedImageKey = @"playButtonSelectedImageKey";
NSString *const LMMediaPlayerViewStopButtonImageKey = @"stopButtonImageKey";
NSString *const LMMediaPlayerViewStopButtonSelectedImageKey = @"stopButtonSelectedImageKey";
NSString *const LMMediaPlayerViewFullscreenButtonImageKey = @"fullscreenButtonImageKey";
NSString *const LMMediaPlayerViewFullscreenButtonSelectedImageKey = @"fullscreenButtonSelectedImageKey";
NSString *const LMMediaPlayerViewUnfullscreenButtonImageKey = @"unfullscreenButtonImageKey";
NSString *const LMMediaPlayerViewUnfullscreenButtonSelectedImageKey = @"unfullscreenButtonSelectedImageKey";
NSString *const LMMediaPlayerViewShuffleButtonShuffledImageKey = @"shuffleButtonShuffledImageKey";
NSString *const LMMediaPlayerViewShuffleButtonShuffledSelectedImageKey = @"shuffleButtonShuffledSelectedImageKey";
NSString *const LMMediaPlayerViewShuffleButtonUnshuffledImageKey = @"shuffleButtonUnshuffledImageKey";
NSString *const LMMediaPlayerViewShuffleButtonUnshuffledSelectedImageKey = @"shuffleButtonUnshuffledSelectedImageKey";
NSString *const LMMediaPlayerViewRepeatButtonRepeatOneImageKey = @"repeatButtonRepeatOneImageKey";
NSString *const LMMediaPlayerViewRepeatButtonRepeatOneSelectedImageKey = @"repeatButtonRepeatOneSelectedImageKey";
NSString *const LMMediaPlayerViewRepeatButtonRepeatAllImageKey = @"repeatButtonRepeatAllImageKey";
NSString *const LMMediaPlayerViewRepeatButtonRepeatAllSelectedImageKey = @"repeatButtonRepeatAllSelectedImageKey";
NSString *const LMMediaPlayerViewRepeatButtonRepeatNoneImageKey = @"repeatButtonRepeatNoneImageKey";
NSString *const LMMediaPlayerViewRepeatButtonRepeatNoneSelectedImageKey = @"repeatButtonRepeatNoneSelectedImageKey";
NSString *const LMMediaPlayerViewActionButtonImageKey = @"LMMediaPlayerViewActionButtonImageKey";

@interface UIViewController (LMMediaPlayerPrefersStatusBarHidden)

- (void)mediaPlayerPrefersStatusBarHidden:(BOOL)hidden;

@end

@interface LMMediaPlayerFullscreenViewController : UIViewController

@end

@implementation LMMediaPlayerFullscreenViewController

- (BOOL)shouldAutorotate
{
	return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
	return UIInterfaceOrientationPortrait;
}

@end

@interface LMMediaPlayerView () {
	__unsafe_unretained IBOutlet UILabel *playbackTimeLabel_;
	__unsafe_unretained IBOutlet UILabel *remainingTimeLabel_;
	__unsafe_unretained IBOutlet UIView *headerView_;
	__unsafe_unretained IBOutlet UIView *footerView_;
	__unsafe_unretained IBOutlet UIImageView *artworkImageView_;
	__unsafe_unretained IBOutlet UIButton *playButton_;
	__unsafe_unretained IBOutlet UIButton *shuffleButton_;
	__unsafe_unretained IBOutlet UIButton *repeatButton_;
	//__unsafe_unretained IBOutlet UIButton *fullscreenButton_;
	__unsafe_unretained IBOutlet UIButton *actionButton_;
	__unsafe_unretained IBOutlet NSLayoutConstraint *actionButtonWidth_;
	__unsafe_unretained IBOutlet NSLayoutConstraint *actionButtonRightMergin;
	BOOL fullscreen_;
	BOOL seeking_;
	BOOL needToSetPlayer_;
	UIView *superView_;
	NSMutableDictionary *buttonImages_;
	AVPlayerLayer *playerLayer_;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
	UIVisualEffectView *headerBlurView_;
	UIVisualEffectView *footerBlurView_;
#endif

	UIWindow *mainWindow_;
}

@end

@implementation LMMediaPlayerView

@synthesize isFullscreen = fullscreen_;

static LMMediaPlayerView *sharedPlayerView;

+ (instancetype)sharedPlayerView
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlayerView = [[self class] create];
	});
	return sharedPlayerView;
}

+ (instancetype)create
{
	return [[UINib nibWithNibName:NSStringFromClass([self class]) bundle:[NSBundle mainBundle]] instantiateWithOwner:nil options:nil][0];
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self setup];
	}

	return self;
}

- (void)drawRect:(CGRect)rect
{
	[super drawRect:rect];

	if (needToSetPlayer_) {
		[playerLayer_ setPlayer:self.mediaPlayer.corePlayer];
		needToSetPlayer_ = NO;
	}
}

- (void)dealloc
{
	_mediaPlayer.delegate = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];

	LM_RELEASE(playbackTimeLabel_);
	LM_RELEASE(remainingTimeLabel_);
	LM_RELEASE(headerView_);
	LM_RELEASE(footerView_);
	LM_RELEASE(artworkImageView_);
	LM_RELEASE(playButton_);
	LM_RELEASE(_nextButton);
	LM_RELEASE(_previousButton);
	LM_RELEASE(shuffleButton_);
	LM_RELEASE(repeatButton_);
	LM_RELEASE(fullscreenButton_);
	LM_RELEASE(_mediaPlayer);
	LM_RELEASE(buttonImages_);
	LM_DEALLOC(super);
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	[self setup];
	[self setupUserInterface];
}

- (void)layoutSubviews
{
	// resize your layers based on the view's new bounds
	[super layoutSubviews];
	playerLayer_.frame = self.bounds;
}

- (UIButton *)actionButton
{
	return actionButton_;
}

- (void)setBluredUserInterface:(BOOL)bluredUserInterface visualEffect:(UIVisualEffect *)effect
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
	if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
		_bluredUserInterface = bluredUserInterface;
		if (_bluredUserInterface == YES) {
			if (headerBlurView_ == nil) {
				headerBlurView_ = [[UIVisualEffectView alloc] initWithEffect:effect];
				footerBlurView_ = [[UIVisualEffectView alloc] initWithEffect:effect];

				headerBlurView_.frame = headerView_.bounds;
				headerBlurView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

				footerBlurView_.frame = footerView_.bounds;
				footerBlurView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

				[headerView_ insertSubview:headerBlurView_ atIndex:0];
				[footerView_ insertSubview:footerBlurView_ atIndex:0];
			}

			headerView_.backgroundColor = [UIColor clearColor];
			footerView_.backgroundColor = [UIColor clearColor];
		}
		else {
			UIColor *backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.400];
			headerView_.backgroundColor = backgroundColor;
			footerView_.backgroundColor = backgroundColor;
		}

		headerBlurView_.hidden = footerBlurView_.hidden = !_bluredUserInterface;
	}
#endif
}

#pragma mark -

- (void)setup
{
	[self setTranslatesAutoresizingMaskIntoConstraints:YES];
	self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

	mainWindow_ = [[UIApplication sharedApplication] keyWindow];
	if (mainWindow_ == nil) {
		mainWindow_ = [[UIApplication sharedApplication] windows][0];
	}
	LM_RETAIN(mainWindow_);

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaPlayerBecomeForgroundMode:) name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaPlayerBecomeBackgroundMode:) name:UIApplicationDidEnterBackgroundNotification object:nil];

	needToSetPlayer_ = NO;
	_userInterfaceHidden = NO;

	_mediaPlayer = [[LMMediaPlayer alloc] init];
	_mediaPlayer.delegate = self;
}

- (void)setupUserInterface
{
	UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reverseUserInterfaceHidden)];
	[self addGestureRecognizer:gesture];
	LM_RELEASE(gesture);

	artworkImageView_.contentMode = UIViewContentModeScaleAspectFit;

	[_currentTimeSlider addTarget:self action:@selector(beginSeek:) forControlEvents:UIControlEventTouchDown];
	[_currentTimeSlider addTarget:self action:@selector(seekPositionChanged:) forControlEvents:UIControlEventValueChanged];
	[_currentTimeSlider addTarget:self action:@selector(endSeek:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];

	[playButton_ addTarget:self action:@selector(changePlaybackState:) forControlEvents:UIControlEventTouchUpInside];
	[_nextButton addTarget:self action:@selector(fourcePlayNextMedia) forControlEvents:UIControlEventTouchUpInside];
	[_previousButton addTarget:self action:@selector(fourcePlayPreviousMedia) forControlEvents:UIControlEventTouchUpInside];

	UIColor *backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.400];
	footerView_.backgroundColor = headerView_.backgroundColor = backgroundColor;
	[_mediaPlayer setShuffleEnabled:NO];
	[_mediaPlayer setRepeatMode:LMMediaRepeatModeDefault];

	buttonImages_ = [@{ LMMediaPlayerViewPlayButtonImageKey : [[self class] imageForFilename:@"play"],
		LMMediaPlayerViewPlayButtonSelectedImageKey : [[self class] imageForFilename:@"play"],
		LMMediaPlayerViewStopButtonImageKey : [[self class] imageForFilename:@"pause"],
		LMMediaPlayerViewStopButtonSelectedImageKey : [[self class] imageForFilename:@"pause"],
		LMMediaPlayerViewShuffleButtonShuffledImageKey : [[self class] imageForFilename:@"shuffle"],
		LMMediaPlayerViewShuffleButtonShuffledSelectedImageKey : [[self class] imageForFilename:@"shuffle"],
		LMMediaPlayerViewShuffleButtonUnshuffledImageKey : [[self class] imageForFilename:@"unshuffle"],
		LMMediaPlayerViewShuffleButtonUnshuffledSelectedImageKey : [[self class] imageForFilename:@"unshuffle"],
		LMMediaPlayerViewRepeatButtonRepeatNoneImageKey : [[self class] imageForFilename:@"repeat_none"],
		LMMediaPlayerViewRepeatButtonRepeatNoneSelectedImageKey : [[self class] imageForFilename:@"repeat_none"],
		LMMediaPlayerViewRepeatButtonRepeatOneImageKey : [[self class] imageForFilename:@"repeat_one"],
		LMMediaPlayerViewRepeatButtonRepeatOneSelectedImageKey : [[self class] imageForFilename:@"repeat_one"],
		LMMediaPlayerViewRepeatButtonRepeatAllImageKey : [[self class] imageForFilename:@"repeat_all"],
		LMMediaPlayerViewRepeatButtonRepeatAllSelectedImageKey : [[self class] imageForFilename:@"repeat_all"],
		LMMediaPlayerViewFullscreenButtonImageKey : [[self class] imageForFilename:@"fullscreen"],
		LMMediaPlayerViewFullscreenButtonSelectedImageKey : [[self class] imageForFilename:@"fullscreen"],
		LMMediaPlayerViewUnfullscreenButtonImageKey : [[self class] imageForFilename:@"unfullscreen"],
		LMMediaPlayerViewUnfullscreenButtonSelectedImageKey : [[self class] imageForFilename:@"unfullscreen"]
	} mutableCopy];

	[playButton_.imageView setContentMode:UIViewContentModeScaleAspectFit];
	[playButton_ setImage:buttonImages_[LMMediaPlayerViewPlayButtonImageKey] forState:UIControlStateNormal];
	[playButton_ setImage:buttonImages_[LMMediaPlayerViewPlayButtonSelectedImageKey] forState:UIControlStateSelected];

	[_fullscreenButton_.imageView setContentMode:UIViewContentModeScaleAspectFit];
	[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewFullscreenButtonImageKey] forState:UIControlStateNormal];
	[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewFullscreenButtonSelectedImageKey] forState:UIControlStateSelected];

	[repeatButton_.imageView setContentMode:UIViewContentModeScaleAspectFit];
	[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatNoneImageKey] forState:UIControlStateNormal];
	[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatNoneSelectedImageKey] forState:UIControlStateSelected];

	[shuffleButton_.imageView setContentMode:UIViewContentModeScaleAspectFit];
	[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonUnshuffledImageKey] forState:UIControlStateNormal];
	[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonUnshuffledSelectedImageKey] forState:UIControlStateSelected];

	[actionButton_.imageView setContentMode:UIViewContentModeScaleAspectFit];
	actionButtonWidth_.constant = 0;
	actionButtonRightMergin.constant = 0;
}

- (void)mediaPlayerBecomeForgroundMode:(NSNotification *)notification
{
	needToSetPlayer_ = YES;
	[self setNeedsDisplay];
}

- (void)mediaPlayerBecomeBackgroundMode:(NSNotification *)notification
{
	double delayInSeconds = 0.01;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
		[playerLayer_ setPlayer:nil];
		if (self.mediaPlayer.playbackState == LMMediaPlaybackStatePlaying) {
			[self.mediaPlayer play];
		}
	});
}

#pragma mark LMMediaPlayerDelegate

- (void)mediaPlayerWillChangeState:(LMMediaPlaybackState)state
{
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewWillChangeState:state:)]) {
		[self.delegate mediaPlayerViewWillChangeState:self state:state];
	}

	if (state == LMMediaPlaybackStateStopped || state == LMMediaPlaybackStatePaused) {
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewPlayButtonImageKey] ?: nil forState:UIControlStateNormal];
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewPlayButtonSelectedImageKey] ?: nil forState:UIControlStateSelected];
	}
	else {
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewStopButtonImageKey] ?: nil forState:UIControlStateNormal];
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewStopButtonSelectedImageKey] ?: nil forState:UIControlStateSelected];
	}
}

- (BOOL)mediaPlayerWillStartPlaying:(LMMediaPlayer *)player media:(LMMediaItem *)media
{
	BOOL result = NO;
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewWillStartPlaying:media:)] == YES) {
		result = [self.delegate mediaPlayerViewWillStartPlaying:self media:media];
	}
	else {
		result = YES;
	}
	self.titleLabel.text = media.title;

	return result;
}

- (void)mediaPlayerDidStartPlaying:(LMMediaPlayer *)player media:(LMMediaItem *)media
{
	if (media.isVideo) {
		artworkImageView_.hidden = YES;
		self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
		if (playerLayer_ == nil) {
			playerLayer_ = [AVPlayerLayer playerLayerWithPlayer:player.corePlayer];
			playerLayer_.frame = self.frame;
			[self.layer insertSublayer:playerLayer_ atIndex:0];
		}
		needToSetPlayer_ = YES;

		playerLayer_.hidden = NO;
	}
	else {
		playerLayer_.hidden = YES;
		artworkImageView_.hidden = NO;
		artworkImageView_.image = [media artworkImageWithSize:self.frame.size];
	}
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewDidStartPlaying:media:)]) {
		[self.delegate mediaPlayerViewDidStartPlaying:self media:media];
	}
}

- (void)mediaPlayerDidFinishPlaying:(LMMediaPlayer *)player media:(LMMediaItem *)media
{
    _currentTimeSlider.value = 1.0;
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewDidFinishPlaying:media:)]) {
		[self.delegate mediaPlayerViewDidFinishPlaying:self media:media];
	}
}

- (void)mediaPlayerDidChangeCurrentTime:(LMMediaPlayer *)player
{
	if (seeking_ == NO) {
		_currentTimeSlider.value = player.currentPlaybackTime / player.currentPlaybackDuration;

		NSMutableString *durationString = [NSMutableString new];
		NSInteger duration = (NSInteger)player.currentPlaybackTime;
		if (duration / (60 * 60) > 0) {
			[durationString appendFormat:@"%02ld:",
					(long int)duration / (60 * 60)];
			duration /= 60 * 60;
		}
		[durationString appendFormat:@"%02ld:", (long int)duration / 60];
		duration %= 60;
		[durationString appendFormat:@"%02ld", (long int)duration];
		playbackTimeLabel_.text = durationString;
		LM_RELEASE(durationString);

		durationString = [[NSMutableString alloc] initWithString:@"-"];
		duration = (NSInteger)fabs(player.currentPlaybackTime - player.currentPlaybackDuration);
		if (duration / (60 * 60) > 0) {
			[durationString appendFormat:@"%02ld:",
					(long int)duration / (60 * 60)];
			duration /= 60 * 60;
		}
		[durationString appendFormat:@"%02ld:", (long int)duration / 60];
		duration %= 60;
		[durationString appendFormat:@"%02ld", (long int)duration];
		remainingTimeLabel_.text = durationString;
		LM_RELEASE(durationString);
	}
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewDidChangeCurrentTime:)]) {
		[self.delegate mediaPlayerViewDidChangeCurrentTime:self];
	}
}

- (void)mediaPlayerDidChangeRepeatMode:(LMMediaRepeatMode)mode player:(LMMediaPlayer *)player
{
	[self setRepeatButtonImageWithRepeatMode:mode];
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewDidChangeRepeatMode:playerView:)]) {
		[self.delegate mediaPlayerViewDidChangeRepeatMode:mode playerView:self];
	}
}

- (void)mediaPlayerDidChangeShuffleMode:(BOOL)enabled player:(LMMediaPlayer *)player
{
	[self setShuffleButtonImageWithShuffleMode:enabled];
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewDidChangeShuffleMode:playerView:)]) {
		[self.delegate mediaPlayerViewDidChangeShuffleMode:enabled playerView:self];
	}
}

#pragma mark -

- (void)beginSeek:(id)sender
{
	seeking_ = YES;
}

- (void)seekPositionChanged:(id)sender
{
	NSMutableString *durationString = [NSMutableString new];
	NSInteger currentTime = (NSInteger)_mediaPlayer.currentPlaybackDuration * _currentTimeSlider.value;
	NSInteger duration = currentTime;
	if (duration / (60 * 60) > 0) {
		[durationString appendFormat:@"%02ld:",
				(long int)duration / (60 * 60)];
		duration /= 60 * 60;
	}
	[durationString appendFormat:@"%02ld:", (long int)duration / 60];
	duration %= 60;
	[durationString appendFormat:@"%02ld", (long int)duration];
	playbackTimeLabel_.text = durationString;
	LM_RELEASE(durationString);

	durationString = [[NSMutableString alloc] initWithString:@"-"];
	duration = (NSInteger)_mediaPlayer.currentPlaybackDuration - currentTime;
	if (duration / (60 * 60) > 0) {
		[durationString appendFormat:@"%02ld:",
				(long int)duration / (60 * 60)];
		duration /= 60 * 60;
	}
	[durationString appendFormat:@"%02ld:", (long int)duration / 60];
	duration %= 60;
	[durationString appendFormat:@"%02ld", (long int)duration];
	remainingTimeLabel_.text = durationString;
	LM_RELEASE(durationString);
}

- (void)endSeek:(id)sender
{
	UISlider *slider = (UISlider *)sender;
	[_mediaPlayer seekTo:_mediaPlayer.currentPlaybackDuration * slider.value];
	seeking_ = NO;
}

- (void)changePlaybackState:(id)sender
{
	if ([_mediaPlayer playbackState] == LMMediaPlaybackStatePlaying) {
		[_mediaPlayer pause];
	}
	else if ([_mediaPlayer playbackState] == LMMediaPlaybackStatePaused || [_mediaPlayer playbackState] == LMMediaPlaybackStateStopped) {
		[_mediaPlayer play];
	}
}

- (void)reverseUserInterfaceHidden
{
	if (seeking_ == NO) {
		[self setUserInterfaceHidden:!_userInterfaceHidden];
	}
}

- (void)fourcePlayNextMedia
{
	LMMediaRepeatMode repeatMode = _mediaPlayer.repeatMode;
	if (repeatMode == LMMediaRepeatModeOne) {
		_mediaPlayer.repeatMode = LMMediaRepeatModeDefault;
	}
	[_mediaPlayer playNextMedia];
	_mediaPlayer.repeatMode = repeatMode;
}

- (void)fourcePlayPreviousMedia
{
	LMMediaRepeatMode repeatMode = _mediaPlayer.repeatMode;
	if (repeatMode == LMMediaRepeatModeOne) {
		_mediaPlayer.repeatMode = LMMediaRepeatModeDefault;
	}
	[_mediaPlayer playPreviousMedia];
	_mediaPlayer.repeatMode = repeatMode;
}

- (IBAction)shuffleButtonPressed:(id)sender
{
	[_mediaPlayer setShuffleEnabled:!_mediaPlayer.shuffleMode];

	if (_mediaPlayer.shuffleMode) {
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonShuffledImageKey] forState:UIControlStateNormal];
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonShuffledSelectedImageKey] forState:UIControlStateSelected];
	}
	else {
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonUnshuffledImageKey] forState:UIControlStateNormal];
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonUnshuffledSelectedImageKey] forState:UIControlStateSelected];
	}
	[self setRepeatButtonImageWithRepeatMode:_mediaPlayer.repeatMode];
}

- (IBAction)repeatButtonPressed:(id)sender
{
	switch (_mediaPlayer.repeatMode) {
		case LMMediaRepeatModeAll: {
			_mediaPlayer.repeatMode = LMMediaRepeatModeOne;
		} break;
		case LMMediaRepeatModeOne: {
			_mediaPlayer.repeatMode = LMMediaRepeatModeDefault;
		} break;
		case LMMediaRepeatModeDefault: {
			_mediaPlayer.repeatMode = LMMediaRepeatModeAll;
		} break;
		default:
			break;
	}
	[self setRepeatButtonImageWithRepeatMode:_mediaPlayer.repeatMode];
}

- (void)setShuffleButtonImageWithShuffleMode:(BOOL)mode
{
	if (mode) {
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonShuffledImageKey] forState:UIControlStateNormal];
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonShuffledSelectedImageKey] forState:UIControlStateSelected];
	}
	else {
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonUnshuffledImageKey] forState:UIControlStateNormal];
		[shuffleButton_ setImage:buttonImages_[LMMediaPlayerViewShuffleButtonUnshuffledSelectedImageKey] forState:UIControlStateSelected];
	}
}

- (void)setRepeatButtonImageWithRepeatMode:(LMMediaRepeatMode)mode
{
	switch (_mediaPlayer.repeatMode) {
		case LMMediaRepeatModeAll: {
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatAllImageKey] forState:UIControlStateNormal];
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatAllSelectedImageKey] forState:UIControlStateSelected];
		} break;
		case LMMediaRepeatModeOne: {
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatOneImageKey] forState:UIControlStateNormal];
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatOneSelectedImageKey] forState:UIControlStateSelected];
		} break;
		case LMMediaRepeatModeDefault: {
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatNoneImageKey] forState:UIControlStateNormal];
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatNoneSelectedImageKey] forState:UIControlStateSelected];
		} break;
		default: {
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatNoneImageKey] forState:UIControlStateNormal];
			[repeatButton_ setImage:buttonImages_[LMMediaPlayerViewRepeatButtonRepeatNoneSelectedImageKey] forState:UIControlStateSelected];
		} break;
	}
}

- (IBAction)fullscreenButtonPressed:(id)sender
{
	[self setFullscreen:!fullscreen_];
}

#pragma mark -

- (void)setHeaderViewHidden:(BOOL)hidden
{
	headerView_.hidden = hidden;
}

- (void)setFooterViewHidden:(BOOL)hidden
{
	footerView_.hidden = hidden;
}

- (void)setUserInterfaceHidden:(BOOL)hidden
{
	_userInterfaceHidden = hidden;
	if (hidden) {
		[UIView animateWithDuration:0.3 animations:^{
			headerView_.alpha = 0;
			footerView_.alpha = 0;
			_currentTimeSlider.alpha = 0;
			_nextButton.superview.alpha = 0;
			_previousButton.superview.alpha = 0;
		} completion:^(BOOL finished){
		}];
	}
	else {
		[UIView animateWithDuration:0.3 animations:^{
			headerView_.alpha = 1;
			footerView_.alpha = 1;
			_currentTimeSlider.alpha = 1;
			_nextButton.superview.alpha = 1;
			_previousButton.superview.alpha = 1;
		} completion:^(BOOL finished){
		}];
	}
}

- (void)setFullscreen:(BOOL)fullscreen animated:(BOOL)animated
{
	if (fullscreen_ == fullscreen) {
		return;
	}

	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewWillChangeFullscreenMode:)]) {
		[self.delegate mediaPlayerViewWillChangeFullscreenMode:fullscreen];
	}

	LMMediaPlayerFullscreenViewController *viewController = [[LMMediaPlayerFullscreenViewController alloc] init];
	LM_AUTORELEASE(viewController);
	viewController.view.frame = [UIScreen mainScreen].bounds;

	if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0) {
		viewController.extendedLayoutIncludesOpaqueBars = YES;
	}
	else {
		//viewController.wantsFullScreenLayout = YES;
	}

	CGRect newRect;
	if (fullscreen == NO) {
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewFullscreenButtonImageKey] forState:UIControlStateNormal];
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewFullscreenButtonSelectedImageKey] forState:UIControlStateSelected];

		newRect = superView_.bounds;
        newRect.size.height = newRect.size.height - 20; //TWS
        
        self.frame = newRect;
		[superView_ addSubview:self];
		LM_RELEASE(superView_);
		[mainWindow_ makeKeyAndVisible];
		[[[UIApplication sharedApplication] delegate] setWindow:mainWindow_];
		[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
		[[UIApplication sharedApplication] setStatusBarOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
		[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
	}
	else {
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewUnfullscreenButtonImageKey] forState:UIControlStateNormal];
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewUnfullscreenButtonSelectedImageKey] forState:UIControlStateSelected];
		superView_ = self.superview;
		LM_RETAIN(superView_);
		newRect = mainWindow_.frame;

		//UIViewController *rootViewController = [mainWindow_ rootViewController];
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation]; //rootViewController.interfaceOrientation;

		if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft) {
			if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0) {
				newRect = CGRectMake(0, 0, CGRectGetWidth(mainWindow_.frame), CGRectGetHeight(mainWindow_.frame));
			}
			else {
				newRect = CGRectMake(0, 0, CGRectGetHeight(mainWindow_.frame), CGRectGetWidth(mainWindow_.frame));
			}
		}

		[self removeFromSuperview];
		[viewController.view addSubview:self];
		UIWindow *newWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
		newWindow.windowLevel = UIWindowLevelAlert;
		newWindow.rootViewController = viewController;
		[newWindow addSubview:viewController.view];
		[newWindow makeKeyAndVisible];
		[[[UIApplication sharedApplication] delegate] setWindow:newWindow];
		LM_RELEASE(newWindow);
	}

	self.frame = newRect;
	if (animated) {
		self.alpha = 0;
		[UIView animateWithDuration:kFullscreenTransitionDuration animations:^{
			self.alpha = 1;
		}];
	}
	fullscreen_ = fullscreen;
	if ([self.delegate respondsToSelector:@selector(mediaPlayerViewDidChangeFullscreenMode:)]) {
		[self.delegate mediaPlayerViewDidChangeFullscreenMode:fullscreen];
	}
	[[UIApplication sharedApplication] setStatusBarHidden:fullscreen];
	[[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
}

- (void)setFullscreen:(BOOL)fullscreen
{
	[self setFullscreen:fullscreen animated:YES];
}

- (void)setButtonImages:(NSDictionary *)info
{
	for (NSString *key in info) {
		buttonImages_[key] = info[key];
	}
	if ([buttonImages_[LMMediaPlayerViewActionButtonImageKey] isKindOfClass:[UIImage class]]) {
		actionButtonWidth_.constant = kActionButtonDefaultEdgeLength;
		actionButtonRightMergin.constant = kActionButtonDefaultRightMergin;
		[actionButton_ setImage:info[LMMediaPlayerViewActionButtonImageKey] forState:UIControlStateNormal];
	}
	else {
		actionButtonWidth_.constant = 0;
		actionButtonRightMergin.constant = 0;
	}
	[self updateButtonImages];
}

- (void)updateButtonImages
{
	if (self.mediaPlayer.playbackState == LMMediaPlaybackStatePlaying) {
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewStopButtonImageKey] forState:UIControlStateNormal];
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewStopButtonSelectedImageKey] forState:UIControlStateSelected];
	}
	else {
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewPlayButtonImageKey] forState:UIControlStateNormal];
		[playButton_ setImage:buttonImages_[LMMediaPlayerViewPlayButtonSelectedImageKey] forState:UIControlStateSelected];
	}

	if (self.isFullscreen) {
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewUnfullscreenButtonImageKey] forState:UIControlStateNormal];
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewUnfullscreenButtonSelectedImageKey] forState:UIControlStateSelected];
	}
	else {
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewFullscreenButtonImageKey] forState:UIControlStateNormal];
		[_fullscreenButton_ setImage:buttonImages_[LMMediaPlayerViewFullscreenButtonSelectedImageKey] forState:UIControlStateSelected];
	}

	[self setRepeatButtonImageWithRepeatMode:self.mediaPlayer.repeatMode];
	[self setShuffleButtonImageWithShuffleMode:self.mediaPlayer.shuffleMode];
}

+ (UIImage *)imageForFilename:(NSString *)filename
{
	NSString *version = @"7";
	if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
		version = @"6";
	}
	UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/%@.png", [[NSBundle mainBundle] pathForResource:@"LMMediaPlayerView" ofType:@"bundle"], version, filename]];

	return image;
}

@end
