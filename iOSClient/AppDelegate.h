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
#import <AVKit/AVKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <TOPasscodeViewController/TOPasscodeViewController.h>
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

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)(void);

// Parameter account
@property (nonatomic, strong) NSString *account;
@property (nonatomic, strong) NSString *urlBase;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *password;

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

@property (nonatomic, strong) NSTimer *timerErrorNetworking;
@property (nonatomic, strong) NCDocumentPickerViewController *documentPickerViewController;
@property (nonatomic) UIUserInterfaceStyle preferredUserInterfaceStyle API_AVAILABLE(ios(12.0));
@property (nonatomic, strong) NSArray *shares;
@property BOOL disableSharesView;
@property (nonatomic, strong) NSUserDefaults *ncUserDefaults;
@property (nonatomic, strong) NCNetworkingAutoUpload *networkingAutoUpload;
@property (nonatomic, retain) TOPasscodeViewController *passcodeViewController;

@property (nonatomic, strong) NSMutableArray *pasteboardOcIds;

// Login
- (void)startTimerErrorNetworking;
- (void)openLoginView:(UIViewController *)viewController selector:(NSInteger)selector openLoginWeb:(BOOL)openLoginWeb;

// Setting Account & Communication
- (void)settingAccount:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user userID:(NSString *)userID password:(NSString *)password;
- (void)deleteAccount:(NSString *)account wipe:(BOOL)wipe;

@end

