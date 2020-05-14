//
//  AppDelegate.h
//  Nextcloud
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
#import <AVKit/AVKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <TOPasscodeViewController/TOPasscodeViewController.h>

#import "Reachability.h"
#import "CCUtility.h"
#import "CCMain.h"
#import "CCSettings.h"
#import "CCFavorites.h"
#import "CCTransfers.h"

@class CCMore;
@class NCMedia;
@class NCOffline;
@class NCAppConfigView;
@class IMImagemeterViewer;
@class NCDetailViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>

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

// Networking 
@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)(void);

// UploadFromOtherUpp
@property (nonatomic, strong) NSString *fileNameUpload;

// Passcode lockDirectory
@property (nonatomic, strong) NSDate *sessionePasscodeLock;

// Audio Video
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerViewController *playerController;
@property BOOL isMediaObserver;

// Push Norification Token
@property (nonatomic, strong) NSString *pushKitToken;

// ProgressView Detail
@property (nonatomic, strong) UIProgressView *progressViewDetail;

// Reachability
@property (nonatomic, strong) Reachability *reachability;
@property BOOL lastReachability;

@property (nonatomic, retain) TOPasscodeViewController *passcodeViewController;

@property (nonatomic, strong) CCMain *activeMain;
@property (nonatomic, strong) CCMain *homeMain;
@property (nonatomic, strong) CCFavorites *activeFavorites;
@property (nonatomic, strong) NCMedia *activeMedia;
@property (nonatomic, retain) NCDetailViewController *activeDetail;
@property (nonatomic, retain) CCTransfers *activeTransfers;
@property (nonatomic, retain) CCLogin *activeLogin;
@property (nonatomic, retain) NCLoginWeb *activeLoginWeb;
@property (nonatomic, retain) CCMore *activeMore;
@property (nonatomic, retain) NCOffline *activeOffline;
@property (nonatomic, retain) NCAppConfigView *appConfigView;
@property (nonatomic, retain) IMImagemeterViewer *activeImagemeterView;

@property (nonatomic, strong) NSMutableDictionary *listMainVC;
@property (nonatomic, strong) NSMutableDictionary *listProgressMetadata;

@property (nonatomic, strong) NSMutableArray *arrayDeleteMetadata;
@property (nonatomic, strong) NSMutableArray *arrayMoveMetadata;
@property (nonatomic, strong) NSMutableArray *arrayMoveServerUrlTo;
@property (nonatomic, strong) NSMutableArray *arrayCopyMetadata;
@property (nonatomic, strong) NSMutableArray *arrayCopyServerUrlTo;

@property (nonatomic) UIUserInterfaceStyle preferredUserInterfaceStyle API_AVAILABLE(ios(12.0));

@property (nonatomic, strong) NSMutableArray *sessionPendingStatusInUpload;

// Shares
@property (nonatomic, strong) NSArray *shares;

// Maintenance Mode
@property BOOL maintenanceMode;

// UserDefaults
@property (nonatomic, strong) NSUserDefaults *ncUserDefaults;

// Login
- (void)startTimerErrorNetworking;
- (void)openLoginView:(UIViewController *)viewController selector:(NSInteger)selector openLoginWeb:(BOOL)openLoginWeb;

// Setting Account & Communication
- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activeUserID:(NSString *)activeUserID activePassword:(NSString *)activePassword;
- (void)deleteAccount:(NSString *)account wipe:(BOOL)wipe;
- (void)settingSetupCommunicationCapabilities:(NSString *)account;

// Quick Actions - ShotcutItem
- (void)configDynamicShortcutItems;
- (BOOL)handleShortCutItem:(UIApplicationShortcutItem *)shortcutItem;

// ApplicationIconBadgeNumber
- (void)updateApplicationIconBadgeNumber;

// TabBarController
- (void)createTabBarController:(UITabBarController *)tabBarController;
- (NSString *)getTabBarControllerActiveServerUrl;

// Push Notification
- (void)pushNotification;
- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account url:(NSString *)url withSubscribing:(BOOL)subscribing;

// Theming Color
- (void)settingThemingColorBrand;
- (void)changeTheming:(UIViewController *)viewController tableView:(UITableView *)tableView collectionView:(UICollectionView *)collectionView form:(BOOL)form;

// Task Networking
- (void)loadAutoDownloadUpload;
- (void)startLoadAutoDownloadUpload;

// Maintenance Mode
- (void)maintenanceMode:(BOOL)mode;

@end

