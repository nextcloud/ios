//
//  AppDelegate.m
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

#import "AppDelegate.h"
#import "CCGraphics.h"
#import "CCSynchronize.h"
#import "CCMain.h"
#import "NCBridgeSwift.h"
#import "NCAutoUpload.h"
#import "NCPushNotificationEncryption.h"
#import <QuartzCore/QuartzCore.h>

@import Sentry;

@class NCViewerRichdocument;

@interface AppDelegate() <TOPasscodeViewControllerDelegate>
@end

@implementation AppDelegate

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UserAgent": [CCUtility getUserAgent]}];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (![CCUtility getDisableCrashservice] && NCBrandOptions.sharedInstance.disable_crash_service == false) {
        [SentrySDK startWithOptions: @{
            @"dsn": @"https://42eaf570ec2646b1a564a4c4bfc8c279@o394108.ingest.sentry.io/5243836",
            @"debug": @(YES),
            @"enableAutoSessionTracking": @(YES)
            /* PRIVACY : https://github.com/getsentry/sentry-cocoa
             By default, we don’t apply the user identification provided to the SDK via the API. Instead, we use
             the installation ID generated with the first use of the application. The ID doesn’t contain any
             private or public data of your users or any public or shared data of their device.
             */
        }];
    }
    
    [CCUtility createDirectoryStandard];
    [CCUtility emptyTemporaryDirectory];
    
    // Networking
    [[NCCommunicationCommon shared] setupWithDelegate:[NCNetworking shared]];
    [[NCCommunicationCommon shared] setupWithUserAgent:[CCUtility getUserAgent] capabilitiesGroup:[NCBrandOptions sharedInstance].capabilitiesGroups];
    
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
        
    // Background Fetch
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    self.listProgressMetadata = [NSMutableDictionary new];
    self.listMainVC = [NSMutableDictionary new];
    self.arrayDeleteMetadata = [NSMutableArray new];
    self.arrayMoveMetadata = [NSMutableArray new];
    self.arrayMoveServerUrlTo = [NSMutableArray new];
    self.arrayCopyMetadata = [NSMutableArray new];
    self.arrayCopyServerUrlTo = [NSMutableArray new];
    
    // Push Notification
    [application registerForRemoteNotifications];
    
    // Display notification
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) { }];
    
    //AV Session
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

    // ProgressView Detail
    self.progressViewDetail = [[UIProgressView alloc] initWithProgressViewStyle: UIProgressViewStyleBar];
    
    // Quick Actions
    if([[UIApplicationShortcutItem class] respondsToSelector:@selector(new)]) {
    
        [self configDynamicShortcutItems];
        
        UIApplicationShortcutItem *shortcutItem = [launchOptions objectForKeyedSubscript:UIApplicationLaunchOptionsShortcutItemKey];
        
        if (shortcutItem)
            [self handleShortCutItem:shortcutItem];
    }
        
    // Start Timer
    self.timerProcessAutoUpload = [NSTimer scheduledTimerWithTimeInterval:k_timerProcessAutoUpload target:self selector:@selector(loadAutoUpload) userInfo:nil repeats:YES];
    self.timerUpdateApplicationIconBadgeNumber = [NSTimer scheduledTimerWithTimeInterval:k_timerUpdateApplicationIconBadgeNumber target:self selector:@selector(updateApplicationIconBadgeNumber) userInfo:nil repeats:YES];
    [self startTimerErrorNetworking];

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
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
    
    // Observer
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteFile:) name:k_notificationCenter_deleteFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moveFile:) name:k_notificationCenter_moveFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(copyFile:) name:k_notificationCenter_copyFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadedFile:) name:k_notificationCenter_uploadedFile object:nil];
    
    // Passcode
    dispatch_async(dispatch_get_main_queue(), ^{
        [self passcodeWithAutomaticallyPromptForBiometricValidation:true];
    });
    
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
    
    NSLog(@"[LOG] Request Passcode");
    [self passcodeWithAutomaticallyPromptForBiometricValidation:true];
    
    NSLog(@"[LOG] Request Service Server Nextcloud");
    [[NCService shared] startRequestServicesServer];
    
    NSLog(@"[LOG] Initialize Auto upload");
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    NSLog(@"[LOG] Read active directory");
    [self.activeMain readFileReloadFolder];
    
    NSLog(@"[LOG] Required unsubscribing / subscribing");
    [self pushNotification];
    
    NSLog(@"[LOG] RichDocument");
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_richdocumentGrabFocus object:nil];
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
        [[NCService shared] middlewarePing];
    }

    // verify delete Asset Local Identifiers in auto upload
    [[NCUtility sharedInstance] deleteAssetLocalIdentifiersWithAccount:self.activeAccount sessionSelector:selectorUploadAutoUpload];
   
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
            
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_applicationDidEnterBackground object:nil];
    [self passcodeWithAutomaticallyPromptForBiometricValidation:false];
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
            [[NCNetworking shared] wrtiteCertificateWithDirectoryCertificate:[CCUtility getDirectoryCerificates]];
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
        navController.navigationBar.barStyle =  UIBarStyleBlack;
        navController.navigationBar.tintColor = NCBrandColor.sharedInstance.customerText;
        navController.navigationBar.barTintColor = NCBrandColor.sharedInstance.customer;
        [navController.navigationBar setTranslucent:false];
        self.window.rootViewController = navController;
        [self.window makeKeyAndVisible];
        
    } else if ([contextViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = ((UINavigationController *)contextViewController);
        [navController pushViewController:viewController animated:true];
        
    } else {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
        navController.navigationBar.barStyle =  UIBarStyleBlack;
        navController.navigationBar.tintColor = NCBrandColor.sharedInstance.customerText;
        navController.navigationBar.barTintColor = NCBrandColor.sharedInstance.customer;
        [navController.navigationBar setTranslucent:false];
        [contextViewController presentViewController:navController animated:true completion:nil];
    }
}

- (void)startTimerErrorNetworking
{
    self.timerErrorNetworking = [NSTimer scheduledTimerWithTimeInterval:k_timerErrorNetworking target:self selector:@selector(checkErrorNetworking) userInfo:nil repeats:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Account & Communication =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activeUserID:(NSString *)activeUserID activePassword:(NSString *)activePassword
{
    self.activeAccount = activeAccount;
    self.activeUrl = activeUrl;
    self.activeUser = activeUser;
    self.activeUserID = activeUserID;
    self.activePassword = activePassword;

    (void)[NCNetworkingNotificationCenter shared];

    [[NCCommunicationCommon shared] setupWithAccount:activeAccount user:activeUser userId:activeUserID password:activePassword url:activeUrl];
    [self settingSetupCommunicationCapabilities:activeAccount];
}

- (void)deleteAccount:(NSString *)account wipe:(BOOL)wipe
{
    // Push Notification
    tableAccount *accountPN = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    [self unsubscribingNextcloudServerPushNotification:accountPN.account url:accountPN.url user:accountPN.user withSubscribing:false];

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
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
        } else {
            [self openLoginView:self.window.rootViewController selector:k_intro_login openLoginWeb:false];
        }
    }
}

- (void)settingSetupCommunicationCapabilities:(NSString *)account
{
    NSInteger serverVersionMajor = [[NCManageDatabase sharedInstance] getCapabilitiesServerIntWithAccount:account elements:NCElementsJSON.shared.capabilitiesVersionMajor];
    if (serverVersionMajor > 0) {
        [[OCNetworking sharedManager].sharedOCCommunication setupNextcloudVersion: serverVersionMajor];
        [[NCCommunicationCommon shared] setupWithNextcloudVersion:serverVersionMajor];
     }
    
    NSString *webDavRoot = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:account elements:NCElementsJSON.shared.capabilitiesWebDavRoot];
    if (webDavRoot != nil) {
        [[NCCommunicationCommon shared] setupWithWebDavRoot:webDavRoot];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Push Notifications =====
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
                [self unsubscribingNextcloudServerPushNotification:result.account url:result.url user:result.user withSubscribing:true];
            } else {
                [self subscribingNextcloudServerPushNotification:result.account url:result.url user:result.user];
            }
        }
    }
}

- (void)subscribingNextcloudServerPushNotification:(NSString *)account url:(NSString *)url user:(NSString *)user
{
    // test
    if (self.activeAccount.length == 0 || self.maintenanceMode || self.pushKitToken.length == 0)
        return;
    
    [[NCPushNotificationEncryption sharedInstance] generatePushNotificationsKeyPair:account];

    NSString *pushTokenHash = [[NCEndToEndEncryption sharedManager] createSHA512:self.pushKitToken];
    NSData *pushPublicKey = [CCUtility getPushNotificationPublicKey:account];
    NSString *pushDevicePublicKey = [[NSString alloc] initWithData:pushPublicKey encoding:NSUTF8StringEncoding];
    NSString *proxyServerPath = [NCBrandOptions sharedInstance].pushNotificationServerProxy;
    
    [[NCCommunication shared] subscribingPushNotificationWithServerUrl:url account:account user:user password:[CCUtility getPassword:account] pushTokenHash:pushTokenHash devicePublicKey:pushDevicePublicKey proxyServerUrl:proxyServerPath customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSString *deviceIdentifier, NSString *signature, NSString *publicKey, NSInteger errorCode, NSString *errorDescription) {
        if (errorCode == 0) {
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [CCUtility getUserAgent]];
            [[NCCommunication shared] subscribingPushProxyWithProxyServerUrl:proxyServerPath pushToken:self.pushKitToken deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey userAgent:userAgent completionHandler:^(NSInteger errorCode, NSString *errorDescription) {
                if (errorCode == 0) {
                    
                    NSLog(@"[LOG] Subscribed to Push Notification server & proxy successfully.");
                        
                    [CCUtility setPushNotificationToken:account token:self.pushKitToken];
                    [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:deviceIdentifier];
                    [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:signature];
                    [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:publicKey];
                }
            }];
        }
    }];
}

- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account url:(NSString *)url user:(NSString *)user withSubscribing:(BOOL)subscribing
{
    // test
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    NSString *deviceIdentifier = [CCUtility getPushNotificationDeviceIdentifier:account];
    NSString *signature = [CCUtility getPushNotificationDeviceIdentifierSignature:account];
    NSString *publicKey = [CCUtility getPushNotificationSubscribingPublicKey:account];

    [[NCCommunication shared] unsubscribingPushNotificationWithServerUrl:url account:account user:user password:[CCUtility getPassword:account] customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSInteger errorCode, NSString *errorDescription) {
        if (errorCode == 0) {
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [CCUtility getUserAgent]];
            NSString *proxyServerPath = [NCBrandOptions sharedInstance].pushNotificationServerProxy;
            [[NCCommunication shared] unsubscribingPushProxyWithProxyServerUrl:proxyServerPath deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey userAgent:userAgent completionHandler:^(NSInteger errorCode, NSString *errorDescription) {
                if (errorCode == 0) {
                
                    NSLog(@"[LOG] Unsubscribed to Push Notification server & proxy successfully.");
                    
                    [CCUtility setPushNotificationPublicKey:account data:nil];
                    [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:nil];
                    [CCUtility setPushNotificationPrivateKey:account data:nil];
                    [CCUtility setPushNotificationToken:account token:nil];
                    [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:nil];
                    [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:nil];
                    
                    if (self.pushKitToken != nil && subscribing) {
                        [self subscribingNextcloudServerPushNotification:account url:url user:user];
                    }
                }
            }];
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

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    self.pushKitToken = [self stringWithDeviceToken:deviceToken];

    [self pushNotification];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSString *message = [userInfo objectForKey:@"subject"];
    if (message) {
        NSArray *results = [[NCManageDatabase sharedInstance] getAllAccount];
        for (tableAccount *result in results) {
            if ([CCUtility getPushNotificationPrivateKey:result.account]) {
                NSData *decryptionKey = [CCUtility getPushNotificationPrivateKey:result.account];
                NSString *decryptedMessage = [[NCPushNotificationEncryption sharedInstance] decryptPushNotification:message withDevicePrivateKey:decryptionKey];
                if (decryptedMessage) {
                    NSData *data = [decryptedMessage dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    NSInteger nid = [[json objectForKey:@"nid"] integerValue];
                    BOOL delete = [[json objectForKey:@"delete"] boolValue];
                    BOOL deleteAll = [[json objectForKey:@"delete-all"] boolValue];
                    if (delete) {
                        [self removeNotificationWithNotificationId:nid usingDecryptionKey:decryptionKey];
                    } else if (deleteAll) {
                        [self cleanAllNotifications];
                    }
                }
            }
        }
    }
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)cleanAllNotifications
{
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
}

- (void)removeNotificationWithNotificationId:(NSInteger)notificationId usingDecryptionKey:(NSData *)key
{
    // Check in pending notifications
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        for (UNNotificationRequest *notificationRequest in requests) {
            NSString *message = [notificationRequest.content.userInfo objectForKey:@"subject"];
            NSString *decryptedMessage = [[NCPushNotificationEncryption sharedInstance] decryptPushNotification:message withDevicePrivateKey:key];
            if (decryptedMessage) {
                NSData *data = [decryptedMessage dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSInteger nid = [[json objectForKey:@"nid"] integerValue];
                if (nid == notificationId) {
                    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[notificationRequest.identifier]];
                }
            }
        }
    }];
    // Check in delivered notifications
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        for (UNNotification *notification in notifications) {
            NSString *message = [notification.request.content.userInfo objectForKey:@"subject"];
            NSString *decryptedMessage = [[NCPushNotificationEncryption sharedInstance] decryptPushNotification:message withDevicePrivateKey:key];
            if (decryptedMessage) {
                NSData *data = [decryptedMessage dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSInteger nid = [[json objectForKey:@"nid"] integerValue];
                if (nid == notificationId) {
                    [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[notification.request.identifier]];
                }
            }
        }
    }];
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
#pragma mark ==== NotificationCenter ====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFile:(NSNotification *)notification
{
    if (self.arrayDeleteMetadata.count > 0) {
        tableMetadata *metadata = self.arrayDeleteMetadata.firstObject;
        [self.arrayDeleteMetadata removeObjectAtIndex:0];
        tableAccount *account = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", metadata.account]];
        if (account) {
            [[NCNetworking shared] deleteMetadata:metadata account:metadata.account url:account.url completion:^(NSInteger errorCode, NSString *errorDescription) { }];
        } else {
            [self deleteFile:[NSNotification new]];
        }
    }
}

- (void)moveFile:(NSNotification *)notification
{
    if (self.arrayMoveMetadata.count > 0) {
        tableMetadata *metadata = self.arrayMoveMetadata.firstObject;
        NSString *serverUrlTo = self.arrayMoveServerUrlTo.firstObject;
        [self.arrayMoveMetadata removeObjectAtIndex:0];
        [self.arrayMoveServerUrlTo removeObjectAtIndex:0];
        tableAccount *account = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", metadata.account]];
        if (account) {
            [[NCNetworking shared] moveMetadata:metadata serverUrlTo:serverUrlTo overwrite:true completion:^(NSInteger errorCode, NSString *errorDescription) { }];
        } else {
            [self moveFile:[NSNotification new]];
        }
    }
}

- (void)copyFile:(NSNotification *)notification
{
    if (self.arrayCopyMetadata.count > 0) {
        tableMetadata *metadata = self.arrayCopyMetadata.firstObject;
        NSString *serverUrlTo = self.arrayCopyServerUrlTo.firstObject;
        [self.arrayCopyMetadata removeObjectAtIndex:0];
        [self.arrayCopyServerUrlTo removeObjectAtIndex:0];
        tableAccount *account = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", metadata.account]];
        if (account) {
            [[NCNetworking shared] copyMetadata:metadata serverUrlTo:serverUrlTo overwrite:true completion:^(NSInteger errorCode, NSString *errorDescription) { }];
        } else {
            [self copyFile:[NSNotification new]];
        }
    }
}

- (void)uploadedFile:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    tableMetadata *metadata = userInfo[@"metadata"];
    NSInteger errorCode = [userInfo[@"errorCode"] integerValue];
   
    if (errorCode == 0) {
        // verify delete Asset Local Identifiers in auto upload
        [[NCUtility sharedInstance] deleteAssetLocalIdentifiersWithAccount:metadata.account sessionSelector:selectorUploadAutoUpload];
    }
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
            if ([splitViewController isKindOfClass:[UISplitViewController class]]) {
                UINavigationController *navigationControllerMaster = (UINavigationController *)splitViewController.viewControllers.firstObject;
                if ([navigationControllerMaster isKindOfClass:[UINavigationController class]]) {
                    UITabBarController *tabBarController = (UITabBarController *)navigationControllerMaster.topViewController;
                     if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                         
                         if (splitViewController.isCollapsed) {
                                         
                             [navigationControllerMaster popToRootViewControllerAnimated:false];
                             UINavigationController *navigationControllerMaster = (UINavigationController *)splitViewController.viewControllers.firstObject;
                             if ([navigationControllerMaster isKindOfClass:[UINavigationController class]]) {
                                 UITabBarController *tabBarController = (UITabBarController *)navigationControllerMaster.topViewController;
                                 if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                                     [tabBarController setSelectedIndex: k_tabBarApplicationIndexMedia];
                                 }
                             }
                        
                         } else {
                         
                             if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                                 [tabBarController setSelectedIndex: k_tabBarApplicationIndexMedia];
                             }
                         }
                     }
                }
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
        
        NSInteger counterDownload = [[NCOperationQueue shared] downloadCount];
        NSInteger counterUpload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d OR status == %d OR status == %d", k_metadataStatusWaitUpload, k_metadataStatusInUpload, k_metadataStatusUploading] sorted:@"fileName" ascending:true] count];

        NSInteger total = counterDownload + counterUpload;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [UIApplication sharedApplication].applicationIconBadgeNumber = total;
            
            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
            if ([splitViewController isKindOfClass:[UISplitViewController class]]) {
                UINavigationController *navigationController = (UINavigationController *)[splitViewController.viewControllers firstObject];
                if ([navigationController isKindOfClass:[UINavigationController class]]) {
                    UITabBarController *tabBarController = (UITabBarController *)navigationController.topViewController;
                    if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                        UITabBarItem *tabBarItem = [tabBarController.tabBar.items objectAtIndex:0];
                            
                        if (total > 0) {
                            [tabBarItem setBadgeValue:[NSString stringWithFormat:@"%li", (unsigned long)total]];
                        } else {
                            [tabBarItem setBadgeValue:nil];
                        }
                    }
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
    CGFloat safeAreaBottom = safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
   
    // File
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFile];
    [item setTitle:NSLocalizedString(@"_home_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarFiles"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // Favorites
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexFavorite];
    [item setTitle:NSLocalizedString(@"_favorites_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // (PLUS INVISIBLE)
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexPlusHide];
    item.title = @"";
    item.image = nil;
    item.enabled = false;
    
    // Media
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexMedia];
    [item setTitle:NSLocalizedString(@"_media_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"media"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // More
    item = [tabBarController.tabBar.items objectAtIndex: k_tabBarApplicationIndexMore];
    [item setTitle:NSLocalizedString(@"_more_", nil)];
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarMore"] width:50 height:50 color:NCBrandColor.sharedInstance.brandElement];
    item.selectedImage = item.image;
    
    // Plus Button
    int buttonSize = 57;
    UIImage *buttonImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"tabBarPlus"] width:120 height:120 color:UIColor.whiteColor];
    UIButton *buttonPlus = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonPlus.tag = 99;
    [buttonPlus setImage:buttonImage forState:UIControlStateNormal];
    buttonPlus.backgroundColor = NCBrandColor.sharedInstance.brand;
    buttonPlus.layer.cornerRadius = buttonSize / 2;
    buttonPlus.layer.masksToBounds = NO;
    buttonPlus.layer.shadowOffset = CGSizeMake(0, 0);
    buttonPlus.layer.shadowRadius = 3.0f;
    buttonPlus.layer.shadowOpacity = 0.5;
    

    [buttonPlus addTarget:self action:@selector(handleTouchTabbarCenter:) forControlEvents:UIControlEventTouchUpInside];
    
    [buttonPlus setTranslatesAutoresizingMaskIntoConstraints:NO];
    [tabBarController.tabBar addSubview:buttonPlus];
    

    if (safeAreaBottom > 0) {
        
        // X
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        [tabBarController.view addConstraint:constraint];
        // Y
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeTop multiplier:1.0 constant:-(buttonSize / 2)];
        [tabBarController.view addConstraint:constraint];
        // Width
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:buttonSize];
        [tabBarController.view addConstraint:constraint];
        // Height
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:buttonSize];
        [tabBarController.view addConstraint:constraint];
        
    } else {
        
        // X
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        [tabBarController.view addConstraint:constraint];
        // Y
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tabBarController.tabBar attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:-(buttonSize / 2)];
        [tabBarController.view addConstraint:constraint];
        // Width
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:buttonSize];
        [tabBarController.view addConstraint:constraint];
        // Height
        constraint = [NSLayoutConstraint constraintWithItem:buttonPlus attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:buttonSize];
        [tabBarController.view addConstraint:constraint];
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

- (NSString *)getTabBarControllerActiveServerUrl
{
    NSString *serverUrl = [CCUtility getHomeServerUrlActiveUrl:self.activeUrl];

    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    if ([splitViewController isKindOfClass:[UISplitViewController class]]) {
        UINavigationController *masterNavigationController = [splitViewController.viewControllers firstObject];
        if ([masterNavigationController isKindOfClass:[UINavigationController class]]) {
            UITabBarController *tabBarController = [masterNavigationController.viewControllers firstObject];
            if ([tabBarController isKindOfClass:[UITabBarController class]]) {
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
            }
        }
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
        
        NSString *themingColor = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:self.activeAccount elements:NCElementsJSON.shared.capabilitiesThemingColor];
        NSString *themingColorElement = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:self.activeAccount elements:NCElementsJSON.shared.capabilitiesThemingColorElement];
        NSString *themingColorText = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:self.activeAccount elements:NCElementsJSON.shared.capabilitiesThemingColorText];

        [CCGraphics settingThemingColor:themingColor themingColorElement:themingColorElement themingColorText:themingColorText];
        
        UIColor *color = NCBrandColor.sharedInstance.brand;
        BOOL isTooLight = NCBrandColor.sharedInstance.brand.isTooLight;
        BOOL isTooDark = NCBrandColor.sharedInstance.brand.isTooDark;
        
        if (isTooLight) {
            color = [NCBrandColor.sharedInstance.brand darkerBy:10];
        } else if (isTooDark) {
            color = [NCBrandColor.sharedInstance.brand lighterBy:10];
        }
        
        NCBrandColor.sharedInstance.brand = color;
            
    } else {
    
        NCBrandColor.sharedInstance.brand = NCBrandColor.sharedInstance.customer;
        NCBrandColor.sharedInstance.brandElement = NCBrandColor.sharedInstance.customer;
        NCBrandColor.sharedInstance.brandText = NCBrandColor.sharedInstance.customerText;
    }
        
    [NCBrandColor.sharedInstance setDarkMode];
    [[NCMainCommon sharedInstance] createImagesThemingColor];
    
    // Tab bar
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    if ([splitViewController isKindOfClass:[UISplitViewController class]]) {
        UINavigationController *masterNavigationController = [splitViewController.viewControllers firstObject];
        if ([masterNavigationController isKindOfClass:[UINavigationController class]]) {
            UITabBarController *tabBarController = [masterNavigationController.viewControllers firstObject];
            if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                tabBarController.tabBar.translucent = NO;
                tabBarController.tabBar.barTintColor = NCBrandColor.sharedInstance.backgroundView;
                tabBarController.tabBar.tintColor = NCBrandColor.sharedInstance.brandElement;
                tabBarController.tabBar.backgroundColor = NCBrandColor.sharedInstance.tabBar;
            }
        }
    }
                   
    [self.window setTintColor:NCBrandColor.sharedInstance.textView];
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_changeTheming object:nil];
}

- (void)changeTheming:(UIViewController *)viewController tableView:(UITableView *)tableView collectionView:(UICollectionView *)collectionView form:(BOOL)form
{
    [NCBrandColor.sharedInstance setDarkMode];
    
    //Tab bar
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    if ([splitViewController isKindOfClass:[UISplitViewController class]]) {
        UINavigationController *masterNavigationController = [splitViewController.viewControllers firstObject];
        if ([masterNavigationController isKindOfClass:[UINavigationController class]]) {
            UITabBarController *tabBarController = [masterNavigationController.viewControllers firstObject];
            if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                tabBarController.tabBar.backgroundColor = NCBrandColor.sharedInstance.tabBar;
            }
        }
    }
    
    // Nav bar
    [self configureNavBarForViewController:viewController];

    // View
    if (form) viewController.view.backgroundColor = NCBrandColor.sharedInstance.backgroundForm;
    else viewController.view.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
            
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.backgroundSessionCompletionHandler = completionHandler;
        void (^completionHandler)() = self.backgroundSessionCompletionHandler;
        self.backgroundSessionCompletionHandler = nil;
        completionHandler();
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Process Load Upload < k_timerProcess seconds > =====
#pragma --------------------------------------------------------------------------------------------

- (void)loadAutoUpload
{
    if (self.activeAccount.length == 0 || self.maintenanceMode)
        return;
    
    tableMetadata *metadataForUpload;
    long counterUpload = 0;
    NSUInteger sizeUpload = 0;
    NSPredicate *predicate;
    
    long maxConcurrentOperationUpload = k_maxConcurrentOperation;
    
    NSArray *metadatasUpload = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d OR status == %d", k_metadataStatusInUpload, k_metadataStatusUploading] sorted:nil ascending:true];
    
    // E2EE only 1
    for(tableMetadata *metadata in metadatasUpload) {
        if ([CCUtility isFolderEncrypted:metadata.serverUrl e2eEncrypted:metadata.e2eEncrypted account:metadata.account]) return;
    }
    
    // Counter
    counterUpload = [metadatasUpload count];
    
    // Size
    for (tableMetadata *metadata in metadatasUpload) {
        sizeUpload = sizeUpload + metadata.size;
    }
    
    NSLog(@"%@", [NSString stringWithFormat:@"[LOG] PROCESS-AUTO-UPLOAD %ld - %@", counterUpload, [CCUtility transformedSize:sizeUpload]]);
    
    // Stop Timer
    [_timerProcessAutoUpload invalidate];
        
    // ------------------------- <selector Upload> -------------------------
    
    while (counterUpload < maxConcurrentOperationUpload) {
        
        if (sizeUpload > k_maxSizeOperationUpload) {
            break;
        }
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
            predicate = [NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d AND typeFile != %@", selectorUploadFile, k_metadataStatusWaitUpload, k_metadataTypeFile_video];
        } else {
            predicate = [NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d", selectorUploadFile, k_metadataStatusWaitUpload];
        }
                
        metadataForUpload = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:predicate sorted:@"date" ascending:YES];
        
        if (metadataForUpload) {
                            
            if ([CCUtility isFolderEncrypted:metadataForUpload.serverUrl e2eEncrypted:metadataForUpload.e2eEncrypted account:metadataForUpload.account]) {
                
                if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) { break; }
                maxConcurrentOperationUpload = 1;
                    
                metadataForUpload.status = k_metadataStatusInUpload;
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                    
                [[NCNetworking shared] uploadWithMetadata:metadata];
                    
                break;
                                        
            } else {
                    
                metadataForUpload.status = k_metadataStatusInUpload;
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                    
                [[NCNetworking shared] uploadWithMetadata:metadata];
                    
                counterUpload++;
                sizeUpload = sizeUpload + metadata.size;
            }
                
        } else {
            break;
        }
    }
    
    // ------------------------- <selector Auto Upload> -------------------------
    
    while (counterUpload < maxConcurrentOperationUpload) {
        
        if (sizeUpload > k_maxSizeOperationUpload) {
            break;
        }
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
            predicate = [NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d AND typeFile != %@", selectorUploadAutoUpload, k_metadataStatusWaitUpload, k_metadataTypeFile_video];
        } else {
            predicate = [NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d", selectorUploadAutoUpload, k_metadataStatusWaitUpload];
        }
        
        metadataForUpload = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:predicate sorted:@"date" ascending:YES];
        if (metadataForUpload) {
            
            if ([CCUtility isFolderEncrypted:metadataForUpload.serverUrl e2eEncrypted:metadataForUpload.e2eEncrypted account:metadataForUpload.account]) {
                
                if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) { break; }
                maxConcurrentOperationUpload = 1;
                
                metadataForUpload.status = k_metadataStatusInUpload;
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                                          
                [[NCNetworking shared] uploadWithMetadata:metadata];
                                
                break;
                
            } else {
                
                metadataForUpload.status = k_metadataStatusInUpload;
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                           
                [[NCNetworking shared] uploadWithMetadata:metadata];
                           
                counterUpload++;
                sizeUpload = sizeUpload + metadata.size;
            }
           
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
        
        while (counterUpload < maxConcurrentOperationUpload) {
            
            if (sizeUpload > k_maxSizeOperationUpload) {
                break;
            }
            
            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                predicate = [NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d AND typeFile != %@", selectorUploadAutoUploadAll, k_metadataStatusWaitUpload, k_metadataTypeFile_video];
            } else {
                predicate = [NSPredicate predicateWithFormat:@"sessionSelector == %@ AND status == %d", selectorUploadAutoUploadAll, k_metadataStatusWaitUpload];
            }
            
            metadataForUpload = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:predicate sorted:@"session" ascending:YES];
            if (metadataForUpload) {
                
                if ([CCUtility isFolderEncrypted:metadataForUpload.serverUrl e2eEncrypted:metadataForUpload.e2eEncrypted account:metadataForUpload.account]) {
                
                    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) { break; }
                    maxConcurrentOperationUpload = 1;
                    
                    metadataForUpload.status = k_metadataStatusInUpload;
                    tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                    
                    [[NCNetworking shared] uploadWithMetadata:metadata];
                    
                    break;
                    
                } else {
                    
                    metadataForUpload.status = k_metadataStatusInUpload;
                    tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                    
                    [[NCNetworking shared] uploadWithMetadata:metadata];
                    
                    counterUpload++;
                    sizeUpload = sizeUpload + metadata.size;
                    
                }
                
            } else {
                break;
            }
        }
    }
    
    // No upload available ? --> Retry Upload in Error
    if (counterUpload == 0) {
        
        NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d", k_metadataStatusUploadError] sorted:nil ascending:NO];
        for (tableMetadata *metadata in metadatas) {
            
            metadata.session = NCCommunicationCommon.shared.sessionIdentifierBackground;
            metadata.sessionError = @"";
            metadata.sessionTaskIdentifier = 0;
            metadata.status = k_metadataStatusInUpload;
            
            [[NCManageDatabase sharedInstance] addMetadata:metadata];
        }
    }
    
    // Start Timer
    _timerProcessAutoUpload = [NSTimer scheduledTimerWithTimeInterval:k_timerProcessAutoUpload target:self selector:@selector(loadAutoUpload) userInfo:nil repeats:YES];
}

- (void)startLoadAutoUpload
{
    if (self.timerProcessAutoUpload.isValid) {
        [self performSelectorOnMainThread:@selector(loadAutoUpload) withObject:nil waitUntilDone:YES];
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
                                    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
                                }
                            }
                        }
                        
                        if (matchedAccount) {
                            
                            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
                            if ([splitViewController isKindOfClass:[UISplitViewController class]]) {
                                UINavigationController *navigationControllerMaster = (UINavigationController *)splitViewController.viewControllers.firstObject;
                                if ([navigationControllerMaster isKindOfClass:[UINavigationController class]]) {
                                    UITabBarController *tabBarController = (UITabBarController *)navigationControllerMaster.topViewController;
                                    if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                                        
                                        if (splitViewController.isCollapsed) {
                                                        
                                            [navigationControllerMaster popToRootViewControllerAnimated:false];
                                            UINavigationController *navigationControllerMaster = (UINavigationController *)splitViewController.viewControllers.firstObject;
                                            if ([navigationControllerMaster isKindOfClass:[UINavigationController class]]) {
                                                UITabBarController *tabBarController = (UITabBarController *)navigationControllerMaster.topViewController;
                                                if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                                                    if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                                                        [tabBarController setSelectedIndex: k_tabBarApplicationIndexFile];
                                                    }
                                                }
                                            }
                                            
                                        } else {
                                        
                                            if ([tabBarController isKindOfClass:[UITabBarController class]]) {
                                                [tabBarController setSelectedIndex: k_tabBarApplicationIndexFile];
                                            }
                                        }
                                        
                                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                                            
                                            [self.activeMain.navigationController popToRootViewControllerAnimated:NO];
                                            
                                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                                                
                                                NSString *fileNamePath = [NSString stringWithFormat:@"%@%@/%@", matchedAccount.url, k_webDAV, path];
                                                
                                                if ([path containsString:@"/"]) {
                                                    
                                                    // Push
                                                    NSString *fileName = [[path stringByDeletingLastPathComponent] lastPathComponent];
                                                    NSString *serverUrl = [CCUtility deletingLastPathComponentFromServerUrl:[NSString stringWithFormat:@"%@%@/%@", matchedAccount.url, k_webDAV, [path stringByDeletingLastPathComponent]]];
                                                    tableMetadata *metadata = [[NCManageDatabase sharedInstance] createMetadataWithAccount:matchedAccount.account fileName:fileName ocId:[[NSUUID UUID] UUIDString] serverUrl:serverUrl url:@"" contentType:@""];
                                                    [self.activeMain performSegueDirectoryWithMetadata:metadata blinkFileNamePath:fileNamePath];
                                                    
                                                } else {
                                                    
                                                    // Reload folder
                                                    NSString *serverUrl = [NSString stringWithFormat:@"%@%@", matchedAccount.url, k_webDAV];
                                                    
                                                    self.activeMain.blinkFileNamePath = fileNamePath;
                                                    [self.activeMain readFolder:serverUrl];
                                                }
                                            });
                                        });
                                        
                                        
                                        
                                    }
                                }
                            }
                       
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
            if ([splitViewController isKindOfClass:[UISplitViewController class]]) {
                UINavigationController *navigationControllerMaster = (UINavigationController *)splitViewController.viewControllers.firstObject;
                if ([navigationControllerMaster isKindOfClass:[UINavigationController class]]) {
                    UIViewController *uploadNavigationViewController = [[UIStoryboard storyboardWithName:@"CCUploadFromOtherUpp" bundle:nil] instantiateViewControllerWithIdentifier:@"CCUploadNavigationViewController"];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timer * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [navigationControllerMaster presentViewController:uploadNavigationViewController animated:YES completion:nil];
                    });
                }
            }
        }
    }
    
    return YES;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Passcode + Delegate =====
#pragma --------------------------------------------------------------------------------------------

- (void)passcodeWithAutomaticallyPromptForBiometricValidation:(BOOL)automaticallyPromptForBiometricValidation
{
    LAContext *laContext = [LAContext new];
    NSError *error;
    BOOL isBiometryAvailable = false;
    
    if ([[CCUtility getPasscode] length] == 0 || [self.activeAccount length] == 0 || [CCUtility getNotPasscodeAtStart]) return;
    
    if (!self.passcodeViewController.view.window) {
           
        self.passcodeViewController = [[TOPasscodeViewController alloc] initWithStyle:TOPasscodeViewStyleTranslucentLight passcodeType:TOPasscodeTypeSixDigits];
        if (@available(iOS 13.0, *)) {
            if ([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
                self.passcodeViewController.style = TOPasscodeViewStyleTranslucentDark;
            }
        }

        self.passcodeViewController.delegate = self;
        self.passcodeViewController.allowCancel = false;
        self.passcodeViewController.keypadButtonShowLettering = false;
        
        if ([laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
            if (error == NULL) {
                if (laContext.biometryType == LABiometryTypeFaceID) {
                    self.passcodeViewController.biometryType = TOPasscodeBiometryTypeFaceID;
                    self.passcodeViewController.allowBiometricValidation = true;
                    isBiometryAvailable = true;
                } else if (laContext.biometryType == LABiometryTypeTouchID) {
                    self.passcodeViewController.biometryType = TOPasscodeBiometryTypeTouchID;
                    self.passcodeViewController.allowBiometricValidation = true;
                    isBiometryAvailable = true;
                } else {
                    isBiometryAvailable = false;
                    NSLog(@"No Biometric support");
                }
            }
        }
    
        [self.window.rootViewController presentViewController:self.passcodeViewController animated:YES completion:nil];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        if (automaticallyPromptForBiometricValidation && self.passcodeViewController.view.window) {
            [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions sharedInstance] brand] reply:^(BOOL success, NSError * _Nullable error) {
                if (success) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                        [self.passcodeViewController dismissViewControllerAnimated:YES completion:nil];
                    });
                }
            }];
        }
    });
}

- (void)didTapCancelInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [passcodeViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)passcodeViewController:(TOPasscodeViewController *)passcodeViewController isCorrectCode:(NSString *)code
{
    return [code isEqualToString:[CCUtility getPasscode]];
}

- (void)didPerformBiometricValidationRequestInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions sharedInstance] brand] reply:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                [passcodeViewController dismissViewControllerAnimated:YES completion:nil];
            });
        }
    }];
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
