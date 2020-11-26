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
#import "NCBridgeSwift.h"
#import "NCAutoUpload.h"
#import "NCPushNotificationEncryption.h"
#import <QuartzCore/QuartzCore.h>

@import Firebase;

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
    BOOL isSimulatorOrTestFlight = [[NCUtility shared] isSimulatorOrTestFlight];
    
    if (![CCUtility getDisableCrashservice] && NCBrandOptions.sharedInstance.disable_crash_service == false) {
        [FIRApp configure];
    }
    
    [CCUtility createDirectoryStandard];
    [CCUtility emptyTemporaryDirectory];
    
    // Networking
    [[NCCommunicationCommon shared] setupWithDelegate:[NCNetworking shared]];
    [[NCCommunicationCommon shared] setupWithUserAgent:[CCUtility getUserAgent]];
    
    NSInteger logLevel = [CCUtility getLogLevel];
    [[NCCommunicationCommon shared] setFileLogWithLevel:logLevel];
    NSString *versionApp = [NSString stringWithFormat:@"%@.%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    NSString *versionNextcloudiOS = [NSString stringWithFormat:[NCBrandOptions sharedInstance].textCopyrightNextcloudiOS, versionApp];
    if (isSimulatorOrTestFlight) {
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Start session with level %lu %@ (Simulator / TestFlight)", (unsigned long)logLevel, versionNextcloudiOS]];
    } else {
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Start session with level %lu %@", (unsigned long)logLevel, versionNextcloudiOS]];
    }
    
    //
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializeMain:) name:k_notificationCenter_initializeMain object:nil];
    
    // Set account, if no exists clear all
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    if (tableAccount == nil) {
        // remove all the keys Chain
        [CCUtility deleteAllChainStore];
        // remove all the App group key
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    } else {
        // FIX 3.0.5 lost urlbase
        if (tableAccount.urlBase.length == 0) {
            NSString *user = [tableAccount.user stringByAppendingString:@" "];
            NSString *urlBase = [tableAccount.account stringByReplacingOccurrencesOfString:user withString:@""];
            tableAccount.urlBase = urlBase;
            [[NCManageDatabase sharedInstance] updateAccount:tableAccount];
            
            tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        }
        [self settingAccount:tableAccount.account urlBase:tableAccount.urlBase user:tableAccount.user userID:tableAccount.userID password:[CCUtility getPassword:tableAccount.account]];
    }
    
    // UserDefaults
    self.ncUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:[NCBrandOptions sharedInstance].capabilitiesGroups];
        
    // Background Fetch
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    self.listProgressMetadata = [NSMutableDictionary new];
    self.listFilesVC = [NSMutableDictionary new];
    self.listFavoriteVC = [NSMutableDictionary new];
    self.listOfflineVC = [NSMutableDictionary new];

    // Push Notification
    [application registerForRemoteNotifications];
    
    // Display notification
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) { }];
    
    //AV Session
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    // Start Timer
    self.timerUpdateApplicationIconBadgeNumber = [NSTimer scheduledTimerWithTimeInterval:k_timerUpdateApplicationIconBadgeNumber target:self selector:@selector(updateApplicationIconBadgeNumber) userInfo:nil repeats:YES];
    [self startTimerErrorNetworking];

    // Store review
    if ([[NCUtility shared] isSimulatorOrTestFlight] == false) {
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
        
        if (self.account.length == 0) {
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

    // Passcode
    dispatch_async(dispatch_get_main_queue(), ^{
        [self passcodeWithAutomaticallyPromptForBiometricValidation:true];
    });
    
    // Auto upload
    self.networkingAutoUpload = [NCNetworkingAutoUpload new];
    
    return YES;
}

//
// L' applicazione si dimetterà dallo stato di attivo
//
- (void)applicationWillResignActive:(UIApplication *)application
{
    if (self.account.length == 0) { return; }
    
    // Dismiss FileViewInFolder
    if (self.activeFileViewInFolder != nil ) {
        [self.activeFileViewInFolder dismissViewControllerAnimated:false completion:^{
            self.activeFileViewInFolder = nil;
        }];
    }
    
    [self updateApplicationIconBadgeNumber];
}

//
// L' applicazione entrerà in primo piano (attivo solo dopo il background)
//
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    if (self.account.length == 0) { return; }
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_applicationWillEnterForeground object:nil];
    
    // Request Passcode
    [self passcodeWithAutomaticallyPromptForBiometricValidation:true];
    
    // Initialize Auto upload
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    // Read active directory
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_reloadDataSourceNetworkForced object:nil];
    
    // Required unsubscribing / subscribing
    [self pushNotification];
    
    // RichDocument
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_richdocumentGrabFocus object:nil];
    
    // Request Service Server Nextcloud
    [[NCService shared] startRequestServicesServer];
}

//
// L' applicazione entrerà in primo piano (attivo sempre)
//
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (self.account.length == 0) { return; }
        
    // Brand
    #if defined(HC)
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    if (account.hcIsTrial == true || account.hcTrialExpired == true || account.hcNextGroupExpirationGroupExpired == true) {
        
        HCTrial *vc = [[UIStoryboard storyboardWithName:@"HCTrial" bundle:nil] instantiateInitialViewController];
        vc.account = account;
        
        [self.window.rootViewController presentViewController:vc animated:YES completion:nil];
    }
    #endif
    
    [[NCNetworking shared] verifyUploadZombie];
}

//
// L' applicazione è entrata nello sfondo
//
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    if (self.account.length == 0) { return; }

    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_applicationDidEnterBackground object:nil];
    
    [self passcodeWithAutomaticallyPromptForBiometricValidation:false];
}

//
// L'applicazione terminerà
//
- (void)applicationWillTerminate:(UIApplication *)application
{
    [[NCCommunicationCommon shared] writeLog:@"bye bye"];
}

// NotificationCenter
- (void)initializeMain:(NSNotification *)notification
{
    if (self.account.length == 0) { return; }
    
    // Clear error certificate
    [CCUtility setCertificateError:self.account error:NO];
    
    // Setting Theming
    [[NCBrandColor sharedInstance] settingThemingColorWithAccount:self.account];
    
    // close detail
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_menuDetailClose object:nil];
    
    // Not Photos Video in library ? then align and Init Auto Upload
    NSArray *recordsPhotoLibrary = [[NCManageDatabase sharedInstance] getPhotoLibraryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", self.account]];
    if ([recordsPhotoLibrary count] == 0) {
        [[NCAutoUpload sharedInstance] alignPhotoLibrary];
    }
    
    // Start Auto Upload
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    // Start services
    [[NCService shared] startRequestServicesServer];
    
    // Registeration push notification
    [self pushNotification];
    
    // Registeration domain File Provider
    //FileProviderDomain *fileProviderDomain = [FileProviderDomain new];
    //[fileProviderDomain removeAllDomains];
    //[fileProviderDomain registerDomains];
    
    [[NCCommunicationCommon shared] writeLog:@"initialize Main"];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Login / checkErrorNetworking =====
#pragma --------------------------------------------------------------------------------------------

- (void)checkErrorNetworking
{
    if (self.account.length == 0) { return; }
    
    // check unauthorized server (401)
    if ([CCUtility getPassword:self.account].length == 0) {
        
        [self openLoginView:self.window.rootViewController selector:k_intro_login openLoginWeb:true];
    }
    
    // check certificate untrusted (-1202)
    if ([CCUtility getCertificateError:self.account]) {
        
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
                self.activeLoginWeb.urlBase = self.urlBase;
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
            self.activeLoginWeb.urlBase = self.urlBase;

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
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navigationController.navigationBar.barStyle =  UIBarStyleBlack;
        navigationController.navigationBar.tintColor = NCBrandColor.sharedInstance.customerText;
        navigationController.navigationBar.barTintColor = NCBrandColor.sharedInstance.customer;
        [navigationController.navigationBar setTranslucent:false];
        self.window.rootViewController = navigationController;
        
        [self.window makeKeyAndVisible];
        
    } else if ([contextViewController isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController *navigationController = ((UINavigationController *)contextViewController);
        [navigationController pushViewController:viewController animated:true];
        
    } else {
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        navigationController.navigationBar.barStyle =  UIBarStyleBlack;
        navigationController.navigationBar.tintColor = NCBrandColor.sharedInstance.customerText;
        navigationController.navigationBar.barTintColor = NCBrandColor.sharedInstance.customer;
        [navigationController.navigationBar setTranslucent:false];
        
        [contextViewController presentViewController:navigationController animated:true completion:nil];
    }
}

- (void)startTimerErrorNetworking
{
    self.timerErrorNetworking = [NSTimer scheduledTimerWithTimeInterval:k_timerErrorNetworking target:self selector:@selector(checkErrorNetworking) userInfo:nil repeats:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Account & Communication =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingAccount:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user userID:(NSString *)userID password:(NSString *)password
{
    self.account = account;
    self.urlBase = urlBase;
    self.user = user;
    self.userID = userID;
    self.password = password;

    (void)[NCNetworkingNotificationCenter shared];

    [[NCCommunicationCommon shared] setupWithAccount:account user:user userId:userID password:password urlBase:urlBase];
    [self settingSetupCommunication:account];
}

- (void)deleteAccount:(NSString *)account wipe:(BOOL)wipe
{
    // Push Notification
    tableAccount *accountPN = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    [self unsubscribingNextcloudServerPushNotification:accountPN.account urlBase:accountPN.urlBase user:accountPN.user withSubscribing:false];

    [self settingAccount:nil urlBase:nil user:nil userID:nil password:nil];
    
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
            [self settingAccount:newAccount urlBase:tableAccount.urlBase user:tableAccount.user userID:tableAccount.userID password:[CCUtility getPassword:tableAccount.account]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
        } else {
            [self openLoginView:self.window.rootViewController selector:k_intro_login openLoginWeb:false];
        }
    }
}

- (void)settingSetupCommunication:(NSString *)account
{
    NSInteger serverVersionMajor = [[NCManageDatabase sharedInstance] getCapabilitiesServerIntWithAccount:account elements:NCElementsJSON.shared.capabilitiesVersionMajor];
    if (serverVersionMajor > 0) {
        [[NCCommunicationCommon shared] setupWithNextcloudVersion:serverVersionMajor];
    }
    
    [[NCCommunicationCommon shared] setupWithWebDav:[[NCUtility shared] getWebDAVWithAccount:account]];
    [[NCCommunicationCommon shared] setupWithDav:[[NCUtility shared] getDAV]];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Push Notifications =====
#pragma --------------------------------------------------------------------------------------------

- (void)pushNotification
{
    if (self.account.length == 0 || self.pushKitToken.length == 0) { return; }
    
    for (tableAccount *result in [[NCManageDatabase sharedInstance] getAllAccount]) {
        
        NSString *token = [CCUtility getPushNotificationToken:result.account];
        
        if (![token isEqualToString:self.pushKitToken]) {
            if (token != nil) {
                // unsubscribing + subscribing
                [self unsubscribingNextcloudServerPushNotification:result.account urlBase:result.urlBase user:result.user withSubscribing:true];
            } else {
                [self subscribingNextcloudServerPushNotification:result.account urlBase:result.urlBase user:result.user];
            }
        }
    }
}

- (void)subscribingNextcloudServerPushNotification:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user
{
    if (self.account.length == 0 || self.pushKitToken.length == 0) { return; }
    
    [[NCPushNotificationEncryption sharedInstance] generatePushNotificationsKeyPair:account];

    NSString *pushTokenHash = [[NCEndToEndEncryption sharedManager] createSHA512:self.pushKitToken];
    NSData *pushPublicKey = [CCUtility getPushNotificationPublicKey:account];
    NSString *pushDevicePublicKey = [[NSString alloc] initWithData:pushPublicKey encoding:NSUTF8StringEncoding];
    NSString *proxyServerPath = [NCBrandOptions sharedInstance].pushNotificationServerProxy;
    
    [[NCCommunication shared] subscribingPushNotificationWithServerUrl:urlBase account:account user:user password:[CCUtility getPassword:account] pushTokenHash:pushTokenHash devicePublicKey:pushDevicePublicKey proxyServerUrl:proxyServerPath customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSString *deviceIdentifier, NSString *signature, NSString *publicKey, NSInteger errorCode, NSString *errorDescription) {
        if (errorCode == 0) {
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [CCUtility getUserAgent]];
            [[NCCommunication shared] subscribingPushProxyWithProxyServerUrl:proxyServerPath pushToken:self.pushKitToken deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey userAgent:userAgent completionHandler:^(NSInteger errorCode, NSString *errorDescription) {
                if (errorCode == 0) {
                    
                    [[NCCommunicationCommon shared] writeLog:@"Subscribed to Push Notification server & proxy successfully"];

                    [CCUtility setPushNotificationToken:account token:self.pushKitToken];
                    [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:deviceIdentifier];
                    [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:signature];
                    [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:publicKey];
                }
            }];
        }
    }];
}

- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user withSubscribing:(BOOL)subscribing
{
    if (self.account.length == 0) { return; }
    
    NSString *deviceIdentifier = [CCUtility getPushNotificationDeviceIdentifier:account];
    NSString *signature = [CCUtility getPushNotificationDeviceIdentifierSignature:account];
    NSString *publicKey = [CCUtility getPushNotificationSubscribingPublicKey:account];

    [[NCCommunication shared] unsubscribingPushNotificationWithServerUrl:urlBase account:account user:user password:[CCUtility getPassword:account] customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSInteger errorCode, NSString *errorDescription) {
        if (errorCode == 0) {
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [CCUtility getUserAgent]];
            NSString *proxyServerPath = [NCBrandOptions sharedInstance].pushNotificationServerProxy;
            [[NCCommunication shared] unsubscribingPushProxyWithProxyServerUrl:proxyServerPath deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey userAgent:userAgent completionHandler:^(NSInteger errorCode, NSString *errorDescription) {
                if (errorCode == 0) {
                
                    [[NCCommunicationCommon shared] writeLog:@"Unsubscribed to Push Notification server & proxy successfully."];
                    
                    [CCUtility setPushNotificationPublicKey:account data:nil];
                    [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:nil];
                    [CCUtility setPushNotificationPrivateKey:account data:nil];
                    [CCUtility setPushNotificationToken:account token:nil];
                    [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:nil];
                    [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:nil];
                    
                    if (self.pushKitToken != nil && subscribing) {
                        [self subscribingNextcloudServerPushNotification:account urlBase:urlBase user:user];
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
#pragma mark ===== ApplicationIconBadgeNumber =====
#pragma --------------------------------------------------------------------------------------------

- (void)updateApplicationIconBadgeNumber
{
    if (self.account.length == 0) { return; }
            
    NSInteger counterDownload = [[NCOperationQueue shared] downloadCount];
    NSInteger counterUpload = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status == %d OR status == %d OR status == %d", k_metadataStatusWaitUpload, k_metadataStatusInUpload, k_metadataStatusUploading]].count;
    NSInteger total = counterDownload + counterUpload;
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = total;
    
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    if ([tabBarController isKindOfClass:[UITabBarController class]]) {
        UITabBarItem *tabBarItem = [tabBarController.tabBar.items objectAtIndex:0];
        if (total > 0) {
            [tabBarItem setBadgeValue:[NSString stringWithFormat:@"%li", (unsigned long)total]];
        } else {
            [tabBarItem setBadgeValue:nil];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Fetch =====
#pragma --------------------------------------------------------------------------------------------

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (self.account.length == 0) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }
    
    [[NCCommunicationCommon shared] writeLog:@"Start perform Fetch With Completion Handler"];
    
    // Verify new photo
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    // after 20 sec
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[NCCommunicationCommon shared] writeLog:@"End 20 sec. perform Fetch With Completion Handler"];
        completionHandler(UIBackgroundFetchResultNoData);
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
    [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Start handle Events For Background URLSession: %@", identifier]];
    
    [self updateApplicationIconBadgeNumber];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.backgroundSessionCompletionHandler = completionHandler;
        void (^completionHandler)() = self.backgroundSessionCompletionHandler;
        self.backgroundSessionCompletionHandler = nil;
        completionHandler();
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== OpenURL  =====
#pragma --------------------------------------------------------------------------------------------

// Method called from iOS system to send a file from other app.
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    if (self.account.length == 0) { return YES; }
    
    NSString *scheme = url.scheme;
    NSString *fileName;
    NSString *serverUrl;

    if ([scheme isEqualToString:@"nextcloud"]) {
                
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
                    NSURL *accountURL = [NSURL URLWithString:account.urlBase];
                    NSString *accountUser = account.user;
                    if ([link containsString:accountURL.host] && [user isEqualToString:accountUser]) {
                        matchedAccount = account;
                    } else {
                        NSArray *accounts = [[NCManageDatabase sharedInstance] getAllAccount];
                        for (tableAccount *account in accounts) {
                            NSURL *accountURL = [NSURL URLWithString:account.urlBase];
                            NSString *accountUser = account.user;
                            if ([link containsString:accountURL.host] && [user isEqualToString:accountUser]) {
                                matchedAccount = [[NCManageDatabase sharedInstance] setAccountActive:account.account];
                                [self settingAccount:matchedAccount.account urlBase:matchedAccount.urlBase user:matchedAccount.user userID:matchedAccount.userID password:[CCUtility getPassword:matchedAccount.account]];
                                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
                            }
                        }
                    }
                    
                    if (matchedAccount) {
                        
                        NSString *webDAV = [[NCUtility shared] getWebDAVWithAccount:self.account];

                        if ([path containsString:@"/"]) {

                            fileName = [path lastPathComponent];
                            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", matchedAccount.urlBase, webDAV, [path stringByDeletingLastPathComponent]];
                            
                        } else {
                            
                            fileName = path;
                            serverUrl = [NSString stringWithFormat:@"%@/%@", matchedAccount.urlBase, webDAV];
                        }
                        
                        [[NCCollectionCommon shared] openFileViewInFolderWithServerUrl:serverUrl fileName:fileName];
                   
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
        return YES;
    }
    
    NSError *error;
    NSLog(@"[LOG] the path is: %@", url.path);
        
    NSArray *splitedUrl = [url.path componentsSeparatedByString:@"/"];
    self.fileNameUpload = [NSString stringWithFormat:@"%@",[splitedUrl objectAtIndex:([splitedUrl count]-1)]];
    
    if (self.account) {
        
        [[NSFileManager defaultManager]removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:self.fileNameUpload] error:nil];
        [[NSFileManager defaultManager]moveItemAtPath:url.path toPath:[NSTemporaryDirectory() stringByAppendingString:self.fileNameUpload] error:&error];
        
        if (error == nil) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                UIViewController *uploadNavigationViewController = [[UIStoryboard storyboardWithName:@"CCUploadFromOtherUpp" bundle:nil] instantiateViewControllerWithIdentifier:@"CCUploadNavigationViewController"];
                [self.window.rootViewController presentViewController:uploadNavigationViewController animated:YES completion:nil];
            });
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
    
    if ([[CCUtility getPasscode] length] == 0 || [self.account length] == 0 || [CCUtility getNotPasscodeAtStart]) return;
    
    if (self.passcodeViewController == nil) {
           
        self.passcodeViewController = [[TOPasscodeViewController alloc] initWithStyle:TOPasscodeViewStyleTranslucentLight passcodeType:TOPasscodeTypeSixDigits];
        if (@available(iOS 13.0, *)) {
            if ([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
                self.passcodeViewController.style = TOPasscodeViewStyleTranslucentDark;
            }
        }

        self.passcodeViewController.delegate = self;
        self.passcodeViewController.keypadButtonShowLettering = false;
        
        if (CCUtility.getEnableTouchFaceID && [laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
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
    
        [self.window.rootViewController presentViewController:self.passcodeViewController animated:YES completion:^{
            [self enableTouchFaceID:automaticallyPromptForBiometricValidation];
        }];
        
    } else {
    
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
            [self enableTouchFaceID:automaticallyPromptForBiometricValidation];
        });
    }
}

- (void)didInputCorrectPasscodeInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [passcodeViewController dismissViewControllerAnimated:YES completion:^{
        self.passcodeViewController = nil;
    }];
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
                [passcodeViewController dismissViewControllerAnimated:YES completion:^{
                    self.passcodeViewController = nil;
                }];
            });
        }
    }];
}

- (void)enableTouchFaceID:(BOOL)automaticallyPromptForBiometricValidation
{
    if (CCUtility.getEnableTouchFaceID && automaticallyPromptForBiometricValidation && self.passcodeViewController.view.window) {
        [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions sharedInstance] brand] reply:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                    [self.passcodeViewController dismissViewControllerAnimated:YES completion:^{
                        self.passcodeViewController = nil;
                    }];
                });
            }
        }];
    }
}

@end
