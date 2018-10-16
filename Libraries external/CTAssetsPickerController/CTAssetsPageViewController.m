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

#import "CTAssetsPageViewController.h"
#import "CTAssetsPageView.h"
#import "CTAssetItemViewController.h"
#import "CTAssetScrollView.h"
#import "NSNumberFormatter+CTAssetsPickerController.h"
#import "NSBundle+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"
#import "PHAsset+CTAssetsPickerController.h"





@interface CTAssetsPageViewController ()
<UIPageViewControllerDataSource, UIPageViewControllerDelegate>


@property (nonatomic, assign) BOOL allowsSelection;

@property (nonatomic, assign, getter = isStatusBarHidden) BOOL statusBarHidden;

@property (nonatomic, copy) NSArray *assets;
@property (nonatomic, strong, readonly) PHAsset *asset;

@property (nonatomic, strong) CTAssetsPageView *pageView;

@property (nonatomic, strong) UIBarButtonItem *playButton;
@property (nonatomic, strong) UIBarButtonItem *pauseButton;

@end





@implementation CTAssetsPageViewController

- (instancetype)initWithFetchResult:(PHFetchResult *)fetchResult
{
    NSMutableArray *assets = [NSMutableArray new];
    
    for (PHAsset *asset in fetchResult)
        [assets addObject:asset];
    
    return [self initWithAssets:[NSArray arrayWithArray:assets]];
}

- (instancetype)initWithAssets:(NSArray *)assets
{
    self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                    navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                  options:@{UIPageViewControllerOptionInterPageSpacingKey:@30.f}];
    
    if (self)
    {
        self.assets          = assets;
        self.dataSource      = self;
        self.delegate        = self;
        self.allowsSelection = NO;
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupViews];
    [self addNotificationObserver];
}

- (void)dealloc
{
    [self removeNotificationObserver];
}

- (BOOL)prefersStatusBarHidden
{
    if (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact)
        return YES;
    else
        return self.isStatusBarHidden;
}



#pragma mark - Setup

- (void)setupViews
{
    self.pageView = [CTAssetsPageView new];
    [self.view insertSubview:self.pageView atIndex:0];
    [self.view setNeedsUpdateConstraints];
}

- (void)setupButtons
{
    if (!self.playButton)
    {
        UIImage *playImage = [UIImage ctassetsPickerImageNamed:@"PlayButton"];
        playImage = [playImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        
        UIBarButtonItem *playButton =
        [[UIBarButtonItem alloc] initWithImage:playImage style:UIBarButtonItemStyleDone target:self action:@selector(playAsset:)];
        
        self.playButton = playButton;
    }
    
    if (!self.pauseButton)
    {
        UIImage *pasueImage = [UIImage ctassetsPickerImageNamed:@"PauseButton"];
        pasueImage = [pasueImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        
        UIBarButtonItem *pauseButton =
        [[UIBarButtonItem alloc] initWithImage:pasueImage style:UIBarButtonItemStylePlain target:self action:@selector(pauseAsset:)];
        
        self.pauseButton = pauseButton;
    }
}


#pragma mark - Update title

- (void)updateTitle:(NSInteger)index
{
    NSNumberFormatter *nf = [NSNumberFormatter new];

    NSInteger count = self.assets.count;
    self.title      = [NSString stringWithFormat:CTAssetsPickerLocalizedString(@"%@ of %@", nil),
                       [nf ctassetsPickerStringFromAssetsCount:index],
                       [nf ctassetsPickerStringFromAssetsCount:count]];
}


#pragma mark - Update toolbar

- (void)updateToolbar
{
    [self setupButtons];
    
    if ([self.asset ctassetsPickerIsVideo])
        self.toolbarItems = @[[self toolbarSpace], self.playButton, [self toolbarSpace]];
    else
        self.toolbarItems = nil;
}

- (void)replaceToolbarButton:(UIBarButtonItem *)button
{
    if (button)
    {
        UIBarButtonItem *space = [self toolbarSpace];
        self.toolbarItems = @[space, button, space];
    }
}

- (UIBarButtonItem *)toolbarSpace
{
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}



#pragma mark - Accessors

- (NSInteger)pageIndex
{
    return [self.assets indexOfObject:self.asset];
}

- (void)setPageIndex:(NSInteger)pageIndex
{
    NSInteger count = self.assets.count;
    
    if (pageIndex >= 0 && pageIndex < count)
    {
        PHAsset *asset = self.assets[pageIndex];
        
        CTAssetItemViewController *page = [CTAssetItemViewController assetItemViewControllerForAsset:asset];
        page.allowsSelection = self.allowsSelection;
        
        [self setViewControllers:@[page]
                       direction:UIPageViewControllerNavigationDirectionForward
                        animated:NO
                      completion:NULL];
        
        [self updateTitle:pageIndex + 1];
        [self updateToolbar];
    }
}

- (PHAsset *)asset
{
    return ((CTAssetItemViewController *)self.viewControllers[0]).asset;
}


#pragma mark - Page view controller data source

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    PHAsset *asset = ((CTAssetItemViewController *)viewController).asset;
    NSInteger index = [self.assets indexOfObject:asset];
    
    if (index > 0)
    {
        PHAsset *beforeAsset = self.assets[(index - 1)];
        CTAssetItemViewController *page = [CTAssetItemViewController assetItemViewControllerForAsset:beforeAsset];
        page.allowsSelection = self.allowsSelection;
        
        return page;
    }

    return nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    PHAsset *asset  = ((CTAssetItemViewController *)viewController).asset;
    NSInteger index = [self.assets indexOfObject:asset];
    NSInteger count = self.assets.count;
    
    if (index < count - 1)
    {
        PHAsset *afterAsset = self.assets[(index + 1)];
        CTAssetItemViewController *page = [CTAssetItemViewController assetItemViewControllerForAsset:afterAsset];
        page.allowsSelection = self.allowsSelection;
        
        return page;
    }
    
    return nil;
}


#pragma mark - Page view controller delegate

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
    if (completed)
    {
        CTAssetItemViewController *vc = (CTAssetItemViewController *)pageViewController.viewControllers[0];
        NSInteger index = [self.assets indexOfObject:vc.asset] + 1;
        
        [self updateTitle:index];
        [self updateToolbar];
    }
}

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
    [self.navigationController setToolbarHidden:YES animated:YES];
}


#pragma mark - Notification observer

- (void)addNotificationObserver
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self
               selector:@selector(assetScrollViewDidTap:)
                   name:CTAssetScrollViewDidTapNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(assetScrollViewPlayerDidPlayToEnd:)
                   name:AVPlayerItemDidPlayToEndTimeNotification
                 object:nil];    
    
    [center addObserver:self
               selector:@selector(assetScrollViewPlayerWillPlay:)
                   name:CTAssetScrollViewPlayerWillPlayNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(assetScrollViewPlayerWillPause:)
                   name:CTAssetScrollViewPlayerWillPauseNotification
                 object:nil];    
}

- (void)removeNotificationObserver
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center removeObserver:self name:CTAssetScrollViewDidTapNotification object:nil];
    [center removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [center removeObserver:self name:CTAssetScrollViewPlayerWillPlayNotification object:nil];
    [center removeObserver:self name:CTAssetScrollViewPlayerWillPauseNotification object:nil];
}


#pragma mark - Notification events

- (void)assetScrollViewDidTap:(NSNotification *)notification
{
    UITapGestureRecognizer *gesture = (UITapGestureRecognizer *)notification.object;
    
    if (gesture.numberOfTapsRequired == 1)
        [self toggleFullscreen:gesture];
}

- (void)assetScrollViewPlayerDidPlayToEnd:(NSNotification *)notification
{
    [self replaceToolbarButton:self.playButton];
    [self setFullscreen:NO];
}

- (void)assetScrollViewPlayerWillPlay:(NSNotification *)notification
{
    [self replaceToolbarButton:self.pauseButton];
    [self setFullscreen:YES];
}

- (void)assetScrollViewPlayerWillPause:(NSNotification *)notification
{
    [self replaceToolbarButton:self.playButton];
}


#pragma mark - Toggle fullscreen

- (void)toggleFullscreen:(id)sender
{
    [self setFullscreen:!self.isStatusBarHidden];
}

- (void)setFullscreen:(BOOL)fullscreen
{
    if (fullscreen)
    {
        [self.pageView enterFullscreen];
        [self fadeAwayControls:self.navigationController];
    }
    else
    {
        [self.pageView exitFullscreen];
        [self fadeInControls:self.navigationController];
    }
    
}

- (void)fadeInControls:(UINavigationController *)nav
{
    self.statusBarHidden = NO;
    
    [nav setNavigationBarHidden:NO];
    nav.navigationBar.alpha = 0.0f;
    
    if ([self.asset ctassetsPickerIsVideo])
    {
        [nav setToolbarHidden:NO];
        nav.toolbar.alpha = 0.0f;
    }
    
    [UIView animateWithDuration:0.2
                     animations:^{
                         [self setNeedsStatusBarAppearanceUpdate];
                         nav.navigationBar.alpha = 1.0f;
                         
                         if ([self.asset ctassetsPickerIsVideo])
                             nav.toolbar.alpha = 1.0f;
                     }];
}

- (void)fadeAwayControls:(UINavigationController *)nav
{
    self.statusBarHidden = YES;
    
    [UIView animateWithDuration:0.2
                     animations:^{
                         [self setNeedsStatusBarAppearanceUpdate];
                         [nav setNavigationBarHidden:YES animated:NO];
                         [nav setToolbarHidden:YES animated:NO];
                         nav.navigationBar.alpha = 0.0f;
                         nav.toolbar.alpha = 0.0f;
                     }];
}


#pragma mark - Playback

- (void)playAsset:(id)sender
{
    [((CTAssetItemViewController *)self.viewControllers[0]) playAsset:sender];
}

- (void)pauseAsset:(id)sender
{
    [((CTAssetItemViewController *)self.viewControllers[0]) pauseAsset:sender];
}


@end
