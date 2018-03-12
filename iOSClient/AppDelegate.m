//
//  AppDelegate.m
//  Nextcloud iOS
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

#import "iRate.h"
#import "AFURLSessionManager.h"
#import "CCNetworking.h"
#import "CCGraphics.h"
#import "CCPhotos.h"
#import "CCSynchronize.h"
#import "CCMain.h"
#import "CCDetail.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "JDStatusBarNotification.h"
#import "NCBridgeSwift.h"
#import "NCAutoUpload.h"

/* Remove comment for activate Firebase and push notification */
//#import "Firebase.h"
//@interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>

@interface AppDelegate () <UNUserNotificationCenterDelegate>
{
    
}
@end

@implementation AppDelegate

+ (void)initialize
{
    [iRate sharedInstance].daysUntilPrompt = 5;
    [iRate sharedInstance].usesUntilPrompt = 5;
    [iRate sharedInstance].promptForNewVersionIfUserRated = true;
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UserAgent": [CCUtility getUserAgent]}];

    //enable preview mode
    //[iRate sharedInstance].previewMode = YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Brand
    if ([NCBrandOptions sharedInstance].use_firebase) {
    
        /* Remove comment for activate Firebase and push notification */
        
        /*
        //In order for this to work, proper GoogleService-Info.plist must be included
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
         */
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

    // create dir Database Nextcloud
    dir = [[dirGroup URLByAppendingPathComponent:appDatabaseNextcloud] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir])
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

    NSError *error = nil;
    [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionNone} ofItemAtPath:dir error:&error];
    
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
        
            [self settingActiveAccount:account.account activeUrl:account.url activeUser:account.user activeUserID:account.userID activePassword:account.password];
        }
    }
    
    // Operation Queue OC Networking
    _netQueue = [[NSOperationQueue alloc] init];
    _netQueue.name = k_queue;
    _netQueue.maxConcurrentOperationCount = k_maxConcurrentOperation;
   
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
    
    // How to hide UINavigationBar 1px bottom line < iOS 11
    [[UINavigationBar appearance] setBackgroundImage:[[UIImage alloc] init] forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    
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
    
    // Verify Lock
    [self verifyLockOnLoadAutoUpload];
    
    // Start Timer
    self.timerProcessAutoDownloadUpload = [NSTimer scheduledTimerWithTimeInterval:k_timerProcessAutoDownloadUpload target:self selector:@selector(processAutoDownloadUpload) userInfo:nil repeats:YES];
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
    // refresh active Main
    if (_activeMain) {
        [_activeMain reloadDatasource];
        [_activeMain readFileReloadFolder];
    }
    
    // refresh Photos tab
    if (_activePhotos) {
        [_activePhotos reloadDatasourceForced];
    }
    
    // Initializations
    [self applicationInitialized];
}

//
// L' applicazione entrerà in primo piano (attivo sempre)
//
- (void)applicationDidBecomeActive:(UIApplication *)application
{
   
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
    NSLog(@"[LOG] bye bye, Nextcloud !");
}

//
// Application Initialized
//
- (void)applicationInitialized
{
    // Test Maintenance
    if (self.maintenanceMode)
        return;

    NSLog(@"[LOG] Update contenttype image for Photos Tab");
    [[CCSynchronize sharedSynchronize] searchContentType:@[@"image/%", @"video/%"] selector:selectorSearchContentType];
    
    // verify Upload
    [self verifyUploadInErrorOrWait];

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
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Login =====
#pragma --------------------------------------------------------------------------------------------

- (void)openLoginView:(id)delegate loginType:(enumLoginType)loginType
{
    BOOL loginWeb = NO;
    
    @synchronized (self) {

        // only for personalized LoginWeb [customer]
        if ([NCBrandOptions sharedInstance].use_login_web_personalized) {
            
            if (_activeLoginWeb == nil) {
                
                _activeLoginWeb = [CCLoginWeb new];
                _activeLoginWeb.delegate = delegate;
                _activeLoginWeb.loginType = loginType;
                _activeLoginWeb.urlBase = [[NCBrandOptions sharedInstance] loginBaseUrl];
                
                dispatch_async(dispatch_get_main_queue(), ^ {
                    [_activeLoginWeb presentModalWithDefaultTheme:delegate];
                });
            }
            return;
        }
        
        // ------------------- Nextcloud -------------------------
        //
        
        // Login flow : LoginWeb
        if (loginType == loginModifyPasswordUser) {
            tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
            if (account.loginFlow)
                loginWeb = YES;
        }
            
        if (loginWeb) {
            
            if (_activeLoginWeb == nil) {
                
                _activeLoginWeb = [CCLoginWeb new];
                _activeLoginWeb.delegate = delegate;
                _activeLoginWeb.loginType = loginType;
                _activeLoginWeb.urlBase = self.activeUrl;

                dispatch_async(dispatch_get_main_queue(), ^ {
                    [_activeLoginWeb presentModalWithDefaultTheme:delegate];
                });
            }
            
        } else {
            
            if (_activeLogin == nil) {
                
                _activeLogin = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
                _activeLogin.delegate = delegate;
                _activeLogin.loginType = loginType;
                
                dispatch_async(dispatch_get_main_queue(), ^ {
                    [delegate presentViewController:_activeLogin animated:YES completion:nil];
                });
            }
        }
        
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Setting Active Account for all APP =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activeUserID:(NSString *)activeUserID activePassword:(NSString *)activePassword
{
    self.activeAccount = activeAccount;
    self.activeUrl = activeUrl;
    self.activeUser = activeUser;
    self.activeUserID = activeUserID;
    self.activePassword = activePassword;
    
    self.directoryUser = [CCUtility getDirectoryActiveUser:activeUser activeUrl:activeUrl];
    
    // Setting Account to CCNetworking
    [[CCNetworking sharedNetworking] settingAccount];
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

/* Remove comment for activate Firebase and push notification */

/*
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // test
    if (self.activeAccount.length == 0)
        return;
    
    // FIREBASE registered token
    
    [[FIRInstanceID instanceID] setAPNSToken:deviceToken type:FIRInstanceIDAPNSTokenTypeSandbox];
    NSString *pushToken = [[FIRInstanceID instanceID] token];
    // NSString *pushToken = [[[[deviceToken description] stringByReplacingOccurrencesOfString: @"<" withString: @""] stringByReplacingOccurrencesOfString: @">" withString: @""] stringByReplacingOccurrencesOfString: @" " withString: @""];
    
    NSString *pushTokenHash = [[NCEndToEndEncryption sharedManager] createSHA512:pushToken];
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
*/

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

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
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

/* Remove comment for activate Firebase and push notification */

#pragma FIREBASE
/*
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
*/

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Quick Actions - ShotcutItem =====
#pragma --------------------------------------------------------------------------------------------

- (void)configDynamicShortcutItems
{
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;

    UIApplicationShortcutIcon *shortcutPhotosIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:@"quickActionPhotos"];
    UIApplicationShortcutIcon *shortcutUploadIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:@"quickActionUpload"];
    
    UIApplicationShortcutItem *shortcutPhotos = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.photos", bundleId] localizedTitle:NSLocalizedString(@"_photo_camera_", nil) localizedSubtitle:nil icon:shortcutPhotosIcon userInfo:nil];
    UIApplicationShortcutItem *shortcutUpload = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.upload", bundleId] localizedTitle:NSLocalizedString(@"_upload_file_", nil) localizedSubtitle:nil icon:shortcutUploadIcon userInfo:nil];
   
    // add the array to our app
    if (shortcutUpload && shortcutPhotos)
        [UIApplication sharedApplication].shortcutItems = @[shortcutUpload, shortcutPhotos];
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
                    [[CCQuickActions quickActionsManager] startQuickActionsViewController:_activeMain];
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
                    [[CCQuickActions quickActionsManager] startQuickActionsViewController:_activeMain];
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
                    [JDStatusBarNotification showWithStatus:NSLocalizedString(@"_network_available_", nil) dismissAfter:delay styleName:JDStatusBarStyleDefault];
                
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

- (void)updateApplicationIconBadgeNumber
{
    // Test Maintenance
    if (self.maintenanceMode)
        return;
    
    NSInteger total = 0;
    
    // Total
    total = [[CCNetworking sharedNetworking] getNumDownloadInProgressWWan:NO] + [[CCNetworking sharedNetworking] getNumDownloadInProgressWWan:YES] + [[CCNetworking sharedNetworking] getNumUploadInProgressWWan:NO] + [[CCNetworking sharedNetworking] getNumUploadInProgressWWan:YES];
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = total;
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    
    if ([[splitViewController.viewControllers firstObject] isKindOfClass:[UITabBarController class]]) {
        
        UITabBarController *tbc = [splitViewController.viewControllers firstObject];
        
        UITabBarItem *tbItem = [tbc.tabBar.items objectAtIndex:0];
        
        if (total > 0) {
            [tbItem setBadgeValue:[NSString stringWithFormat:@"%li", (unsigned long)total]];
        } else {
            [tbItem setBadgeValue:nil];
            
            NSDictionary* userInfo = @{@"fileID": @"", @"serverUrl": @"", @"progress": [NSNumber numberWithFloat:0]};
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== TabBarController =====
#pragma --------------------------------------------------------------------------------------------

- (void)createTabBarController:(UITabBarController *)tabBarController
{
    UITabBarItem *item;
    NSLayoutConstraint *constraint;
    CGFloat multiplier = 0;
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom/2;
    }
    
    [self aspectTabBar:tabBarController.tabBar hidden:NO];
    
    // File
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
    [item setTitle:NSLocalizedString(@"_home_", nil)];
    item.image = [UIImage imageNamed:@"tabBarFiles"];
    item.selectedImage = [UIImage imageNamed:@"tabBarFiles"];
    
    // Favorites
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFavorite];
    [item setTitle:NSLocalizedString(@"_favorites_", nil)];
    item.image = [UIImage imageNamed:@"tabBarFavorite"];
    item.selectedImage = [UIImage imageNamed:@"tabBarFavorite"];
    
    // (PLUS)
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexPlusHide];
    item.title = @"";
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] color:[UIColor clearColor]];
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
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] color:[NCBrandColor sharedInstance].brandElement];
    UIButton *buttonPlus = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonPlus.tag = 99;
    [buttonPlus setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [buttonPlus setBackgroundImage:buttonImage forState:UIControlStateHighlighted];
    [buttonPlus addTarget:self action:@selector(handleTouchTabbarCenter:) forControlEvents:UIControlEventTouchUpInside];
    
    [buttonPlus setTranslatesAutoresizingMaskIntoConstraints:NO];
    [tabBarController.tabBar addSubview:buttonPlus];
    
    constraint =[NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
    [tabBarController.view addConstraint:constraint];
    
    multiplier = 1 * (tabBarController.tabBar.frame.size.height - safeAreaBottom) / tabBarController.tabBar.frame.size.height;
    constraint =[NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterY multiplier:multiplier constant:0];
    [tabBarController.view addConstraint:constraint];
    
    multiplier = 0.8 * (tabBarController.tabBar.frame.size.height - safeAreaBottom) / tabBarController.tabBar.frame.size.height;
    
    constraint =[NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeHeight multiplier:multiplier constant:0];
    [tabBarController.view addConstraint:constraint];
    
    constraint =[NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeHeight multiplier:multiplier constant:0];
    [tabBarController.view addConstraint:constraint];
}

- (void)aspectNavigationControllerBar:(UINavigationBar *)nav online:(BOOL)online hidden:(BOOL)hidden
{
    nav.translucent = NO;
    nav.barTintColor = [NCBrandColor sharedInstance].brand;
    nav.tintColor = [NCBrandColor sharedInstance].brandText;
    [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : [NCBrandColor sharedInstance].brandText}];
    // Change bar bottom line shadow
    nav.shadowImage = [CCGraphics generateSinglePixelImageWithColor:[NCBrandColor sharedInstance].brand];
    
    if (!online)
        [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : [NCBrandColor sharedInstance].connectionNo}];
    
    nav.hidden = hidden;
    
    [nav setAlpha:1];
}

- (void)aspectTabBar:(UITabBar *)tab hidden:(BOOL)hidden
{
    tab.translucent = NO;
    tab.barTintColor = [NCBrandColor sharedInstance].tabBar;
    tab.tintColor = [NCBrandColor sharedInstance].brandElement;
    
    tab.hidden = hidden;
    
    [tab setAlpha:1];
}

- (void)plusButtonVisibile:(BOOL)visible
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    UIButton *buttonPlus = [tabBarController.view viewWithTag:99];
    
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] color:[NCBrandColor sharedInstance].brandElement];
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
    
    UIView *view = [[(UIButton *)sender superview] superview];
    
    CreateMenuAdd *menuAdd = [[CreateMenuAdd alloc] initWithThemingColor:[NCBrandColor sharedInstance].brandElement];
    [menuAdd createMenuWithView:view];
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

- (NSString *)getTabBarControllerActiveServerUrl
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];

    NSString *serverUrl = [CCUtility getHomeServerUrlActiveUrl:self.activeUrl];
    NSInteger index = tabBarController.selectedIndex;
    
    // select active serverUrl
    if (index == k_tabBarApplicationIndexFile) {
        serverUrl = self.activeMain.serverUrl;
    } else if (index == k_tabBarApplicationIndexFavorite) {
        if (self.activeFavorites.serverUrl)
            serverUrl = self.activeFavorites.serverUrl;
    } else if (index == k_tabBarApplicationIndexPhotos) {
        serverUrl = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:self.activeUrl];
    }
    
    return serverUrl;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Theming Color =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingThemingColorBrand
{
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    if ([NCBrandOptions sharedInstance].use_themingColor) {
        
        tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilites];

        [CCGraphics settingThemingColor:capabilities.themingColor themingColorElement:capabilities.themingColorElement themingColorText:capabilities.themingColorText];
            
    } else {
    
        [NCBrandColor sharedInstance].brand = [NCBrandColor sharedInstance].customer;
        [NCBrandColor sharedInstance].brandElement = [NCBrandColor sharedInstance].customer;
        [NCBrandColor sharedInstance].brandText = [NCBrandColor sharedInstance].customerText;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"changeTheming" object:nil];
}

- (void)changeTheming:(UIViewController *)vc
{
    // Change Navigation & TabBar color
    vc.navigationController.navigationBar.barTintColor = [NCBrandColor sharedInstance].brand;
    vc.tabBarController.tabBar.tintColor = [NCBrandColor sharedInstance].brandElement;
    // Change bar bottom line shadow
    vc.navigationController.navigationBar.shadowImage = [CCGraphics generateSinglePixelImageWithColor:[NCBrandColor sharedInstance].brand];
    
    // Change button Plus
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    UIButton *button = [tabBarController.view viewWithTag:99];
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] color:[NCBrandColor sharedInstance].brandElement];
    
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [button setBackgroundImage:buttonImage forState:UIControlStateHighlighted];
    
    // Tint Color GLOBAL WINDOW
    [self.window setTintColor:[NCBrandColor sharedInstance].textView];
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
    
    // verify Upload
    [self verifyUploadInErrorOrWait];
    
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
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler
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

- (void)addNetworkingOperationQueue:(NSOperationQueue *)netQueue delegate:(id)delegate metadataNet:(CCMetadataNet *)metadataNet
{
    id operation;
    
    operation = [[OCnetworking alloc] initWithDelegate:delegate metadataNet:metadataNet withUser:_activeUser withUserID:_activeUserID withPassword:_activePassword withUrl:_activeUrl];
        
    [operation setQueuePriority:metadataNet.priority];
    
    [netQueue addOperation:operation];
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
    if (!serverUrl) return;
    
    if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"stopUpload"]) {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierStop predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
    }
    else if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"reloadUpload"]) {
        
        // V 1.8 if upload_session_wwan change in upload_session
        if ([metadata.session isEqualToString:k_upload_session_wwan])
            metadata.session = k_upload_session;
        
        [[CCNetworking sharedNetworking] uploadFileMetadata:metadata taskStatus:k_taskStatusResume];
    }
    else if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"reloadDownload"]) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] downloadFile:metadata.fileName fileID:fileID serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost session:k_download_session taskStatus:k_taskStatusResume delegate:self.activeMain];
        });
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"cancelUpload"]) {
        
        // remove the file
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", self.directoryUser, fileID] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", self.directoryUser, fileID] error:nil];
        
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID] clearDateReadDirectoryID:nil];
    }
    else if ([[_listChangeTask objectForKey:fileID] isEqualToString:@"cancelDownload"]) {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
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
#pragma mark ===== Process Auto Upload < k_timerProcess seconds > =====
#pragma --------------------------------------------------------------------------------------------

- (void)processAutoDownloadUpload
{
    // Test Maintenance
    if (self.maintenanceMode)
        return;
    
    // BACKGROND & FOREGROUND
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        
        // ONLY BACKGROUND
        NSLog(@"[LOG] -PROCESS-AUTO-UPLOAD-");
        [self performSelectorOnMainThread:@selector(loadAutoDownloadUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUploadBackground] waitUntilDone:NO];
        
    } else {
        
        // ONLY FOREFROUND
        NSLog(@"[LOG] -PROCESS-AUTO-UPLOAD-");
        [self performSelectorOnMainThread:@selector(loadAutoDownloadUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUpload] waitUntilDone:NO];
    }
}

- (void)loadAutoDownloadUpload:(NSNumber *)maxConcurrent
{
    CCMetadataNet *metadataNet;
    
    // E2EE : not in background
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        metadataNet = [[NCManageDatabase sharedInstance] getQueueUploadLock];
        if (metadataNet) {
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@ AND e2eEncrypted = 1", self.activeAccount, metadataNet.serverUrl]];
            if (directory != nil)
                return;
        }
    }
    
    // Stop Timer
    [_timerProcessAutoDownloadUpload invalidate];
    
    NSInteger maxConcurrentDownloadUpload = [maxConcurrent integerValue];
    
    NSInteger counterDownloadInSession = [[[NCManageDatabase sharedInstance] getTableMetadataDownload] count] + [[[NCManageDatabase sharedInstance] getTableMetadataDownloadWWan] count];
    NSInteger counterUploadInSessionAndInLock = [[[NCManageDatabase sharedInstance] getTableMetadataUpload] count] + [[[NCManageDatabase sharedInstance] getTableMetadataUploadWWan] count] + [[[NCManageDatabase sharedInstance] getLockQueueUpload] count];
    NSInteger counterUploadInLock = [[[NCManageDatabase sharedInstance] getQueueUploadWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND lock = true", self.activeAccount]] count];

    NSInteger counterNewUpload = 0;
    
    // ------------------------- <selector Auto Download> -------------------------
    
    while (counterDownloadInSession < maxConcurrentDownloadUpload) {
        
        metadataNet = [[NCManageDatabase sharedInstance] getQueueDownload];
        if (metadataNet) {
            
            [[CCNetworking sharedNetworking] downloadFile:metadataNet.fileName fileID:metadataNet.fileID serverUrl:metadataNet.serverUrl selector:metadataNet.selector selectorPost:metadataNet.selectorPost session:metadataNet.session taskStatus:metadataNet.taskStatus delegate:self.activeMain];
            
        } else
            break;
        
        counterDownloadInSession = [[[NCManageDatabase sharedInstance] getTableMetadataDownload] count] + [[[NCManageDatabase sharedInstance] getTableMetadataDownloadWWan] count];
    }
    
    // ------------------------- <selector Auto Upload> -------------------------
    
    if (counterUploadInSessionAndInLock < maxConcurrentDownloadUpload && counterUploadInLock < 1) {
        
        metadataNet = [[NCManageDatabase sharedInstance] getQueueUploadLockWithSelector:selectorUploadAutoUpload];
        if (metadataNet) {
            
            [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:metadataNet delegate:_activeMain];
            
            counterNewUpload++;
        }
        
        counterUploadInSessionAndInLock = [[[NCManageDatabase sharedInstance] getTableMetadataUpload] count] + [[[NCManageDatabase sharedInstance] getTableMetadataUploadWWan] count] + [[[NCManageDatabase sharedInstance] getLockQueueUpload] count];
    }
    
    // ------------------------- <selector Auto Upload All> ----------------------
    
    // Verify num error k_maxErrorAutoUploadAll after STOP (100)
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND sessionSelector = %@ AND sessionTaskIdentifier = %i", _activeAccount, selectorUploadAutoUploadAll, k_taskIdentifierError] sorted:nil ascending:NO];
    
    NSInteger errorCount = [metadatas count];
    
    if (errorCount >= k_maxErrorAutoUploadAll) {
        
        [self messageNotification:@"_error_" description:@"_too_errors_automatic_all_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
        
        [[NCManageDatabase sharedInstance] addActivityClient:@"" fileID:@"" action:k_activityDebugActionAutoUpload selector:selectorUploadAutoUploadAll note:@"_too_errors_automatic_all_" type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];

    } else {
        
        if (counterUploadInSessionAndInLock < maxConcurrentDownloadUpload && counterUploadInLock < 1) {
            
            metadataNet = [[NCManageDatabase sharedInstance] getQueueUploadLockWithSelector:selectorUploadAutoUploadAll];
            if (metadataNet) {
                
                [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:metadataNet delegate:_activeMain];
                
                counterNewUpload++;
            }
            
            counterUploadInSessionAndInLock = [[[NCManageDatabase sharedInstance] getTableMetadataUpload] count] + [[[NCManageDatabase sharedInstance] getTableMetadataUploadWWan] count] + [[[NCManageDatabase sharedInstance] getLockQueueUpload] count];
        }
    }
    
    // ------------------------- <selector Upload File> -------------------------
    
    if (counterUploadInSessionAndInLock < maxConcurrentDownloadUpload && counterUploadInLock < 1) {
        
        metadataNet = [[NCManageDatabase sharedInstance] getQueueUploadLockWithSelector:selectorUploadFile];
        if (metadataNet) {
            
            [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:metadataNet delegate:_activeMain];
            
            counterNewUpload++;
        }
        
        counterUploadInSessionAndInLock = [[[NCManageDatabase sharedInstance] getTableMetadataUpload] count] + [[[NCManageDatabase sharedInstance] getTableMetadataUploadWWan] count] + [[[NCManageDatabase sharedInstance] getLockQueueUpload] count];
    }
    
    // Start Timer
    _timerProcessAutoDownloadUpload = [NSTimer scheduledTimerWithTimeInterval:k_timerProcessAutoDownloadUpload target:self selector:@selector(processAutoDownloadUpload) userInfo:nil repeats:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Process Verify =====
#pragma --------------------------------------------------------------------------------------------

- (void)verifyLockOnLoadAutoUpload
{
    // Test Maintenance
    if (self.maintenanceMode || self.activeAccount.length == 0)
        return;
    
    NSInteger counterUploadInSession = [[[NCManageDatabase sharedInstance] getTableMetadataUpload] count] + [[[NCManageDatabase sharedInstance] getTableMetadataUploadWWan] count];
    NSArray *tableMetadatasInLock = [[NCManageDatabase sharedInstance] getLockQueueUpload];
     
     if (counterUploadInSession == 0 && [tableMetadatasInLock count] > 0) {
     
         // Unlock
         for (tableMetadata *metadata in tableMetadatasInLock) {
     
             if ([[NCManageDatabase sharedInstance] isTableInvalidated:metadata] == NO)
                 [[NCManageDatabase sharedInstance] unlockQueueUploadWithAssetLocalIdentifier:metadata.assetLocalIdentifier];
         }
     }
}

- (void)verifyUploadInErrorOrWait
{
    NSMutableSet *directoryIDs = [NSMutableSet new];
    
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND session CONTAINS 'upload' AND (sessionTaskIdentifier = %i OR sessionTaskIdentifier = %i)", _activeAccount, k_taskIdentifierError, k_taskIdentifierWaitStart] sorted:nil ascending:NO];
    
    NSLog(@"[LOG] Verify re upload in error n. %lu", (unsigned long)[metadatas count]);
    
    for (tableMetadata *metadata in metadatas) {
        
        [[CCNetworking sharedNetworking] uploadFileMetadata:metadata taskStatus: k_taskStatusResume];
        
        [directoryIDs addObject:metadata.directoryID];
        
        NSLog(@"[LOG] Re upload file : %@", metadata.fileName);
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
#pragma mark ===== Maintenance Mode =====
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
    
    // VERSION < 2.17.6

    if (([actualVersion compare:@"2.17.6" options:NSNumericSearch] == NSOrderedAscending)) {
        
        // Remove All old Photo Library
        [[NCManageDatabase sharedInstance] clearTable:[tablePhotoLibrary class] account:nil];
    }
    
    // VERSION == 2.17.6
    if ([actualVersion isEqualToString:@"2.17.6"]) {
        
        // Build < 10
        if (([actualBuild compare:@"10" options:NSNumericSearch] == NSOrderedAscending) || actualBuild == nil) {
            
            // Remove All old Photo Library
            //[[NCManageDatabase sharedInstance] clearTable:[tablePhotoLibrary class] account:nil];
        }
    }
    
    // VERSION < 2.19.1
    
    if (([actualVersion compare:@"2.19.1" options:NSNumericSearch] == NSOrderedAscending)) {

        [[NCManageDatabase sharedInstance] clearTable:[tableMetadata class] account:nil];
        [[NCManageDatabase sharedInstance] setClearAllDateReadDirectory];
    }
    
    return YES;
}

@end
