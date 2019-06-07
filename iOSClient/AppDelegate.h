//
//  AppDelegate.h
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 04/09/14.
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

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <PushKit/PushKit.h>

#import "BKPasscodeLockScreenManager.h"
#import "REMenu.h"
#import "Reachability.h"
#import "TWMessageBarManager.h"
#import "CCBKPasscode.h"
#import "CCUtility.h"
#import "CCDetail.h"
#import "CCMain.h"
#import "CCSettings.h"
#import "CCFavorites.h"
#import "CCTransfers.h"

@class CCLoginWeb;
@class CCMore;
@class NCMedia;

@interface AppDelegate : UIResponder <UIApplicationDelegate, BKPasscodeLockScreenManagerDelegate, BKPasscodeViewControllerDelegate, TWMessageBarStyleSheet, CCNetworkingDelegate, PKPushRegistryDelegate>

// Timer Process
@property (nonatomic, strong) NSTimer *timerProcessAutoDownloadUpload;
@property (nonatomic, strong) NSTimer *timerUpdateApplicationIconBadgeNumber;
@property (nonatomic, strong) NSTimer *timerErrorNetworking;

// For LMMediaPlayerView
@property (strong, nonatomic) UIWindow *window;

// User
@property (nonatomic, strong) NSString *activeAccount;
@property (nonatomic, strong) NSString *activeUrl;
@property (nonatomic, strong) NSString *activeUser;
@property (nonatomic, strong) NSString *activeUserID;
@property (nonatomic, strong) NSString *activePassword;
@property (nonatomic, strong) NSString *activeEmail;

// next version ... ? ...
@property double currentLatitude;
@property double currentLongitude;

// Notification
@property (nonatomic, strong) NSMutableArray<OCCommunication *> *listOfNotifications;

// Networking 
@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)(void);

// Network Share
@property (nonatomic, strong) NSMutableDictionary *sharesID;
@property (nonatomic, strong) NSMutableDictionary *sharesLink;
@property (nonatomic, strong) NSMutableDictionary *sharesUserAndGroup;

// UploadFromOtherUpp
@property (nonatomic, strong) NSString *fileNameUpload;

// Passcode lockDirectory
@property (nonatomic, strong) NSDate *sessionePasscodeLock;

// Audio Video
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerViewController *playerController;

// Push Norification Token
@property (nonatomic, strong) NSString *pushKitToken;

// Remenu
@property (nonatomic, strong) REMenu *reMainMenu;
@property (nonatomic, strong) REMenuItem *selezionaItem;
@property (nonatomic, strong) REMenuItem *sortFileNameAZItem;
@property (nonatomic, strong) REMenuItem *sortFileNameZAItem;
@property (nonatomic, strong) REMenuItem *sortDateMoreRecentItem;
@property (nonatomic, strong) REMenuItem *sortDateLessRecentItem;
@property (nonatomic, strong) REMenuItem *sortSmallestItem;
@property (nonatomic, strong) REMenuItem *sortLargestItem;
@property (nonatomic, strong) REMenuItem *alphabeticItem;
@property (nonatomic, strong) REMenuItem *typefileItem;
@property (nonatomic, strong) REMenuItem *dateItem;
@property (nonatomic, strong) REMenuItem *directoryOnTopItem;

@property (nonatomic, strong) REMenu *reSelectMenu;
@property (nonatomic, strong) REMenuItem *selectAllItem;
@property (nonatomic, strong) REMenuItem *deleteItem;
@property (nonatomic, strong) REMenuItem *moveItem;
@property (nonatomic, strong) REMenuItem *encryptItem;
@property (nonatomic, strong) REMenuItem *decryptItem;
@property (nonatomic, strong) REMenuItem *downloadItem;
@property (nonatomic, strong) REMenuItem *saveItem;

// Reachability
@property (nonatomic, strong) Reachability *reachability;
@property BOOL lastReachability;

@property (nonatomic, strong) CCMain *activeMain;
@property (nonatomic, strong) CCMain *homeMain;
@property (nonatomic, strong) CCFavorites *activeFavorites;
@property (nonatomic, strong) NCMedia *activeMedia;
@property (nonatomic, retain) CCDetail *activeDetail;
@property (nonatomic, retain) CCSettings *activeSettings;
@property (nonatomic, retain) CCTransfers *activeTransfers;
@property (nonatomic, retain) CCLogin *activeLogin;
@property (nonatomic, retain) CCLoginWeb *activeLoginWeb;
@property (nonatomic, retain) CCMore *activeMore;

@property (nonatomic, strong) NSMutableDictionary *listMainVC;
@property (nonatomic, strong) NSMutableDictionary *listProgressMetadata;

@property (nonatomic, strong) NSMutableArray *filterFileID;

@property (nonatomic, strong) NSMutableArray *sessionPendingStatusInUpload;

// Maintenance Mode
@property BOOL maintenanceMode;

// UserDefaults
@property (nonatomic, strong) NSUserDefaults *ncUserDefaults;

// Timer Error Networking
- (void)startTimerErrorNetworking;

// Login View
- (void)openLoginView:(UIViewController *)viewController delegate:(id)delegate loginType:(NSInteger)loginType selector:(NSInteger)selector;

// Setting Active Account
- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activeUserID:(NSString *)activeUserID activePassword:(NSString *)activePassword;

// Quick Actions - ShotcutItem
- (void)configDynamicShortcutItems;
- (BOOL)handleShortCutItem:(UIApplicationShortcutItem *)shortcutItem;

// StatusBar & ApplicationIconBadgeNumber
- (void)messageNotification:(NSString *)title description:(NSString *)description visible:(BOOL)visible delay:(NSTimeInterval)delay type:(TWMessageBarMessageType)type errorCode:(NSInteger)errorcode;
- (void)updateApplicationIconBadgeNumber;

// TabBarController
- (void)createTabBarController:(UITabBarController *)tabBarController;
- (void)aspectNavigationControllerBar:(UINavigationBar *)nav online:(BOOL)online hidden:(BOOL)hidden;
- (void)aspectTabBar:(UITabBar *)tab hidden:(BOOL)hidden;
- (void)plusButtonVisibile:(BOOL)visible;
- (void)selectedTabBarController:(NSInteger)index;
- (NSString *)getTabBarControllerActiveServerUrl;

// Push Notification
- (void)pushNotification;
- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account url:(NSString *)url withSubscribing:(BOOL)subscribing;

// Theming Color
- (void)settingThemingColorBrand;
- (void)changeTheming:(UIViewController *)vc;

// Task Networking
- (void)loadAutoDownloadUpload;
- (void)startLoadAutoDownloadUpload;

// Maintenance Mode
- (void)maintenanceMode:(BOOL)mode;

@end

