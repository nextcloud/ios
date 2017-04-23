//
//  AppDelegate.m
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

#import "AppDelegate.h"

#import "iRate.h"
#import "AFURLSessionManager.h"
#import "CCNetworking.h"
#import "CCCoreData.h"
#import "CCCrypto.h"
#import "CCManageAsset.h"
#import "CCGraphics.h"
#import "CCPhotosCameraUpload.h"
#import "CCSynchronize.h"
#import "CCMain.h"
#import "CCDetail.h"
#import "Firebase.h"

#ifdef CUSTOM_BUILD
    #import "CustomSwift.h"
#else
    #import "Nextcloud-Swift.h"
#endif

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
    
    //enable preview mode
    //[iRate sharedInstance].previewMode = YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Brand
    if (k_option_use_firebase) {
    
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
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:k_capabilitiesGroups];
    
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
    
    //[CCCoreData verifyVersionCoreData];
    
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:(id)[dirGroup URLByAppendingPathComponent:[appDatabase stringByAppendingPathComponent:@"cryptocloud"]]];
    
#ifdef DEBUG
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelWarn];
#else
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelOff];
#endif
    
    // Verify upgrade
    [self upgrade];
    
    // Set account, if no exists clear all
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    if (recordAccount == nil) {
        
        // remove all the keys Chain
        [CCUtility deleteAllChainStore];
    
        // remove all the App group key
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];

    } else {
        
        [self settingActiveAccount:recordAccount.account activeUrl:recordAccount.url activeUser:recordAccount.user activePassword:recordAccount.password];
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
    
    // Check new Asset Photos/Video in progress  
    _automaticCheckAssetInProgress = NO;
    _automaticUploadInProgress = NO;
    
    // Add notification change session
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionChanged:) name:k_networkingSessionNotification object:nil];
        
    // Initialization Share
    self.sharesID = [NSMutableDictionary new];
    self.sharesLink = [NSMutableDictionary new];
    self.sharesUserAndGroup = [NSMutableDictionary new];
    
    // Initialization Notification
    self.listOfNotifications = [NSMutableArray new];
    
    // Verify Session in progress and Init date task
    self.sessionDateLastDownloadTasks = [NSDate date];
    self.sessionDateLastUploadTasks = [NSDate date];
    self.timerVerifySessionInProgress = [NSTimer scheduledTimerWithTimeInterval:k_timerVerifySession target:self selector:@selector(verifyDownloadUploadInProgress) userInfo:nil repeats:YES];
    
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
    
    // Page Control
    UIPageControl *pageControl = [UIPageControl appearance];
    pageControl.pageIndicatorTintColor = [UIColor whiteColor];
    pageControl.currentPageIndicatorTintColor = COLOR_PAGECONTROL_INDICATOR;
    pageControl.backgroundColor = COLOR_BACKGROUND_PAGECONTROL;
    
    // remove tmp & cache
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
        for (NSString *file in tmpDirectory) {
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
        }
        
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
    });
    
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
    
    // Tint Color GLOBAL WINDOW
    [self.window setTintColor:COLOR_WINDOW_TINTCOLOR];
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    //UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];

    navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    [CCAspect aspectNavigationControllerBar:navigationController.navigationBar encrypted:NO online:YES hidden:NO];
    
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
    
    // Start timer Verify Process
    self.timerProcess = [NSTimer scheduledTimerWithTimeInterval:k_timerProcess target:self selector:@selector(process) userInfo:nil repeats:YES];
    
    // Registration Push Notification
    UIUserNotificationType types = UIUserNotificationTypeSound | UIUserNotificationTypeBadge | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [application registerUserNotificationSettings:notificationSettings];
    
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
    self.timerVerifySessionInProgress = [NSTimer scheduledTimerWithTimeInterval:k_timerVerifySession target:self selector:@selector(verifyDownloadUploadInProgress) userInfo:nil repeats:YES];
    
    // refresh active Main
    if (_activeMain)
        [_activeMain reloadDatasource];
    
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
    // Execute : now
    
    NSLog(@"[LOG] Update Folder Photo");
    NSString *folderCameraUpload = [CCCoreData getCameraUploadFolderNamePathActiveAccount:self.activeAccount activeUrl:self.activeUrl];
    if ([folderCameraUpload length] > 0)
        [[CCSynchronize sharedSynchronize] readFolderServerUrl:folderCameraUpload directoryID:[CCCoreData getDirectoryIDFromServerUrl:folderCameraUpload activeAccount:self.activeAccount] selector:selectorReadFolder];

    // Execute : after 0.5 sec.
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        NSLog(@"[LOG] Request Server Information");
    
        if (_activeMain)
            [_activeMain requestServerInformation];
    
        NSLog(@"[LOG] Initialize Camera Upload");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"initStateCameraUpload" object:nil];
        
        NSLog(@"[LOG] Listning Favorites");
        [[CCSynchronize sharedSynchronize] readListingFavorites];        
    });
    
    // Initialize Camera Upload
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"initStateCameraUpload" object:@{@"afterDelay": @(2)}];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Process k_timerProcess seconds =====
#pragma --------------------------------------------------------------------------------------------

- (void)process
{
    // BACKGROND & FOREGROUND

    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {

        // ONLY BACKGROUND
       
    } else {

        // ONLY FOREFROUND
        
        [app performSelectorOnMainThread:@selector(loadAutomaticUpload) withObject:nil waitUntilDone:NO];
    
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

    UIApplicationShortcutIcon *shortcutPhotosIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:image_quickActionPhotos];
    UIApplicationShortcutIcon *shortcutUploadIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:image_quickActionUpload];
    UIApplicationShortcutIcon *shortcutUploadEncryptedIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:image_quickActionUploadEncrypted];
    
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

- (void)messageNotification:(NSString *)title description:(NSString *)description visible:(BOOL)visible delay:(NSTimeInterval)delay type:(TWMessageBarMessageType)type
{
    title = [NSString stringWithFormat:@"%@\n",[CCUtility localizableBrand:title table:nil]];
        
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (visible) {
            
            [TWMessageBarManager sharedInstance].styleSheet = self;
            [[TWMessageBarManager sharedInstance] showMessageWithTitle:title description:[CCUtility localizableBrand:description table:nil] type:type duration:delay];
            
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
            backgroundColor = COLOR_BACKGROUND_MESSAGE_INFO;
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
    
    [CCAspect aspectTabBar:tabBarController.tabBar hidden:NO];
    
    // File
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
    [item setTitle:NSLocalizedString(@"_home_", nil)];
    item.image = [UIImage imageNamed:image_tabBarFiles];
    item.selectedImage = [UIImage imageNamed:image_tabBarFiles];
    
    // Favorites
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexOffline];
    [item setTitle:NSLocalizedString(@"_favorites_", nil)];
    item.image = [UIImage imageNamed:image_tabBarFavorite];
    item.selectedImage = [UIImage imageNamed:image_tabBarFavorite];
    
    // Hide (PLUS)
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexHide];
    item.title = nil;
    item.image = nil;
    item.enabled = false;
    
    // Photos
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexPhotos];
    [item setTitle:NSLocalizedString(@"_photo_camera_", nil)];
    item.image = [UIImage imageNamed:image_tabBarPhotos];
    item.selectedImage = [UIImage imageNamed:image_tabBarPhotos];
    
    // More
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexMore];
    [item setTitle:NSLocalizedString(@"_more_", nil)];
    item.image = [UIImage imageNamed:image_tabBarMore];
    item.selectedImage = [UIImage imageNamed:image_tabBarMore];
    
    // Plus Button
    UIImage *buttonImage = [UIImage imageNamed:image_tabBarPlus];    
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

- (void)plusButtonVisibile:(BOOL)visible
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    UIButton *buttonPlus = [tabBarController.view viewWithTag:99];
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
    CreateMenuAdd *menuAdd = [[CreateMenuAdd alloc] init];
    
    if ([CCUtility getCreateMenuEncrypted])
        [menuAdd createMenuEncryptedWithView:self.window.rootViewController.view];
    else
        [menuAdd createMenuPlainWithView:self.window.rootViewController.view];
}

- (void)updateApplicationIconBadgeNumber
{
    // Core Data
    _queueNunDownload = [[CCCoreData getTableMetadataDownloadAccount:self.activeAccount] count];
    _queueNumDownloadWWan = [[CCCoreData getTableMetadataDownloadWWanAccount:self.activeAccount] count];
    
    _queueNumUpload = [[CCCoreData getTableMetadataUploadAccount:self.activeAccount] count];
    _queueNumUploadWWan = [[CCCoreData getTableMetadataUploadWWanAccount:self.activeAccount] count];
    
    // netQueueDownload
    for (NSOperation *operation in [app.netQueueDownload operations]) {
        
        if (((OCnetworking *)operation).isExecuting == NO) _queueNunDownload++;
    }
    
    // netQueueDownloadWWan
    for (NSOperation *operation in [app.netQueueDownloadWWan operations]) {
        
        if (((OCnetworking *)operation).isExecuting == NO) _queueNumDownloadWWan++;
    }
    
    // netQueueUpload
    for (NSOperation *operation in [app.netQueueUpload operations]) {
        
        if (((OCnetworking *)operation).isExecuting == NO) _queueNumUpload++;
    }
    
    // netQueueUploadWWan
    for (NSOperation *operation in [app.netQueueUploadWWan operations]) {
        
        if (((OCnetworking *)operation).isExecuting == NO) _queueNumUploadWWan++;
    }
    
    // Total
    NSUInteger total = _queueNunDownload + _queueNumDownloadWWan + _queueNumUpload + _queueNumUploadWWan + [CCCoreData countTableAutomaticUploadForAccount:self.activeAccount selector:nil];
    
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
    
    // fermiamo la data della sessione
    self.sessionePasscodeLock = nil;
    
    // se il block code è a zero esci con NON attivare la richiesta password
    if ([[CCUtility getBlockCode] length] == 0) return NO;
    // se non c'è attivo un account esci con NON attivare la richiesta password
    if ([self.activeAccount length] == 0) return NO;
    // se non è attivo il OnlyLockDir esci con NON attivare la richiesta password
    if ([CCUtility getOnlyLockDir] && ![CCCoreData isBlockZone:serverUrl activeAccount:self.activeAccount]) return NO;
        
    return YES;
}

- (UIViewController *)lockScreenManagerPasscodeViewController:(BKPasscodeLockScreenManager *)aManager
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.type = BKPasscodeViewControllerCheckPasscodeType;
    viewController.delegate = self;
    viewController.title = k_brand;
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
    viewController.touchIDManager.promptText = [CCUtility localizableBrand:@"_scan_fingerprint_" table:nil];

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
        NSString *serverUrl = self.activeMain.serverUrl;
        if ([CCCoreData isBlockZone:serverUrl activeAccount:self.activeAccount])
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
            
            [self messageNotification:@"_network_available_" description:nil visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo];
            
            if (_activeMain)
                [_activeMain performSelector:@selector(requestServerInformation) withObject:nil afterDelay:3];
        }
        
        NSLog(@"[LOG] Reachability Changed: Reachable");
        
        self.lastReachability = YES;
        
    } else {
        
        if (self.lastReachability == YES) {
            [self messageNotification:@"_network_not_available_" description:nil visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        }
        
        NSLog(@"[LOG] Reachability Changed: NOT Reachable");
        
        self.lastReachability = NO;
    }
    
    if ([self.reachability isReachableViaWiFi]) NSLog(@"[LOG] Reachability Changed: WiFi");
    if ([self.reachability isReachableViaWWAN]) NSLog(@"[LOG] Reachability Changed: WWAn");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"setTitleMain" object:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Fetch =====
#pragma --------------------------------------------------------------------------------------------

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"[LOG] Start Fetch");
    
    // Verify new photo
    [[NSNotificationCenter defaultCenter] postNotificationName:@"initStateCameraUpload" object:nil];
    
    // after 20 sec verify Re
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [[CCNetworking sharedNetworking] automaticDownloadInError];
        [[CCNetworking sharedNetworking] automaticUploadInError];
        
        NSLog(@"[LOG] End Fetch 20 sec.");
    });
    
    // after 25 sec
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        NSArray *records = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session != NULL) AND (session != '')", self.activeAccount] context:nil];
        
        if ([records count] > 0) {
            completionHandler(UIBackgroundFetchResultNewData);
        } else {
            completionHandler(UIBackgroundFetchResultNoData);
        }
        
        NSLog(@"[LOG] End Fetch 25 sec.");
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
    NSLog(@"[LOG] Start completition handler from background - identifier : %@", identifier);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [[CCNetworking sharedNetworking] automaticDownloadInError];
        [[CCNetworking sharedNetworking] automaticUploadInError];
        
        self.backgroundSessionCompletionHandler = completionHandler;
        void (^completionHandler)() = self.backgroundSessionCompletionHandler;
        self.backgroundSessionCompletionHandler = nil;
        completionHandler();
        
        NSLog(@"[LOG] End 25 sec. completition handler - identifier : %@", identifier);
    });
}

- (void)cancelAllOperations
{
    [_netQueue cancelAllOperations];
    
    [_netQueueDownload cancelAllOperations];
    [_netQueueDownloadWWan cancelAllOperations];
    [_netQueueUpload cancelAllOperations];
    [_netQueueUploadWWan cancelAllOperations];
    
    [self performSelector:@selector(updateApplicationIconBadgeNumber) withObject:nil afterDelay:0.5];
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

- (void)loadAutomaticUpload
{
    CCMetadataNet *metadataNet;
    
    // Is loading new Asset or this  ?
    if (_automaticCheckAssetInProgress || _automaticUploadInProgress)
        return;
    
    // START Automatic Upload in progress
    _automaticUploadInProgress = YES;
    
    NSArray *uploadInQueue = [CCCoreData getTableMetadataUploadAccount:app.activeAccount];
    NSArray *recordAutomaticUploadInLock = [CCCoreData getAllLockTableAutomaticUploadForAccount:_activeAccount];
    
    for (TableAutomaticUpload *tableAutomaticUpload in recordAutomaticUploadInLock) {
        
        BOOL recordFound = NO;
        
        for (CCMetadataNet *metadataNet in uploadInQueue) {
            if (metadataNet.assetLocalIdentifier == tableAutomaticUpload.assetLocalIdentifier)
                recordFound = YES;
        }
        
        if (!recordFound)
            [CCCoreData unlockTableAutomaticUploadForAccount:_activeAccount assetLocalIdentifier:tableAutomaticUpload.assetLocalIdentifier];
    }

    // ------------------------- <selectorUploadAutomatic> -------------------------
    
    metadataNet = [CCCoreData getTableAutomaticUploadForAccount:self.activeAccount selector:selectorUploadAutomatic];
    
    while (metadataNet) {
        
        PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadataNet.assetLocalIdentifier] options:nil];
        
        if (result.count) {
            
            [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:metadataNet.assetLocalIdentifier fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl cryptated:metadataNet.cryptated session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:app.activeMain];
            
        } else {
            
            [CCCoreData addActivityClient:metadataNet.fileName fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionUpload selector:selectorUploadAutomatic note:@"Internal error image/video not found [0]" type:k_activityTypeFailure verbose:k_activityVerboseHigh account:_activeAccount activeUrl:_activeUrl];
            
            [CCCoreData deleteTableAutomaticUploadForAccount:_activeAccount assetLocalIdentifier:metadataNet.assetLocalIdentifier];
            
            [self updateApplicationIconBadgeNumber];
        }

        metadataNet = [CCCoreData getTableAutomaticUploadForAccount:self.activeAccount selector:selectorUploadAutomatic];
    }
    
    // ------------------------- <selectorUploadAutomaticAll> -------------------------
    
    // Verify num error MAX 10 after STOP
    NSUInteger errorCount = [TableMetadata MR_countOfEntitiesWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (sessionSelector == %@) AND ((sessionTaskIdentifier == %i) OR (sessionTaskIdentifierPlist == %i))", app.activeAccount, selectorUploadAutomaticAll,k_taskIdentifierError, k_taskIdentifierError]];
    
    if (errorCount >= 10) {
        
        [app messageNotification:@"_error_" description:@"_too_errors_automatic_all_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
        
        // STOP Im progress
        _automaticUploadInProgress = NO;
        
        return;
    }
    
    NSUInteger count = [TableMetadata MR_countOfEntitiesWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (sessionSelector == %@) AND ((sessionTaskIdentifier > 0) OR (sessionTaskIdentifierPlist > 0))", app.activeAccount, selectorUploadAutomaticAll]];
    
    if (count >= k_maxConcurrentOperationDownloadUpload) {
        
        // STOP Im progress
        _automaticUploadInProgress = NO;
        
        return;
    }
    
    metadataNet = [CCCoreData getTableAutomaticUploadForAccount:self.activeAccount selector:selectorUploadAutomaticAll];
    if (metadataNet) {
        
        PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadataNet.assetLocalIdentifier] options:nil];
        
        if (result.count) {
            
            [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:metadataNet.assetLocalIdentifier fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl cryptated:metadataNet.cryptated session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:app.activeMain];
            
        } else {
            
            [CCCoreData addActivityClient:metadataNet.fileName fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionUpload selector:selectorUploadAutomatic note:@"Internal error image/video not found [0]" type:k_activityTypeFailure verbose:k_activityVerboseHigh account:_activeAccount activeUrl:_activeUrl];
            
            [CCCoreData deleteTableAutomaticUploadForAccount:_activeAccount assetLocalIdentifier:metadataNet.assetLocalIdentifier];
            
            [self updateApplicationIconBadgeNumber];
        }
    }
    
    // STOP Im progress
    _automaticUploadInProgress = NO;
}

- (void)verifyDownloadUploadInProgress
{
    BOOL callVerifyDownload = NO;
    BOOL callVerifyUpload = NO;
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
        
        NSLog(@"[LOG] Verify Download/Upload in progress now : %@ - Download %@ - Upload %@", [NSDate date], [self.sessionDateLastDownloadTasks dateByAddingTimeInterval:k_timerVerifySession], [self.sessionDateLastUploadTasks dateByAddingTimeInterval:k_timerVerifySession]);
        
        if ([[NSDate date] compare:[self.sessionDateLastDownloadTasks dateByAddingTimeInterval:k_timerVerifySession]] == NSOrderedDescending) {
            
            callVerifyDownload = YES;
            [[CCNetworking sharedNetworking] verifyDownloadInProgress];
        }
        
        if ([[NSDate date] compare:[self.sessionDateLastUploadTasks dateByAddingTimeInterval:k_timerVerifySession]] == NSOrderedDescending) {
            
            callVerifyUpload = YES;
            [[CCNetworking sharedNetworking] verifyUploadInProgress];
        }
        
        if (callVerifyDownload && callVerifyUpload) {
            
            NSLog(@"[LOG] Stop timer verify session");
            
            [self.timerVerifySessionInProgress invalidate];
        }
    }
}

// Notification change session
- (void)sessionChanged:(NSNotification *)notification
{
    NSURLSession *session;
    CCMetadata *metadata;
    NSURLSessionTask *task;
    
    for (id object in notification.object) {
        
        if ([object isKindOfClass:[NSURLSession class]])
            session = object;
        
        if ([object isKindOfClass:[CCMetadata class]])
            metadata = object;
        
        if ([object isKindOfClass:[NSURLSessionTask class]])
            task = object;
    }
    
    /*
    Task
    */
    if ([task isKindOfClass:[NSURLSessionDownloadTask class]])
        app.sessionDateLastDownloadTasks = [NSDate date];

    if ([task isKindOfClass:[NSURLSessionUploadTask class]])
        app.sessionDateLastUploadTasks = [NSDate date];
    
    if (metadata && [_listChangeTask objectForKey:metadata.fileID])
        dispatch_async(dispatch_get_main_queue(), ^{
            [self changeTask:metadata];
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

- (void)changeTask:(CCMetadata *)metadata
{
    NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:metadata.account];
    
    if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"stopUpload"]) {
        
        // sessionTaskIdentifier on Stop
        [CCCoreData setMetadataSession:nil sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierStop sessionTaskIdentifierPlist:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, self.activeAccount] context:nil];
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"reloadUpload"]) {
        
        // V 1.8 if upload_session_wwan change in upload_session
        if ([metadata.session isEqualToString:k_upload_session_wwan])
            metadata.session = k_upload_session;
        
        [[CCNetworking sharedNetworking] uploadFileMetadata:metadata taskStatus:k_taskStatusResume];
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"reloadDownload"]) {
        
        BOOL downloadData = NO, downloadPlist = NO;
            
        if (metadata.sessionTaskIdentifier != k_taskIdentifierDone) downloadData = YES;
        if (metadata.sessionTaskIdentifierPlist != k_taskIdentifierDone) downloadPlist = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:serverUrl downloadData:downloadData downloadPlist:downloadPlist selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost session:k_download_session taskStatus:k_taskStatusResume delegate:nil];
        });
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"cancelUpload"]) {
        
        // remove the file
        [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, app.activeAccount]];
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID] error:nil];
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"cancelDownload"]) {
        
        [CCCoreData setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:k_taskIdentifierDone sessionTaskIdentifierPlist:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, self.activeAccount] context:nil];
    }
    
    // remove ChangeTask (fileID) from the list
    [_listChangeTask removeObjectForKey:metadata.fileID];
    
    // delete progress
    [_listProgressMetadata removeObjectForKey:metadata.fileID];
    
    // Progress Task
    NSDictionary* userInfo = @{@"fileID": (metadata.fileID), @"serverUrl": (serverUrl), @"cryptated": ([NSNumber numberWithBool:NO]), @"progress": ([NSNumber numberWithFloat:0.0])};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NotificationProgressTask" object:nil userInfo:userInfo];

    // Refresh
    if (_activeMain && [_listChangeTask count] == 0) {
        [_activeMain reloadDatasource:[CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:metadata.account] fileID:nil selector:nil];
    }
}

- (BOOL)createFolderSubFolderAutomaticUploadFolderPhotos:(NSString *)folderPhotos useSubFolder:(BOOL)useSubFolder assets:(NSArray *)assets selector:(NSString *)selector
{
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:_activeUser withPassword:_activePassword withUrl:_activeUrl isCryptoCloudMode:NO];

    if(![ocNetworking automaticCreateFolderSync:folderPhotos]) {
        
        // Activity
        [CCCoreData addActivityClient:folderPhotos fileID:@"" action:k_activityDebugActionAutomaticUpload selector:selector note:NSLocalizedStringFromTable(@"_not_possible_create_folder_", @"Error", nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault account:_activeAccount activeUrl:_activeUrl];
        
        return false;
    }
    
    // Create if request the subfolders
    if (useSubFolder) {
        
        for (NSString *dateSubFolder in [CCUtility createNameSubFolder:assets]) {
            
            if(![ocNetworking automaticCreateFolderSync:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder]]) {
                
                // Activity
                [CCCoreData addActivityClient:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder] fileID:@"" action:k_activityDebugActionAutomaticUpload selector:selector note:NSLocalizedString(@"_error_createsubfolders_upload_",nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault account:_activeAccount activeUrl:_activeUrl];
                
                return false;
            }
        }
    }
    
    return true;
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
#pragma mark ===== UPGRADE =====
#pragma --------------------------------------------------------------------------------------------

- (void)upgrade
{
#ifdef DEBUG
   // [CCCoreData flushTableGPS];
   // [CCCoreData setGeoInformationLocalNull];
#endif
    
    NSString *actualVersion = [CCUtility getVersionCryptoCloud];
    
    /* ---------------------- UPGRADE VERSION ----------------------- */
    
    if (([actualVersion compare:@"2.13" options:NSNumericSearch] == NSOrderedAscending)) {
     
        [CCCoreData flushTableDirectoryAccount:nil];
        [CCCoreData flushTableLocalFileAccount:nil];
        [CCCoreData flushTableMetadataAccount:nil];
    }
    
    if (([actualVersion compare:@"2.15" options:NSNumericSearch] == NSOrderedAscending)) {
        
        [CCCoreData flushTableGPS];
        [CCCoreData setGeoInformationLocalNull];
    }
    
    if (([actualVersion compare:@"2.17" options:NSNumericSearch] == NSOrderedAscending)) {
        
        [CCCoreData clearAllDateReadDirectory];
        [CCCoreData flushTableMetadataAccount:nil];
    }
    
    if (([actualVersion compare:@"2.17.1" options:NSNumericSearch] == NSOrderedAscending)) {
        
    }
}

@end
