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
#import "CCLogin.h"

@class NCFiles;
@class NCFileViewInFolder;
@class NCRecent;
@class NCMore;
@class NCMedia;
@class NCOffline;
@class NCTransfers;
@class NCFavorite;
@class NCShares;
@class NCTrash;
@class NCAppConfigView;
@class IMImagemeterViewer;
@class NCNetworkingAutoUpload;
@class NCDocumentPickerViewController;
@class FileProviderDomain;
@class NCViewerVideo;

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

// Networking 
@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)(void);

// UploadFromOtherUpp
@property (nonatomic, strong) NSString *fileNameUpload;

// Passcode lockDirectory
@property (nonatomic, strong) NSDate *sessionePasscodeLock;

// Push Norification Token
@property (nonatomic, strong) NSString *pushKitToken;

@property (nonatomic, retain) TOPasscodeViewController *passcodeViewController;

@property (nonatomic, retain) NSString *activeServerUrl;
@property (nonatomic, retain) UIViewController *activeViewController;

@property (nonatomic, retain) NCFiles *activeFiles;
@property (nonatomic, retain) NCFileViewInFolder *activeFileViewInFolder;
@property (nonatomic, retain) NCFavorite *activeFavorite;
@property (nonatomic, retain) NCRecent *activeRecent;
@property (nonatomic, retain) NCShares *activeShares;
@property (nonatomic, retain) NCMedia *activeMedia;
@property (nonatomic, retain) NCTransfers *activeTransfers;
@property (nonatomic, retain) CCLogin *activeLogin;
@property (nonatomic, retain) NCLoginWeb *activeLoginWeb;
@property (nonatomic, retain) NCMore *activeMore;
@property (nonatomic, retain) NCOffline *activeOffline;
@property (nonatomic, retain) NCTrash *activeTrash;
@property (nonatomic, retain) NCAppConfigView *appConfigView;
@property (nonatomic, retain) IMImagemeterViewer *activeImagemeterView;
@property (nonatomic, retain) NCViewerVideo *activeViewerVideo;

@property (nonatomic, strong) NSMutableDictionary *listFilesVC;
@property (nonatomic, strong) NSMutableDictionary *listFavoriteVC;
@property (nonatomic, strong) NSMutableDictionary *listOfflineVC;
@property (nonatomic, strong) NSMutableDictionary *listProgressMetadata;

@property (nonatomic) UIUserInterfaceStyle preferredUserInterfaceStyle API_AVAILABLE(ios(12.0));

// Shares
@property (nonatomic, strong) NSArray *shares;

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

// Push Notification
- (void)pushNotification;

@end

