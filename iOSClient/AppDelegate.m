//
//  AppDelegate.m
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

#import "AppDelegate.h"
#import "CCNetworking.h"
#import "CCGraphics.h"
#import "CCSynchronize.h"
#import "CCMain.h"
#import "CCDetail.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "NCBridgeSwift.h"
#import "NCAutoUpload.h"
#import "NCPushNotificationEncryption.h"

@class NCViewerRichdocument;

@interface AppDelegate () <UNUserNotificationCenterDelegate>
{
PKPushRegistry *pushRegistry;
}
@end

@implementation AppDelegate

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UserAgent": [CCUtility getUserAgent]}];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [CCUtility createDirectoryStandard];
    
    // Networking
    [[NCCommunicationCommon sharedInstance] setupWithUserAgent:[CCUtility getUserAgent] capabilitiesGroup:[NCBrandOptions sharedInstance].capabilitiesGroups delegate:[NCNetworking sharedInstance]];
    
    // Verify upgrade
    if ([self upgrade]) {
        // Set account, if no exists clear all
        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (tableAccount == nil) {
            // remove all the keys Chain
            [CCUtility deleteAllChainStore];
            // remove all the App group key
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
        } else {
            [self settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activeUserID:tableAccount.userID activePassword:[CCUtility getPassword:tableAccount.account]];
        }
    }
    
    // UserDefaults
    self.ncUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:[NCBrandOptions sharedInstance].capabilitiesGroups];
    
    // Filter ocId
    self.filterocId = [NSMutableArray new];

    // Upload Pending In Upload (crash)
    self.sessionPendingStatusInUpload = [NSMutableArray new];
    
    // Initialization Notification
    self.listOfNotifications = [NSMutableArray new];
    
    // Background Fetch
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    // Initialization List
    self.listProgressMetadata = [[NSMutableDictionary alloc] init];
    self.listMainVC = [[NSMutableDictionary alloc] init];
    
    // Push Notification
//    pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
//    pushRegistry.delegate = self;
//    pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    [application registerForRemoteNotifications];
    
    // Display notification (sent via APNS)
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
    }];
    
    // setting Reachable in back
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        self.reachability = [Reachability reachabilityForInternetConnection];
    
        self.lastReachability = [self.reachability isReachable];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
        [self.reachability startNotifier];
    });
    
    //AV Session
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:nil];
    // [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    // APPEARANCE: How to hide UINavigationBar 1px bottom line < iOS 11
    [[UINavigationBar appearance] setBackgroundImage:[[UIImage alloc] init] forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    [UINavigationBar appearance].translucent = NO;
    
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
    self.timerProcessAutoDownloadUpload = [NSTimer scheduledTimerWithTimeInterval:k_timerProcessAutoDownloadUpload target:self selector:@selector(loadAutoDownloadUpload) userInfo:nil repeats:YES];
    self.timerUpdateApplicationIconBadgeNumber = [NSTimer scheduledTimerWithTimeInterval:k_timerUpdateApplicationIconBadgeNumber target:self selector:@selector(updateApplicationIconBadgeNumber) userInfo:nil repeats:YES];
    [self startTimerErrorNetworking];

    // Fabric
    if (![CCUtility getDisableCrashservice] && NCBrandOptions.sharedInstance.disable_crash_service == false) {
        [Fabric with:@[[Crashlytics class]]];
    }
    
    // Store review
    if ([[NCUtility sharedInstance] isSimulatorOrTestFlight] == false) {
        NCStoreReview *review = [NCStoreReview new];
        [review incrementAppRuns];
        [review showStoreReview];
    }
    
    // Detect Dark mode
    if (@available(iOS 13.0, *)) {
        if ([CCUtility getDarkModeDetect]) {
            if ([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
                [CCUtility setDarkMode:YES];
            } else {
                [CCUtility setDarkMode:NO];
            }
        }
    }
    
    if ([NCBrandOptions sharedInstance].disable_intro) {
        [CCUtility setIntro:YES];
        
        if (self.activeAccount.length == 0) {
            [self openLoginView:nil selector:k_intro_login openLoginWeb:false];
        }
    } else {
        if ([CCUtility getIntro] == NO) {
            UIViewController *introViewController = [[UIStoryboard storyboardWithName:@"NCIntro" bundle:[NSBundle mainBundle]] instantiateInitialViewController];
            
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: introViewController];
            self.window.rootViewController = navController;
            [self.window makeKeyAndVisible];
        }
    }

    // init home
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil userInfo:nil];
    
    return YES;
}

//
// L' applicazione si dimetterà dallo stato di attivo
//
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Test Maintenance
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
        
    [self updateApplicationIconBadgeNumber];
}

//
// L' applicazione entrerà in primo piano (attivo solo dopo il background)
//
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Test Maintenance
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    NSLog(@"[LOG] Request Service Server Nextcloud");
    [[NCService sharedInstance] startRequestServicesServer];
    
    NSLog(@"[LOG] Initialize Auto upload");
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    NSLog(@"[LOG] Read active directory");
    [self.activeMain readFileReloadFolder];
    
    NSLog(@"[LOG] Required unsubscribing / subscribing");
    [self pushNotification];
    
    NSLog(@"[LOG] RichDocument");
    if (self.activeDetail.richDocument) {
        [self.activeDetail.richDocument grabFocus];
    }
}

//
// L' applicazione entrerà in primo piano (attivo sempre)
//
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Test Maintenance
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    // middelware ping
    if ([[NCBrandOptions sharedInstance] use_middlewarePing]) {
        NSLog(@"[LOG] Middleware Ping");
        [[NCService sharedInstance] middlewarePing];
    }
    
    // Brand
#if defined(HC)
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    if (account.hcIsTrial == true || account.hcTrialExpired == true || account.hcNextGroupExpirationGroupExpired == true) {
        
        HCTrial *vc = [[UIStoryboard storyboardWithName:@"HCTrial" bundle:nil] instantiateInitialViewController];
        vc.account = account;
        
        [self.window.rootViewController presentViewController:vc animated:YES completion:nil];
    }
#endif
}

//
// L' applicazione è entrata nello sfondo
//
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"[LOG] Enter in Background");
    
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Login / checkErrorNetworking =====
#pragma --------------------------------------------------------------------------------------------

- (void)checkErrorNetworking
{
    // test
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    // check unauthorized server (401)
    if ([CCUtility getPassword:self.activeAccount].length == 0) {
        
        [self openLoginView:self.window.rootViewController selector:k_intro_login openLoginWeb:true];
    }
    
    // check certificate untrusted (-1202)
    if ([CCUtility getCertificateError:self.activeAccount]) {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_ssl_certificate_untrusted_", nil) message:NSLocalizedString(@"_connect_server_anyway_", nil)  preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_yes_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[NCNetworking sharedInstance] wrtiteCertificateWithDirectoryCertificate:[CCUtility getDirectoryCerificates]];
            [self startTimerErrorNetworking];
        }]];
                       
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_no_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self startTimerErrorNetworking];
        }]];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:^{
            // Stop timer error network
            [self.timerErrorNetworking invalidate];
        }];
    }
}

- (void)openLoginView:(UIViewController *)viewController selector:(NSInteger)selector openLoginWeb:(BOOL)openLoginWeb
{
        // use appConfig [MDM]
        if ([NCBrandOptions sharedInstance].use_configuration) {
            
            if (!(_appConfigView.isViewLoaded && _appConfigView.view.window)) {
            
                self.appConfigView = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCAppConfigView"];
                
                [self showLoginViewController:self.appConfigView forContext:viewController];
            }
        
            return;
        }
        
        // only for personalized LoginWeb [customer]
        if ([NCBrandOptions sharedInstance].use_login_web_personalized) {
            
            if (!(_activeLoginWeb.isViewLoaded && _activeLoginWeb.view.window)) {
                
                self.activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
                self.activeLoginWeb.urlBase = [[NCBrandOptions sharedInstance] loginBaseUrl];

                [self showLoginViewController:self.activeLoginWeb forContext:viewController];
            }
            
            return;
        }
        
        // normal login
        if (selector == k_intro_signup) {
            
            if (!(_activeLoginWeb.isViewLoaded && _activeLoginWeb.view.window)) {
                
                self.activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
                
                if (selector == k_intro_signup) {
                    self.activeLoginWeb.urlBase = [[NCBrandOptions sharedInstance] linkloginPreferredProviders];
                } else {
                    self.activeLoginWeb.urlBase = self.activeUrl;
                }
                
               [self showLoginViewController:self.activeLoginWeb forContext:viewController];
            }
            
        } else if ([NCBrandOptions sharedInstance].disable_intro && [NCBrandOptions sharedInstance].disable_request_login_url) {
            
            self.activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
            self.activeLoginWeb.urlBase = [[NCBrandOptions sharedInstance] loginBaseUrl];
            
            [self showLoginViewController:self.activeLoginWeb forContext:viewController];
            
        } else if (openLoginWeb) {
            
            if (!(_activeLoginWeb.isViewLoaded && _activeLoginWeb.view.window)) {
                self.activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
                self.activeLoginWeb.urlBase = self.activeUrl;

                [self showLoginViewController:self.activeLoginWeb forContext:viewController];
            }
            
        } else {
            
            if (!(_activeLogin.isViewLoaded && _activeLogin.view.window)) {
                
                _activeLogin = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
                
                [self showLoginViewController:_activeLogin forContext:viewController];
            }
        }
}

-(void)showLoginViewController:(UIViewController *)viewController forContext:(UIViewController *)contextViewController
{
    if (contextViewController == NULL) {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navController.navigationBar.tintColor = NCBrandColor.sharedInstance.customerText;
        navController.navigationBar.barTintColor = NCBrandColor.sharedInstance.customer;
        self.window.rootViewController = navController;
        [self.window makeKeyAndVisible];
        
    } else if ([contextViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = ((UINavigationController *)contextViewController);
        [navController pushViewController:viewController animated:true];
        
    } else {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
        navController.navigationBar.tintColor = NCBrandColor.sharedInstance.customerText;
        navController.navigationBar.barTintColor = NCBrandColor.sharedInstance.customer;
        [contextViewController presentViewController:navController animated:true completion:nil];
    }
}

- (void)startTimerErrorNetworking
{
    self.timerErrorNetworking = [NSTimer scheduledTimerWithTimeInterval:k_timerErrorNetworking target:self selector:@selector(checkErrorNetworking) userInfo:nil repeats:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Account =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activeUserID:(NSString *)activeUserID activePassword:(NSString *)activePassword
{
    self.activeAccount = activeAccount;
    self.activeUrl = activeUrl;
    self.activeUser = activeUser;
    self.activeUserID = activeUserID;
    self.activePassword = activePassword;
    tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilitesWithAccount:activeAccount];

    // Setting Account to Networking
    [CCNetworking sharedNetworking].delegate = [NCNetworkingMain sharedInstance];
    
    [[NCNetworking sharedInstance] setupWithAccount:activeAccount delegate:nil];
    [[NCCommunicationCommon sharedInstance] setupWithUsername:activeUser userID:activeUserID password:activePassword userAgent:[CCUtility getUserAgent] capabilitiesGroup:[NCBrandOptions sharedInstance].capabilitiesGroups nextcloudVersion:capabilities.versionMajor delegate:[NCNetworking sharedInstance]];
}

- (void)deleteAccount:(NSString *)account wipe:(BOOL)wipe
{
    [self unsubscribingNextcloudServerPushNotification:account url:self.activeUrl withSubscribing:false];
    [self settingActiveAccount:nil activeUrl:nil activeUser:nil activeUserID:nil activePassword:nil];
    
    /* DELETE ALL FILES LOCAL FS */
    NSArray *results = [[NCManageDatabase sharedInstance] getTableLocalFilesWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account] sorted:@"ocId" ascending:NO];
    for (tableLocalFile *result in results) {
        [CCUtility removeFileAtPath:[CCUtility getDirectoryProviderStorageOcId:result.ocId]];
    }
    // Clear database
    [[NCManageDatabase sharedInstance] clearDatabaseWithAccount:account removeAccount:true];

    [CCUtility clearAllKeysEndToEnd:account];
    [CCUtility clearAllKeysPushNotification:account];
    [CCUtility setCertificateError:account error:false];
    [CCUtility setPassword:account password:nil];
       
    if (wipe) {
        NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
        if ([listAccount count] > 0) {
            NSString *newAccount = listAccount[0];
            tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:newAccount];
            [self settingActiveAccount:newAccount activeUrl:tableAccount.url activeUser:tableAccount.user activeUserID:tableAccount.userID activePassword:[CCUtility getPassword:tableAccount.account]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil userInfo:nil];
        } else {
            [self openLoginView:self.window.rootViewController selector:k_intro_login openLoginWeb:false];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== PushNotification & PushKit Delegate =====
#pragma --------------------------------------------------------------------------------------------

- (void)pushNotification
{
    // test
    if (self.activeAccount.length == 0 || self.maintenanceMode || self.pushKitToken.length == 0)
        return;
    
    for (tableAccount *result in [[NCManageDatabase sharedInstance] getAllAccount]) {
        
        NSString *token = [CCUtility getPushNotificationToken:result.account];
        
        if (![token isEqualToString:self.pushKitToken]) {
            if (token != nil) {
                // unsubscribing + subscribing
                [self unsubscribingNextcloudServerPushNotification:result.account url:result.url withSubscribing:true];
            } else {
                [self subscribingNextcloudServerPushNotification:result.account url:result.url];
            }
        }
    }
}

- (void)subscribingNextcloudServerPushNotification:(NSString *)account url:(NSString *)url
{
    // test
    if (self.activeAccount.length == 0 || self.maintenanceMode || self.pushKitToken.length == 0)
        return;
    
    [[NCPushNotificationEncryption sharedInstance] generatePushNotificationsKeyPair:account];

    NSString *pushTokenHash = [[NCEndToEndEncryption sharedManager] createSHA512:self.pushKitToken];
    NSData *pushPublicKey = [CCUtility getPushNotificationPublicKey:account];
    NSString *pushDevicePublicKey = [[NSString alloc] initWithData:pushPublicKey encoding:NSUTF8StringEncoding];
    
    [[OCNetworking sharedManager] subscribingPushNotificationWithAccount:account url:url pushToken:self.pushKitToken Hash:pushTokenHash devicePublicKey:pushDevicePublicKey completion:^(NSString *accountCompletion, NSString *deviceIdentifier, NSString *deviceIdentifierSignature, NSString *publicKey, NSString *message, NSInteger errorCode) {
        
        if (errorCode == 0 && [accountCompletion isEqualToString:account]) {
            
            NSLog(@"[LOG] Subscribed to Push Notification server & proxy successfully.");
            
            [CCUtility setPushNotificationToken:account token:self.pushKitToken];
            [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:deviceIdentifier];
            [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:deviceIdentifierSignature];
            [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:publicKey];
            
        } else if (errorCode != 0) {
            NSLog(@"[LOG] Subscribed to Push Notification server & proxy error.");
        } else {
            NSLog(@"[LOG] It has been changed user during networking process, error.");
        }
    }];
}

- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account url:(NSString *)url withSubscribing:(BOOL)subscribing
{
    // test
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    NSString *deviceIdentifier = [CCUtility getPushNotificationDeviceIdentifier:account];
    NSString *deviceIdentifierSignature = [CCUtility getPushNotificationDeviceIdentifierSignature:account];
    NSString *publicKey = [CCUtility getPushNotificationSubscribingPublicKey:account];

    [[OCNetworking sharedManager] unsubscribingPushNotificationWithAccount:account url:url deviceIdentifier:deviceIdentifier deviceIdentifierSignature:deviceIdentifierSignature publicKey:publicKey completion:^(NSString *account, NSString *message, NSInteger errorCode) {
       
        if (errorCode == 0) {
            
            NSLog(@"[LOG] Unsubscribed to Push Notification server & proxy successfully.");
            
            [CCUtility setPushNotificationPublicKey:account data:nil];
            [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:nil];
            [CCUtility setPushNotificationPrivateKey:account data:nil];
            [CCUtility setPushNotificationToken:account token:nil];
            [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:nil];
            [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:nil];
            
            if (self.pushKitToken != nil && subscribing) {
                [self subscribingNextcloudServerPushNotification:account url:url];
            }
            
        } else if (errorCode != 0) {
            NSLog(@"[LOG] Unsubscribed to Push Notification server & proxy error.");
        } else {
            NSLog(@"[LOG] It has been changed user during networking process, error.");
        }
    }];
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    //Called when a notification is delivered to a foreground app.
    completionHandler(UNNotificationPresentationOptionAlert);
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(nonnull UNNotificationResponse *)response withCompletionHandler:(nonnull void (^)(void))completionHandler
{
    completionHandler();
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type
{
    self.pushKitToken = [self stringWithDeviceToken:credentials.token];

    [self pushNotification];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    NSString *message = [payload.dictionaryPayload objectForKey:@"subject"];
    
    if (message) {
        NSArray *results = [[NCManageDatabase sharedInstance] getAllAccount];
        for (tableAccount *result in results) {
            if ([CCUtility getPushNotificationPrivateKey:result.account]) {
                NSString *decryptedMessage = [[NCPushNotificationEncryption sharedInstance] decryptPushNotification:message withDevicePrivateKey: [CCUtility getPushNotificationPrivateKey:result.account]];
                if (decryptedMessage) {
                    
                    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
                    
                    NSData *data = [decryptedMessage dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    
                    NSString *app = [json objectForKey:@"app"];
                    NSString *subject = [json objectForKey:@"subject"];
                    //NSInteger notificationId = [[json objectForKey:@"nid"] integerValue];
                    BOOL delete = [[json objectForKey:@"delete"] boolValue];
                    BOOL deleteAll = [[json objectForKey:@"delete-all"] boolValue];

                    if (delete || deleteAll) {
                        
                        // TODO: Delete notifications locally
                        
                    } else {
                        
                        NSURL *url = [NSURL URLWithString:result.url];
                        NSString *domain = [url host];
                    
                        if ([app isEqualToString:@"spreed"]) {
                            content.title = @"Nextcloud Talk";
                            if (results.count > 1) { content.subtitle = [NSString stringWithFormat:@"%@ (%@)", result.displayName, domain]; }
                            if (subject) { content.body = subject; }
                        } else {
                            if (results.count > 1) { content.title = [NSString stringWithFormat:@"%@ (%@)", result.displayName, domain]; }
                            if (subject) { content.body = subject; }
                        }
                    
                        content.sound = [UNNotificationSound defaultSound];

                        /*
                        [[OCNetworking sharedManager] getServerNotification:result.url notificationId:notificationId completion:^(NSDictionary *json, NSString *message, NSInteger errorCode) {
                            //
                        }];
                        */
                    
                        NSString *identifier = [NSString stringWithFormat:@"Notification-%@", [NSDate new]];
                    
                        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1 repeats:NO];
                        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
                    
                        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
                    }
                }
            }
        }
    }
}

- (NSString *)stringWithDeviceToken:(NSData *)deviceToken
{
    const char *data = [deviceToken bytes];
    NSMutableString *token = [NSMutableString string];
    
    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [token appendFormat:@"%02.2hhX", data[i]];
    }
    
    return [token copy];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Quick Actions - ShotcutItem =====
#pragma --------------------------------------------------------------------------------------------

- (void)configDynamicShortcutItems
{
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    UIApplicationShortcutIcon *shortcutMediaIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:@"media"];
    UIApplicationShortcutItem *shortcutMedia = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.media", bundleId] localizedTitle:NSLocalizedString(@"_media_", nil) localizedSubtitle:nil icon:shortcutMediaIcon userInfo:nil];
   
    // add the array to our app
    if (shortcutMedia)
        [UIApplication sharedApplication].shortcutItems = @[shortcutMedia];
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
    NSString *shortcutMedia = [NSString stringWithFormat:@"%@.media", bundleId];
    
    if ([shortcutItem.type isEqualToString:shortcutMedia] && self.activeAccount) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;

            if (splitViewController.isCollapsed) {
            
                UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                for (UINavigationController *nvc in tbc.viewControllers) {
                
                    if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                        [nvc popToRootViewControllerAnimated:NO];
                }
            
                [tbc setSelectedIndex: k_tabBarApplicationIndexMedia];

            } else {
            
                UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                [nvcDetail popToRootViewControllerAnimated:NO];
            
                UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                [tbc setSelectedIndex: k_tabBarApplicationIndexMedia];
            }
        });
        
        handled = YES;
    }
    
    return handled;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== ApplicationIconBadgeNumber =====
#pragma --------------------------------------------------------------------------------------------

- (void)updateApplicationIconBadgeNumber
{
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSInteger counterDownload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status = %d OR status == %d OR status == %d", k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading] sorted:@"fileName" ascending:true] count];
        NSInteger counterUpload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d OR status == %d OR status == %d", k_metadataStatusWaitUpload, k_metadataStatusInUpload, k_metadataStatusUploading] sorted:@"fileName" ascending:true] count];

        NSInteger total = counterDownload + counterUpload;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [UIApplication sharedApplication].applicationIconBadgeNumber = total;
            
            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
            
            if ([[splitViewController.viewControllers firstObject] isKindOfClass:[UITabBarController class]]) {
                
                UITabBarController *tbc = [splitViewController.viewControllers firstObject];
                
                UITabBarItem *tbItem = [tbc.tabBar.items objectAtIndex:0];
                
                if (total > 0) {
                    [tbItem setBadgeValue:[NSString stringWithFormat:@"%li", (unsigned long)total]];
                } else {
                    [tbItem setBadgeValue:nil];
                }
            }
        });
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== TabBarController =====
#pragma --------------------------------------------------------------------------------------------

- (void)createTabBarController:(UITabBarController *)tabBarController
{
    UITabBarItem *item;
    NSLayoutConstraint *constraint;
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
   
    // File
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
    [item setTitle:NSLocalizedString(@"_home_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarFiles"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // Favorites
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFavorite];
    [item setTitle:NSLocalizedString(@"_favorites_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarFavorites"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // (PLUS INVISIBLE)
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexPlusHide];
    item.title = @"";
    item.image = nil;
    item.enabled = false;
    
    // Media
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexMedia];
    [item setTitle:NSLocalizedString(@"_media_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarMedia"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // More
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexMore];
    [item setTitle:NSLocalizedString(@"_more_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarMore"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // Plus Button
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] width:120 height:120 color:NCBrandColor.sharedInstance.brandElement];
    UIButton *buttonPlus = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonPlus.tag = 99;
    [buttonPlus setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [buttonPlus setBackgroundImage:buttonImage forState:UIControlStateHighlighted];
    [buttonPlus addTarget:self action:@selector(handleTouchTabbarCenter:) forControlEvents:UIControlEventTouchUpInside];
    
    [buttonPlus setTranslatesAutoresizingMaskIntoConstraints:NO];
    [tabBarController.tabBar addSubview:buttonPlus];
    
    if (safeAreaBottom > 0) {
        
        // X
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        [tabBarController.view addConstraint:constraint];
        // Y
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeTop multiplier:1.0 constant:5];
        [tabBarController.view addConstraint:constraint];
        // Width
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:40];
        [tabBarController.view addConstraint:constraint];
        // Height
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:40];
        [tabBarController.view addConstraint:constraint];
        
    } else {
        
        // X
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        [tabBarController.view addConstraint:constraint];
        // Y
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0];
        [tabBarController.view addConstraint:constraint];
        // Width
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:33];
        [tabBarController.view addConstraint:constraint];
        // Height
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:33];
        [tabBarController.view addConstraint:constraint];
    }
}

- (void)plusButtonVisibile:(BOOL)visible
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    UIButton *buttonPlus = [tabBarController.view viewWithTag:99];
    
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] multiplier:3 color:NCBrandColor.sharedInstance.brandElement];
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
    
    tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", self.activeAccount, self.activeMain.serverUrl]];
    
    if ([tableDirectory.permissions containsString:@"CK"]) {
        UIViewController *vc = _activeMain.splitViewController.viewControllers[0];
        [self showMenuInViewController: vc];
    } else {
        [[NCContentPresenter shared] messageNotification:@"_warning_" description:@"_no_permission_add_file_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
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
    } else if (index == k_tabBarApplicationIndexMedia) {
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
        
        tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilitesWithAccount:self.activeAccount];

        [CCGraphics settingThemingColor:capabilities.themingColor themingColorElement:capabilities.themingColorElement themingColorText:capabilities.themingColorText];
            
    } else {
    
        NCBrandColor.sharedInstance.brand = NCBrandColor.sharedInstance.customer;
        NCBrandColor.sharedInstance.brandElement = NCBrandColor.sharedInstance.customer;
        NCBrandColor.sharedInstance.brandText = NCBrandColor.sharedInstance.customerText;
    }
    
    [[NCMainCommon sharedInstance] createImagesThemingColor];
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"changeTheming" object:nil];
}

- (void)changeTheming:(UIViewController *)viewController tableView:(UITableView *)tableView collectionView:(UICollectionView *)collectionView form:(BOOL)form
{
    // Dark Mode
    [NCBrandColor.sharedInstance setDarkMode];
    
    // View
    if (form) viewController.view.backgroundColor = NCBrandColor.sharedInstance.backgroundForm;
    else viewController.view.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
        
    // NavigationBar
    if (viewController.navigationController.navigationBar) {
        viewController.navigationController.navigationBar.translucent = NO;
        viewController.navigationController.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand;
        viewController.navigationController.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText;
        if ([self.reachability isReachable]) {
            [viewController.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : NCBrandColor.sharedInstance.brandText}];
        } else {
            [viewController.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : NCBrandColor.sharedInstance.connectionNo}];
        }
        viewController.navigationController.navigationBar.shadowImage = [CCGraphics generateSinglePixelImageWithColor:NCBrandColor.sharedInstance.brand];
        [viewController.navigationController.navigationBar setAlpha:1];
    }
    
    //tabBar
    if (viewController.tabBarController.tabBar) {
        viewController.tabBarController.tabBar.translucent = NO;
        viewController.tabBarController.tabBar.barTintColor = NCBrandColor.sharedInstance.tabBar;
        viewController.tabBarController.tabBar.tintColor = NCBrandColor.sharedInstance.brandElement;
        [viewController.tabBarController.tabBar setAlpha:1];
    }
    
    //tabBar button Plus
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    UIButton *button = [tabBarController.view viewWithTag:99];
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] multiplier:3 color:NCBrandColor.sharedInstance.brandElement];
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [button setBackgroundImage:buttonImage forState:UIControlStateHighlighted];
                
    // TableView
    if (tableView) {
        if (form) tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm;
        else tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
        tableView.separatorColor = NCBrandColor.sharedInstance.separator;
        [tableView reloadData];
    }
    
    // CollectionView
    if (collectionView) {
        if (form) collectionView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm;
        else collectionView.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
        [collectionView reloadData];
    }
    
    // Tint Color GLOBAL WINDOW
    [self.window setTintColor:NCBrandColor.sharedInstance.textView];
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
            
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", self.activeAccount, serverUrl]];
            
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
    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
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
            
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", self.activeAccount, serverUrl]];
            
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
            
            NSLog(@"[LOG] Request Service Server Nextcloud");
            [[NCService sharedInstance] startRequestServicesServer];
        }
        
        NSLog(@"[LOG] Reachability Changed: Reachable");
        
        self.lastReachability = YES;
        
    } else {
        
        if (self.lastReachability == YES) {
            [[NCContentPresenter shared] messageNotification:@"_network_not_available_" description:nil delay:k_dismissAfterSecond type:messageTypeInfo errorCode:kCFURLErrorNotConnectedToInternet];
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
    // Test Maintenance
    if (self.activeAccount.length == 0 || self.maintenanceMode) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }
    
    NSLog(@"[LOG] Start perform Fetch With Completion Handler");
    
    // Verify new photo
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    // after 20 sec
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        NSArray *records = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session != ''"] sorted:nil ascending:NO];
        
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Process Load Download/Upload < k_timerProcess seconds > =====
#pragma --------------------------------------------------------------------------------------------

- (void)loadAutoDownloadUpload
{
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    tableMetadata *metadataForUpload, *metadataForDownload;
    long counterDownload = 0, counterUpload = 0;
    NSUInteger sizeDownload = 0, sizeUpload = 0;
    BOOL isE2EE = false;
    NSMutableArray *uploaded = [NSMutableArray new];
    
    long maxConcurrentOperationDownloadUpload = k_maxConcurrentOperation;
    
    // Detect E2EE
    NSString *saveserverUrl = @"";
    NSArray *metadatasForE2EE = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status != %d", k_metadataStatusNormal] sorted:@"serverUrl" ascending:NO];
    for (tableMetadata *metadata in metadatasForE2EE) {
        if (![saveserverUrl isEqualToString:metadata.serverUrl]) {
            saveserverUrl = metadata.serverUrl;
            if ([[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND e2eEncrypted == 1", metadata.account, metadata.serverUrl]] != nil) {
                isE2EE = true;
                break;
            }
        }
    }
    
    // E2EE : not in background
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground && isE2EE) {
        return;
    }
    
    // E2EE : only 1 operation
    if (isE2EE) {
        maxConcurrentOperationDownloadUpload = 1;
    }
    
    // Stop Timer
    [_timerProcessAutoDownloadUpload invalidate];
    NSArray *metadatasDownload = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d OR status == %d", k_metadataStatusInDownload, k_metadataStatusDownloading] sorted:nil ascending:true];
    NSArray *metadatasUpload = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d OR status == %d", k_metadataStatusInUpload, k_metadataStatusUploading] sorted:nil ascending:true];
    
    // Counter
    counterDownload = [metadatasDownload count];
    counterUpload = [metadatasUpload count];
    
    // Size
    for (tableMetadata *metadata in metadatasDownload) {
        sizeDownload = sizeDownload + metadata.size;
    }
    for (tableMetadata *metadata in metadatasUpload) {
        sizeUpload = sizeUpload + metadata.size;
    }
    
    NSLog(@"%@", [NSString stringWithFormat:@"[LOG] PROCESS-AUTO-UPLOAD | Download %ld - %@ | Upload %ld - %@", counterDownload, [CCUtility transformedSize:sizeDownload], counterUpload, [CCUtility transformedSize:sizeUpload]]);
    
    // ------------------------- <selector Download> -------------------------
    
    while (counterDownload < maxConcurrentOperationDownloadUpload) {
        
        metadataForDownload = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"status == %d", k_metadataStatusWaitDownload] sorted:@"date" ascending:YES];
        if (metadataForDownload) {
            
            metadataForDownload.status = k_metadataStatusInDownload;
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForDownload];
            
            [[CCNetworking sharedNetworking] downloadFile:metadata taskStatus:k_taskStatusResume];
            
            counterDownload++;
            sizeDownload = sizeDownload + metadata.size;
        } else {
            break;
        }
    }
    
    // ------------------------- <selector Upload> -------------------------
    
    while (counterUpload < maxConcurrentOperationDownloadUpload) {
        
        if (sizeUpload > k_maxSizeOperationUpload) {
            break;
        }
        
        metadataForUpload = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d", selectorUploadFile, k_metadataStatusWaitUpload] sorted:@"date" ascending:YES];
        
        // Verify modify file
        if ([uploaded containsObject:[NSString stringWithFormat:@"%@%@%@", metadataForUpload.account, metadataForUpload.serverUrl, metadataForUpload.fileName]]) {
            break;
        }
        
        if (metadataForUpload) {
            
            // Verify modify file
            BOOL isAleadyInUpload = false;
            for (tableMetadata *metadata in metadatasUpload) {
                if ([metadataForUpload.account isEqualToString:metadata.account] && [metadataForUpload.serverUrl isEqualToString:metadata.serverUrl] && [metadataForUpload.fileName isEqualToString:metadata.fileName]) {
                    isAleadyInUpload = true;
                }
            }
            
            if (isAleadyInUpload == false) {
                metadataForUpload.status = k_metadataStatusInUpload;
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                
                [[CCNetworking sharedNetworking] uploadFile:metadata taskStatus:k_taskStatusResume];
                
                counterUpload++;
                sizeUpload = sizeUpload + metadata.size;
                
                // For verify modify file
                [uploaded addObject:[NSString stringWithFormat:@"%@%@%@", metadata.account, metadata.serverUrl, metadata.fileName]];
                
            } else {
                break;
            }
            
        } else {
            break;
        }
    }
    
    // ------------------------- <selector Auto Upload> -------------------------
    
    while (counterUpload < maxConcurrentOperationDownloadUpload) {
        
        if (sizeUpload > k_maxSizeOperationUpload) {
            break;
        }
        
        metadataForUpload = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d", selectorUploadAutoUpload, k_metadataStatusWaitUpload] sorted:@"date" ascending:YES];
        if (metadataForUpload) {
            
            metadataForUpload.status = k_metadataStatusInUpload;
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
            
            [[CCNetworking sharedNetworking] uploadFile:metadata taskStatus:k_taskStatusResume];
            
            counterUpload++;
            sizeUpload = sizeUpload + metadata.size;
        } else {
            break;
        }
    }
    
    // ------------------------- <selector Auto Upload All> ----------------------
    
    // Verify num error k_maxErrorAutoUploadAll after STOP (100)
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %i", selectorUploadAutoUploadAll, k_metadataStatusUploadError] sorted:@"date" ascending:YES];
    NSInteger errorCount = [metadatas count];
    
    if (errorCount >= k_maxErrorAutoUploadAll) {
        
        [[NCContentPresenter shared] messageNotification:@"_error_" description:@"_too_errors_automatic_all_" delay:k_dismissAfterSecond type:messageTypeError errorCode:k_CCErrorInternalError];
        
    } else {
        
        while (counterUpload < maxConcurrentOperationDownloadUpload) {
            
            if (sizeUpload > k_maxSizeOperationUpload) {
                break;
            }
            
            metadataForUpload = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d", selectorUploadAutoUploadAll, k_metadataStatusWaitUpload] sorted:@"session" ascending:YES];
            if (metadataForUpload) {
                
                metadataForUpload.status = k_metadataStatusInUpload;
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                
                [[CCNetworking sharedNetworking] uploadFile:metadata taskStatus:k_taskStatusResume];
                
                counterUpload++;
                sizeUpload = sizeUpload + metadata.size;
            } else {
                break;
            }
        }
    }
    
    // No Download/upload available ? --> remove errors for retry
    //
    if (counterDownload+counterUpload < maxConcurrentOperationDownloadUpload+1) {
        
        NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d OR status == %d", k_metadataStatusDownloadError, k_metadataStatusUploadError] sorted:nil ascending:NO];
        for (tableMetadata *metadata in metadatas) {
            
            if (metadata.status == k_metadataStatusDownloadError)
                metadata.status = k_metadataStatusWaitDownload;
            else if (metadata.status == k_metadataStatusUploadError)
                metadata.status = k_metadataStatusWaitUpload;
            
            (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
        }
    }
    
    // Verify internal error download (lost task)
    //
    NSArray *matadatasInDownloading = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d", k_metadataStatusDownloading] sorted:nil ascending:true];
    for (tableMetadata *metadata in matadatasInDownloading) {
        
        NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            NSURLSessionTask *findTask;
            
            for (NSURLSessionTask *task in downloadTasks) {
                if (task.taskIdentifier == metadata.sessionTaskIdentifier) {
                    findTask = task;
                }
            }
            
            if (!findTask) {
                
                metadata.sessionTaskIdentifier = k_taskIdentifierDone;
                metadata.status = k_metadataStatusWaitDownload;
                
                (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
            }
        }];
    }
    
    // Verify internal error upload (lost task)
    //
    NSArray *metadatasUploading = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session != %@ AND status == %d", k_upload_session_extension, k_metadataStatusUploading] sorted:nil ascending:true];
    for (tableMetadata *metadata in metadatasUploading) {
        
        NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            NSURLSessionTask *findTask;
            
            for (NSURLSessionTask *task in uploadTasks) {
                if (task.taskIdentifier == metadata.sessionTaskIdentifier) {
                    findTask = task;
                }
            }
            
            if (!findTask) {
                
                metadata.sessionTaskIdentifier = k_taskIdentifierDone;
                metadata.status = k_metadataStatusWaitUpload;
                
                (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
            }
        }];
    }
    
    // Upload in pending
    //
    NSArray *metadatasInUpload = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session != %@ AND status == %d AND sessionTaskIdentifier == 0", k_upload_session_extension, k_metadataStatusInUpload] sorted:nil ascending:true];
    for (tableMetadata *metadata in metadatasInUpload) {
        if ([self.sessionPendingStatusInUpload containsObject:metadata.ocId]) {
            metadata.status = k_metadataStatusWaitUpload;
            (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
        } else {
            [self.sessionPendingStatusInUpload addObject:metadata.ocId];
        }
    }
    if (metadatasInUpload.count == 0) {
        [self.sessionPendingStatusInUpload removeAllObjects];
    }
    
    // Start Timer
    _timerProcessAutoDownloadUpload = [NSTimer scheduledTimerWithTimeInterval:k_timerProcessAutoDownloadUpload target:self selector:@selector(loadAutoDownloadUpload) userInfo:nil repeats:YES];
}

- (void)startLoadAutoDownloadUpload
{
    if (self.timerProcessAutoDownloadUpload.isValid) {
        [self performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== OpenURL  =====
#pragma --------------------------------------------------------------------------------------------

// Method called from iOS system to send a file from other app.
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return YES;
    
    NSString *scheme = url.scheme;

    dispatch_time_t timer = 0;
    if (self.activeMain == nil) timer = 1;

    if ([scheme isEqualToString:@"nextcloud"]) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timer * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
            NSString *action = url.host;
            if ([action isEqualToString:@"open-file"]) {
                NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
                NSArray *queryItems = urlComponents.queryItems;
                NSString *user = [CCUtility valueForKey:@"user" fromQueryItems:queryItems];
                NSString *path = [CCUtility valueForKey:@"path" fromQueryItems:queryItems];
                NSString *link = [CCUtility valueForKey:@"link" fromQueryItems:queryItems];
                tableAccount *matchedAccount = nil;

                // verify parameter
                if (user.length == 0 || path.length == 0 || [[NSURL URLWithString:link] host].length == 0) {
                    
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_error_parameter_schema_", nil) preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                    
                    [alertController addAction:okAction];
                    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
                    
                } else {
                
                    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
                    if (account) {
                        NSURL *activeAccountURL = [NSURL URLWithString:account.url];
                        NSString *activeAccountUser = account.user;
                        if ([link containsString:activeAccountURL.host] && [user isEqualToString:activeAccountUser]) {
                            matchedAccount = account;
                        } else {
                            NSArray *accounts = [[NCManageDatabase sharedInstance] getAllAccount];
                            for (tableAccount *account in accounts) {
                                NSURL *accountURL = [NSURL URLWithString:account.url];
                                NSString *accountUser = account.user;
                                if ([link containsString:accountURL.host] && [user isEqualToString:accountUser]) {
                                    matchedAccount = [[NCManageDatabase sharedInstance] setAccountActive:account.account];
                                    [self settingActiveAccount:matchedAccount.account activeUrl:matchedAccount.url activeUser:matchedAccount.user activeUserID:matchedAccount.userID activePassword:[CCUtility getPassword:matchedAccount.account]];
                                    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil userInfo:nil];
                                }
                            }
                        }
                        
                        if (matchedAccount) {
                            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
                            UITabBarController *tbc;
                            
                            if (splitViewController.isCollapsed) {
                                
                                tbc = splitViewController.viewControllers.firstObject;
                                for (UINavigationController *nvc in tbc.viewControllers) {
                                    
                                    if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                                        [nvc popToRootViewControllerAnimated:NO];
                                }
                                
                            } else {
                                
                                UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                                [nvcDetail popToRootViewControllerAnimated:NO];
                                
                                tbc = splitViewController.viewControllers.firstObject;
                            }
                            
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                                
                                [tbc setSelectedIndex: k_tabBarApplicationIndexFile];
                                
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                                    
                                    [self.activeMain.navigationController popToRootViewControllerAnimated:NO];
                                    
                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                                        
                                        NSString *fileNamePath = [NSString stringWithFormat:@"%@%@/%@", matchedAccount.url, k_webDAV, path];
                                        
                                        if ([path containsString:@"/"]) {
                                            
                                            // Push
                                            NSString *directoryName = [[path stringByDeletingLastPathComponent] lastPathComponent];
                                            NSString *serverUrl = [CCUtility deletingLastPathComponentFromServerUrl:[NSString stringWithFormat:@"%@%@/%@", matchedAccount.url, k_webDAV, [path stringByDeletingLastPathComponent]]];
                                            tableMetadata *metadata = [CCUtility createMetadataWithAccount:matchedAccount.account date:[NSDate date] directory:NO ocId:[[NSUUID UUID] UUIDString] serverUrl:serverUrl fileName:directoryName etag:@"" size:0 status:k_metadataStatusNormal url:@"" contentType:@""];
                                            
                                            [self.activeMain performSegueDirectoryWithControlPasscode:true metadata:metadata blinkFileNamePath:fileNamePath];
                                            
                                        } else {
                                            
                                            // Reload folder
                                            NSString *serverUrl = [NSString stringWithFormat:@"%@%@", matchedAccount.url, k_webDAV];
                                            
                                            self.activeMain.blinkFileNamePath = fileNamePath;
                                            [self.activeMain readFolder:serverUrl];
                                        }
                                    });
                                });
                            });
              
                        } else {
                            
                            NSString *domain = [[NSURL URLWithString:link] host];
                            NSString *fileName = [path lastPathComponent];
                            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"_account_not_available_", nil), user, domain, fileName];
                            
                            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                            
                            [alertController addAction:okAction];
                            [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
                        }
                    }
                }
            }
        });
        
        return YES;
    }
    
    NSError *error;
    NSLog(@"[LOG] the path is: %@", url.path);
        
    NSArray *splitedUrl = [url.path componentsSeparatedByString:@"/"];
    self.fileNameUpload = [NSString stringWithFormat:@"%@",[splitedUrl objectAtIndex:([splitedUrl count]-1)]];
    
    if (self.activeAccount) {
        
        [[NSFileManager defaultManager]removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:self.fileNameUpload] error:nil];
        [[NSFileManager defaultManager]moveItemAtPath:url.path toPath:[NSTemporaryDirectory() stringByAppendingString:self.fileNameUpload] error:&error];
        
        if (error == nil) {
            
            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
            UINavigationController *splitNavigationController = [splitViewController.viewControllers firstObject];
            
            UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"CCUploadFromOtherUpp" bundle:nil] instantiateViewControllerWithIdentifier:@"CCUploadNavigationViewController"];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timer * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [splitNavigationController presentViewController:navigationController animated:YES completion:nil];
            });
        }
    }
    
    return YES;
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
        
    if (([actualVersion compare:@"2.19.1" options:NSNumericSearch] == NSOrderedAscending)) {

        [[NCManageDatabase sharedInstance] clearTable:[tableMetadata class] account:nil];
        [[NCManageDatabase sharedInstance] setClearAllDateReadDirectory];
    }
    
    if (([actualVersion compare:@"2.22.0" options:NSNumericSearch] == NSOrderedAscending)) {
     
        NSArray *records = [[NCManageDatabase sharedInstance] getTableLocalFilesWithPredicate:[NSPredicate predicateWithFormat:@"#size > 0"] sorted:@"account" ascending:NO];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            NSString *account = @"";
            NSString *directoryUser = @"";
            NSString *fileName;
            
            for (tableLocalFile *record in records) {
                if (![account isEqualToString:record.account]) {
                    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", record.account]];
                    if (tableAccount) {
                        directoryUser = [CCUtility getDirectoryActiveUser:tableAccount.user activeUrl:tableAccount.url];
                        account = record.account;
                    }
                }
                fileName = [NSString stringWithFormat:@"%@/%@", directoryUser, record.ocId];
                if (![directoryUser isEqualToString:@""] && [[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
                    [CCUtility moveFileAtPath:fileName toPath:[CCUtility getDirectoryProviderStorageOcId:record.ocId fileNameView:record.fileName]];
                }
            }
        });
    }
    
    if ([actualVersion isEqualToString:@"2.22.9"]) {
        if (([actualBuild compare:@"8" options:NSNumericSearch] == NSOrderedAscending) || actualBuild == nil) {
            [[NCManageDatabase sharedInstance] clearTable:[tableActivity class] account:nil];
            [[NCManageDatabase sharedInstance] clearTable:[tableActivitySubjectRich class] account:nil];
            [[NCManageDatabase sharedInstance] clearTable:[tableActivityPreview class] account:nil];
        }
    }
    
    if (([actualVersion compare:@"2.23.4" options:NSNumericSearch] == NSOrderedAscending)) {
        NSArray *records = [[NCManageDatabase sharedInstance] getAllAccount];
        for (tableAccount *record in records) {
            [CCUtility setPassword:record.account password:record.password];
            [[NCManageDatabase sharedInstance] removePasswordAccount:record.account];
        }
    }

    return YES;
}

@end
