 //
//  CCSplit.m
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/15.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

#import "CCSplit.h"
#import "AppDelegate.h"
#import "CCLogin.h"
#import "NCAutoUpload.h"
#import "NCBridgeSwift.h"

@interface CCSplit ()
{
    AppDelegate *appDelegate;
    BOOL prevRunningInFullScreen;
}
@end

@implementation CCSplit

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        prevRunningInFullScreen = YES;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.delegate = self;
    
    // Display mode SPLIT
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    //self.maximumPrimaryColumnWidth = 400;
    
    // Settings TabBar
    UITabBarController *tabBarController = [self.viewControllers firstObject];
    [appDelegate createTabBarController:tabBarController];
    
    [self inizialize];    
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    // iPhone + (fallthrough res)
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact && [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone && (UIScreen.mainScreen.nativeBounds.size.height == 2208 || UIScreen.mainScreen.nativeBounds.size.height == 1920)) {
    
        // FIX master-detail
        UITabBarController *tbc = self.viewControllers.firstObject;
        for (UINavigationController *nvc in tbc.viewControllers) {
        
            if ([nvc.topViewController isKindOfClass:[CCDetail class]]) {
                [nvc popViewControllerAnimated:NO];
            }
        }
    }
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        if (self.view.frame.size.width == ([[UIScreen mainScreen] bounds].size.width*([[UIScreen mainScreen] bounds].size.width<[[UIScreen mainScreen] bounds].size.height))+([[UIScreen mainScreen] bounds].size.height*([[UIScreen mainScreen] bounds].size.width>[[UIScreen mainScreen] bounds].size.height))) {
            
            // Portrait
            
        } else {
            
            // Landscape
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== inizialization =====
#pragma --------------------------------------------------------------------------------------------

- (void)inizialize
{
    //  setting version
    self.version = [CCUtility setVersion];
    self.build = [CCUtility setBuild];
    
    // init home
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil userInfo:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Split View Controller =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController
{
    return YES;
}

- (UIViewController *)splitViewController:(UISplitViewController *)splitViewController separateSecondaryViewControllerFromPrimaryViewController:(UIViewController *)primaryViewController
{
    if ([primaryViewController isKindOfClass:[UINavigationController class]]) {
        for (UIViewController *controller in [(UINavigationController *)primaryViewController viewControllers]) {
            if ([controller isKindOfClass:[UINavigationController class]] && [[(UINavigationController *)controller visibleViewController] isKindOfClass:[CCDetail class]]) {
                return controller;
            }
        }
    }
    
    // No detail view present
    UINavigationController *secondaryNC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCDetailNC"];
    
    // Ensure back button is enabled
    UIViewController *detailViewController = [secondaryNC visibleViewController];
    
    detailViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    detailViewController.navigationItem.leftItemsSupplementBackButton = YES;
    
    return secondaryNC;
}

- (UIViewController *)primaryViewControllerForExpandingSplitViewController:(UISplitViewController *)splitViewController
{
    UITabBarController *tbMaster = splitViewController.viewControllers[0];
    UINavigationController *ncMaster = [tbMaster selectedViewController];
    
    //UIViewController *main = [ncMaster.viewControllers firstObject];
    UIViewController *detail = [ncMaster.viewControllers lastObject];
    
    if ([detail isKindOfClass:[CCDetail class]]) {
        
        [ncMaster popViewControllerAnimated:NO];
    }
    
    return nil;
}

// sender = CCMain
// vc = UINavigationController detail
- (void)showDetailViewController:(UIViewController *)vc sender:(id)sender
{
    UINavigationController *ncDetail = (UINavigationController *)vc;
    UINavigationController *ncMaster = [self.viewControllers.firstObject selectedViewController];

    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        
        if ([self.viewControllers.firstObject isKindOfClass:[UITabBarController class]]) {
                        
            // Fix : Application tried to present modally an active controller
            if ([ncMaster isBeingPresented]) {
                // being presented
            } else if ([ncMaster isMovingToParentViewController]) {
                // being pushed
            } else {
                [ncMaster pushViewController:ncDetail.topViewController animated:YES];
            }

            return;
        }
    }
    
    [super showDetailViewController:vc sender:sender];
    
    // display icon "<>"
    ncDetail.topViewController.navigationItem.leftBarButtonItem = self.displayModeButtonItem;
}

// OK
- (void)splitViewController:(UISplitViewController *)svc willChangeToDisplayMode:(UISplitViewControllerDisplayMode)displayMode
{
    UIViewController *viewController = [svc.viewControllers lastObject];
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController *navigationController = (UINavigationController *)viewController;
        
        UIViewController *detail = [navigationController.viewControllers firstObject];
        
        if ([detail isKindOfClass:[CCDetail class]]) {
            
            [(CCDetail *)detail performSelector:@selector(changeToDisplayMode) withObject:nil afterDelay:0.05];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Slide Over - Split View =====
#pragma --------------------------------------------------------------------------------------------

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    // simply create a property of 'BOOL' type
    BOOL isRunningInFullScreen = CGRectEqualToRect([UIApplication sharedApplication].delegate.window.frame, [UIApplication sharedApplication].delegate.window.screen.bounds);
    
    // detect Dark Mode
    if (@available(iOS 13.0, *)) {
        if ([CCUtility getDarkModeDetect]) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                [CCUtility setDarkMode:YES];
            } else {
                [CCUtility setDarkMode:NO];
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"changeTheming" object:nil];
    }
    
    prevRunningInFullScreen = isRunningInFullScreen;
    
    if (prevRunningInFullScreen == NO) {
        
        // FIX master-detail
        UITabBarController *tbc = self.viewControllers.firstObject;
        for (UINavigationController *nvc in tbc.viewControllers) {
            
            if ([nvc.topViewController isKindOfClass:[CCDetail class]]) {
                [nvc popViewControllerAnimated:NO];
            }
        }
    }
}

@end
