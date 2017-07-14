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


#import "CTAssetsPickerDefines.h"
#import "CTAssetsPickerController.h"
#import "CTAssetsPickerAccessDeniedView.h"
#import "CTAssetsPickerNoAssetsView.h"
#import "CTAssetCollectionViewController.h"
#import "CTAssetsGridViewController.h"
#import "CTAssetScrollView.h"
#import "CTAssetsPageViewController.h"
#import "CTAssetsViewControllerTransition.h"
#import "NSBundle+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"
#import "NSNumberFormatter+CTAssetsPickerController.h"
#import "CTAssetsNavigationController.h"



NSString * const CTAssetsPickerSelectedAssetsDidChangeNotification = @"CTAssetsPickerSelectedAssetsDidChangeNotification";
NSString * const CTAssetsPickerDidSelectAssetNotification = @"CTAssetsPickerDidSelectAssetNotification";
NSString * const CTAssetsPickerDidDeselectAssetNotification = @"CTAssetsPickerDidDeselectAssetNotification";



@interface CTAssetsPickerController ()
<PHPhotoLibraryChangeObserver, UISplitViewControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, assign) BOOL shouldCollapseDetailViewController;

@property (nonatomic, assign) CGSize assetCollectionThumbnailSize;
@property (nonatomic, assign) CGSize assetThumbnailSize;

@property (nonatomic, strong) PHImageRequestOptions *thumbnailRequestOptions;

@end



@implementation CTAssetsPickerController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        _shouldCollapseDetailViewController = YES;
        _assetCollectionThumbnailSize       = CTAssetCollectionThumbnailSize;
        _assetCollectionFetchOptions        = nil;
        _assetsFetchOptions                 = nil;
        _selectedAssets                     = [NSMutableArray new];
        _showsCancelButton                  = YES;
        _showsEmptyAlbums                   = YES;
        _showsNumberOfAssets                = YES;
        _alwaysEnableDoneButton             = NO;
        _showsSelectionIndex                = NO;
        _defaultAssetCollection             = PHAssetCollectionSubtypeAny;
        
        [self initAssetCollectionSubtypes];
        [self initThumbnailRequestOptions];
        self.preferredContentSize           = CTAssetsPickerPopoverContentSize;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupViews];
    [self setupEmptyViewController];
    [self checkAuthorizationStatus];
    [self addKeyValueObserver];
    [self registerChangeObserver];
}

- (void)dealloc
{
    [self removeKeyValueObserver];
    [self unregisterChangeObserver];
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.childSplitViewController.viewControllers.firstObject;
}

- (UIViewController *)childViewControllerForStatusBarHidden
{
    UIViewController *vc = self.childSplitViewController.viewControllers.lastObject;
    
    if ([vc isMemberOfClass:[UINavigationController class]])
        return ((UINavigationController *)vc).topViewController;
    else
        return nil;
}



#pragma mark - Init properties

- (void)initAssetCollectionSubtypes
{
    _assetCollectionSubtypes =
    @[@(PHAssetCollectionSubtypeSmartAlbumUserLibrary),
      @(PHAssetCollectionSubtypeAlbumMyPhotoStream),
      @(PHAssetCollectionSubtypeSmartAlbumRecentlyAdded),
      @(PHAssetCollectionSubtypeSmartAlbumFavorites),
      @(PHAssetCollectionSubtypeSmartAlbumPanoramas),
      @(PHAssetCollectionSubtypeSmartAlbumVideos),
      @(PHAssetCollectionSubtypeSmartAlbumSlomoVideos),
      @(PHAssetCollectionSubtypeSmartAlbumTimelapses),
      @(PHAssetCollectionSubtypeSmartAlbumBursts),
      @(PHAssetCollectionSubtypeSmartAlbumAllHidden),
      @(PHAssetCollectionSubtypeSmartAlbumGeneric),
      @(PHAssetCollectionSubtypeAlbumRegular),
      @(PHAssetCollectionSubtypeAlbumSyncedAlbum),
      @(PHAssetCollectionSubtypeAlbumSyncedEvent),
      @(PHAssetCollectionSubtypeAlbumSyncedFaces),
      @(PHAssetCollectionSubtypeAlbumImported),
      @(PHAssetCollectionSubtypeAlbumCloudShared)];
    
    // Add iOS 9's new albums
    if ([[PHAsset new] respondsToSelector:@selector(sourceType)])
    {
        NSMutableArray *subtypes = [NSMutableArray arrayWithArray:self.assetCollectionSubtypes];
        [subtypes insertObject:@(PHAssetCollectionSubtypeSmartAlbumSelfPortraits) atIndex:4];
        [subtypes insertObject:@(PHAssetCollectionSubtypeSmartAlbumScreenshots) atIndex:10];
        
        self.assetCollectionSubtypes = [NSArray arrayWithArray:subtypes];
    }
}

- (void)initThumbnailRequestOptions
{
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeFast;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
 
    _thumbnailRequestOptions = options;
}


#pragma mark - Check authorization status

- (void)checkAuthorizationStatus
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    switch (status)
    {
        case PHAuthorizationStatusNotDetermined:
            [self requestAuthorizationStatus];
            break;
        case PHAuthorizationStatusRestricted:
        case PHAuthorizationStatusDenied:
        {
            [self showAccessDenied];
            break;
        }
        case PHAuthorizationStatusAuthorized:
        default:
        {
            [self checkAssetsCount];
            break;
        }
    }
}


#pragma mark - Request authorization status

- (void)requestAuthorizationStatus
{
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
        switch (status) {
            case PHAuthorizationStatusAuthorized:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self checkAssetsCount];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showAccessDenied];
                });
                break;
            }
        }
    }];
}


#pragma mark - Check assets count

- (void)checkAssetsCount
{
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithOptions:self.assetsFetchOptions];
    
    if (fetchResult.count > 0) {
        [self showAssetCollectionViewController];
    } else {
        [self showNoAssets];
    }
}


#pragma mark - Setup views

- (void)setupViews
{
    self.view.backgroundColor = [UIColor whiteColor];
}


#pragma mark - Setup view controllers

- (void)setupEmptyViewController
{
    UINavigationController *nav = [self emptyNavigationController];
    [self setupChildViewController:nav];
}

- (void)setupSplitViewController
{
    CTAssetCollectionViewController *vc = [CTAssetCollectionViewController new];
    CTAssetsNavigationController *master = [[CTAssetsNavigationController alloc] initWithRootViewController:vc];
    UINavigationController *detail = [self emptyNavigationController];
    UISplitViewController *svc  = [UISplitViewController new];
    
    svc.delegate = self;
    svc.viewControllers = @[master, detail];
    svc.presentsWithGesture = NO;
    svc.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
    [self addChildViewController:svc];
    svc.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    [self.view addSubview:svc.view];
    [svc didMoveToParentViewController:self];

    [vc reloadUserInterface];
}

- (void)setupChildViewController:(UIViewController *)vc
{
    [self addChildViewController:vc];
    vc.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    [self.view addSubview:vc.view];
    [vc didMoveToParentViewController:self];
}

- (void)removeChildViewController
{
    UIViewController *vc = self.childViewControllers.firstObject;
    [vc willMoveToParentViewController:nil];
    [vc.view removeFromSuperview];
    [vc removeFromParentViewController];
}

#pragma mark - Setup view controllers

- (UINavigationController *)emptyNavigationController
{
    UIViewController *vc = [self emptyViewController];
    return [[UINavigationController alloc] initWithRootViewController:vc];
}

- (UIViewController *)emptyViewController
{
    UIViewController *vc                = [UIViewController new];
    vc.view.backgroundColor             = [UIColor whiteColor];
    vc.navigationItem.hidesBackButton   = YES;
 
    return vc;
}




#pragma mark - Show asset collection view controller

- (void)showAssetCollectionViewController
{
    [self removeChildViewController];
    [self setupSplitViewController];
}


#pragma mark - Show auxiliary view

- (void)showAuxiliaryView:(UIView *)view
{
    [self removeChildViewController];

    UIViewController *vc = [self emptyViewController];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    [vc.view addSubview:view];
    [view setNeedsUpdateConstraints];
    [view updateConstraintsIfNeeded];
    
    [self setupButtonInViewController:vc];
    [self setupChildViewController:nav];
}


#pragma mark - Access denied

- (void)showAccessDenied
{
    [self showAuxiliaryView:[CTAssetsPickerAccessDeniedView new]];
}


#pragma mark - No Assets

- (void)showNoAssets
{
    [self showAuxiliaryView:[CTAssetsPickerNoAssetsView new]];
}


#pragma mark - Cancel button

- (void)setupButtonInViewController:(UIViewController *)viewController
{
    if (self.showsCancelButton)
    {
        viewController.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:CTAssetsPickerLocalizedString(@"Cancel", nil)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(dismiss:)];
    }
}


#pragma mark - Key-Value observer

- (void)addKeyValueObserver
{
    [self addObserver:self
           forKeyPath:@"selectedAssets"
              options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
              context:nil];
}

- (void)removeKeyValueObserver
{
    @try {
        [self removeObserver:self forKeyPath:@"selectedAssets"];
    }
    @catch (NSException *exception) {
        // do nothing
    }
}


#pragma mark - Key-Value changed

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:@"selectedAssets"])
    {
        [self toggleDoneButton];
        [self postSelectedAssetsDidChangeNotification:[object valueForKey:keyPath]];
    }
}


#pragma mark - Photo library change observer

- (void)registerChangeObserver
{
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)unregisterChangeObserver
{
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}



#pragma mark - Photo library changed

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    // Call might come on any background queue. Re-dispatch to the main queue to handle it.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSMutableArray *deselectAssets = [NSMutableArray new];
        
        for (PHAsset *asset in self.selectedAssets)
        {
            PHObjectChangeDetails *changeDetails = [changeInstance changeDetailsForObject:asset];
    
            if (changeDetails.objectWasDeleted)
                [deselectAssets addObject:asset];
        }
        
        // Deselect asset if it was deleted from library
        for (PHAsset *asset in deselectAssets)
            [self deselectAsset:asset];
    });
}



#pragma mark - Toggle button

- (void)toggleDoneButton
{
    UIViewController *vc = self.childSplitViewController.viewControllers.firstObject;
    
    if ([vc isMemberOfClass:[UINavigationController class]])
    {
        BOOL enabled = (self.alwaysEnableDoneButton) ? YES : (self.selectedAssets.count > 0);
        
        for (UIViewController *viewController in ((UINavigationController *)vc).viewControllers)
            viewController.navigationItem.rightBarButtonItem.enabled = enabled;
    }
}


#pragma mark - Post notifications

- (void)postSelectedAssetsDidChangeNotification:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:CTAssetsPickerSelectedAssetsDidChangeNotification
                                                        object:sender];
}

- (void)postDidSelectAssetNotification:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:CTAssetsPickerDidSelectAssetNotification
                                                        object:sender];
}

- (void)postDidDeselectAssetNotification:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:CTAssetsPickerDidDeselectAssetNotification
                                                        object:sender];
}


#pragma mark - Accessors

- (UISplitViewController *)childSplitViewController
{
    return (UISplitViewController *)self.childViewControllers.firstObject;
}


#pragma mark - Indexed accessors

- (NSUInteger)countOfSelectedAssets
{
    return self.selectedAssets.count;
}

- (instancetype)objectInSelectedAssetsAtIndex:(NSUInteger)index
{
    return self.selectedAssets[index];
}

- (void)insertObject:(id)object inSelectedAssetsAtIndex:(NSUInteger)index
{
    [self.selectedAssets insertObject:object atIndex:index];
}

- (void)removeObjectFromSelectedAssetsAtIndex:(NSUInteger)index
{
    [self.selectedAssets removeObjectAtIndex:index];
}

- (void)replaceObjectInSelectedAssetsAtIndex:(NSUInteger)index withObject:(PHAsset *)object
{
    self.selectedAssets[index] = object;
}


#pragma mark - De/Select asset

- (void)selectAsset:(PHAsset *)asset
{
    [self insertObject:asset inSelectedAssetsAtIndex:self.countOfSelectedAssets];
    [self postDidSelectAssetNotification:asset];
}

- (void)deselectAsset:(PHAsset *)asset
{
    [self removeObjectFromSelectedAssetsAtIndex:[self.selectedAssets indexOfObject:asset]];
    [self postDidDeselectAssetNotification:asset];
}


#pragma mark - Selected assets string

- (NSPredicate *)predicateOfMediaType:(PHAssetMediaType)type
{
    return [NSPredicate predicateWithBlock:^BOOL(PHAsset *asset, NSDictionary *bindings) {
        return (asset.mediaType == type);
    }];
}

- (NSString *)selectedAssetsString
{
    if (self.selectedAssets.count == 0)
        return nil;
    
    NSPredicate *photoPredicate = [self predicateOfMediaType:PHAssetMediaTypeImage];
    NSPredicate *videoPredicate = [self predicateOfMediaType:PHAssetMediaTypeVideo];
    
    BOOL photoSelected = ([self.selectedAssets filteredArrayUsingPredicate:photoPredicate].count > 0);
    BOOL videoSelected = ([self.selectedAssets filteredArrayUsingPredicate:videoPredicate].count > 0);
    
    NSString *format;
    
    if (photoSelected && videoSelected)
        format = CTAssetsPickerLocalizedString(@"%@ Items Selected", nil);
    
    else if (photoSelected)
        format = (self.selectedAssets.count > 1) ?
        CTAssetsPickerLocalizedString(@"%@ Photos Selected", nil) :
        CTAssetsPickerLocalizedString(@"%@ Photo Selected", nil);
    
    else if (videoSelected)
        format = (self.selectedAssets.count > 1) ?
        CTAssetsPickerLocalizedString(@"%@ Videos Selected", nil) :
        CTAssetsPickerLocalizedString(@"%@ Video Selected", nil);
    
    NSNumberFormatter *nf = [NSNumberFormatter new];
    
    return [NSString stringWithFormat:format, [nf ctassetsPickerStringFromAssetsCount:self.selectedAssets.count]];
}


#pragma mark - Image target size

- (CGSize)imageSizeForContainerSize:(CGSize)size
{
    CGFloat scale = UIScreen.mainScreen.scale;
    return CGSizeMake(size.width * scale, size.height * scale);
}


#pragma mark - Split view controller delegate

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController
{
    return self.shouldCollapseDetailViewController;
}


#pragma mark - Navigation controller delegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC
{
    if ((operation == UINavigationControllerOperationPush && [toVC isKindOfClass:[CTAssetsPageViewController class]]) ||
        (operation == UINavigationControllerOperationPop && [fromVC isKindOfClass:[CTAssetsPageViewController class]]))
    {
        CTAssetsViewControllerTransition *transition = [[CTAssetsViewControllerTransition alloc] init];
        transition.operation = operation;

        return transition;
    }
    else
    {
        return nil;
    }
}


#pragma mark - Actions

- (void)dismiss:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(assetsPickerControllerDidCancel:)])
        [self.delegate assetsPickerControllerDidCancel:self];
    else
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}


- (void)finishPickingAssets:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(assetsPickerController:didFinishPickingAssets:)])
        [self.delegate assetsPickerController:self didFinishPickingAssets:self.selectedAssets];
}


@end