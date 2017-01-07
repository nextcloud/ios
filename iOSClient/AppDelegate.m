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
#import "OCFrameworkConstants.h"
#import "AFURLSessionManager.h"
#import "JBroken.h"
#import "CCNetworking.h"
#import "CCCoreData.h"
#import "CCCrypto.h"
#import "CCFavorite.h"
#import "CCManageAsset.h"
#import "CCGraphics.h"
#import "CCPhotosCameraUpload.h"
#import "CCSynchronization.h"
#import "CCMain.h"
#import "CCDetail.h"

@interface AppDelegate ()
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
    NSString *dir;
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:capabilitiesGroups];
    
    NSLog(@"[LOG] Start program group %@", dirGroup);
    
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
        
        [self settingActiveAccount:recordAccount.account activeUrl:recordAccount.url activeUser:recordAccount.user activePassword:recordAccount.password activeUID:recordAccount.uid activeAccessToken:recordAccount.token typeCloud:recordAccount.typeCloud];
    }
    
    // Operation Queue OC-DB Networking
    _netQueue = [[NSOperationQueue alloc] init];
    _netQueue.name = netQueueName;
    _netQueue.maxConcurrentOperationCount = maxConcurrentOperation;
   
    _netQueueDownload = [[NSOperationQueue alloc] init];
    _netQueueDownload.name = netQueueDownloadName;
    _netQueueDownload.maxConcurrentOperationCount = maxConcurrentOperationDownloadUpload;

    _netQueueDownloadWWan = [[NSOperationQueue alloc] init];
    _netQueueDownloadWWan.name = netQueueDownloadWWanName;
    _netQueueDownloadWWan.maxConcurrentOperationCount = maxConcurrentOperationDownloadUpload;
    
    _netQueueUpload = [[NSOperationQueue alloc] init];
    _netQueueUpload.name = netQueueUploadName;
    _netQueueUpload.maxConcurrentOperationCount = maxConcurrentOperationDownloadUpload;
    
    _netQueueUploadWWan = [[NSOperationQueue alloc] init];
    _netQueueUploadWWan.name = netQueueUploadWWanName;
    _netQueueUploadWWan.maxConcurrentOperationCount = maxConcurrentOperationDownloadUpload;
    
#ifdef CC
    // Inizialize DBSession for Dropbox
    NSString *appKey = appKeyCryptoCloud;
    NSString *appSecret = appSecretCryptoCloud;
    
    DBSession *dbSession = [[DBSession alloc] initWithAppKey:appKey appSecret:appSecret root:kDBRootDropbox];
    [DBSession setSharedSession:dbSession];
#endif
    
    // Add notification change session
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionChanged:) name:networkingSessionNotification object:nil];
    
    // Inizializzazioni Share
    self.sharesID = [[NSMutableDictionary alloc] init];
    self.sharesLink = [[NSMutableDictionary alloc] init];
    self.sharesUserAndGroup = [[NSMutableDictionary alloc] init];
    
    // Verify Session in progress and Init date task
    self.sessionDateLastDownloadTasks = [NSDate date];
    self.sessionDateLastUploadTasks = [NSDate date];
    self.timerVerifySessionInProgress = [NSTimer scheduledTimerWithTimeInterval:timerVerifySession target:self selector:@selector(verifyDownloadUploadInProgress) userInfo:nil repeats:YES];
    
    // Background Fetch
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    // Init List
    self.listProgressMetadata = [[NSMutableDictionary alloc] init];
    self.listChangeTask = [[NSMutableDictionary alloc] init];
    self.listMainVC = [[NSMutableDictionary alloc] init];
    
    // Player audio
    self.player = [LMMediaPlayerView sharedPlayerView];
    self.player.delegate = self;
    
    // ico Image Cache
    self.icoImagesCache = [[NSMutableDictionary alloc] init];
    
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
    
    // permission request camera roll
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    
    [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        //NSLog(@"[LOG] %li",(long)[group numberOfAssets]);
    } failureBlock:^(NSError *error) {
        if (error.code == ALAssetsLibraryAccessUserDeniedError) {
            NSLog(@"[LOG] user denied access, code: %li",(long)error.code);
        }else{
            NSLog(@"[LOG] Other error code: %li",(long)error.code);
        }
    }];
    
    // permission request notification
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge|UIUserNotificationTypeAlert|UIUserNotificationTypeSound) categories:nil];
        [application registerUserNotificationSettings:settings];
    }
    
    // it is a device Jailbroken
    self.isDeviceJailbroken = isDeviceJailbroken();

    [self.window setTintColor:COLOR_BRAND];
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    //UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];

    navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
    // Settings TabBar
    [self createTabBarController];
    [self plusButton:true];
    
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
    self.timerVerifyProcess = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(verifyProcess) userInfo:nil repeats:YES];
    
    return YES;
}

//
// L' applicazione è diventata attiva
//
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // After 5 sec. for wait load app.activeMain start if exists in Table Automatic Upload + All
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        if ([CCCoreData countTableAutomaticUploadForAccount:self.activeAccount selector:selectorUploadAutomatic] > 0)
            [app loadTableAutomaticUploadForSelector:selectorUploadAutomatic];
    
        if ([CCCoreData countTableAutomaticUploadForAccount:self.activeAccount selector:selectorUploadAutomaticAll] > 0)
            [app loadTableAutomaticUploadForSelector:selectorUploadAutomaticAll];
    });
}

//
// L' applicazione si dimetterà dallo stato di attivo
//
- (void)applicationWillResignActive:(UIApplication *)application
{
    [self updateApplicationIconBadgeNumber];
}

//
// L' applicazione entrerà in primo piano (attivo solo dopo il background)
//
- (void)applicationWillEnterForeground:(UIApplication *)application
{    
    // facciamo partire il timer per il controllo delle sessioni
    [self.timerVerifySessionInProgress invalidate];
    self.timerVerifySessionInProgress = [NSTimer scheduledTimerWithTimeInterval:timerVerifySession target:self selector:@selector(verifyDownloadUploadInProgress) userInfo:nil repeats:YES];
    
    // refresh active Main
    if (_activeMain)
        [_activeMain getDataSourceWithReloadTableView];
    
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

//
// Application Initialized
//
- (void)applicationInitialized
{
    // now
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //NSLog(@"[LOG] Read Folder for change Rev");
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"readFileSelfFolderRev" object:nil];
        
    });

    // 0.5 sec.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //
        NSLog(@"[LOG] Request Server Information");
        //
        if (_activeMain)
            [_activeMain requestServerInformation];
        
    });
    
    // 1 sec.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        NSLog(@"[LOG] Synchronize Favorites");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"synchronizedFavorites" object:nil];
        
        NSLog(@"[LOG] Synchronize Folders");
        [[CCSynchronization sharedSynchronization] synchronizationFolders];
        
    });
    
    // 1.5 sec.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        NSLog(@"[LOG] Initialize Camera Upload");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"initStateCameraUpload" object:nil];
    });
    
    // Initialize Camera Upload
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"initStateCameraUpload" object:@{@"afterDelay": @(2)}];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Verify Process 5 seconds =====
#pragma --------------------------------------------------------------------------------------------

- (void)verifyProcess
{
// BACKGROND & FOREGROUND
    
    /* Active/Disactive Graphics Animation Synchronization Folders */
    NSArray *records = [CCCoreData getSynchronizedDirectoryActiveAccount:app.activeAccount];
    NSMutableArray *directory = [[NSMutableArray alloc] init];
    for (TableDirectory *record in records)
        [directory addObject:record.serverUrl];
    
    if ([directory count] > 0)
        [[CCSynchronization sharedSynchronization] synchronizationAnimationDirectory:directory callViewController:YES];

// ONLY BACKGROUND
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
    
       
    } else {

// ONLY FOREFROUND
    
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Setting Active Account =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl activeUser:(NSString *)activeUser activePassword:(NSString *)activePassword activeUID:(NSString *)activeUID activeAccessToken:(NSString *)activeAccessToken typeCloud:(NSString *)typeCloud
{
    self.activeAccount = activeAccount;
    self.activeUrl = activeUrl;
    self.activeUser = activeUser;
    self.activePassword = activePassword;
    self.typeCloud = typeCloud;
    
    self.directoryUser = [CCUtility getDirectoryActiveUser:activeUser activeUrl:activeUrl];
    
    self.activeUID = activeUID;
    self.activeAccessToken = activeAccessToken;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Quick Actions - ShotcutItem =====
#pragma --------------------------------------------------------------------------------------------

- (void)configDynamicShortcutItems
{
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;

    UIApplicationShortcutIcon *shortcutPhotosIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:image_quickActionPhotos];
    UIApplicationShortcutIcon *shortcutUploadClearIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:image_quickActionUploadClear];
    UIApplicationShortcutIcon *shortcutUploadEncryptedIcon = [UIApplicationShortcutIcon iconWithTemplateImageName:image_quickActionUploadEncrypted];
    
    UIApplicationShortcutItem *shortcutPhotos = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.photos", bundleId] localizedTitle:NSLocalizedString(@"_photo_camera_", nil) localizedSubtitle:nil icon:shortcutPhotosIcon userInfo:nil];

    UIApplicationShortcutItem *shortcutFavorite = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.favorite", bundleId] localizedTitle:NSLocalizedString(@"_favorites_", nil) localizedSubtitle:nil icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeFavorite] userInfo:nil];
    
    UIApplicationShortcutItem *shortcutUploadClear = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.uploadClear", bundleId] localizedTitle:NSLocalizedString(@"_upload_file_", nil) localizedSubtitle:nil icon:shortcutUploadClearIcon userInfo:nil];
    
    UIApplicationShortcutItem *shortcutUploadEncrypted = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.uploadEncrypted", bundleId] localizedTitle:NSLocalizedString(@"_upload_encrypted_file_", nil) localizedSubtitle:nil icon:shortcutUploadEncryptedIcon userInfo:nil];
    
    // add all items to an array
    NSArray *items = @[shortcutUploadEncrypted, shortcutUploadClear, shortcutPhotos, shortcutFavorite];
    
    // add the array to our app
    [UIApplication sharedApplication].shortcutItems = items;
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
    
    NSString *shortcutFavorite = [NSString stringWithFormat:@"%@.favorite", bundleId];
    NSString *shortcutPhotos = [NSString stringWithFormat:@"%@.photos", bundleId];
    NSString *shortcutUploadClear = [NSString stringWithFormat:@"%@.uploadClear", bundleId];
    NSString *shortcutUploadEncrypted = [NSString stringWithFormat:@"%@.uploadEncrypted", bundleId];
        
    if ([shortcutItem.type isEqualToString:shortcutUploadClear] && self.activeAccount) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (_activeMain) {
                
                UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
                
                if (splitViewController.isCollapsed) {
                    
                    UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                    for (UINavigationController *nvc in tbc.viewControllers) {
                        
                        if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                            [nvc popToRootViewControllerAnimated:NO];
                    }
                    
                    [tbc setSelectedIndex:TabBarApplicationIndexFile];
                    
                } else {
                    
                    UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                    [nvcDetail popToRootViewControllerAnimated:NO];
                    
                    UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                    [tbc setSelectedIndex:TabBarApplicationIndexFile];
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
                    
                    [tbc setSelectedIndex:TabBarApplicationIndexFile];
                    
                } else {
                    
                    UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                    [nvcDetail popToRootViewControllerAnimated:NO];
                    
                    UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                    [tbc setSelectedIndex:TabBarApplicationIndexFile];
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
            
                [tbc setSelectedIndex:TabBarApplicationIndexPhotos];

            } else {
            
                UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                [nvcDetail popToRootViewControllerAnimated:NO];
            
                UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                [tbc setSelectedIndex:TabBarApplicationIndexPhotos];
            }
        });
        
        handled = YES;
    }
    
    else if ([shortcutItem.type isEqualToString:shortcutFavorite] && self.activeAccount) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        
            if (splitViewController.isCollapsed) {
            
                UITabBarController *tbc = splitViewController.viewControllers.firstObject;
                for (UINavigationController *nvc in tbc.viewControllers) {
                
                    if ([nvc.topViewController isKindOfClass:[CCDetail class]])
                        [nvc popToRootViewControllerAnimated:NO];
                
                    if ([nvc.topViewController isKindOfClass:[CCFavorite class]])
                        [(CCFavorite *)nvc.topViewController forcedSwitchFavorite];
                }
            
                [tbc setSelectedIndex:TabBarApplicationIndexFavorite];
            
            } else {
            
                UINavigationController *nvcDetail = splitViewController.viewControllers.lastObject;
                [nvcDetail popToRootViewControllerAnimated:NO];
            
                UITabBarController *tbc = splitViewController.viewControllers.firstObject;
        
                UINavigationController *ncFavorite = [tbc.viewControllers objectAtIndex:TabBarApplicationIndexFavorite];
                if ([ncFavorite.topViewController isKindOfClass:[CCFavorite class]])
                    [(CCFavorite *)ncFavorite.topViewController forcedSwitchFavorite];
            
                [tbc setSelectedIndex:TabBarApplicationIndexFavorite];
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
            backgroundColor = COLOR_BRAND_MESSAGE;
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
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    [CCAspect aspectTabBar:tabBarController.tabBar hidden:NO];
    
    // File
    item = [tabBarController.tabBar.items objectAtIndex:TabBarApplicationIndexFile];
    [item setTitle:NSLocalizedString(@"_home_", nil)];
    item.image = [UIImage imageNamed:image_tabBarFile];
    item.selectedImage = [UIImage imageNamed:image_tabBarFile];
    
    // Favorite - Local
    item = [tabBarController.tabBar.items objectAtIndex:TabBarApplicationIndexFavorite];
    if (app.isLocalStorage) {
        [item setTitle:NSLocalizedString(@"_local_storage_", nil)];
        item.image = [UIImage imageNamed:image_tabBarLocal];
        item.selectedImage = [UIImage imageNamed:image_tabBarLocal];
    } else {
        [item setTitle:NSLocalizedString(@"_favorites_", nil)];
        item.image = [UIImage imageNamed:image_tabBarFavorite];
        item.selectedImage = [UIImage imageNamed:image_tabBarFavorite];
    }
    
    // Hide (PLUS)
    item = [tabBarController.tabBar.items objectAtIndex:TabBarApplicationIndexHide];
    item.title = nil;
    item.image = nil;
    item.enabled = false;
    
    // Photos
    item = [tabBarController.tabBar.items objectAtIndex:TabBarApplicationIndexPhotos];
    [item setTitle:NSLocalizedString(@"_photo_camera_", nil)];
    item.image = [UIImage imageNamed:image_tabBarPhotos];
    item.selectedImage = [UIImage imageNamed:image_tabBarPhotos];
    
    // Settings
    item = [tabBarController.tabBar.items objectAtIndex:TabBarApplicationIndexSettings];
    [item setTitle:NSLocalizedString(@"_settings_", nil)];
    item.image = [UIImage imageNamed:image_tabBarSettings];
    item.selectedImage = [UIImage imageNamed:image_tabBarSettings];
    
}

- (void)plusButton:(BOOL)visible
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UITabBarController *tabBarController = [splitViewController.viewControllers firstObject];
    
    UIButton *buttonPlus = [tabBarController.view viewWithTag:99];
    if (buttonPlus)
            [buttonPlus removeFromSuperview];

    if (visible) {
        
        NSLayoutConstraint *constraint;
        
        UIImage *buttonImage = [UIImage imageNamed:@"Plus"];
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
}

- (void)handleTouchTabbarCenter:(id)sender
{
    if (_activeMain)
        [_activeMain addActionTable];
    
    /*
    AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.window.rootViewController.view title:nil];
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"Info", nil)
                              image:[UIImage imageNamed:@"passcode"]
                               type:AHKActionSheetButtonTypeDefault
                            handler:^(AHKActionSheet *as) {
                                if (_activeMain)
                                    [_activeMain returnCreate:returnCreateFolderPlain];
                            }];
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"Add to Favorites", nil)
                              image:[UIImage imageNamed:@"password"]
                               type:AHKActionSheetButtonTypeDefault
                            handler:^(AHKActionSheet *as) {
                                if (_activeMain)
                                    [_activeMain returnCreate:returnCreateFotoVideoPlain];
                            }];
    
      
    [actionSheet show];
    */
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
        
        /*** NEXTCLOUD OWNCLOUD ***/
        
        if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud])
            if (((OCnetworking *)operation).isExecuting == NO) _queueNunDownload++;
        
#ifdef CC
        
        /*** DROPBOX ***/
        
        if ([app.typeCloud isEqualToString:typeCloudDropbox])
            if (((DBnetworking *)operation).isExecuting == NO) _queueNunDownload++;
        
#endif
    }
    
    // netQueueDownloadWWan
    for (NSOperation *operation in [app.netQueueDownloadWWan operations]) {
        
        /*** NEXTCLOUD OWNCLOUD ***/
        
        if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud])
            if (((OCnetworking *)operation).isExecuting == NO) _queueNumDownloadWWan++;
        
#ifdef CC
        
        /*** DROPBOX ***/
        
        if ([app.typeCloud isEqualToString:typeCloudDropbox])
            if (((DBnetworking *)operation).isExecuting == NO) _queueNumDownloadWWan++;
        
#endif
    }
    
    // netQueueUpload
    for (NSOperation *operation in [app.netQueueUpload operations]) {
        
        /*** NEXTCLOUD OWNCLOUD ***/
        
        if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud])
            if (((OCnetworking *)operation).isExecuting == NO) _queueNumUpload++;
        
#ifdef CC
        
        /*** DROPBOX ***/
        
        if ([app.typeCloud isEqualToString:typeCloudDropbox])
            if (((DBnetworking *)operation).isExecuting == NO) _queueNumUpload++;
#endif
    }
    
    // netQueueUploadWWan
    for (NSOperation *operation in [app.netQueueUploadWWan operations]) {
        
        /*** NEXTCLOUD OWNCLOUD ***/
        
        if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud])
            if (((OCnetworking *)operation).isExecuting == NO) _queueNumUploadWWan++;
        
#ifdef CC
        
        /*** DROPBOX ***/
        
        if ([app.typeCloud isEqualToString:typeCloudDropbox])
            if (((DBnetworking *)operation).isExecuting == NO) _queueNumUploadWWan++;
#endif
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
    // fermiamo la data della sessione
    self.sessionePasscodeLock = nil;
    
    // se il block code è a zero esci con NON attivare la richiesta password
    if ([[CCUtility getBlockCode] length] == 0) return NO;
    // se non c'è attivo un account esci con NON attivare la richiesta password
    if ([self.activeAccount length] == 0) return NO;
    // se non c'è il passcode esci con NON attivare la richiesta password
    if ([[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) return NO;
    // se non è attivo il OnlyLockDir esci con NON attivare la richiesta password
    if ([CCUtility getOnlyLockDir] && ![CCCoreData isBlockZone:self.serverUrl activeAccount:self.activeAccount]) return NO;
        
    return YES;
}

- (UIViewController *)lockScreenManagerPasscodeViewController:(BKPasscodeLockScreenManager *)aManager
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.type = BKPasscodeViewControllerCheckPasscodeType;
    viewController.delegate = self;
    viewController.title = _brand_;
    viewController.fromType = CCBKPasscodeFromLockScreen;
    viewController.inputViewTitlePassword = YES;
    
    if ([CCUtility getSimplyBlockCode]) {
        
        viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 6;
        
    } else {
        
        viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 64;
    }

    viewController.touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:BKPasscodeKeychainServiceName];
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
        if ([CCCoreData isBlockZone:self.serverUrl activeAccount:self.activeAccount])
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
            
            [self messageNotification:@"_network_available_" description:nil visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
            
            if (_activeMain)
                [_activeMain performSelector:@selector(requestServerInformation) withObject:nil afterDelay:3];
        }
        
        NSLog(@"[LOG] Reachability Changed: Reachable");
        
        self.lastReachability = YES;
        
    } else {
        
        if (self.lastReachability == YES) {
            [self messageNotification:@"_network_not_available_" description:nil visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        }
        
        NSLog(@"[LOG] Reachability Changed: NOT Reachable");
        
        self.lastReachability = NO;
    }
    
    if ([self.reachability isReachableViaWiFi]) NSLog(@"[LOG] Reachability Changed: WiFi");
    if ([self.reachability isReachableViaWWAN]) NSLog(@"[LOG] Reachability Changed: WWAn");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"setTitleCCMainNOAnimation" object:nil];
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
    BOOL activityIndicator = NO;
    
    // Activity Indicator
    if (netQueue == _netQueue)
        activityIndicator = YES;
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([_typeCloud isEqualToString:typeCloudOwnCloud] || [_typeCloud isEqualToString:typeCloudNextcloud])
        operation = [[OCnetworking alloc] initWithDelegate:delegate metadataNet:metadataNet withUser:_activeUser withPassword:_activePassword withUrl:_activeUrl withTypeCloud:_typeCloud activityIndicator:activityIndicator];
    
#ifdef CC
    
    /*** DROPBOX ***/
    
    if ([_typeCloud isEqualToString:typeCloudDropbox])
        operation = [[DBnetworking alloc] initWithDelegate:delegate metadataNet:metadataNet withUser:_activeUser withPassword:_activePassword withUrl:_activeUrl withActiveUID:_activeUID withActiveAccessToken:_activeAccessToken activityIndicator:activityIndicator];
#endif
    
    [operation setQueuePriority:metadataNet.priority];
    
    [netQueue addOperation:operation];
}

- (NSMutableArray *)verifyExistsInQueuesDownloadSelector:(NSString *)selector
{
    NSMutableArray *metadatasNet = [[NSMutableArray alloc] init];
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
        
        for (OCnetworking *operation in [self.netQueueDownload operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:[operation.metadataNet copy]];
        
        for (OCnetworking *operation in [self.netQueueDownloadWWan operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:[operation.metadataNet copy]];
    }
    
#ifdef CC
    
    /*** DROPBOX ***/
    
    if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
        
        for (DBnetworking *operation in [self.netQueueDownload operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:operation.metadataNet];
        
        for (DBnetworking *operation in [self.netQueueDownloadWWan operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:operation.metadataNet];
    }
    
#endif
    
    return metadatasNet;
}

- (NSMutableArray *)verifyExistsInQueuesUploadSelector:(NSString *)selector
{
    NSMutableArray *metadatasNet = [[NSMutableArray alloc] init];
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
        
        for (OCnetworking *operation in [self.netQueueUpload operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:[operation.metadataNet copy]];
        
        for (OCnetworking *operation in [self.netQueueUploadWWan operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:[operation.metadataNet copy]];
    }
    
#ifdef CC

    /*** DROPBOX ***/
    
    if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
        
        for (DBnetworking *operation in [self.netQueueUpload operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:operation.metadataNet];
        
        for (DBnetworking *operation in [self.netQueueUploadWWan operations])
            if ([operation.metadataNet.selector isEqualToString:selector])
                [metadatasNet addObject:operation.metadataNet];
    }
    
#endif
    
    return metadatasNet;
}

- (void)loadTableAutomaticUploadForSelector:(NSString *)selector
{
    // Only one
    if ([[self verifyExistsInQueuesUploadSelector:selector] count] > 1)
        return;

    // Verify num error if selectorUploadAutomaticAll
    if ([selector isEqualToString:selectorUploadAutomaticAll]) {
    
        NSUInteger count = [TableMetadata MR_countOfEntitiesWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (sessionSelector == %@) AND ((sessionTaskIdentifier == %i) OR (sessionTaskIdentifierPlist == %i))", app.activeAccount, selectorUploadAutomaticAll,taskIdentifierError, taskIdentifierError]];
        
#ifdef DEBUG
        NSArray *records = [[NSArray alloc] init];
        records = [TableMetadata MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (sessionSelector == %@) AND ((sessionTaskIdentifier == %i) OR (sessionTaskIdentifierPlist == %i))", app.activeAccount, selectorUploadAutomaticAll,taskIdentifierError, taskIdentifierError]];
#endif
        
        if (count >= 10) {
            
            [app messageNotification:@"_error_" description:@"_too_errors_automatic_all_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
            
            return;
        }
    }
    
    // Add Network queue
    CCMetadataNet *metadataNet = [CCCoreData getTableAutomaticUploadForAccount:self.activeAccount selector:selector context:nil];
    
    if (metadataNet) {
        
        NSOperationQueue *queue;
        
        if ([metadataNet.session containsString:@"wwan"])
            queue = app.netQueueUploadWWan;
        else
            queue = app.netQueueUpload;
        
        [self addNetworkingOperationQueue:queue delegate:app.activeMain metadataNet:metadataNet];
    }
}

- (void)verifyDownloadUploadInProgress
{
    BOOL callVerifyDownload = NO;
    BOOL callVerifyUpload = NO;
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
        
        NSLog(@"[LOG] Verify Download/Upload in progress now : %@ - Download %@ - Upload %@", [NSDate date], [self.sessionDateLastDownloadTasks dateByAddingTimeInterval:timerVerifySession], [self.sessionDateLastUploadTasks dateByAddingTimeInterval:timerVerifySession]);
        
        if ([[NSDate date] compare:[self.sessionDateLastDownloadTasks dateByAddingTimeInterval:timerVerifySession]] == NSOrderedDescending) {
            
            callVerifyDownload = YES;
            [[CCNetworking sharedNetworking] verifyDownloadInProgress];
        }
        
        if ([[NSDate date] compare:[self.sessionDateLastUploadTasks dateByAddingTimeInterval:timerVerifySession]] == NSOrderedDescending) {
            
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
    if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"stopUpload"]) {
        
        // sessionTaskIdentifier on Stop
        [CCCoreData setMetadataSession:nil sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:taskIdentifierStop sessionTaskIdentifierPlist:taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, self.activeAccount] context:nil];
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"reloadUpload"]) {
        
        // V 1.8 if upload_session_wwan change in upload_session
        if ([metadata.session isEqualToString:upload_session_wwan])
            metadata.session = upload_session;
        
        [[CCNetworking sharedNetworking] uploadFileMetadata:metadata taskStatus:taskStatusResume];
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"reloadDownload"]) {
        
        BOOL downloadData = NO, downloadPlist = NO;
            
        if (metadata.sessionTaskIdentifier != taskIdentifierDone) downloadData = YES;
        if (metadata.sessionTaskIdentifierPlist != taskIdentifierDone) downloadPlist = YES;
            
        NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:metadata.account];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:serverUrl downloadData:downloadData downloadPlist:downloadPlist selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost session:download_session taskStatus:taskStatusResume delegate:nil];
        });
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"cancelUpload"]) {
        
        // remove the file
        [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, app.activeAccount]];
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID] error:nil];
    }
    else if ([[_listChangeTask objectForKey:metadata.fileID] isEqualToString:@"cancelDownload"]) {
        
        [CCCoreData setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:taskIdentifierDone sessionTaskIdentifierPlist:taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, self.activeAccount] context:nil];
    }
    
    // remove ChangeTask (fileID) from the list
    [_listChangeTask removeObjectForKey:metadata.fileID];
    
    // delete progress
    [_listProgressMetadata removeObjectForKey:metadata.fileID];
    
    // Detail
    if (_activeDetail)
        [_activeDetail progressTask:nil serverUrl:nil cryptated:NO progress:0];
    
    // Refresh
    if (_activeMain && [_listChangeTask count] == 0)
        [_activeMain getDataSourceWithReloadTableView:metadata.directoryID fileID:nil selector:nil];
}

- (void)dropAutomaticUploadWithSelector:(NSString *)selector
{
    [CCCoreData flushTableAutomaticUploadAccount:self.activeAccount selector:selector];
    
    // Update icon badge number
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self updateApplicationIconBadgeNumber];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Dropbox =====
#pragma --------------------------------------------------------------------------------------------

#ifdef CC
- (void)sessionDidReceiveAuthorizationFailure:(DBSession*)session userId:(NSString *)userId
{
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageLoginIncorrect" object:nil];
}

- (void)restClient:(DBRestClient *)client loadedAccountInfo:(DBAccountInfo *)info
{
    NSString *account = [NSString stringWithFormat:@"%@ %@", [info email], typeCloudDropbox];
    
    [CCCoreData deleteAccount:account];
        
    // new account
    [CCCoreData addAccount:account url:@"https://www.dropbox.com" user:[info email] password:nil uid:info.userId typeCloud:typeCloudDropbox];
    TableAccount *tableAccount = [CCCoreData setActiveAccount:account];
    if (tableAccount)
        [self settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activePassword:tableAccount.password activeUID:tableAccount.uid activeAccessToken:tableAccount.token typeCloud:tableAccount.typeCloud];
    
    NSString *uuid = [CCUtility getUUID];
    NSString *passcode = [CCUtility getKeyChainPasscodeForUUID:uuid];
    
    // update ManageAccount
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateFormManageAccount" object:nil];
    
    // Login correct
    if ([passcode length] > 0  && [self.activeAccount length] > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageLoginCorrect" object:nil];
}
#endif

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
    
#ifdef CC
    /*************************************** DROPBOX *********************************/
    
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        NSString *query = url.query;
        if ([[url absoluteString] rangeOfString:@"cancel"].location == NSNotFound) {
            NSDictionary *urlData = [DBSession parseURLParams:query];
            NSString *uid = [urlData objectForKey:@"uid"];
            if ([[[DBSession sharedSession] userIds] containsObject:uid]) {
                
                self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession] userId:uid];
                self.restClient.delegate = self;
                
                [self.restClient loadAccountInfo];
            }
            
        } else {
            
            // user cancelled the login
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageLoginIncorrect" object:nil];
        }
        
        return YES;
    }
    /*********************************************************************************/
#endif
    
    NSArray *splitedUrl = [url.path componentsSeparatedByString:@"/"];
    self.fileNameUpload = [NSString stringWithFormat:@"%@",[splitedUrl objectAtIndex:([splitedUrl count]-1)]];
    NSString *passcode = [CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]];
    
    if (self.activeAccount && [passcode length]) {
        
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
    
}

@end
