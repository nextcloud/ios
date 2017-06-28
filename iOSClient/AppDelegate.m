//
//  AppDelegate.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
//  Copyright (c) 2017 TWS. All rights reserved.
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

#import "AppDelegate.h"

#import <MagicalRecord/MagicalRecord.h>
#import "CCCoreData.h"
#import "iRate.h"
#import "AFURLSessionManager.h"
#import "CCNetworking.h"
#import "CCCrypto.h"
#import "CCGraphics.h"
#import "CCPhotos.h"
#import "CCSynchronize.h"
#import "CCMain.h"
#import "CCDetail.h"
#import "Firebase.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "JDStatusBarNotification.h"
#import "NCBridgeSwift.h"
#import "NCAutoUpload.h"

@interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
{
    
}
@end

@implementation AppDelegate

+ (void)initialize
{
    [iRate sharedInstance].daysUntilPrompt = 10;
    [iRate sharedInstance].usesUntilPrompt = 10;
    [iRate sharedInstance].promptForNewVersionIfUserRated = true;
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UserAgent": [CCUtility getUserAgent]}];

    //enable preview mode
    //[iRate sharedInstance].previewMode = YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Brand
    if ([NCBrandOptions sharedInstance].use_firebase) {
    
        /*
         In order for this to work, proper GoogleService-Info.plist must be included
         */
    
        @try {
            [FIRApp configure];
        } @catch (NSException *exception) {
            NSLog(@"[LOG] Something went wrong while configuring Firebase");
        }
    
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        
            UIUserNotificationType allNotificationTypes =(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        
        } else {
        
            // iOS 10 or later
            #if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
            // For iOS 10 display notification (sent via APNS)
            [UNUserNotificationCenter currentNotificationCenter].delegate = self;
            UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
            [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
            }];
        
            // For iOS 10 data message (sent via FCM)
            [FIRMessaging messaging].remoteMessageDelegate = self;
            #endif
        }
    }

    NSString *dir;
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions sharedInstance].capabilitiesGroups];
    
    NSLog(@"[LOG] Start program group -----------------");
    NSLog(@"%@", dirGroup);    
    NSLog(@"[LOG] Start program application -----------");
    NSLog(@"%@", [[CCUtility getDirectoryLocal] stringByDeletingLastPathComponent]);
    NSLog(@"[LOG] -------------------------------------");

    // create Directory local => Documents
    dir = [CCUtility getDirectoryLocal];
    if (![[NSFileManager defaultManager] fileExistsAtPath: dir] && [dir length])
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory audio => Library, Application Support, audio
    dir = [CCUtility getDirectoryAudio];
    if (![[NSFileManager defaultManager] fileExistsAtPath: dir] && [dir length])
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

    // create Crypto Cloud in Group => Library, Application Support, Crypto Cloud
    dir = [[dirGroup URLByAppendingPathComponent:appDatabase] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir])
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create dir Database Nextcloud
    dir = [[dirGroup URLByAppendingPathComponent:appDatabaseNextcloud] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir])
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

    NSError *error = nil;
    [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionNone} ofItemAtPath:dir error:&error];
    
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:(id)[dirGroup URLByAppendingPathComponent:[appDatabase stringByAppendingPathComponent:@"cryptocloud"]]];
    
#ifdef DEBUG
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelWarn];
#else
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelOff];
#endif
    
    // Verify upgrade
    if ([self upgrade]) {
    
        // Set account, if no exists clear all
        tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    
        if (account == nil) {
        
            // remove all the keys Chain
            [CCUtility deleteAllChainStore];
    
            // remove all the App group key
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];

        } else {
        
            [self settingActiveAccount:account.account activeUrl:account.url activeUser:account.user activePassword:account.password];
        }
    }
    
    // Operation Queue OC Networking
    _netQueue = [[NSOperationQueue alloc] init];
    _netQueue.name = k_queue;
    _netQueue.maxConcurrentOperationCount = k_maxConcurrentOperation;
   
    _netQueueDownload = [[NSOperationQueue alloc] init];
    _netQueueDownload.name = k_download_queue;
    _netQueueDownload.maxConcurrentOperationCount = k_maxConcurrentOperationDownloadUpload;

    _netQueueDownloadWWan = [[NSOperationQueue alloc] init];
    _netQueueDownloadWWan.name = k_download_queuewwan;
    _netQueueDownloadWWan.maxConcurrentOperationCount = k_maxConcurrentOperationDownloadUpload;
    
    _netQueueUpload = [[NSOperationQueue alloc] init];
    _netQueueUpload.name = k_upload_queue;
    _netQueueUpload.maxConcurrentOperationCount = k_maxConcurrentOperationDownloadUpload;
    
    _netQueueUploadWWan = [[NSOperationQueue alloc] init];
    _netQueueUploadWWan.name = k_upload_queuewwan;
    _netQueueUploadWWan.maxConcurrentOperationCount = k_maxConcurrentOperationDownloadUpload;
    
    // Add notification change session
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionChanged:) name:k_networkingSessionNotification object:nil];
        
    // Initialization Share
    self.sharesID = [NSMutableDictionary new];
    self.sharesLink = [NSMutableDictionary new];
    self.sharesUserAndGroup = [NSMutableDictionary new];
    
    // Initialization Notification
    self.listOfNotifications = [NSMutableArray new];
    
    // Background Fetch
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    // Initialization List
    self.listProgressMetadata = [[NSMutableDictionary alloc] init];
    self.listChangeTask = [[NSMutableDictionary alloc] init];
    self.listMainVC = [[NSMutableDictionary alloc] init];
    
    // Player audio
    self.player = [LMMediaPlayerView sharedPlayerView];
    self.player.delegate = self;
        
    // ico Image Cache
    self.icoImagesCache = [[NSMutableDictionary alloc] init];
    
    // setting Reachable in back
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        self.reachability = [Reachability reachabilityForInternetConnection];
    
        self.lastReachability = [self.reachability isReachable];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
        [self.reachability startNotifier];
    });
    
    //AV Session
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:nil];
    //[[AVAudioSession sharedInstance] setActive:YES error:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    //UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];

    navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    [app aspectNavigationControllerBar:navigationController.navigationBar encrypted:NO online:YES hidden:NO];
    
    // Settings TabBar
    [self createTabBarController];
    
    // passcode
    [[BKPasscodeLockScreenManager sharedManager] setDelegate:self];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[BKPasscodeLockScreenManager sharedManager] showLockScreen:NO];
    });
    
    // Quick Actions
    if([[UIApplicationShortcutItem class] respondsToSelector:@selector(new)]) {
    
        [self configDynamicShortcutItems];
        
        UIApplicationShortcutItem *shortcutItem = [launchOptions objectForKeyedSubscript:UIApplicationLaunchOptionsShortcutItemKey];
        
        if (shortcutItem)
            [self handleShortCutItem:shortcutItem];
    }
    
    // Start Timer
    self.timerProcessAutoUpload = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(processAutoUpload) userInfo:nil repeats:YES];
    self.timerVerifySessionInProgress = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(verifyDownloadUploadInProgress) userInfo:nil repeats:YES];
    self.timerUpdateApplicationIconBadgeNumber = [NSTimer scheduledTimerWithTimeInterval:k_timerUpdateApplicationIconBadgeNumber target:self selector:@selector(updateApplicationIconBadgeNumber) userInfo:nil repeats:YES];

    // Registration Push Notification
    UIUserNotificationType types = UIUserNotificationTypeSound | UIUserNotificationTypeBadge | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [application registerUserNotificationSettings:notificationSettings];
    
    // Fabric
    [Fabric with:@[[Crashlytics class]]];
    [self logUser];
        
    return YES;
}

//
// L' applicazione si dimetterà dallo stato di attivo
//
- (void)applicationWillResignActive:(UIApplication *)application
{
    [_activeMain closeAllMenu];
    
    [self updateApplicationIconBadgeNumber];
}

//
// L' applicazione entrerà in primo piano (attivo solo dopo il background)
//
- (void)applicationWillEnterForeground:(UIApplication *)application
{    
    // facciamo partire il timer per il controllo delle sessioni e dei Lock
    [self.timerVerifySessionInProgress invalidate];
    self.timerVerifySessionInProgress = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(verifyDownloadUploadInProgress) userInfo:nil repeats:YES];
    
    // refresh active Main
    if (_activeMain) {
        [_activeMain reloadDatasource];
        [_activeMain readFileReloadFolder];
    }
    
    // Initializations
    [self applicationInitialized];
}

//
// L' applicazione è entrata nello sfondo
//
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"[LOG] Enter in Background");

    [[CCQuickActions quickActionsManager] closeAll];
    
    [[BKPasscodeLockScreenManager sharedManager] showLockScreen:YES];
    
    if([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]) {
        
        __block UIBackgroundTaskIdentifier background_task;
        
        background_task = [application beginBackgroundTaskWithExpirationHandler:^ {
            
            //Clean up code. Tell the system that we are done.
            [application endBackgroundTask: background_task];
            background_task = UIBackgroundTaskInvalid;
        }];
    }
}

//
// L'applicazione terminerà
//
- (void)applicationWillTerminate:(UIApplication *)application
{    
    [MagicalRecord cleanUp];

    NSLog(@"[LOG] bye bye, Crypto Cloud !");
}

//
// Application Initialized
//
- (void)applicationInitialized
{
    // Test Maintenance
    if (self.maintenanceMode)
        return;

    // Execute : now
    NSLog(@"[LOG] Update Folder Photo");
    NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:_activeUrl];
    if ([autoUploadPath length] > 0)
        [[CCSynchronize sharedSynchronize] synchronizedFolder:autoUploadPath selector:selectorReadFolder];

    // Execute : after 1 sec.
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        if (_activeMain) {
            NSLog(@"[LOG] Request Server Capabilities");
            [_activeMain requestServerCapabilities];
        }
        
        if (_activeMain && [[NCBrandOptions sharedInstance] use_middlewarePing]) {
            NSLog(@"[LOG] Middleware Ping");
            [_activeMain middlewarePing];
        }
        
        NSLog(@"[LOG] Initialize Auto upload");
        [[NCAutoUpload sharedInstance] initStateAutoUpload];
        
        NSLog(@"[LOG] Listning Favorites");
        [_activeFavorites readListingFavorites];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Process Auto Upload k_timerProcess seconds =====
#pragma --------------------------------------------------------------------------------------------

- (void)processAutoUpload
{
    // Test Maintenance
    if (self.maintenanceMode)
        return;
    
    // BACKGROND & FOREGROUND

    NSLog(@"-PROCESS-AUTO-UPLOAD-");
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {

        // ONLY BACKGROUND
        [[NCAutoUpload sharedInstance] performSelectorOnMainThread:@selector(loadAutoUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUploadBackground] waitUntilDone:NO];
        
    } else {

        // ONLY FOREFROUND
        [[NCAutoUpload sharedInstance] performSelectorOnMainThread:@selector(loadAutoUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUpload] waitUntilDone:NO];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Setting Active Account =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activePassword:(NSString *)activePassword
{
    self.activeAccount = activeAccount;
    self.activeUrl = activeUrl;
    self.activeUser = activeUser;
    self.activePassword = activePassword;
    
    self.directoryUser = [CCUtility getDirectoryActiveUser:activeUser activeUrl:activeUrl];    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Push Notification =====
#pragma --------------------------------------------------------------------------------------------

- (void)subscribingNextcloudServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"[LOG] Error Subscribing Nextcloud Server %@", message);
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [application registerForRemoteNotifications];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // test
    if (self.activeAccount.length == 0)
        return;
    
    // FIREBASE registered token
    
    [[FIRInstanceID instanceID] setAPNSToken:deviceToken type:FIRInstanceIDAPNSTokenTypeSandbox];
    NSString *pushToken = [[FIRInstanceID instanceID] token];
    // NSString *pushToken = [[[[deviceToken description] stringByReplacingOccurrencesOfString: @"<" withString: @""] stringByReplacingOccurrencesOfString: @">" withString: @""] stringByReplacingOccurrencesOfString: @" " withString: @""];
    
    NSString *pushTokenHash = [[CCCrypto sharedManager] createSHA512:pushToken];
    NSDictionary *devicePushKey = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DevicePushKey-Info" ofType:@"plist"]];
    
#ifdef DEBUG
    NSString *devicePublicKey = [devicePushKey objectForKey:@"devicePublicKeyDevelopment"];
#else
    NSString *devicePublicKey = [devicePushKey objectForKey:@"devicePublicKeyProduction"];
#endif
    
    if ([devicePublicKey length] > 0 && [pushTokenHash length] > 0) {
        
        NSLog(@"[LOG] Firebase InstanceID push token: %@", pushToken);
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
        NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:pushToken, @"pushToken", pushTokenHash, @"pushTokenHash", devicePublicKey, @"devicePublicKey", nil];
        
        metadataNet.action = actionSubscribingNextcloudServer;
        metadataNet.options = options;
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }    
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"[LOG] Error register remote notification %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
    UIApplicationState state = [application applicationState];
    
    if (state == UIApplicationStateInactive || state == UIApplicationStateBackground) {
        
        NSLog(@"[LOG] Receive Notification on Inactive or Background state");
        
    } else {
        
        NSLog(@"[LOG] Receive Notification on Active state");
    }
    
    // If you are receiving a notification message while your app is in the background,
    // this callback will not be fired till the user taps on the notification launching the application.
    // TODO: Handle data of notification
    
    // Print message ID.
    //if (userInfo[kGCMMessageIDKey]) {
    //    NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);
    //}
    
    // Print full message.
    NSLog(@"[LOG] %@", userInfo);

}

- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    UIApplicationState state = [application applicationState];
    
    // Print message ID.
    //if (userInfo[kGCMMessageIDKey]) {
    //    NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);
    //}
    
    // Print full message.
    NSLog(@"[LOG] %@", userInfo);

    
    if (state == UIApplicationStateBackground || (state == UIApplicationStateInactive)) {
        
    } else if (state == UIApplicationStateInactive) {
        
        // user tapped notification
        completionHandler(UIBackgroundFetchResultNewData);
        
    } else {
        
        // app is active
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

#pragma FIREBASE

- (void)tokenRefreshNotification:(NSNotification *)notification {
    
    // Note that this callback will be fired everytime a new token is generated, including the first
    // time. So if you need to retrieve the token as soon as it is available this is where that
    // should be done.
    
    NSString *refreshedToken = [[FIRInstanceID instanceID] token];
    NSLog(@"[LOG] InstanceID token: %@", refreshedToken);
    
    // Connect to FCM since connection may have failed when attempted before having a token.
    [self connectToFcm];
    
    // TODO: If necessary send token to application server.
}

- (void)connectToFcm {
    
    // Won't connect since there is no token
    if (![[FIRInstanceID instanceID] token]) {
        return;
    }
    
    // Disconnect previous FCM connection if it exists.
    [[FIRMessaging messaging] disconnect];
    
    [[FIRMessaging messaging] connectWithCompletion:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[LOG] Unable to connect to FCM. %@", error);
        } else {
            NSLog(@"[LOG] Connected to FCM.");
        }
    }];
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Receive data message on iOS 10 devices while app is in the foreground.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    // Print full message
    NSLog(@"[LOG] %@", remoteMessage.appData);
}
#endif

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Quick Actions - ShotcutItem =====
#pragma --------------------------------------------------------------------------------------------

- (void)configDynamicShortcutItems
{
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;

    UIApplicationShortcutIcon *shortcutPhotosIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:@"quickActionPhotos"];
    UIApplicationShortcutIcon *shortcutUploadIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:@"quickActionUpload"];
    UIApplicationShortcutIcon *shortcutUploadEncryptedIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:@"quickActionUploadEncrypted"];
    
    UIApplicationShortcutItem *shortcutPhotos = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.photos", bundleId] localizedTitle:NSLocalizedString(@"_photo_camera_", nil) localizedSubtitle:nil icon:shortcutPhotosIcon userInfo:nil];

    UIApplicationShortcutItem *shortcutUpload = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.upload", bundleId] localizedTitle:NSLocalizedString(@"_upload_file_", nil) localizedSubtitle:nil icon:shortcutUploadIcon userInfo:nil];
    
    UIApplicationShortcutItem *shortcutUploadEncrypted = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.uploadEncrypted", bundleId] localizedTitle:NSLocalizedString(@"_upload_encrypted_file_", nil) localizedSubtitle:nil icon:shortcutUploadEncryptedIcon userInfo:nil];
    
    
    if (app.isCryptoCloudMode) {
        
        // add the array to our app
        [UIApplication sharedApplication].shortcutItems = @[shortcutUploadEncrypted, shortcutUpload, shortcutPhotos];

    } else {

        // add the array to our app
        [UIApplication sharedApplication].shortcutItems = @[shortcutUpload, shortcutPhotos];

    }
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
    BOOL handledShortCutItem = [self handleShortCutItem:shortcutItem];
    
    completionHandler(handledShortCutItem);
}

- (BOOL)handleShortCutItem:(UIApplicationShortcutItem *)shortcutItem
{
    BOOL handled = NO;
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    NSString *shortcutPhotos = [NSString stringWithFormat:@"%@.photos", bundleId];
    NSString *shortcutUpload = [NSString stringWithFormat:@"%@.upload", bundleId];
    NSString *shortcutUploadEncrypted = [NSString stringWithFormat:@"%@.uploadEncrypted", bundleId];
        
    if ([shortcutItem.type isEqualToString:shortcutUpload] && self.activeAccount) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (_activeMain) {
                
                UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
                
                if (splitViewController.isCollapsed) {
                    
                    UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                    for (UINavigationController *nvc in tbc.viewControllers) {
                        
                        if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                            [nvc popToRootViewControllerAnimated:NO];
                    }
                    
                    [tbc setSelectedIndex: k_tabBarApplicationIndexFile];
                    
                } else {
                    
                    UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                    [nvcDetail popToRootViewControllerAnimated:NO];
                    
                    UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                    [tbc setSelectedIndex: k_tabBarApplicationIndexFile];
                }

                [_activeMain.navigationController popToRootViewControllerAnimated:NO];

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [[CCQuickActions quickActionsManager] startQuickActionsEncrypted:NO viewController:_activeMain];
                });
            }
        });
        
        handled = YES;
    }
    
    else if ([shortcutItem.type isEqualToString:shortcutUploadEncrypted] && self.activeAccount) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            if (_activeMain) {
                
                UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
                
                if (splitViewController.isCollapsed) {
                    
                    UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                    for (UINavigationController *nvc in tbc.viewControllers) {
                        
                        if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                            [nvc popToRootViewControllerAnimated:NO];
                    }
                    
                    [tbc setSelectedIndex: k_tabBarApplicationIndexFile];
                    
                } else {
                    
                    UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                    [nvcDetail popToRootViewControllerAnimated:NO];
                    
                    UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                    [tbc setSelectedIndex: k_tabBarApplicationIndexFile];
                }
                
                [_activeMain.navigationController popToRootViewControllerAnimated:NO];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [[CCQuickActions quickActionsManager] startQuickActionsEncrypted:YES viewController:_activeMain];
                });
            }
        });
        
        handled = YES;
    }
    
    else if ([shortcutItem.type isEqualToString:shortcutPhotos] && self.activeAccount) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;

            if (splitViewController.isCollapsed) {
            
                UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                for (UINavigationController *nvc in tbc.viewControllers) {
                
                    if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                        [nvc popToRootViewControllerAnimated:NO];
                }
            
                [tbc setSelectedIndex: k_tabBarApplicationIndexPhotos];

            } else {
            
                UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                [nvcDetail popToRootViewControllerAnimated:NO];
            
                UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                [tbc setSelectedIndex: k_tabBarApplicationIndexPhotos];
            }
        });
        
        handled = YES;
    }
    
    return handled;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== StatusBar & ApplicationIconBadgeNumber =====
#pragma --------------------------------------------------------------------------------------------

- (void)messageNotification:(NSString *)title description:(NSString *)description visible:(BOOL)visible delay:(NSTimeInterval)delay type:(TWMessageBarMessageType)type errorCode:(NSInteger)errorcode
{
    static NSInteger errorCodePrev = 0;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (visible) {
            
            if (errorcode == kCFURLErrorNotConnectedToInternet || errorcode == k_CCErrorNetworkNowAvailable) {
                
                if (errorCodePrev != errorcode)
                    [JDStatusBarNotification showWithStatus:NSLocalizedString(title, nil) dismissAfter:delay styleName:JDStatusBarStyleDefault];
                
                errorCodePrev = errorcode;
                
            } else {
                
                if (description.length > 0) {
                
                    [TWMessageBarManager sharedInstance].styleSheet = self;
                    [[TWMessageBarManager sharedInstance] showMessageWithTitle:[NSString stringWithFormat:@"%@\n", NSLocalizedString(title, nil)] description:NSLocalizedString(description, nil) type:type duration:delay];
                }
            }
            
        } else {
            
            [[TWMessageBarManager sharedInstance] hideAllAnimated:YES];
        }
    });
}

- (UIColor *)backgroundColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *backgroundColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.90];
            break;
        case TWMessageBarMessageTypeSuccess:
            backgroundColor = [UIColor colorWithRed:0.588 green:0.797 blue:0.000 alpha:0.90];
            break;
        case TWMessageBarMessageTypeInfo:
            backgroundColor = [NCBrandColor sharedInstance].brand;
            break;
        default:
            break;
    }
    return backgroundColor;
}

- (UIColor *)strokeColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *strokeColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            strokeColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
            break;
        case TWMessageBarMessageTypeSuccess:
            strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0];
            break;
        case TWMessageBarMessageTypeInfo:
            strokeColor = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:1.0];
            break;
        default:
            break;
    }
    return strokeColor;
}

- (UIImage *)iconImageForMessageType:(TWMessageBarMessageType)type
{
    UIImage *iconImage = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            iconImage = [UIImage imageNamed:@"icon-error.png"];
            break;
        case TWMessageBarMessageTypeSuccess:
            iconImage = [UIImage imageNamed:@"icon-success.png"];
            break;
        case TWMessageBarMessageTypeInfo:
            iconImage = [UIImage imageNamed:@"icon-info.png"];
            break;
        default:
            break;
    }
    return iconImage;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== TabBarController =====
#pragma --------------------------------------------------------------------------------------------

- (void)createTabBarController
{
    UITabBarItem *item;
    NSLayoutConstraint *constraint;
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    [app aspectTabBar:tabBarController.tabBar hidden:NO];
    
    // File
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
    [item setTitle:NSLocalizedString(@"_home_", nil)];
    item.image = [UIImage imageNamed:@"tabBarFiles"];
    item.selectedImage = [UIImage imageNamed:@"tabBarFiles"];
    
    // Favorites
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexOffline];
    [item setTitle:NSLocalizedString(@"_favorites_", nil)];
    item.image = [UIImage imageNamed:@"tabBarFavorite"];
    item.selectedImage = [UIImage imageNamed:@"tabBarFavorite"];
    
    // Hide (PLUS)
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexHide];
    item.title = nil;
    item.image = nil;
    item.enabled = false;
    
    // Photos
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexPhotos];
    [item setTitle:NSLocalizedString(@"_photo_camera_", nil)];
    item.image = [UIImage imageNamed:@"tabBarPhotos"];
    item.selectedImage = [UIImage imageNamed:@"tabBarPhotos"];
    
    // More
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexMore];
    [item setTitle:NSLocalizedString(@"_more_", nil)];
    item.image = [UIImage imageNamed:@"tabBarMore"];
    item.selectedImage = [UIImage imageNamed:@"tabBarMore"];
    
    // Plus Button
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] color:[NCBrandColor sharedInstance].brand];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = 99;
    button.frame = CGRectMake(0.0, 0.0, buttonImage.size.width, buttonImage.size.height);
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [button setBackgroundImage:buttonImage forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(handleTouchTabbarCenter:) forControlEvents:UIControlEventTouchUpInside];
    
    [button setTranslatesAutoresizingMaskIntoConstraints:NO];
    [tabBarController.view addSubview:button];
    
    constraint =[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tabBarController.view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
    
    [tabBarController.view addConstraint:constraint];
    
    constraint =[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:tabBarController.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-5];
    
    [tabBarController.view addConstraint:constraint];
}

- (void)aspectNavigationControllerBar:(UINavigationBar *)nav encrypted:(BOOL)encrypted online:(BOOL)online hidden:(BOOL)hidden
{
    nav.translucent = NO;
    nav.barTintColor = [NCBrandColor sharedInstance].brand;
    nav.tintColor = [NCBrandColor sharedInstance].navigationBarText;
    [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : [NCBrandColor sharedInstance].navigationBarText}];
    
    if (encrypted)
        [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : [NCBrandColor sharedInstance].cryptocloud}];
    
    if (!online)
        [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : [NCBrandColor sharedInstance].connectionNo}];
    
    nav.hidden = hidden;
    
    [nav setAlpha:1];
}

- (void)aspectTabBar:(UITabBar *)tab hidden:(BOOL)hidden
{
    tab.translucent = NO;
    tab.barTintColor = [NCBrandColor sharedInstance].tabBar;
    tab.tintColor = [NCBrandColor sharedInstance].brand;
    
    tab.hidden = hidden;
    
    [tab setAlpha:1];
}

- (void)plusButtonVisibile:(BOOL)visible
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    UIButton *buttonPlus = [tabBarController.view viewWithTag:99];
    
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] color:[NCBrandColor sharedInstance].brand];
    [buttonPlus setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [buttonPlus setBackgroundImage:buttonImage forState:UIControlStateHighlighted];
    
    if (buttonPlus) {

        if (visible) {
            
            buttonPlus.hidden = false;
        
        } else {
            
            buttonPlus.hidden = true;
        }
    }
}

- (void)handleTouchTabbarCenter:(id)sender
{
    // Test Maintenance
    if (self.maintenanceMode)
        return;
    
    CreateMenuAdd *menuAdd = [[CreateMenuAdd alloc] initWithThemingColor:[NCBrandColor sharedInstance].brand];
    
    if ([CCUtility getCreateMenuEncrypted])
        [menuAdd createMenuEncryptedWithView:self.window.rootViewController.view];
    else
        [menuAdd createMenuPlainWithView:self.window.rootViewController.view];
}

- (void)updateApplicationIconBadgeNumber
{
    // Test Maintenance
    if (self.maintenanceMode)
        return;

    NSInteger queueDownload = [self getNumberDownloadInQueues] + [self getNumberDownloadInQueuesWWan];
    NSInteger queueUpload = [self getNumberUploadInQueues] + [self getNumberUploadInQueuesWWan];
    
    // Total
    NSInteger total = queueDownload + queueUpload + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:nil];
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = total;
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    
    if ([[splitViewController.viewControllers firstObject] isKindOfClass:[UITabBarController class]]) {
        
        UITabBarController *tbc = [splitViewController.viewControllers firstObject];
        
        UITabBarItem *tbItem = [tbc.tabBar.items objectAtIndex:0];
        
        if (total > 0)
            [tbItem setBadgeValue:[NSString stringWithFormat:@"%li", (unsigned long)total]];
        else
            [tbItem setBadgeValue:nil];
    }
}

- (void)selectedTabBarController:(NSInteger)index
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    
    if (splitViewController.isCollapsed) {
        
        UITabBarController *tbc = splitViewController.viewControllers.firstObject;
        for (UINavigationController *nvc in tbc.viewControllers) {
            
            if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                [nvc popToRootViewControllerAnimated:NO];
        }
        
        [tbc setSelectedIndex: index];
        
    } else {
        
        UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
        [nvcDetail popToRootViewControllerAnimated:NO];
        
        UITabBarController *tbc = splitViewController.viewControllers.firstObject;
        [tbc setSelectedIndex: index];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Theming Color =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingThemingColorBrand
{
    UIColor* newColor;
    
    if (self.activeAccount.length > 0) {
    
        tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilites];
    
        if ([NCBrandOptions sharedInstance].use_themingColor && capabilities.themingColor.length == 7) {
        
            BOOL isLight = [CCGraphics isLight:[CCGraphics colorFromHexString:capabilities.themingColor]];
            
            if (isLight) {
                
                // Activity
                [[NCManageDatabase sharedInstance] addActivityClient:@"" fileID:@"" action:k_activityDebugActionCapabilities selector:@"Server Theming" note:NSLocalizedString(@"_theming_is_light_", nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
                
                [NCBrandColor sharedInstance].brand = [NCBrandColor sharedInstance].customer;
                
            } else {
                
                newColor = [CCGraphics colorFromHexString:capabilities.themingColor];
            }
            
        } else {
            
            newColor = [NCBrandColor sharedInstance].customer;
        }
        
    } else {
        
        newColor = [NCBrandColor sharedInstance].customer;
    }
    
    if (self.activeAccount.length > 0 && ![newColor isEqual:[NCBrandColor sharedInstance].brand]) {
        
        [NCBrandColor sharedInstance].brand = newColor;
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"changeTheming" object:nil];
    }
}

- (void)changeTheming:(UIViewController *)vc
{
    UIColor *color = [NCBrandColor sharedInstance].brand;
    
    // Change Navigation & TabBar color
    vc.navigationController.navigationBar.barTintColor = color;
    vc.tabBarController.tabBar.tintColor = color;
    
    // Change button Plus
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    UIButton *button = [tabBarController.view viewWithTag:99];
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] color:color];
    
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [button setBackgroundImage:buttonImage forState:UIControlStateHighlighted];
    
    // Tint Color GLOBAL WINDOW
    [self.window setTintColor:[NCBrandColor sharedInstance].brand];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Media Player Control =====
#pragma --------------------------------------------------------------------------------------------

- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
    switch (event.subtype) {
            
        case UIEventSubtypeRemoteControlPlay:
            
            if (self.player.mediaPlayer) {
                
                NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
                
                if (self.player.mediaPlayer.nowPlayingItem.title)
                    [songInfo setObject:self.player.mediaPlayer.nowPlayingItem.title forKey:MPMediaItemPropertyTitle];
                
                if (self.player.mediaPlayer.nowPlayingItem.artist)
                    [songInfo setObject:self.player.mediaPlayer.nowPlayingItem.artist forKey:MPMediaItemPropertyArtist];
                
                [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
                
                [self.player.mediaPlayer play];
            }
            break;
        
        case UIEventSubtypeRemoteControlPause:
            
            if (self.player.mediaPlayer) {
                [self.player.mediaPlayer pause];
            }
            break;
            
        case UIEventSubtypeRemoteControlNextTrack:
            // handle it break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            // handle it break;
        default:
            break;
    }
}

- (BOOL)mediaPlayerViewWillStartPlaying:(LMMediaPlayerView *)playerView media:(LMMediaItem *)media
{
    return YES;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Manager Passcode =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)lockScreenManagerShouldShowLockScreen:(BKPasscodeLockScreenManager *)aManager
{
    // ServerUrl active
    NSString *serverUrl = self.activeMain.serverUrl;
    BOOL isBlockZone = false;
    
    // fermiamo la data della sessione
    self.sessionePasscodeLock = nil;
    
    // se il block code è a zero esci con NON attivare la richiesta password
    if ([[CCUtility getBlockCode] length] == 0) return NO;
    
    // se non c'è attivo un account esci con NON attivare la richiesta password
    if ([self.activeAccount length] == 0) return NO;
    
    // se non è attivo il OnlyLockDir esci con NON attivare la richiesta password
    if (serverUrl && _activeUrl) {
        
        while (![serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:_activeUrl]]) {
            
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", self.activeAccount, serverUrl]];
            
            if (directory.lock) {
                isBlockZone = true;
                break;
            } else {
                serverUrl = [CCUtility deletingLastPathComponentFromServerUrl:serverUrl];
                if (serverUrl == self.activeUrl)
                    break;
            }
        }
    }
    
    if ([CCUtility getOnlyLockDir] && !isBlockZone) return NO;
    
    return YES;
}

- (UIViewController *)lockScreenManagerPasscodeViewController:(BKPasscodeLockScreenManager *)aManager
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.type = BKPasscodeViewControllerCheckPasscodeType;
    viewController.delegate = self;
    viewController.title = [NCBrandOptions sharedInstance].brand;
    viewController.fromType = CCBKPasscodeFromLockScreen;
    viewController.inputViewTitlePassword = YES;
    
    if ([CCUtility getSimplyBlockCode]) {
        
        viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 6;
        
    } else {
        
        viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 64;
    }

    viewController.touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName: k_serviceShareKeyChain];
    viewController.touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    return navigationController;
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    // is a lock screen
    if (aViewController.fromType == CCBKPasscodeFromLockScreen) {
        
        [aViewController dismissViewControllerAnimated:YES completion:nil];
        
        // start session Passcode Lock
        BOOL isBlockZone = false;
        NSString *serverUrl = self.activeMain.serverUrl;
        
        while (![serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:_activeUrl]]) {
            
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", self.activeAccount, serverUrl]];
            
            if (directory.lock) {
                isBlockZone = true;
                break;
            } else {
                serverUrl = [CCUtility deletingLastPathComponentFromServerUrl:serverUrl];
                if (serverUrl == self.activeUrl)
                    break;
            }
        }
        if (isBlockZone)
            self.sessionePasscodeLock = [NSDate date];
     }
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if (aViewController.fromType == CCBKPasscodeFromLockScreen || aViewController.fromType == CCBKPasscodeFromInit) {
        if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
            //self.lockUntilDate = nil;
            //self.failedAttempts = 0;
            aResultHandler(YES);
        } else aResultHandler(NO);
    } else aResultHandler(YES);
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== reachabilityChanged =====
#pragma --------------------------------------------------------------------------------------------

-(void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
    if ([self.reachability isReachable]) {
        
        if (self.lastReachability == NO) {
            
            [self messageNotification:@"_network_available_" description:nil visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:k_CCErrorNetworkNowAvailable];
            
            if (_activeMain)
                [_activeMain performSelector:@selector(requestServerCapabilities) withObject:nil afterDelay:3];
        }
        
        NSLog(@"[LOG] Reachability Changed: Reachable");
        
        self.lastReachability = YES;
        
    } else {
        
        if (self.lastReachability == YES) {
            [self messageNotification:@"_network_not_available_" description:nil visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:kCFURLErrorNotConnectedToInternet];
        }
        
        NSLog(@"[LOG] Reachability Changed: NOT Reachable");
        
        self.lastReachability = NO;
    }
    
    if ([self.reachability isReachableViaWiFi]) NSLog(@"[LOG] Reachability Changed: WiFi");
    if ([self.reachability isReachableViaWWAN]) NSLog(@"[LOG] Reachability Changed: WWAn");
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"setTitleMain" object:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Fetch =====
#pragma --------------------------------------------------------------------------------------------

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"[LOG] Start perform Fetch With Completion Handler");
    
    // Verify new photo
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    // after 20 sec
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        NSArray *records = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND session != ''", self.activeAccount] sorted:nil ascending:NO];
        
        if ([records count] > 0) {
            completionHandler(UIBackgroundFetchResultNewData);
        } else {
            completionHandler(UIBackgroundFetchResultNoData);
        }
        
        NSLog(@"[LOG] End 20 sec. perform Fetch With Completion Handler");
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Operation Networking & Session =====
#pragma --------------------------------------------------------------------------------------------

//
// Method called by the system when all the background task has end
//
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    NSLog(@"[LOG] Start handle Events For Background URLSession: %@", identifier);
    
    // after 20 sec
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        self.backgroundSessionCompletionHandler = completionHandler;
        void (^completionHandler)() = self.backgroundSessionCompletionHandler;
        self.backgroundSessionCompletionHandler = nil;
        completionHandler();
        
        NSLog(@"[LOG] End 20 sec. Start handle Events For Background URLSession: %@", identifier);
    });
}

- (void)cancelAllOperations
{
    [_netQueue cancelAllOperations];
    
    [_netQueueDownload cancelAllOperations];
    [_netQueueDownloadWWan cancelAllOperations];
    [_netQueueUpload cancelAllOperations];
    [_netQueueUploadWWan cancelAllOperations];
}

- (void)addNetworkingOperationQueue:(NSOperationQueue *)netQueue delegate:(id)delegate metadataNet:(CCMetadataNet *)metadataNet
{
    id operation;
    
    operation = [[OCnetworking alloc] initWithDelegate:delegate metadataNet:metadataNet withUser:_activeUser withPassword:_activePassword withUrl:_activeUrl isCryptoCloudMode:_isCryptoCloudMode];
        
    [operation setQueuePriority:metadataNet.priority];
    
    [netQueue addOperation:operation];
}

- (NSMutableArray *)verifyExistsInQueuesDownloadSelector:(NSString *)selector
{
    NSMutableArray *metadatasNet = [[NSMutableArray alloc] init];
    
    for (OCnetworking *operation in [self.netQueueDownload operations])
        if ([operation.metadataNet.selector isEqualToString:selector])
            [metadatasNet addObject:[operation.metadataNet copy]];
        
    for (OCnetworking *operation in [self.netQueueDownloadWWan operations])
        if ([operation.metadataNet.selector isEqualToString:selector])
            [metadatasNet addObject:[operation.metadataNet copy]];
    
    return metadatasNet;
}

- (NSInteger)getNumberDownloadInQueues
{
    NSArray *results = [[NCManageDatabase sharedInstance] getTableMetadataDownload];
    
    NSInteger queueNunDownload = [results count];
    
    // netQueueDownload
    for (NSOperation *operation in [self.netQueueDownload operations])
        if (((OCnetworking *)operation).isExecuting == NO) queueNunDownload++;
    
    return queueNunDownload;
}

- (NSInteger)getNumberDownloadInQueuesWWan
{
    NSArray *results = [[NCManageDatabase sharedInstance] getTableMetadataDownloadWWan];
    
    NSInteger queueNumDownloadWWan = [results count];
    
    // netQueueDownloadWWan
    for (NSOperation *operation in [self.netQueueDownloadWWan operations])
        if (((OCnetworking *)operation).isExecuting == NO) queueNumDownloadWWan++;
    
    return queueNumDownloadWWan;
}

- (NSInteger)getNumberUploadInQueues
{
    NSArray *results = [[NCManageDatabase sharedInstance] getTableMetadataUpload];
    
    NSInteger queueNumUpload = [results count];
    
    // netQueueUpload
    for (NSOperation *operation in [self.netQueueUpload operations])
        if (((OCnetworking *)operation).isExecuting == NO) queueNumUpload++;
    
    return queueNumUpload;
}

- (NSInteger)getNumberUploadInQueuesWWan
{
    NSArray *results = [[NCManageDatabase sharedInstance] getTableMetadataUploadWWan];
    
    NSInteger queueNumUploadWWan = [results count];
    
    // netQueueUploadWWan
    for (NSOperation *operation in [self.netQueueUploadWWan operations])
        if (((OCnetworking *)operation).isExecuting == NO) queueNumUploadWWan++;
    
    return queueNumUploadWWan;
}

- (void)verifyDownloadUploadInProgress
{
    [self.timerVerifySessionInProgress invalidate];
    
    // Test Maintenance - Account
    if (self.maintenanceMode == NO || self.activeAccount.length > 0) {
    
        [[CCNetworking sharedNetworking] verifyDownloadInProgress];
        [[CCNetworking sharedNetworking] verifyUploadInProgress];
    }
    
    self.timerVerifySessionInProgress = [NSTimer scheduledTimerWithTimeInterval:k_timerVerifySession target:self selector:@selector(verifyDownloadUploadInProgress) userInfo:nil repeats:YES];
}

// Notification change session
- (void)sessionChanged:(NSNotification *)notification
{
    NSURLSession *session;
    NSString *fileID;
    NSURLSessionTask *task;
    
    for (id object in notification.object) {
        
        if ([object isKindOfClass:[NSURLSession class]])
            session = object;
        
        if ([object isKindOfClass:[NSString class]])
            fileID = object;
        
        if ([object isKindOfClass:[NSURLSessionTask class]])
            task = object;
    }
    
    /*
    Task
    */
    if (fileID && [_listChangeTask objectForKey:fileID])
        dispatch_async(dispatch_get_main_queue(), ^{
            [self changeTask:fileID];
        });
        
    /* 
    Session
    */
    if (session) {
                
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            unsigned long numDownload = [downloadTasks count];
            unsigned long numUpload = [uploadTasks count];
        
            NSLog(@"[LOG] Num Download in queue %lu, num upload in queue %lu", numDownload, numUpload);
        }];
    }
}

- (void)changeTask:(NSString *)fileID
{
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    if (!metadata) return;
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    
    if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"stopUpload"]) {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierStop sessionTaskIdentifierPlist:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
    }
    else if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"reloadUpload"]) {
        
        // V 1.8 if upload_session_wwan change in upload_session
        if ([metadata.session isEqualToString:k_upload_session_wwan])
            metadata.session = k_upload_session;
        
        [[CCNetworking sharedNetworking] uploadFileMetadata:metadata taskStatus:k_taskStatusResume];
    }
    else if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"reloadDownload"]) {
        
        BOOL downloadData = NO, downloadPlist = NO;
            
        if (metadata.sessionTaskIdentifier != k_taskIdentifierDone) downloadData = YES;
        if (metadata.sessionTaskIdentifierPlist != k_taskIdentifierDone) downloadPlist = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] downloadFile:fileID serverUrl:serverUrl downloadData:downloadData downloadPlist:downloadPlist selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost session:k_download_session taskStatus:k_taskStatusResume delegate:nil];
        });
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"cancelUpload"]) {
        
        // remove the file
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, fileID] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, fileID] error:nil];
        
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID] clearDateReadDirectoryID:nil];
    }
    else if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"cancelDownload"]) {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:k_taskIdentifierDone sessionTaskIdentifierPlist:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    }
    
    // remove ChangeTask (fileID) from the list
    [_listChangeTask removeObjectForKey:fileID];
    
    // delete progress
    [_listProgressMetadata removeObjectForKey:fileID];
    
    // Progress Task
    NSDictionary* userInfo = @{@"fileID": (fileID), @"serverUrl": (serverUrl), @"cryptated": ([NSNumber numberWithBool:NO]), @"progress": ([NSNumber numberWithFloat:0.0])};
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];

    // Refresh
    if (_activeMain && [_listChangeTask count] == 0) {
        [_activeMain reloadDatasource:serverUrl];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Open CCUploadFromOtherUpp  =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    return YES;
}

// Method called from iOS system to send a file from other app.
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    NSLog(@"[LOG] URL from %@ application", sourceApplication);
    NSLog(@"[LOG] the path is: %@", url.path);
        
    NSArray *splitedUrl = [url.path componentsSeparatedByString:@"/"];
    self.fileNameUpload = [NSString stringWithFormat:@"%@",[splitedUrl objectAtIndex:([splitedUrl count]-1)]];
    
    if (self.activeAccount) {
        
        [[NSFileManager defaultManager]moveItemAtPath:[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Inbox"] stringByAppendingPathComponent:self.fileNameUpload] toPath:[NSString stringWithFormat:@"%@/%@", self.directoryUser, self.fileNameUpload] error:nil];
        
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *splitNavigationController = [splitViewController.viewControllers firstObject];
        
        UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"CCUploadFromOtherUpp" bundle:nil] instantiateViewControllerWithIdentifier:@"CCUploadNavigationViewController"];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [splitNavigationController presentViewController:navigationController animated:YES completion:nil];
        });
    }
    
    // remove from InBox
    [[NSFileManager defaultManager] removeItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Inbox"] error:nil];
    
    return YES;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Crashlytics =====
#pragma --------------------------------------------------------------------------------------------

- (void) logUser
{
    if (self.activeAccount.length > 0)
        [CrashlyticsKit setUserName:self.activeAccount];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== maintenance Mode =====
#pragma --------------------------------------------------------------------------------------------

- (void)maintenanceMode:(BOOL)mode
{
    self.maintenanceMode = mode;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== UPGRADE =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)upgrade
{
#ifdef DEBUG
    //self.maintenanceMode = YES;
#endif
    
    NSString *actualVersion = [CCUtility getVersion];
    NSString *actualBuild = [CCUtility getBuild];
    
    /* ---------------------- UPGRADE VERSION ----------------------- */
    
    if (([actualVersion compare:@"2.17.3" options:NSNumericSearch] == NSOrderedAscending)) {
    
        // Migrate Certificates Table From CoreData to Realm
        
        NSArray *listCertificateLocation = [CCCoreData migrateCertificatesLocation];
        
        for (NSString *certificateLocation in listCertificateLocation)
            [[NCManageDatabase sharedInstance] addCertificates:certificateLocation];
    }
    
    // VERSION < 2.17.4
    
    if (([actualVersion compare:@"2.17.4" options:NSNumericSearch] == NSOrderedAscending)) {
        
        [self maintenanceMode:YES];
        
        // Migrate Account Table From CoreData to Realm
        
        NSArray *listAccount = [CCCoreData migrateAccount];
        for (TableAccount *account in listAccount)
            [[NCManageDatabase sharedInstance] addTableAccountFromCoredata:account];
        
        // Align Photo Library
        [[NCAutoUpload sharedInstance] alignPhotoLibrary];
        
        // Most important is done
        [CCUtility setVersion];
        [CCUtility setBuild];

        // Directories + LocalFile
        NSArray *listDirectories = [CCCoreData migrateDirectories];
        for (TableDirectory *directory in listDirectories)
            [[NCManageDatabase sharedInstance] addTableDirectoryFromCoredata:directory];
        
        NSArray *listLocalFile = [CCCoreData migrateLocalFile];
        for (TableLocalFile *localFile in listLocalFile)
            [[NCManageDatabase sharedInstance] addTableLocalFileFromCoredata:localFile];
        
        [self maintenanceMode:NO];
    }
    
    // VERSION == 2.17.4 BUILD < 23
    
    if ([actualVersion isEqualToString:@"2.17.4"]) {
        
        // Build 23 remove DB
        if (([actualBuild compare:@"23" options:NSNumericSearch] == NSOrderedAscending) || actualBuild == nil) {
            
            [CCUtility setBuild];
            
            NSString *file;
            NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions sharedInstance].capabilitiesGroups];
            NSString *dirIniziale = [[dirGroup URLByAppendingPathComponent:appApplicationSupport] path];
            
            NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirIniziale];
            
            while (file = [enumerator nextObject])
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dirIniziale, file] error:nil];
        }
    }
    
    return YES;
}

@end
