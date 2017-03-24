//
//  CCControlCenter.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 07/04/16.
//  Copyright (c) 2014 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCControlCenter.h"
#import "CCControlCenterTransfer.h"

#import "CCControlCenterActivity.h"

#import "AppDelegate.h"
#import "CCMain.h"
#import "CCDetail.h"

#define SIZE_FONT_NORECORD 18.0f
#define ANIMATION_GESTURE 0.50f

@interface CCControlCenter ()
{
    UIVisualEffectView *_mainView;
    UIView *_endLine;
    
    CGFloat start, stop;
    
    UIPanGestureRecognizer *panNavigationBar, *panImageDrag;
    UITapGestureRecognizer *_singleFingerTap;
    
    UIPageControl *_pageControl;
}
@end

@implementation CCControlCenter

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        app.controlCenter = self;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _controlCenterPagesContent = [NSMutableArray new];

    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    _mainView = [[UIVisualEffectView alloc] initWithEffect:effect];
    [_mainView setFrame:CGRectMake(0, 0, self.navigationBar.frame.size.width, 0)];
    _mainView.hidden = YES;
    
    // TEST
    //_mainView.backgroundColor = [UIColor yellowColor];
    
    // Create data model
    _pageType = @[k_pageControlCenterTransfer, k_pageControlCenterActivity];
    
    // Create page view controller
    _pageViewController = [[UIStoryboard storyboardWithName: @"ControlCenter" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"ControlCenterPageViewController"];
    _pageViewController.dataSource = self;
    _pageViewController.delegate = self;
    
    UIViewController *startingViewController;
    NSArray *viewControllers;
    
    startingViewController= [self viewControllerAtIndex:0];
    viewControllers = @[startingViewController];
    [_pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    [_pageViewController.view setFrame:CGRectMake(0, 0, self.navigationBar.frame.size.width, 0)];
    _pageViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
     
    [_mainView addSubview:_pageViewController.view];
    
    _labelMessageNoRecord =[[UILabel alloc]init];
    _labelMessageNoRecord.backgroundColor=[UIColor clearColor];
    _labelMessageNoRecord.textColor = COLOR_CONTROL_CENTER;
    _labelMessageNoRecord.font = [UIFont systemFontOfSize:SIZE_FONT_NORECORD];
    _labelMessageNoRecord.textAlignment = NSTextAlignmentCenter;

    [_mainView addSubview:_labelMessageNoRecord];
    
    _endLine = [[UIView alloc] init];
    [_endLine setFrame:CGRectMake(0, 0, self.navigationBar.frame.size.width, 0)];
    _endLine.backgroundColor = COLOR_CONTROL_CENTER;

    [_mainView addSubview:_endLine];
    
    [self.navigationBar.superview insertSubview:_mainView belowSubview:self.navigationBar];
    
    // Pop Gesture Recognizer
    [self.interactivePopGestureRecognizer addTarget:self action:@selector(handlePopGesture:)];
    
    panImageDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panImageDrag.maximumNumberOfTouches = panImageDrag.minimumNumberOfTouches = 1;
    
    // Add Gesture on _pageControl
    NSArray *subviews = self.pageViewController.view.subviews;
    for (int i=0; i<[subviews count]; i++) {
        if ([[subviews objectAtIndex:i] isKindOfClass:[UIPageControl class]]) {
            _pageControl = (UIPageControl *)[subviews objectAtIndex:i];
            [_pageControl addGestureRecognizer:panImageDrag];
        }
    }

    panNavigationBar = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panNavigationBar.maximumNumberOfTouches = panNavigationBar.minimumNumberOfTouches = 1;
    
    [self.navigationBar addGestureRecognizer:panNavigationBar];
}

/* iOS Developer Library : A panning gesture is continuous. It begins (UIGestureRecognizerStateBegan) when the minimum number of fingers allowed (minimumNumberOfTouches) has moved enough to be considered a pan. It changes (UIGestureRecognizerStateChanged) when a finger moves while at least the minimum number of fingers are pressed down. It ends (UIGestureRecognizerStateEnded) when all fingers are lifted. */

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture;
{
    CGPoint currentPoint = [gesture locationInView:self.view];
    CGFloat navigationBarH = self.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat navigationBarW = self.navigationBar.frame.size.width;
    CGFloat heightScreen = [UIScreen mainScreen].bounds.size.height - self.tabBarController.tabBar.frame.size.height;
    CGFloat heightTableView = heightScreen - navigationBarH;

    float centerMaxH = [self getMaxH] / 2;
    float step = [self getMaxH] / 10;
    float tableViewY = navigationBarH;
    
    // BUG Scroll to top of UITableView by tapping status bar
    _mainView.hidden = NO;
    
    // start
    if (gesture.state == UIGestureRecognizerStateBegan) {
     
        start = currentPoint.y;
    }
    
    // cancelled (return to 0)
    if (gesture.state == UIGestureRecognizerStateCancelled) {
        
        currentPoint.y = 0;
        tableViewY = 0;
        panNavigationBar.enabled = YES;
    }

    // end
    if (gesture.state == UIGestureRecognizerStateEnded) {
        
        stop = currentPoint.y;
        
        // DOWN
        if (start < stop) {
        
            if (stop < (start + step + navigationBarH) && start <= navigationBarH) {
                currentPoint.y = 0;
                tableViewY = 0;
                panNavigationBar.enabled = YES;
            } else {
                currentPoint.y = [self getMaxH];
                tableViewY = navigationBarH;
                panNavigationBar.enabled = NO;
            }
        }
        
        // UP
        if (start >= stop && start >= navigationBarH) {
            
            if (stop > (start - step)) {
                currentPoint.y = [self getMaxH];
                tableViewY = navigationBarH;
                panNavigationBar.enabled = NO;
            } else {
                currentPoint.y = 0;
                tableViewY = 0;
                panNavigationBar.enabled = YES;
            }
        }
    }
    
    // changed
    if (gesture.state == UIGestureRecognizerStateChanged) {
        
        if (currentPoint.y <= navigationBarH) {
            currentPoint.y = 0;
            tableViewY = 0;
        }
        else if (currentPoint.y >= [self getMaxH]) {
            currentPoint.y = [self getMaxH];
            tableViewY = navigationBarH;
        }
        else {
            if (currentPoint.y - navigationBarH < navigationBarH) tableViewY = currentPoint.y - navigationBarH;
            else tableViewY = navigationBarH;
        }
    }
    
    [UIView animateWithDuration:ANIMATION_GESTURE delay:0.0 options:UIViewAnimationOptionTransitionCrossDissolve
        animations:^ {
        
            _mainView.frame = CGRectMake(0, 0, navigationBarW, currentPoint.y);
            _pageViewController.view.frame = CGRectMake(0, currentPoint.y - heightScreen + navigationBarH, navigationBarW, heightTableView);
            _labelMessageNoRecord.frame = CGRectMake(0, currentPoint.y - centerMaxH, navigationBarW, SIZE_FONT_NORECORD+10);
            _endLine.frame = CGRectMake(0, currentPoint.y - _pageControl.frame.size.height, navigationBarW, 1);
            
        } completion:^ (BOOL completed) {
            
            if (_mainView.frame.size.height == [self getMaxH]) {
                [self setIsOpen:YES];
            } else {
                [self setIsOpen:NO];
            }
            
            // BUG Scroll to top of UITableView by tapping status bar
            if (_mainView.frame.size.height == 0)
                _mainView.hidden = YES;
        }
    ];
}

/* iOS Developer Library : The navigation controller installs this gesture recognizer on its view and uses it to pop the topmost view controller off the navigation stack. You can use this property to retrieve the gesture recognizer and tie it to the behavior of other gesture recognizers in your user interface. When tying your gesture recognizers together, make sure they recognize their gestures simultaneously to ensure that your gesture recognizers are given a chance to handle the event. */

- (void)handlePopGesture:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _isPopGesture = YES;
    }
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        _isPopGesture = NO;
    }
}

//  rotazione
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    if (_isOpen) {
    
        /*
        [self setControlCenterHidden:YES];
    
        [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
            [self openControlCenterToSize];
        
            [self setControlCenterHidden: self.navigationBarHidden];
        }];
        */
        
        [self closeControlCenter];
    }
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)setControlCenterHidden:(BOOL)hidden
{
    _mainView.hidden = hidden;
}

- (float)getMaxH
{
    //return ([UIScreen mainScreen].bounds.size.height / 4) * 3;
    
    return [UIScreen mainScreen].bounds.size.height - self.tabBarController.tabBar.frame.size.height;
}

- (void)closeControlCenter
{
    _mainView.frame = CGRectMake(0, 0, self.navigationBar.frame.size.width, 0);
    _pageViewController.view.frame = CGRectMake(0, 0, _mainView.frame.size.width, 0);
    _labelMessageNoRecord.frame = CGRectMake(0, 0, _mainView.frame.size.width, 0);
    _endLine.frame = CGRectMake(0, 0, _mainView.frame.size.width, 0);
 
    panNavigationBar.enabled = YES;
    [self setIsOpen:NO];
}

- (void)setIsOpen:(BOOL)setOpen
{
    if (setOpen) {
        
        if (!_isOpen) {
            
            _isOpen = YES;

            [app.controlCenterTransfer reloadDatasource];
            [app.controlCenterActivity reloadDatasource];
        }
        
    } else {
        
        _isOpen = NO;
        
    }
    
    [self changeTabBarApplicationFileImage];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ===== Single Finger Tap =====
#pragma --------------------------------------------------------------------------------------------

- (void)enableSingleFingerTap:(SEL)selector target:(id)target
{
    _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:target action:selector];
    [self.navigationBar addGestureRecognizer:_singleFingerTap];
}

- (void)disableSingleFingerTap
{
    [self.navigationBar removeGestureRecognizer:_singleFingerTap];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Page  =====
#pragma --------------------------------------------------------------------------------------------

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index
{
    if (([self.pageType count] == 0) || (index >= [self.pageType count])) {
        return nil;
    }
    
    UIViewController *pageContentViewController;
    
    if ([self.controlCenterPagesContent count] >= index+1) {
        
        pageContentViewController = [self.controlCenterPagesContent objectAtIndex:index];
        
    } else {
        
        if (index == 0)
            pageContentViewController = [[UIStoryboard storyboardWithName: @"ControlCenter" bundle:[NSBundle mainBundle]]  instantiateViewControllerWithIdentifier:@"ControlCenterTransfer"];
        
        if (index == 1)
            pageContentViewController = [[UIStoryboard storyboardWithName: @"ControlCenter" bundle:[NSBundle mainBundle]]  instantiateViewControllerWithIdentifier:@"ControlCenterActivity"];
        
        [self.controlCenterPagesContent addObject:pageContentViewController];
    }
    
    ((CCControlCenterTransfer *) pageContentViewController).pageIndex = index;
    ((CCControlCenterTransfer *) pageContentViewController).pageType = self.pageType[index];
    
    return pageContentViewController;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSUInteger index = ((CCControlCenterTransfer *) viewController).pageIndex;
    
    if ((index == 0) || (index == NSNotFound)) {
        return nil;
    }
    
    index--;
    return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSUInteger index = ((CCControlCenterTransfer *) viewController).pageIndex;
    
    if (index == NSNotFound) {
        return nil;
    }
    
    index++;
    if (index == [self.pageType count]) {
        return nil;
    }
    return [self viewControllerAtIndex:index];
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
{
    return [self.pageType count];
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
{
    return 0;
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    [self changeTabBarApplicationFileImage];
}

- (void)changeTabBarApplicationFileImage
{
    // Standard Image
    if (!_isOpen) {
        
        self.title = NSLocalizedString(@"_home_", nil);

        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
        item.selectedImage = [UIImage imageNamed:image_tabBarFiles];
        item.image = [UIImage imageNamed:image_tabBarFiles];
        
        return;
    }

    // Change Image
    
    if ([[self getActivePage] isEqualToString:k_pageControlCenterActivity]) {
        
        self.title = NSLocalizedString(@"_activity_", nil);
        
        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
        item.selectedImage = [UIImage imageNamed:image_tabBarActivity];
        item.image = [UIImage imageNamed:image_tabBarActivity];
        
    }
    
    if ([[self getActivePage] isEqualToString:k_pageControlCenterTransfer]) {
        
        self.title = NSLocalizedString(@"_transfers_", nil);
        
        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
        item.selectedImage = [UIImage imageNamed:image_tabBarTransfer];
        item.image = [UIImage imageNamed:image_tabBarTransfer];
    }
}

- (NSString *)getActivePage
{
    CCControlCenterTransfer *vc = [self.pageViewController.viewControllers lastObject];
    
    return vc.pageType;
}

@end
