//
//  AppDelegate.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <MagicalRecord/MagicalRecord.h>
#import <UserNotifications/UserNotifications.h>

#import "BKPasscodeLockScreenManager.h"
#import "REMenu.h"
#import "LMMediaPlayerView.h"
#import "Reachability.h"
#import "TWMessageBarManager.h"
#import "CCBKPasscode.h"
#import "CCUtility.h"
#import "CCActivity.h"
#import "CCDetail.h"
#import "CCQuickActions.h"
#import "CCMain.h"
#import "CCPhotosCameraUpload.h"
#import "CCSettings.h"
#import "CCTransfers.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, BKPasscodeLockScreenManagerDelegate, BKPasscodeViewControllerDelegate, LMMediaPlayerViewDelegate, TWMessageBarStyleSheet, CCNetworkingDelegate>

// Timer 5 sec.
@property (nonatomic, strong) NSTimer *timerVerifyProcess;

// For LMMediaPlayerView
@property (strong, nonatomic) UIWindow *window;

// User
@property (nonatomic, strong) NSString *activeAccount;
@property (nonatomic, strong) NSString *activeUrl;
@property (nonatomic, strong) NSString *activeUser;
@property (nonatomic, strong) NSString *activePassword;
@property (nonatomic, strong) NSString *directoryUser;

// next version ... ? ...
@property double currentLatitude;
@property double currentLongitude;

// ownCloud & Nextcloud
@property BOOL hasServerForbiddenCharactersSupport;
@property BOOL hasServerShareSupport;
@property BOOL hasServerShareeSupport;
@property BOOL hasServerCapabilitiesSupport;
@property OCCapabilities *capabilities;
@property (nonatomic, strong) NSMutableArray<OCCommunication *> *listOfNotifications;
@property NSInteger serverVersion;

// Network Operation
@property (nonatomic, strong) NSOperationQueue *netQueue;

@property (nonatomic, strong) NSOperationQueue *netQueueDownload;
@property (nonatomic, strong) NSOperationQueue *netQueueDownloadWWan;
@property (nonatomic, strong) NSOperationQueue *netQueueUpload;
@property (nonatomic, strong) NSOperationQueue *netQueueUploadWWan;

@property NSUInteger queueNunDownload, queueNumDownloadWWan, queueNumUpload, queueNumUploadWWan;

// Networking 
@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)(void);
@property (nonatomic, strong) NSDate *sessionDateLastUploadTasks;
@property (nonatomic, strong) NSDate *sessionDateLastDownloadTasks;
@property (nonatomic, strong) NSTimer *timerVerifySessionInProgress;

// Network Share
@property (nonatomic, strong) NSMutableDictionary *sharesID;
@property (nonatomic, strong) NSMutableDictionary *sharesLink;
@property (nonatomic, strong) NSMutableDictionary *sharesUserAndGroup;

// UploadFromOtherUpp
@property (nonatomic, strong) NSString *fileNameUpload;

// Passcode lockDirectory
@property (nonatomic, strong) NSDate *sessionePasscodeLock;

// Remenu
@property (nonatomic, strong) REMenu *reMainMenu;
@property (nonatomic, strong) REMenuItem *selezionaItem;
@property (nonatomic, strong) REMenuItem *directoryOnTopItem;
@property (nonatomic, strong) REMenuItem *ordinaItem;
@property (nonatomic, strong) REMenuItem *ascendenteItem;
@property (nonatomic, strong) REMenuItem *alphabeticItem;
@property (nonatomic, strong) REMenuItem *typefileItem;
@property (nonatomic, strong) REMenuItem *dateItem;

@property (nonatomic, strong) REMenu *reSelectMenu;
@property (nonatomic, strong) REMenuItem *deleteItem;
@property (nonatomic, strong) REMenuItem *moveItem;
@property (nonatomic, strong) REMenuItem *encryptItem;
@property (nonatomic, strong) REMenuItem *decryptItem;
@property (nonatomic, strong) REMenuItem *downloadItem;
@property (nonatomic, strong) REMenuItem *saveItem;

// List Change Task
@property (nonatomic, retain) NSMutableDictionary *listChangeTask;

// Player Audio
@property (nonatomic, strong) LMMediaPlayerView *player;

// Reachability
@property (nonatomic, strong) Reachability *reachability;
@property BOOL lastReachability;

@property (nonatomic, strong) CCMain *activeMain;
@property (nonatomic, strong) CCMain *homeMain;
@property (nonatomic, strong) CCPhotosCameraUpload *activePhotosCameraUpload;
@property (nonatomic, retain) CCDetail *activeDetail;
@property (nonatomic, retain) CCSettings *activeSettings;
@property (nonatomic, retain) CCActivity *activeActivity;
@property (nonatomic, retain) CCTransfers *activeTransfers;

@property (nonatomic, strong) NSMutableDictionary *listMainVC;
@property (nonatomic, strong) NSMutableDictionary *listProgressMetadata;

// ico Image Cache
@property (nonatomic, strong) NSMutableDictionary *icoImagesCache;

// Is in Crypto Mode
@property BOOL isCryptoCloudMode;

// Setting Active Account
- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activePassword:(NSString *)activePassword;

// initializations 
- (void)applicationInitialized;

- (void)configDynamicShortcutItems;

- (void)messageNotification:(NSString *)title description:(NSString *)description visible:(BOOL)visible delay:(NSTimeInterval)delay type:(TWMessageBarMessageType)type;
- (void)updateApplicationIconBadgeNumber;
- (BOOL)handleShortCutItem:(UIApplicationShortcutItem *)shortcutItem;

- (void)plusButtonVisibile:(BOOL)visible;

// Operation Networking
- (void)cancelAllOperations;
- (void)addNetworkingOperationQueue:(NSOperationQueue *)netQueue delegate:(id)delegate metadataNet:(CCMetadataNet *)metadataNet;

- (NSMutableArray *)verifyExistsInQueuesDownloadSelector:(NSString *)selector;
- (NSMutableArray *)verifyExistsInQueuesUploadSelector:(NSString *)selector;

- (void)loadAutomaticUploadForSelector:(NSString *)selector;
- (BOOL)createFolderSubFolderAutomaticUploadFolderPhotos:(NSString *)folderPhotos useSubFolder:(BOOL)useSubFolder assets:(NSArray *)assets selector:(NSString *)selector;
- (void)dropAutomaticUploadWithSelector:(NSString *)selector;

@end

