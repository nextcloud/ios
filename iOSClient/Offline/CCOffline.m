//
//  CCOffline.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 16/01/17.
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

#import "CCOffline.h"
#import "AppDelegate.h"
#import "CCSynchronize.h"

#ifdef CUSTOM_BUILD
    #import "NextcloudCustom-Swift.h"
#else
    #import "Nextcloud-Swift.h"
#endif

#pragma GCC diagnostic ignored "-Wundeclared-selector"

@interface CCOffline ()
{
    UIPageControl *pageControl;
}

@end

@implementation CCOffline

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        app.activeOffline = self;
    }
    return self;
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Create data model
    _pageType = @[k_pageOfflineFavorites, k_pageOfflineOffline, k_pageOfflineLocal];
    _currentPageType = k_pageOfflineFavorites;
    self.title = NSLocalizedString(@"_favorites_", nil);
    
    // Create page view controller
    self.pageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"OfflinePageViewController"];
    self.pageViewController.dataSource = self;
    self.pageViewController.delegate = self;
    
    CCOfflinePageContent *startingViewController = [self viewControllerAtIndex:0];
    NSArray *viewControllers = @[startingViewController];
    [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];

    // Change the size of page view controller
    self.pageViewController.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    
    [self addChildViewController:_pageViewController];
    [self.view addSubview:_pageViewController.view];
    [self.pageViewController didMoveToParentViewController:self];
    
    // Enable swipe gesture only for page controller
    for (UIScrollView *view in self.pageViewController.view.subviews) {
        if ([view isKindOfClass:[UIScrollView class]]) {
            view.scrollEnabled = NO;
        }
    }
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [app plusButtonVisibile:true];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Page  =====
#pragma --------------------------------------------------------------------------------------------

- (CCOfflinePageContent *)viewControllerAtIndex:(NSUInteger)index
{
    if (([self.pageType count] == 0) || (index >= [self.pageType count])) {
        return nil;
    }
    
    // Create a new view controller and pass suitable data.
    CCOfflinePageContent *pageContentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"OfflinePageContentViewController"];
    
    pageContentViewController.pageIndex = index;
    pageContentViewController.pageType = self.pageType[index];
    
    return pageContentViewController;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSUInteger index = ((CCOfflinePageContent*) viewController).pageIndex;
    
    if ((index == 0) || (index == NSNotFound)) {
        return nil;
    }
    
    index--;
    return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSUInteger index = ((CCOfflinePageContent*) viewController).pageIndex;
    
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

/*
- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers
{
}
*/

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    CCOfflinePageContent *vc = [self.pageViewController.viewControllers lastObject];
    
    NSString *serverUrl = vc.serverUrl;
    _currentPageType = vc.pageType;

    if ([_currentPageType isEqualToString:k_pageOfflineFavorites]) {
        if (serverUrl)
            self.title = NSLocalizedString(@"_favorites_", nil);
        else
            self.title = NSLocalizedString(@"_favorites_", nil);
        
        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexOffline];
        item.selectedImage = [UIImage imageNamed:image_tabBarFavorite];
        item.image = [UIImage imageNamed:image_tabBarFavorite];
    }

    if ([_currentPageType isEqualToString:k_pageOfflineOffline]) {
        if (serverUrl)
            self.title = NSLocalizedString(@"_offline_", nil);
        else
            self.title = NSLocalizedString(@"_offline_", nil);
        
        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexOffline];
        item.selectedImage = [UIImage imageNamed:image_tabBarOffline];
        item.image = [UIImage imageNamed:image_tabBarOffline];
    }
    
    if ([_currentPageType isEqualToString:k_pageOfflineLocal]) {
        if ([serverUrl isEqualToString:[CCUtility getDirectoryLocal]])
            self.title = NSLocalizedString(@"_local_storage_", nil);
        else
            self.title = NSLocalizedString(@"_local_storage_", nil);
        
        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexOffline];
        item.selectedImage = [UIImage imageNamed:image_tabBarLocal];
        item.image = [UIImage imageNamed:image_tabBarLocal];
    }
}

@end
