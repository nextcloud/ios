//
//  BKPasscodeLockScreenManager.h
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 8. 2..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BKPasscodeViewController.h"
#import "BKPasscodeDummyViewController.h"

@protocol BKPasscodeLockScreenManagerDelegate;


@interface BKPasscodeLockScreenManager : NSObject <BKPasscodeDummyViewControllerDelegate>

@property (weak, nonatomic) id<BKPasscodeLockScreenManagerDelegate> delegate;

/**
 * Shared(singleton) instance.
 */
+ (BKPasscodeLockScreenManager *)sharedManager;

/**
 * Shows lock screen. You should call this method at applicationDidEnterBackground: in app delegate.
 */
- (void)showLockScreen:(BOOL)animated;

@end


@protocol BKPasscodeLockScreenManagerDelegate <NSObject>

/**
 * Ask the delegate a view controller that should be displayed as lock screen.
 */
- (UIViewController *)lockScreenManagerPasscodeViewController:(BKPasscodeLockScreenManager *)aManager;

@optional
/**
 * Ask the delegate that lock screen should be displayed or not.
 * If you prevent displaying lock screen, return NO.
 * If delegate does not implement this method, the lock screen will be shown everytime when application did enter background.
 */
- (BOOL)lockScreenManagerShouldShowLockScreen:(BKPasscodeLockScreenManager *)aManager;

/**
 * Ask the delegate for the view that will be used as snapshot.
 */
- (UIView *)lockScreenManagerBlindView:(BKPasscodeLockScreenManager *)aManager;

@end