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
#import "CTAssetsPickerController+Internal.h"
#import "CTAssetsGridViewController.h"
#import "CTAssetsGridView.h"
#import "CTAssetsGridViewLayout.h"
#import "CTAssetsGridViewCell.h"
#import "CTAssetsGridViewFooter.h"
#import "CTAssetsPickerNoAssetsView.h"
#import "CTAssetsPageViewController.h"
#import "CTAssetsPageViewController+Internal.h"
#import "CTAssetsViewControllerTransition.h"
#import "UICollectionView+CTAssetsPickerController.h"
#import "NSIndexSet+CTAssetsPickerController.h"
#import "NSBundle+CTAssetsPickerController.h"
#import "PHImageManager+CTAssetsPickerController.h"





NSString * const CTAssetsGridViewCellIdentifier = @"CTAssetsGridViewCellIdentifier";
NSString * const CTAssetsGridViewFooterIdentifier = @"CTAssetsGridViewFooterIdentifier";


@interface CTAssetsGridViewController ()
<PHPhotoLibraryChangeObserver>

@property (nonatomic, weak) CTAssetsPickerController *picker;
@property (nonatomic, strong) PHFetchResult *fetchResult;
@property (nonatomic, strong) PHCachingImageManager *imageManager;

@property (nonatomic, assign) CGRect previousPreheatRect;
@property (nonatomic, assign) CGRect previousBounds;

@property (nonatomic, strong) CTAssetsGridViewFooter *footer;
@property (nonatomic, strong) CTAssetsPickerNoAssetsView *noAssetsView;

@property (nonatomic, assign) BOOL didLayoutSubviews;

@end





@implementation CTAssetsGridViewController


- (instancetype)init
{
    CTAssetsGridViewLayout *layout = [CTAssetsGridViewLayout new];
    
    if (self = [super initWithCollectionViewLayout:layout])
    {
        _imageManager = [PHCachingImageManager new];
        
        self.extendedLayoutIncludesOpaqueBars = YES;
        
        self.collectionView.allowsMultipleSelection = YES;
        
        [self.collectionView registerClass:CTAssetsGridViewCell.class
                forCellWithReuseIdentifier:CTAssetsGridViewCellIdentifier];
        
        [self.collectionView registerClass:CTAssetsGridViewFooter.class
                forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                       withReuseIdentifier:CTAssetsGridViewFooterIdentifier];
        
        [self addNotificationObserver];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupViews];
    [self registerChangeObserver];
    [self addGestureRecognizer];
    [self addNotificationObserver];
    [self resetCachedAssetImages];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setupButtons];
    [self setupAssets];
    [self updateTitle:self.picker.selectedAssets];
    [self updateButton:self.picker.selectedAssets];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateCachedAssetImages];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if (!CGRectEqualToRect(self.view.bounds, self.previousBounds))
    {
        [self updateCollectionViewLayout];
        self.previousBounds = self.view.bounds;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (!self.didLayoutSubviews && self.fetchResult.count > 0)
    {
        [self scrollToBottomIfNeeded];
        self.didLayoutSubviews = YES;
    }
}

- (void)dealloc
{
    [self unregisterChangeObserver];
    [self removeNotificationObserver];
}


#pragma mark - Accessors

- (CTAssetsPickerController *)picker
{
    return (CTAssetsPickerController *)self.splitViewController.parentViewController;
}

- (PHAsset *)assetAtIndexPath:(NSIndexPath *)indexPath
{
    return (self.fetchResult.count > 0) ? self.fetchResult[indexPath.item] : nil;
}


#pragma mark - Setup

- (void)setupViews
{
    self.collectionView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    CTAssetsGridView *gridView = [CTAssetsGridView new];
    [self.view insertSubview:gridView atIndex:0];
    [self.view setNeedsUpdateConstraints];
}

- (void)setupButtons
{
    if (self.navigationItem.rightBarButtonItem == nil)
    {
        NSString *title = (self.picker.doneButtonTitle) ?
        self.picker.doneButtonTitle : CTAssetsPickerLocalizedString(@"Done", nil);
        
        self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:title
                                         style:UIBarButtonItemStyleDone
                                        target:self.picker
                                        action:@selector(finishPickingAssets:)];
    }
}

- (void)setupAssets
{
    PHFetchResult *fetchResult =
    [PHAsset fetchAssetsInAssetCollection:self.assetCollection
                                  options:self.picker.assetsFetchOptions];
    
    self.fetchResult = fetchResult;
    [self reloadData];
}




#pragma mark - Collection view layout

- (void)updateCollectionViewLayout
{
    UITraitCollection *trait = self.traitCollection;
    CGSize contentSize = self.view.bounds.size;
    UICollectionViewLayout *layout;

    NSArray *attributes = [self.collectionView.collectionViewLayout layoutAttributesForElementsInRect:self.collectionView.bounds];
    UICollectionViewLayoutAttributes *attr = (UICollectionViewLayoutAttributes*)attributes.firstObject;
    // new content size should be at least of first item size, else ignoring
    if (contentSize.width < attr.size.width || contentSize.height < attr.size.height) {
        return;
    }

    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:collectionViewLayoutForContentSize:traitCollection:)]) {
        layout = [self.picker.delegate assetsPickerController:self.picker collectionViewLayoutForContentSize:contentSize traitCollection:trait];
    } else {
        layout = [[CTAssetsGridViewLayout alloc] initWithContentSize:contentSize traitCollection:trait];
    }
    
    __weak CTAssetsGridViewController *weakSelf = self;
    
    [self.collectionView setCollectionViewLayout:layout animated:NO completion:^(BOOL finished){
        [weakSelf.collectionView reloadItemsAtIndexPaths:[weakSelf.collectionView indexPathsForVisibleItems]];
    }];
}



#pragma mark - Scroll to bottom

- (void)scrollToBottomIfNeeded
{
    BOOL shouldScrollToBottom;
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:shouldScrollToBottomForAssetCollection:)])
        shouldScrollToBottom = [self.picker.delegate assetsPickerController:self.picker shouldScrollToBottomForAssetCollection:self.assetCollection];
    else
        shouldScrollToBottom = YES;
 
    if (shouldScrollToBottom)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:self.fetchResult.count-1 inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
    }
}



#pragma mark - Notifications

- (void)addNotificationObserver
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self
               selector:@selector(assetsPickerSelectedAssetsDidChange:)
                   name:CTAssetsPickerSelectedAssetsDidChangeNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(assetsPickerDidSelectAsset:)
                   name:CTAssetsPickerDidSelectAssetNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(assetsPickerDidDeselectAsset:)
                   name:CTAssetsPickerDidDeselectAssetNotification
                 object:nil];
}

- (void)removeNotificationObserver
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center removeObserver:self name:CTAssetsPickerSelectedAssetsDidChangeNotification object:nil];
    [center removeObserver:self name:CTAssetsPickerDidSelectAssetNotification object:nil];
    [center removeObserver:self name:CTAssetsPickerDidDeselectAssetNotification object:nil];
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
        
        PHFetchResultChangeDetails *changeDetails = [changeInstance changeDetailsForFetchResult:self.fetchResult];
        
        if (changeDetails)
        {
            self.fetchResult = changeDetails.fetchResultAfterChanges;
            
            UICollectionView *collectionView = self.collectionView;
            
            if (!changeDetails.hasIncrementalChanges || changeDetails.hasMoves)
            {
                [collectionView reloadData];
                [self resetCachedAssetImages];
            }
            else
            {
                NSArray *removedPaths;
                NSArray *insertedPaths;
                NSArray *changedPaths;
                
                NSIndexSet *removedIndexes = changeDetails.removedIndexes;
                removedPaths = [removedIndexes ctassetsPickerIndexPathsFromIndexesWithSection:0];
                
                NSIndexSet *insertedIndexes = changeDetails.insertedIndexes;
                insertedPaths = [insertedIndexes ctassetsPickerIndexPathsFromIndexesWithSection:0];
                
                NSIndexSet *changedIndexes = changeDetails.changedIndexes;
                changedPaths = [changedIndexes ctassetsPickerIndexPathsFromIndexesWithSection:0];
                
                BOOL shouldReload = NO;
                
                if (changedPaths != nil && removedPaths != nil)
                {
                    for (NSIndexPath *changedPath in changedPaths)
                    {
                        if ([removedPaths containsObject:changedPath])
                        {
                            shouldReload = YES;
                            break;
                        }
                    }
                }
                
                if (removedPaths.lastObject && ((NSIndexPath *)removedPaths.lastObject).item >= self.fetchResult.count)
                {
                    shouldReload = YES;
                }
                
                if (shouldReload)
                {
                    [collectionView reloadData];
                    
                }
                else
                {
                    // if we have incremental diffs, tell the collection view to animate insertions and deletions
                    [collectionView performBatchUpdates:^{
                        if (removedPaths.count)
                        {
                            [collectionView deleteItemsAtIndexPaths:[removedIndexes ctassetsPickerIndexPathsFromIndexesWithSection:0]];
                        }
                        
                        if (insertedPaths.count)
                        {
                            [collectionView insertItemsAtIndexPaths:[insertedIndexes ctassetsPickerIndexPathsFromIndexesWithSection:0]];
                        }
                        
                        if (changedPaths.count)
                        {
                            [collectionView reloadItemsAtIndexPaths:[changedIndexes ctassetsPickerIndexPathsFromIndexesWithSection:0] ];
                        }
                    } completion:^(BOOL finished){
                        if (finished)
                            [self resetCachedAssetImages];
                    }];
                }
            }
            
            [self.footer bind:self.fetchResult];
            
            if (self.fetchResult.count == 0)
                [self showNoAssets];
            else
                [self hideNoAssets];
        }
        
        if ([self.delegate respondsToSelector:@selector(assetsGridViewController:photoLibraryDidChangeForAssetCollection:)])
            [self.delegate assetsGridViewController:self photoLibraryDidChangeForAssetCollection:self.assetCollection];
        
    });
}


#pragma mark - Selected assets changed

- (void)assetsPickerSelectedAssetsDidChange:(NSNotification *)notification
{
    NSArray *selectedAssets = (NSArray *)notification.object;
    [self updateTitle:selectedAssets];
    [self updateButton:selectedAssets];
}

- (void)updateTitle:(NSArray *)selectedAssets
{
    if (selectedAssets.count > 0)
        self.title = self.picker.selectedAssetsString;
    else
        self.title = self.assetCollection.localizedTitle;
}

- (void)updateButton:(NSArray *)selectedAssets
{
    if (self.picker.alwaysEnableDoneButton)
        self.navigationItem.rightBarButtonItem.enabled = YES;
    else
        self.navigationItem.rightBarButtonItem.enabled = (self.picker.selectedAssets.count > 0);
}


#pragma mark - Did de/select asset notifications

- (void)assetsPickerDidSelectAsset:(NSNotification *)notification
{
    PHAsset *asset = (PHAsset *)notification.object;
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self.fetchResult indexOfObject:asset] inSection:0];
    [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    
    [self updateSelectionOrderLabels];
}

- (void)assetsPickerDidDeselectAsset:(NSNotification *)notification
{
    PHAsset *asset = (PHAsset *)notification.object;
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self.fetchResult indexOfObject:asset] inSection:0];
    [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
    
    [self updateSelectionOrderLabels];
}


#pragma mark - Update Selection Order Labels

- (void)updateSelectionOrderLabels
{
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems])
    {
        PHAsset *asset = [self assetAtIndexPath:indexPath];
        CTAssetsGridViewCell *cell = (CTAssetsGridViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        cell.selectionIndex = [self.picker.selectedAssets indexOfObject:asset];
    }
}


#pragma mark - Gesture recognizer

- (void)addGestureRecognizer
{
    UILongPressGestureRecognizer *longPress =
    [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pushPageViewController:)];
    
    [self.collectionView addGestureRecognizer:longPress];
}


#pragma mark - Push assets page view controller

- (void)pushPageViewController:(UILongPressGestureRecognizer *)longPress
{
    if (longPress.state == UIGestureRecognizerStateBegan)
    {
        CGPoint point           = [longPress locationInView:self.collectionView];
        NSIndexPath *indexPath  = [self.collectionView indexPathForItemAtPoint:point];
        
        CTAssetsPageViewController *vc = [[CTAssetsPageViewController alloc] initWithFetchResult:self.fetchResult];
        vc.allowsSelection = YES;
        vc.pageIndex = indexPath.item;
        
        [self.navigationController pushViewController:vc animated:YES];
    }
}


#pragma mark - Reload data

- (void)reloadData
{
    if (self.fetchResult.count > 0)
    {
        [self hideNoAssets];
        [self.collectionView reloadData];
    }
    else
    {
        [self showNoAssets];
    }
}


#pragma mark - Asset images caching

- (void)resetCachedAssetImages
{
    [self.imageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssetImages
{
    BOOL isViewVisible = [self isViewLoaded] && self.view.window != nil;
    
    if (!isViewVisible)
        return;
    
    // The preheat window is twice the height of the visible rect
    CGRect preheatRect = self.collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    // If scrolled by a "reasonable" amount...
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    
    if (delta > CGRectGetHeight(self.collectionView.bounds) / 3.0f)
    {
        // Compute the assets to start caching and to stop caching.
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect
                                   andRect:preheatRect
                            removedHandler:^(CGRect removedRect) {
                                NSArray *indexPaths = [self.collectionView ctassetsPickerIndexPathsForElementsInRect:removedRect];
                                [removedIndexPaths addObjectsFromArray:indexPaths];
                            } addedHandler:^(CGRect addedRect) {
                                NSArray *indexPaths = [self.collectionView ctassetsPickerIndexPathsForElementsInRect:addedRect];
                                [addedIndexPaths addObjectsFromArray:indexPaths];
                            }];
        
        [self startCachingThumbnailsForIndexPaths:addedIndexPaths];
        [self stopCachingThumbnailsForIndexPaths:removedIndexPaths];
        
        self.previousPreheatRect = preheatRect;
    }
}

- (void)startCachingThumbnailsForIndexPaths:(NSArray *)indexPaths
{
    for (NSIndexPath *indexPath in indexPaths)
    {
        PHAsset *asset = [self assetAtIndexPath:indexPath];
        
        if (!asset) break;
        
        UICollectionViewLayoutAttributes *attributes =
        [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
        
        CGSize targetSize = [self.picker imageSizeForContainerSize:attributes.size];
        
        [self.imageManager startCachingImagesForAssets:@[asset]
                                            targetSize:targetSize
                                           contentMode:PHImageContentModeAspectFill
                                               options:self.picker.thumbnailRequestOptions];
    }
}

- (void)stopCachingThumbnailsForIndexPaths:(NSArray *)indexPaths
{
    for (NSIndexPath *indexPath in indexPaths)
    {
        PHAsset *asset = [self assetAtIndexPath:indexPath];
        
        if (!asset) break;

        UICollectionViewLayoutAttributes *attributes =
        [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
        
        CGSize targetSize = [self.picker imageSizeForContainerSize:attributes.size];
        
        [self.imageManager stopCachingImagesForAssets:@[asset]
                                           targetSize:targetSize
                                          contentMode:PHImageContentModeAspectFill
                                              options:self.picker.thumbnailRequestOptions];
    }
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler
{
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}


#pragma mark - Scroll view delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateCachedAssetImages];
}


#pragma mark - No assets

- (void)showNoAssets
{
    CTAssetsPickerNoAssetsView *view = [CTAssetsPickerNoAssetsView new];
    [self.view addSubview:view];
    [view setNeedsUpdateConstraints];
    [view updateConstraintsIfNeeded];
    
    self.noAssetsView = view;
}

- (void)hideNoAssets
{
    if (self.noAssetsView)
    {
        [self.noAssetsView removeFromSuperview];
        self.noAssetsView = nil;
    }
}


#pragma mark - Collection view data source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.fetchResult.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CTAssetsGridViewCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:CTAssetsGridViewCellIdentifier
                                              forIndexPath:indexPath];
    
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:shouldEnableAsset:)])
        cell.enabled = [self.picker.delegate assetsPickerController:self.picker shouldEnableAsset:asset];
    else
        cell.enabled = YES;
    
    cell.showsSelectionIndex = self.picker.showsSelectionIndex;
    
    // XXX
    // Setting `selected` property blocks further deselection.
    // Have to call selectItemAtIndexPath too. ( ref: http://stackoverflow.com/a/17812116/1648333 )
    if ([self.picker.selectedAssets containsObject:asset])
    {
        cell.selected = YES;
        cell.selectionIndex = [self.picker.selectedAssets indexOfObject:asset];
        [collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    }
    
    [cell bind:asset];
    
    UICollectionViewLayoutAttributes *attributes =
    [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    
    CGSize targetSize = [self.picker imageSizeForContainerSize:attributes.size];
    
    [self requestThumbnailForCell:cell targetSize:targetSize asset:asset];

    return cell;
}

- (void)requestThumbnailForCell:(CTAssetsGridViewCell *)cell targetSize:(CGSize)targetSize asset:(PHAsset *)asset
{
    NSInteger tag = cell.tag + 1;
    cell.tag = tag;

    [self.imageManager ctassetsPickerRequestImageForAsset:asset
                                 targetSize:targetSize
                                contentMode:PHImageContentModeAspectFill
                                    options:self.picker.thumbnailRequestOptions
                              resultHandler:^(UIImage *image, NSDictionary *info){
                                  // Only update the image if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                                  if (cell.tag == tag)
                                      [(CTAssetThumbnailView *)cell.backgroundView bind:image asset:asset];
                              }];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    CTAssetsGridViewFooter *footer =
    [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                       withReuseIdentifier:CTAssetsGridViewFooterIdentifier
                                              forIndexPath:indexPath];
    
    [footer bind:self.fetchResult];
    
    self.footer = footer;
    
    return footer;
}


#pragma mark - Collection view delegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    CTAssetsGridViewCell *cell = (CTAssetsGridViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    
    if (!cell.isEnabled)
        return NO;
    else if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:shouldSelectAsset:)])
        return [self.picker.delegate assetsPickerController:self.picker shouldSelectAsset:asset];
    else
        return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    [self.picker selectAsset:asset];
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:didSelectAsset:)])
        [self.picker.delegate assetsPickerController:self.picker didSelectAsset:asset];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:shouldDeselectAsset:)])
        return [self.picker.delegate assetsPickerController:self.picker shouldDeselectAsset:asset];
    else
        return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    [self.picker deselectAsset:asset];
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:didDeselectAsset:)])
        [self.picker.delegate assetsPickerController:self.picker didDeselectAsset:asset];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:shouldHighlightAsset:)])
        return [self.picker.delegate assetsPickerController:self.picker shouldHighlightAsset:asset];
    else
        return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:didHighlightAsset:)])
        [self.picker.delegate assetsPickerController:self.picker didHighlightAsset:asset];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self assetAtIndexPath:indexPath];
    
    if ([self.picker.delegate respondsToSelector:@selector(assetsPickerController:didUnhighlightAsset:)])
        [self.picker.delegate assetsPickerController:self.picker didUnhighlightAsset:asset];
}

@end