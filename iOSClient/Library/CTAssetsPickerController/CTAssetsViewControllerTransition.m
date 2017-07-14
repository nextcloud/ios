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

#import "CTAssetsViewControllerTransition.h"
#import "CTAssetsPickerDefines.h"
#import "CTAssetsGridViewController.h"
#import "CTAssetsPageViewController.h"
#import "CTAssetItemViewController.h"
#import "CTAssetScrollView.h"
#import "CTAssetsPageView.h"



@interface CTAssetsViewControllerTransition ()

@end




@implementation CTAssetsViewControllerTransition


#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.35f;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIView *containerView = [transitionContext containerView];
    
    UIColor *backgroundColor = [CTAssetsPageView appearance].pageBackgroundColor;
    containerView.backgroundColor = (backgroundColor) ? backgroundColor : CTAssetsPageViewPageBackgroundColor;

    if (self.operation == UINavigationControllerOperationPush)
    {
        CTAssetsGridViewController *fromVC  = (CTAssetsGridViewController *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
        CTAssetsPageViewController *toVC    = (CTAssetsPageViewController *)[transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
        CTAssetItemViewController *iVC      = (CTAssetItemViewController *)toVC.viewControllers[0];
        NSIndexPath *indexPath              = [NSIndexPath indexPathForItem:toVC.pageIndex inSection:0];
        
        UIView *cellView        = [fromVC.collectionView cellForItemAtIndexPath:indexPath];
        UIImageView *imageView  = [[UIImageView alloc] initWithImage:iVC.image];
        UIView *snapshot        = [self resizedSnapshot:imageView];
        
        CGPoint cellCenter  = [fromVC.view convertPoint:cellView.center fromView:cellView.superview];
        CGPoint snapCenter  = toVC.view.center;
        
        // Find the scales of snapshot
        float startScale        = MAX(cellView.frame.size.width / snapshot.frame.size.width,
                                      cellView.frame.size.height / snapshot.frame.size.height);
        
        float minScale          = MIN(toVC.view.frame.size.width / snapshot.frame.size.width,
                                      toVC.view.frame.size.height / snapshot.frame.size.height);
        
        float perspectiveScale  = MAX(toVC.view.frame.size.width / snapshot.frame.size.width,
                                      toVC.view.frame.size.height / snapshot.frame.size.height);
        
        BOOL canPerspectiveZoom = ([self canPerspectiveZoomWithImageSize:iVC.image.size boundsSize:toVC.view.bounds.size]);
        
        float endScale          = (canPerspectiveZoom) ? perspectiveScale : minScale;
        
        // Find the bounds of the snapshot mask
        float width         = snapshot.bounds.size.width;
        float height        = snapshot.bounds.size.height;
        float length        = MIN(width, height);
        
        CGRect startBounds  = CGRectMake((width-length)/2, (height-length)/2, length, length);
        
        // Create the mask
        UIView *mask            = [[UIView alloc] initWithFrame:startBounds];
        mask.backgroundColor    = [UIColor whiteColor];
        
        // Prepare transition
        snapshot.transform  = CGAffineTransformMakeScale(startScale, startScale);;
        snapshot.layer.mask = mask.layer;
        snapshot.center     = cellCenter;
        
        toVC.view.frame     = [transitionContext finalFrameForViewController:toVC];
        toVC.view.alpha     = 0;
        
        // Add to container view
        [containerView addSubview:toVC.view];
        [containerView addSubview:snapshot];
        
        // Animate
        [UIView animateWithDuration:[self transitionDuration:transitionContext]
                              delay:0
             usingSpringWithDamping:0.75
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                             fromVC.view.alpha          = 0;
                             snapshot.transform         = CGAffineTransformMakeScale(endScale, endScale);
                             snapshot.layer.mask.bounds = snapshot.bounds;
                             snapshot.center            = snapCenter;
                             toVC.navigationController.toolbar.alpha = 0;
                         }
                         completion:^(BOOL finished){
                             toVC.view.alpha   = 1;
                             [snapshot removeFromSuperview];
                             [transitionContext completeTransition:YES];
                         }];
    }
    
    else
    {
        CTAssetsPageViewController *fromVC  = (CTAssetsPageViewController *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
        CTAssetsGridViewController *toVC    = (CTAssetsGridViewController *)[transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
        CTAssetItemViewController *iVC      = (CTAssetItemViewController *)fromVC.viewControllers[0];
        NSIndexPath *indexPath              = [NSIndexPath indexPathForItem:fromVC.pageIndex inSection:0];
        
        // Scroll to index path
        [toVC.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
        [toVC.collectionView layoutIfNeeded];
        
        UIView *cellView                = [toVC.collectionView cellForItemAtIndexPath:indexPath];
        CTAssetScrollView *scrollView   = iVC.view.subviews[0];
        UIImageView *imageView          = scrollView.imageView;
        UIView *snapshot                = [self resizedSnapshot:imageView];
        
        CGPoint cellCenter  = [toVC.view convertPoint:cellView.center fromView:cellView.superview];
        CGPoint snapCenter  = fromVC.view.center;
        
        // Find the scales of snapshot
        float startScale    = MIN(fromVC.view.frame.size.width / snapshot.frame.size.width,
                                  fromVC.view.frame.size.height / snapshot.frame.size.height);
        
        float endScale      = MAX(cellView.frame.size.width / snapshot.frame.size.width,
                                  cellView.frame.size.height / snapshot.frame.size.height);
        
        // Find the bounds of the snapshot mask
        float width         = snapshot.bounds.size.width;
        float height        = snapshot.bounds.size.height;
        float length        = MIN(width, height);
        CGRect endBounds    = CGRectMake((width-length)/2, (height-length)/2, length, length);
        
        UIView *mask            = [[UIView alloc] initWithFrame:snapshot.bounds];
        mask.backgroundColor    = [UIColor whiteColor];
        
        // Prepare transition
        snapshot.transform      = CGAffineTransformMakeScale(startScale, startScale);
        snapshot.layer.mask     = mask.layer;
        snapshot.center         = snapCenter;
        
        toVC.view.frame         = [transitionContext finalFrameForViewController:toVC];
        toVC.view.alpha         = 0;
        fromVC.view.alpha       = 0;
        
        // Add to container view
        [containerView addSubview:toVC.view];
        [containerView addSubview:snapshot];
        
        // Animate
        [UIView animateWithDuration:[self transitionDuration:transitionContext]
                              delay:0
             usingSpringWithDamping:1
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                             toVC.view.alpha            = 1;
                             snapshot.transform         = CGAffineTransformMakeScale(endScale, endScale);
                             snapshot.layer.mask.bounds = endBounds;
                             snapshot.center            = cellCenter;
                             toVC.navigationController.toolbar.alpha = 0;
                         }
                         completion:^(BOOL finished){
                             [snapshot removeFromSuperview];
                             [transitionContext completeTransition:YES];
                         }];
    }
}


#pragma mark - Perspective Zoom

- (BOOL)canPerspectiveZoomWithImageSize:(CGSize)imageSize boundsSize:(CGSize)boundsSize
{
    CGFloat imageRatio  = imageSize.width / imageSize.height;
    CGFloat boundsRatio = boundsSize.width / boundsSize.height;
    
    // can perform perspective zoom when the difference of aspect ratios is smaller than 20%
    return (fabs( (imageRatio - boundsRatio) / boundsRatio ) < 0.2f);
}



#pragma mark - Snapshot

- (UIView *)resizedSnapshot:(UIImageView *)imageView
{
    CGSize size = imageView.frame.size;
    
    if (CGSizeEqualToSize(size, CGSizeZero))
        return nil;
    
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    
    [[UIColor whiteColor] set];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    
    [imageView.image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return (UIView *)[[UIImageView alloc] initWithImage:resized];
}

@end
