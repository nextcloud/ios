//
//  AppDelegate.h
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
//  Copyright (c) 2014 Marino Faggiana. All rights reserved.
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

#import "CCUtility.h"
#import "CCMain.h"
#import "CCSettings.h"

@class CCMore;
@class NCMedia;
@class NCOffline;
@class NCTransfers;
@class NCFavorite;
@class NCTrash;
@class NCAppConfigView;
@class IMImagemeterViewer;
@class NCDetailViewController;
@class NCNetworkingAutoUpload;
@class NCDocumentPickerViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>

// Timer Process
@property (nonatomic, strong) NSTimer *timerUpdateApplicationIconBadgeNumber;
@property (nonatomic, strong) NSTimer *timerErrorNetworking;

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NCDocumentPickerViewController *documentPickerViewController;

// Parameter account
@property (nonatomic, strong) NSString *account;
@property (nonatomic, strong) NSString *urlBase;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *password;

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

@property (nonatomic, retain) TOPasscodeViewController *passcodeViewController;

@property (nonatomic, retain) NSString *activeServerUrl;
@property (nonatomic, retain) id activeViewController;

@property (nonatomic, retain) CCMain *activeMain;
@property (nonatomic, retain) CCMain *homeMain;
@property (nonatomic, retain) NCFavorite *activeFavorite;
@property (nonatomic, retain) NCMedia *activeMedia;
@property (nonatomic, retain) NCDetailViewController *activeDetail;
@property (nonatomic, retain) NCTransfers *activeTransfers;
@property (nonatomic, retain) CCLogin *activeLogin;
@property (nonatomic, retain) NCLoginWeb *activeLoginWeb;
@property (nonatomic, retain) CCMore *activeMore;
@property (nonatomic, retain) NCOffline *activeOffline;
@property (nonatomic, retain) NCTrash *activeTrash;
@property (nonatomic, retain) NCAppConfigView *appConfigView;
@property (nonatomic, retain) IMImagemeterViewer *activeImagemeterView;

@property (nonatomic, strong) NSMutableDictionary *listMainVC;
@property (nonatomic, strong) NSMutableDictionary *listFavoriteVC;
@property (nonatomic, strong) NSMutableDictionary *listOfflineVC;

@property (nonatomic, strong) NSMutableDictionary *listProgressMetadata;

@property (nonatomic) UIUserInterfaceStyle preferredUserInterfaceStyle API_AVAILABLE(ios(12.0));

// Shares
@property (nonatomic, strong) NSArray *shares;

// Maintenance Mode
@property BOOL maintenanceMode;

// UserDefaults
@property (nonatomic, strong) NSUserDefaults *ncUserDefaults;

// Network Auto Upload
@property (nonatomic, strong) NCNetworkingAutoUpload *networkingAutoUpload;

// Login
- (void)startTimerErrorNetworking;
- (void)openLoginView:(UIViewController *)viewController selector:(NSInteger)selector openLoginWeb:(BOOL)openLoginWeb;

// Setting Account & Communication
- (void)settingAccount:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user userID:(NSString *)userID password:(NSString *)password;
- (void)deleteAccount:(NSString *)account wipe:(BOOL)wipe;
- (void)settingSetupCommunication:(NSString *)account;

// Quick Actions - ShotcutItem
- (void)configDynamicShortcutItems;
- (BOOL)handleShortCutItem:(UIApplicationShortcutItem *)shortcutItem;

// TabBarController
- (void)createTabBarController:(UITabBarController *)tabBarController;

// Push Notification
- (void)pushNotification;

// Theming Color
- (void)settingThemingColorBrand;
- (void)changeTheming:(UIViewController *)viewController tableView:(UITableView *)tableView collectionView:(UICollectionView *)collectionView form:(BOOL)form;

// Maintenance Mode
- (void)maintenanceMode:(BOOL)mode;

@end

