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
#import "NCBridgeSwift.h"
#import "NCAutoUpload.h"
#import "NSNotificationCenter+MainThread.h"
#import "NCPushNotification.h"
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
    
    if (![CCUtility getDisableCrashservice] && NCBrandOptions.shared.disable_crash_service == false) {
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
    NSString *versionNextcloudiOS = [NSString stringWithFormat:[NCBrandOptions shared].textCopyrightNextcloudiOS, versionApp];
    if (isSimulatorOrTestFlight) {
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Start session with level %lu %@ (Simulator / TestFlight)", (unsigned long)logLevel, versionNextcloudiOS]];
    } else {
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Start session with level %lu %@", (unsigned long)logLevel, versionNextcloudiOS]];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializeMain:) name:NCBrandGlobal.shared.notificationCenterInitializeMain object:nil];
    
    // Set account, if no exists clear all
    tableAccount *tableAccount = [[NCManageDatabase shared] getAccountActive];
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
            [[NCManageDatabase shared] updateAccount:tableAccount];
            
            tableAccount = [[NCManageDatabase shared] getAccountActive];
        }
        [self settingAccount:tableAccount.account urlBase:tableAccount.urlBase user:tableAccount.user userID:tableAccount.userID password:[CCUtility getPassword:tableAccount.account]];
    }
    
    // UserDefaults
    self.ncUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:[NCBrandOptions shared].capabilitiesGroups];
        
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
        
    if ([NCBrandOptions shared].disable_intro) {
        [CCUtility setIntro:YES];
        
        if (self.account == nil || self.account.length == 0) {
            [self openLoginView:nil selector:NCBrandGlobal.shared.introLogin openLoginWeb:false];
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
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterInitializeMain object:nil userInfo:nil];

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
    if (self.account == nil || self.account.length == 0) { return; }
    
    // Dismiss FileViewInFolder
    if (self.activeFileViewInFolder != nil ) {
        [self.activeFileViewInFolder dismissViewControllerAnimated:false completion:^{
            self.activeFileViewInFolder = nil;
        }];
    }
}

//
// L' applicazione entrerà in primo piano (attivo solo dopo il background)
//
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    if (self.account == nil || self.account.length == 0) { return; }
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterApplicationWillEnterForeground object:nil];
    
    // Request Passcode
    [self passcodeWithAutomaticallyPromptForBiometricValidation:true];
    
    // Initialize Auto upload
    [[NCAutoUpload shared] initStateAutoUpload];
    
    // Read active directory
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterReloadDataSourceNetworkForced object:nil];
    
    // Required unsubscribing / subscribing
    [[NCPushNotification shared] pushNotification];
    
    // RichDocument
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterRichdocumentGrabFocus object:nil];
    
    // Request Service Server Nextcloud
    [[NCService shared] startRequestServicesServer];
}

//
// L' applicazione entrerà in primo piano (attivo sempre)
//
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (self.account == nil || self.account.length == 0) { return; }
        
    // Brand
    #if defined(HC)
    tableAccount *account = [[NCManageDatabase shared] getAccountActive];
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
    if (self.account == nil || self.account.length == 0) { return; }

    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterApplicationDidEnterBackground object:nil];
    
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
    if (self.account == nil || self.account.length == 0) { return; }
    
    // Clear error certificate
    [CCUtility setCertificateError:self.account error:NO];
    
    // Setting Theming
    [[NCBrandColor shared] settingThemingColorWithAccount:self.account];
    
    // close detail
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterMenuDetailClose object:nil];
    
    // Not Photos Video in library ? then align and Init Auto Upload
    NSArray *recordsPhotoLibrary = [[NCManageDatabase shared] getPhotoLibraryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", self.account]];
    if ([recordsPhotoLibrary count] == 0) {
        [[NCAutoUpload shared] alignPhotoLibrary];
    }
    
    // Start Auto Upload
    [[NCAutoUpload shared] initStateAutoUpload];
    
    // Start services
    [[NCService shared] startRequestServicesServer];
    
    // Registeration push notification
    [[NCPushNotification shared] pushNotification];
    
    // Registeration domain File Provider
    //FileProviderDomain *fileProviderDomain = [FileProviderDomain new];
    //[fileProviderDomain removeAllDomains];
    //[fileProviderDomain registerDomains];
    
    [[NCCommunicationCommon shared] writeLog:@"initialize Main"];
}

#pragma mark Login / checkErrorNetworking

- (void)checkErrorNetworking
{
    if (self.account == nil || self.account.length == 0) { return; }
    
    // check unauthorized server (401)
    if ([CCUtility getPassword:self.account].length == 0) {
        
        [self openLoginView:self.window.rootViewController selector:NCBrandGlobal.shared.introLogin openLoginWeb:true];
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
    if ([NCBrandOptions shared].use_configuration) {
        
        if (!(_appConfigView.isViewLoaded && _appConfigView.view.window)) {
        
            self.appConfigView = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCAppConfigView"];
            
            [self showLoginViewController:self.appConfigView forContext:viewController];
        }
    
        return;
    }
    
    // only for personalized LoginWeb [customer]
    if ([NCBrandOptions shared].use_login_web_personalized) {
        
        if (!(_activeLoginWeb.isViewLoaded && _activeLoginWeb.view.window)) {
            
            self.activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
            self.activeLoginWeb.urlBase = [[NCBrandOptions shared] loginBaseUrl];

            [self showLoginViewController:self.activeLoginWeb forContext:viewController];
        }
        
        return;
    }
    
    // normal login
    if (selector == NCBrandGlobal.shared.introSignup) {
        
        if (!(_activeLoginWeb.isViewLoaded && _activeLoginWeb.view.window)) {
            
            self.activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
            
            if (selector == NCBrandGlobal.shared.introSignup) {
                self.activeLoginWeb.urlBase = [[NCBrandOptions shared] linkloginPreferredProviders];
            } else {
                self.activeLoginWeb.urlBase = self.urlBase;
            }
            
           [self showLoginViewController:self.activeLoginWeb forContext:viewController];
        }
        
    } else if ([NCBrandOptions shared].disable_intro && [NCBrandOptions shared].disable_request_login_url) {
        
        self.activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
        self.activeLoginWeb.urlBase = [[NCBrandOptions shared] loginBaseUrl];
        
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
        navigationController.navigationBar.tintColor = NCBrandColor.shared.customerText;
        navigationController.navigationBar.barTintColor = NCBrandColor.shared.customer;
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
        navigationController.navigationBar.tintColor = NCBrandColor.shared.customerText;
        navigationController.navigationBar.barTintColor = NCBrandColor.shared.customer;
        [navigationController.navigationBar setTranslucent:false];
        
        [contextViewController presentViewController:navigationController animated:true completion:nil];
    }
}

- (void)startTimerErrorNetworking
{
    self.timerErrorNetworking = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(checkErrorNetworking) userInfo:nil repeats:YES];
}

#pragma mark Account & Communication

- (void)settingAccount:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user userID:(NSString *)userID password:(NSString *)password
{
    self.account = account;
    self.urlBase = urlBase;
    self.user = user;
    self.userID = userID;
    self.password = password;

    (void)[NCNetworkingNotificationCenter shared];

    [[NCCommunicationCommon shared] setupWithAccount:account user:user userId:userID password:password urlBase:urlBase];
    
    NSInteger serverVersionMajor = [[NCManageDatabase shared] getCapabilitiesServerIntWithAccount:account elements:NCElementsJSON.shared.capabilitiesVersionMajor];
    if (serverVersionMajor > 0) {
        [[NCCommunicationCommon shared] setupWithNextcloudVersion:serverVersionMajor];
    }
    
    [[NCCommunicationCommon shared] setupWithWebDav:[[NCUtilityFileSystem shared] getWebDAVWithAccount:account]];
    [[NCCommunicationCommon shared] setupWithDav:[[NCUtilityFileSystem shared] getDAV]];
}

- (void)deleteAccount:(NSString *)account wipe:(BOOL)wipe
{
    // Push Notification
    tableAccount *accountPN = [[NCManageDatabase shared] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    [[NCPushNotification shared] unsubscribingNextcloudServerPushNotification:accountPN.account urlBase:accountPN.urlBase user:accountPN.user withSubscribing:false];

    [self settingAccount:nil urlBase:nil user:nil userID:nil password:nil];
    
    /* DELETE ALL FILES LOCAL FS */
    NSArray *results = [[NCManageDatabase shared] getTableLocalFilesWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account] sorted:@"ocId" ascending:NO];
    for (tableLocalFile *result in results) {
        [CCUtility removeFileAtPath:[CCUtility getDirectoryProviderStorageOcId:result.ocId]];
    }
    // Clear database
    [[NCManageDatabase shared] clearDatabaseWithAccount:account removeAccount:true];

    [CCUtility clearAllKeysEndToEnd:account];
    [CCUtility clearAllKeysPushNotification:account];
    [CCUtility setCertificateError:account error:false];
    [CCUtility setPassword:account password:nil];
       
    if (wipe) {
        NSArray *listAccount = [[NCManageDatabase shared] getAccounts];
        if ([listAccount count] > 0) {
            NSString *newAccount = listAccount[0];
            tableAccount *tableAccount = [[NCManageDatabase shared] setAccountActive:newAccount];
            [self settingAccount:newAccount urlBase:tableAccount.urlBase user:tableAccount.user userID:tableAccount.userID password:[CCUtility getPassword:tableAccount.account]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterInitializeMain object:nil userInfo:nil];
        } else {
            [self openLoginView:self.window.rootViewController selector:NCBrandGlobal.shared.introLogin openLoginWeb:false];
        }
    }
}

#pragma mark Push Notifications

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    completionHandler(UNNotificationPresentationOptionAlert);
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(nonnull UNNotificationResponse *)response withCompletionHandler:(nonnull void (^)(void))completionHandler
{
    completionHandler();
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[NCPushNotification shared] registerForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [[NCPushNotification shared] applicationdidReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        completionHandler(result);
    }];
}

#pragma mark Fetch

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (self.account == nil || self.account.length == 0) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }
    
    [[NCCommunicationCommon shared] writeLog:@"Start perform Fetch With Completion Handler"];
    
    // Verify new photo
    [[NCAutoUpload shared] initStateAutoUpload];
    
    // after 20 sec
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[NCCommunicationCommon shared] writeLog:@"End 20 sec. perform Fetch With Completion Handler"];
        completionHandler(UIBackgroundFetchResultNoData);
    });
}

#pragma mark Operation Networking & Session

//
// Method called by the system when all the background task has end
//
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler
{
    [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Start handle Events For Background URLSession: %@", identifier]];
        
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.backgroundSessionCompletionHandler = completionHandler;
        void (^completionHandler)() = self.backgroundSessionCompletionHandler;
        self.backgroundSessionCompletionHandler = nil;
        completionHandler();
    });
}

#pragma mark OpenURL

// Method called from iOS system to send a file from other app.
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    if (self.account == nil || self.account.length == 0) { return YES; }
    
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
            
                tableAccount *account = [[NCManageDatabase shared] getAccountActive];
                if (account) {
                    NSURL *accountURL = [NSURL URLWithString:account.urlBase];
                    NSString *accountUser = account.user;
                    if ([link containsString:accountURL.host] && [user isEqualToString:accountUser]) {
                        matchedAccount = account;
                    } else {
                        NSArray *accounts = [[NCManageDatabase shared] getAllAccount];
                        for (tableAccount *account in accounts) {
                            NSURL *accountURL = [NSURL URLWithString:account.urlBase];
                            NSString *accountUser = account.user;
                            if ([link containsString:accountURL.host] && [user isEqualToString:accountUser]) {
                                matchedAccount = [[NCManageDatabase shared] setAccountActive:account.account];
                                [self settingAccount:matchedAccount.account urlBase:matchedAccount.urlBase user:matchedAccount.user userID:matchedAccount.userID password:[CCUtility getPassword:matchedAccount.account]];
                                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterInitializeMain object:nil userInfo:nil];
                            }
                        }
                    }
                    
                    if (matchedAccount) {
                        
                        NSString *webDAV = [[NCUtilityFileSystem shared] getWebDAVWithAccount:self.account];

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
    
    if (self.account && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:self.fileNameUpload] error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:url.path toPath:[NSTemporaryDirectory() stringByAppendingString:self.fileNameUpload] error:&error];
        
        if (error == nil) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                UIViewController *uploadNavigationViewController = [[UIStoryboard storyboardWithName:@"CCUploadFromOtherUpp" bundle:nil] instantiateViewControllerWithIdentifier:@"CCUploadNavigationViewController"];
                [self.window.rootViewController presentViewController:uploadNavigationViewController animated:YES completion:nil];
            });
        }
    }
    
    return YES;
}

#pragma mark Passcode + Delegate

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
    [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions shared] brand] reply:^(BOOL success, NSError * _Nullable error) {
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
        [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions shared] brand] reply:^(BOOL success, NSError * _Nullable error) {
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
