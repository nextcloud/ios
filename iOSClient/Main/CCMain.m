//
//  CCMain.m
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

#import "CCMain.h"
#import "AppDelegate.h"
#import "CCPhotos.h"
#import "CCSynchronize.h"
#import "OCActivity.h"
#import "OCNotifications.h"
#import "OCNotificationsAction.h"
#import "OCFrameworkConstants.h"
#import "OCCapabilities.h"
#import "CTAssetCheckmark.h"
#import "JDStatusBarNotification.h"
#import "NCAutoUpload.h"
#import "NCBridgeSwift.h"
#import "NCNetworkingEndToEnd.h"
#import "PKDownloadButton.h"

@interface CCMain () <CCActionsRenameDelegate, CCActionsSearchDelegate, UITextViewDelegate, createFormUploadAssetsDelegate, MGSwipeTableCellDelegate, CCLoginDelegate, CCLoginDelegateWeb>
{
    AppDelegate *appDelegate;
    
    tableMetadata *_metadata;
    
    BOOL _isRoot;
    BOOL _isViewDidLoad;
    
    NSMutableDictionary *_selectedFileIDsMetadatas;
    NSUInteger _numSelectedFileIDsMetadatas;
    NSMutableArray *_queueSelector;
    
    UIImageView *_ImageTitleHomeCryptoCloud;
    
    NSString *_directoryGroupBy;
    NSString *_directoryOrder;
    
    NSUInteger _failedAttempts;
    NSDate *_lockUntilDate;

    UIRefreshControl *_refreshControl;
    UIDocumentInteractionController *_docController;

    CCHud *_hud;
    
    // Datasource
    CCSectionDataSourceMetadata *sectionDataSource;
    NSDate *_dateReadDataSource;
    
    // Search
    BOOL _isSearchMode;
    NSString *_searchFileName;
    NSMutableArray *_searchResultMetadatas;
    NSString *_noFilesSearchTitle;
    NSString *_noFilesSearchDescription;
    NSTimer *_timerWaitInput;

    // Automatic Upload Folder
    NSString *_autoUploadFileName;
    NSString *_autoUploadDirectory;
    
    // Folder
    BOOL _loadingFolder;
    tableMetadata *_metadataFolder;
    
    // Image Title Segue
    UIImage *imageTitleSegue;
}
@end

@implementation CCMain

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{    
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

        _directoryOrder = [CCUtility getOrderSettings];
        _directoryGroupBy = [CCUtility getGroupBySettings];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializeMain:) name:@"initializeMain" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearDateReadDataSource:) name:@"clearDateReadDataSource" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setTitle) name:@"setTitleMain" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        // Active Main
        appDelegate.activeMain = self;
    }
    
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // init object
    _metadata = [tableMetadata new];
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    _selectedFileIDsMetadatas = [NSMutableDictionary new];
    _queueSelector = [NSMutableArray new];
    _isViewDidLoad = YES;
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchResultMetadatas = [NSMutableArray new];
    _searchFileName = @"";
    _noFilesSearchTitle = @"";
    _noFilesSearchDescription = @"";
    
    // delegate
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorColor = [NCBrandColor sharedInstance].seperator;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.searchController.delegate = self;
    self.searchController.searchBar.delegate = self;
    
    // Actie Delegate Networking
    [CCNetworking sharedNetworking].delegate = self;
    
    // Register cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMainTransfer" bundle:nil] forCellReuseIdentifier:@"CellMainTransfer"];
    
    // long press recognizer TableView
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressTableView:)];
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    // Pull-to-Refresh
    [self createRefreshControl];
    
    // Register for 3D Touch Previewing if available
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] && (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable))
    {
        [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }

    // Back Button
    if ([_serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]]) {
        
        UIImage *backButtonImage = [UIImage imageNamed:@"navigationLogo"];
        backButtonImage = [backButtonImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:backButtonImage style:UIBarButtonItemStylePlain target:nil action:nil];
    }
    
    // reMenu Background
    _reMenuBackgroundView = [UIView new];
    _reMenuBackgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    
    // if this is not Main (the Main uses inizializeMain)
    if (_isRoot == NO && appDelegate.activeAccount.length > 0) {
        
        // Read (File) Folder
        [self readFileReloadFolder];
    }
    
    // Title
    [self setTitle];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // test
    if (appDelegate.activeAccount.length == 0)
        return;
    
    // delegate for Networking
    [CCNetworking sharedNetworking].delegate = self;
    
    // Color
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    [appDelegate aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    if (_isSelectedMode)
        [self setUINavigationBarSelected];
    else
        [self setUINavigationBarDefault];
    
    // If not editing mode remove _selectedFileIDs
    if (!self.tableView.editing)
        [_selectedFileIDsMetadatas removeAllObjects];
    
    // Plus Button
    [appDelegate plusButtonVisibile:true];
    
    // Search Bar
    if ([CCUtility isFolderEncrypted:self.serverUrl account:appDelegate.activeAccount]) {
        [self searchEnabled:NO];
    } else {
        [self searchEnabled:YES];
    }
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Active Main
    appDelegate.activeMain = self;
    
    // Test viewDidLoad
    if (_isViewDidLoad) {
        
        _isViewDidLoad = NO;
        
    } else {
        
        if (appDelegate.activeAccount.length > 0 && [_selectedFileIDsMetadatas count] == 0) {
        
            // Read (file) Folder
            [self readFileReloadFolder];
        }
    }

    // Title
    [self setTitle];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self closeAllMenu];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.    
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [self closeAllMenu];

    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        if (self.view.frame.size.width == ([[UIScreen mainScreen] bounds].size.width*([[UIScreen mainScreen] bounds].size.width<[[UIScreen mainScreen] bounds].size.height))+([[UIScreen mainScreen] bounds].size.height*([[UIScreen mainScreen] bounds].size.width>[[UIScreen mainScreen] bounds].size.height))) {
            
            // Portrait
            
        } else {
            
            // Landscape
        }
        
        [self.tableView reloadData];
    }];
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

// detect scroll for remove keyboard in search mode
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (_isSearchMode && scrollView == self.tableView) {
        
        [self.searchController.searchBar endEditing:YES];
    }
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [appDelegate changeTheming:self];
    
    // Refresh control
    _refreshControl.tintColor = [NCBrandColor sharedInstance].brandText;
    _refreshControl.backgroundColor = [NCBrandColor sharedInstance].brand;

    // color searchbar
    self.searchController.searchBar.barTintColor = [NCBrandColor sharedInstance].brand;
    self.searchController.searchBar.backgroundColor = [NCBrandColor sharedInstance].brand;
    // color searchbbar button text (cancel)
    UIButton *searchButton = self.searchController.searchBar.subviews.firstObject.subviews.lastObject;
    if (searchButton && [searchButton isKindOfClass:[UIButton class]]) {
        [searchButton setTitleColor:[NCBrandColor sharedInstance].brandText forState:UIControlStateNormal];
    }
    
    // Title
    [self setTitle];
    
    // Reload Table View
    [self tableViewReloadData];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Initizlize Mail =====
#pragma --------------------------------------------------------------------------------------------

//
// Callers :
//
// loginSuccess (delagate)
// ChangeDefaultAccount (delegate)
// Split : inizialize
// Settings Advanced : removeAllFiles
//
- (void)initializeMain:(NSNotification *)notification
{
    _directoryGroupBy = nil;
    _directoryOrder = nil;
    _dateReadDataSource = nil;
    
    // test
    if (appDelegate.activeAccount.length == 0)
        return;
    
    if ([appDelegate.listMainVC count] == 0 || _isRoot) {
        
        // This is Root home main add list
        appDelegate.homeMain = self;
        _isRoot = YES;
        _serverUrl = [CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl];
        [appDelegate.listMainVC setObject:self forKey:_serverUrl];
        
        // go Home
        [self.navigationController popToRootViewControllerAnimated:NO];
        
        // setting Networking
        [CCNetworking sharedNetworking].delegate = self;
        [[CCNetworking sharedNetworking] settingAccount];
        
        // Remove search mode
        [self cancelSearchBar];
        
        // populate shared Link & User
        NSArray *results = [[NCManageDatabase sharedInstance] getShares];
        if (results) {
            appDelegate.sharesLink = results[0];
            appDelegate.sharesUserAndGroup = results[1];
        }
                
        // Setting Theming
        [appDelegate settingThemingColorBrand];
        
        // Detail
        // If AVPlayer in play -> Stop
        if (appDelegate.player != nil && appDelegate.player.rate != 0) {
            [appDelegate.player pause];
        }
        for (UIView *view in [appDelegate.activeDetail.view subviews]) {
            if ([view isKindOfClass:[UIImageView class]] == NO) { // View Image Nextcloud
                [view removeFromSuperview];
            }
        }
        appDelegate.activeDetail.title = nil;
        
        // remove all Notification Messages
        [appDelegate.listOfNotifications removeAllObjects];
        
        // Not Photos Video in library ? then align and Init Auto Upload
        NSArray *recordsPhotoLibrary = [[NCManageDatabase sharedInstance] getPhotoLibraryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", appDelegate.activeAccount]];
        if ([recordsPhotoLibrary count] == 0) {
            [[NCAutoUpload sharedInstance] alignPhotoLibrary];
        }
        [[NCAutoUpload sharedInstance] initStateAutoUpload];
        
        NSLog(@"[LOG] Request Service Server Nextcloud");
        [[NCService sharedInstance] startRequestServicesServer];
        
        // Clear datasorce
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:nil];
        
        // Read this folder
        [self readFileReloadFolder];
        
    } else {
        
        // reload datasource
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:_serverUrl];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{
    if (_loadingFolder)
        return NO;
    else
        return YES;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [NCBrandColor sharedInstance].backgroundView;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    if (_isSearchMode)
        return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"searchBig"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement];
    else
        return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"filesNoFiles"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement];
}

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView
{
    if (_loadingFolder && _refreshControl.isRefreshing == NO) {
    
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
        activityView.color = [NCBrandColor sharedInstance].brandElement;
        [activityView startAnimating];
        
        return activityView;
    }
    
    return nil;
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if (_isSearchMode) {
        
        text = _noFilesSearchTitle;
        
    } else {
        
        text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_files_no_files_", nil)];
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if (_isSearchMode) {
        
        text = _noFilesSearchDescription;
        
    } else {
        
        text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_no_file_pull_down_", nil)];
    }
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Text Field =====
#pragma --------------------------------------------------------------------------------------------

- (void)minCharTextFieldDidChange:(UITextField *)sender
{
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    
    if (alertController)
    {
        UITextField *fileName = alertController.textFields.firstObject;
        UIAlertAction *okAction = alertController.actions.lastObject;
        okAction.enabled = fileName.text.length > 0;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
    [textField selectAll:textField];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Graphic Window =====
#pragma --------------------------------------------------------------------------------------------

- (void)createRefreshControl
{
    _refreshControl = [UIRefreshControl new];
    
    if (@available(iOS 10, *)) {
        _tableView.refreshControl = _refreshControl;
    } else {
        [_tableView addSubview:_refreshControl];
    }
       
    _refreshControl.tintColor = [NCBrandColor sharedInstance].brandText;
    _refreshControl.backgroundColor = [NCBrandColor sharedInstance].brand;
    
    [_refreshControl addTarget:self action:@selector(refreshControlTarget) forControlEvents:UIControlEventValueChanged];
}

- (void)deleteRefreshControl
{
    [_refreshControl endRefreshing];
    
    for (UIView *subview in [_tableView subviews]) {
        if (subview == _refreshControl)
            [subview removeFromSuperview];
    }
    
    _tableView.refreshControl = nil;
    _refreshControl = nil;
}

- (void)refreshControlTarget
{
    [self readFolder:_serverUrl];
    
    // Actuate `Peek` feedback (weak boom)
    AudioServicesPlaySystemSound(1519);
    
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:NO];
}

- (void)setTitle
{
    // Color text self.navigationItem.title
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];

    if (_isSelectedMode) {
        
        NSUInteger totali = [sectionDataSource.allRecordsDataSource count];
        NSUInteger selezionati = [[self.tableView indexPathsForSelectedRows] count];
        
        self.navigationItem.titleView = nil;
        self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)selezionati, (unsigned long)totali];

    } else {
        
        // we are in home : LOGO BRAND
        if ([_serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]]) {
            
            self.navigationItem.title = nil;
            
            if ([appDelegate.reachability isReachable] == NO) {
                _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"navigationLogoOffline"]];
            } else {
                
                if ([NCBrandOptions sharedInstance].use_themingColor) {
                
                    tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilites];
                    
                    if ([capabilities.themingColor isEqualToString:@"#FFFFFF"])
                        _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"navigationLogo"] multiplier:2 color:[UIColor blackColor]]];
                    else
                        _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"navigationLogo"] multiplier:2 color:[UIColor whiteColor]]];
                } else {
                    
                    _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"navigationLogo"]];
                }
            }
            
            [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
            UITapGestureRecognizer *singleTap =  [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(menuLogo:)];
            [singleTap setNumberOfTapsRequired:1];
            [_ImageTitleHomeCryptoCloud addGestureRecognizer:singleTap];
            
            self.navigationItem.titleView = _ImageTitleHomeCryptoCloud;
            
        } else {
        
            NSString *shareLink, *shareUserAndGroup;
            NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadataFolder.directoryID];
            if (serverUrl) {
                shareLink = [appDelegate.sharesLink objectForKey:[serverUrl stringByAppendingString:_metadataFolder.fileName]];
                shareUserAndGroup = [appDelegate.sharesUserAndGroup objectForKey:[serverUrl stringByAppendingString:_metadataFolder.fileName]];
            }
            
            self.navigationItem.title = _titleMain;
            
            if (self.imageTitle) {
                [CCGraphics addImageToTitle:_titleMain colorTitle:[NCBrandColor sharedInstance].brandText imageTitle:[CCGraphics changeThemingColorImage:self.imageTitle multiplier:2 color:[NCBrandColor sharedInstance].brandText] navigationItem:self.navigationItem];
            } else {
                self.navigationItem.titleView = nil;
            }
        }
    }
}

- (void)setUINavigationBarDefault
{
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    
    UIBarButtonItem *buttonMore, *buttonNotification;
    
    // =
    buttonMore = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navigationControllerMenu"] style:UIBarButtonItemStylePlain target:self action:@selector(toggleReMainMenu)];
    buttonMore.enabled = true;
    
    // <
    self.navigationController.navigationBar.hidden = NO;
    
    // Notification
    if ([appDelegate.listOfNotifications count] > 0) {
        
        buttonNotification = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"notification"] style:UIBarButtonItemStylePlain target:self action:@selector(viewNotification)];
        buttonNotification.tintColor = [NCBrandColor sharedInstance].brandText;
        buttonNotification.enabled = true;
    }
    
    if (buttonNotification)
        self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, buttonNotification, nil];
    else
        self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, nil];

    self.navigationItem.leftBarButtonItem = nil;
}

- (void)setUINavigationBarSelected
{
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    
    UIImage *icon = [UIImage imageNamed:@"navigationControllerMenu"];
    UIBarButtonItem *buttonMore = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(toggleReSelectMenu)];

    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelSelect)];
    
    self.navigationItem.leftBarButtonItem = leftButton;
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, nil];
}

- (void)cancelSelect
{
    [self tableViewSelect:NO];
    [appDelegate.reSelectMenu close];
}

- (void)closeAllMenu
{
    // close Menu
    [appDelegate.reSelectMenu close];
    [appDelegate.reMainMenu close];
    
    // Close Menu Logo
    [CCMenuAccount dismissMenu];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Document Picker =====
#pragma --------------------------------------------------------------------------------------------

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu
{
    NSLog(@"[LOG] Cancelled");
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    NSLog(@"[LOG] Cancelled");
}

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker
{
    documentPicker.delegate = self;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *error;
        
        [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingForUploading error:&error byAccessor:^(NSURL *newURL) {
            
            NSString *serverUrl = [appDelegate getTabBarControllerActiveServerUrl];
            NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
            NSString *fileName =  [[NCUtility sharedInstance] createFileName:[url lastPathComponent] directoryID:directoryID];
            NSString *fileID = [directoryID stringByAppendingString:fileName];
            NSData *data = [NSData dataWithContentsOfURL:newURL];
            
            if (data && error == nil) {
                
                if ([data writeToFile:[CCUtility getDirectoryProviderStorageFileID:fileID fileName:fileName] options:NSDataWritingAtomic error:&error]) {
                    
                    tableMetadata *metadataForUpload = [tableMetadata new];
                    
                    metadataForUpload.account = appDelegate.activeAccount;
                    metadataForUpload.date = [NSDate new];
                    metadataForUpload.directoryID = directoryID;
                    metadataForUpload.fileID = fileID;
                    metadataForUpload.fileName = fileName;
                    metadataForUpload.fileNameView = fileName;
                    metadataForUpload.session = k_upload_session;
                    metadataForUpload.sessionSelector = selectorUploadFile;
                    metadataForUpload.size = data.length;
                    metadataForUpload.status = k_metadataStatusWaitUpload;
                    
                    // Check il file already exists
                    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND fileNameView == %@", directoryID, fileName]];
                    if (metadata) {
                        
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:fileName message:NSLocalizedString(@"_file_already_exists_", nil) preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                            // NO OVERWITE
                        }];
                        UIAlertAction *overwriteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_overwrite_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                            
                            // Remove record metadata
                            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:metadata.directoryID];
                            
                            // Add Medtadata for upload
                            (void)[[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                            [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
                        }];
                        
                        [alertController addAction:cancelAction];
                        [alertController addAction:overwriteAction];
                        
                        UIWindow *alertWindow = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
                        alertWindow.rootViewController = [[UIViewController alloc]init];
                        alertWindow.windowLevel = UIWindowLevelAlert + 1;
                        [alertWindow makeKeyAndVisible];
                        [alertWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
                        
                    } else {
                        
                        // Add Medtadata for upload
                        (void)[[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                        [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];

                    }
                    
                } else {
                    
                    [appDelegate messageNotification:@"_error_" description:error.description visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                }
                
            } else {
                
                [appDelegate messageNotification:@"_error_" description:@"_read_file_error_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
            }
        }];
    }
}

- (void)openImportDocumentPicker
{
    UIDocumentMenuViewController *documentProviderMenu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    
    documentProviderMenu.modalPresentationStyle = UIModalPresentationFormSheet;
    documentProviderMenu.popoverPresentationController.sourceView = self.view;
    documentProviderMenu.popoverPresentationController.sourceRect = self.view.bounds;
    documentProviderMenu.delegate = self;
    
    [self presentViewController:documentProviderMenu animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Assets Picker =====
#pragma --------------------------------------------------------------------------------------------

-(void)dismissFormUploadAssets
{
    [self reloadDatasource];
}

- (void)openAssetsPickerController
{
    CTAssetCheckmark *checkmark = [CTAssetCheckmark appearance];
    checkmark.tintColor = [NCBrandColor sharedInstance].brandElement;
    [checkmark setMargin:0.0 forVerticalEdge:NSLayoutAttributeRight horizontalEdge:NSLayoutAttributeTop];
    
    //UINavigationBar *navBar = [UINavigationBar appearanceWhenContainedIn:[CTAssetsPickerController class], nil]; // DEPRECATED iOS9
    UINavigationBar *navBar = [UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[[CTAssetsPickerController class]]];
    
    [appDelegate aspectNavigationControllerBar:navBar online:YES hidden:NO];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
        dispatch_async(dispatch_get_main_queue(), ^{
            
            CTAssetCheckmark *checkmark = [CTAssetCheckmark appearance];
            [checkmark setMargin:0.0 forVerticalEdge:NSLayoutAttributeRight horizontalEdge:NSLayoutAttributeBottom];
            
            // init picker
            CTAssetsPickerController *picker = [CTAssetsPickerController new];
            
            // set delegate
            picker.delegate = self;
            
            // to show selection order
            //picker.showsSelectionIndex = YES;
            
            // to present picker as a form sheet in iPad
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                picker.modalPresentationStyle = UIModalPresentationFormSheet;
            
            // present picker
            [self presentViewController:picker animated:YES completion:nil];
        });
    }];
}

- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldSelectAsset:(PHAsset *)asset
{
    if (picker.selectedAssets.count > k_pickerControllerMax) {
        
        [appDelegate messageNotification:@"_info_" description:@"_limited_dimension_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:k_CCErrorInternalError];
        
        return NO;
    }
    
    return YES;
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSMutableArray *)assets
{
    [picker dismissViewControllerAnimated:YES completion:^{
        
        NSString *serverUrl = [appDelegate getTabBarControllerActiveServerUrl];
        
        CreateFormUploadAssets *form = [[CreateFormUploadAssets alloc] initWithServerUrl:serverUrl assets:assets cryptated:NO session:k_upload_session delegate:self];
        form.title = NSLocalizedString(@"_upload_photos_videos_", nil);
            
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:form];
            
        [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }];
}

// New folder or new photo or video
- (void)returnCreate:(NSInteger)type
{
    switch (type) {
            
        case k_returnCreateFolderPlain: {
            
            NSString *serverUrl = [appDelegate getTabBarControllerActiveServerUrl];
            NSString *message;
            UIAlertController *alertController;
            
            if ([serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]]) {
                message = @"/";
            } else {
                message = [serverUrl lastPathComponent];
            }
            
            alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_create_folder_on_",nil) message:message preferredStyle:UIAlertControllerStyleAlert];

            [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                
                textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            }];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                NSLog(@"[LOG] Cancel action");
            }];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                
                UITextField *fileName = alertController.textFields.firstObject;
                [self createFolder:fileName.text serverUrl:serverUrl];
            }];
            
            okAction.enabled = NO;
            
            [alertController addAction:cancelAction];
            [alertController addAction:okAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
            break;
        case k_returnCreateFotoVideoPlain: {
            
            [self openAssetsPickerController];
        }
            break;
        case k_returnCreateFilePlain: {
            
            [self openImportDocumentPicker];
        }
            break;
            
        case k_returnCreateFotoVideoEncrypted: {
            
            [self openAssetsPickerController];
        }
            break;
        case k_returnCreateFileEncrypted: {
            
            [self openImportDocumentPicker];
        }
            break;
    
        case k_returnCreateFileText: {
            
            UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"NCText" bundle:nil] instantiateViewControllerWithIdentifier:@"NCText"];
                        
            navigationController.modalPresentationStyle = UIModalPresentationPageSheet;

            [self presentViewController:navigationController animated:YES completion:nil];
        }
            break;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Save selected File =====
#pragma --------------------------------------------------------------------------------------------

-(void)saveSelectedFilesSelector:(NSString *)path didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error)
        [appDelegate messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
    else
        [appDelegate messageNotification:@"_save_selected_files_" description:@"_file_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:error.code];
}

- (void)saveSelectedFiles
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;

    NSLog(@"[LOG] Start download selected files ...");
    
    [_hud visibleHudTitle:@"" mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *metadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (tableMetadata *metadata in metadatas) {
            
            if (metadata.directory == NO && ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] || [metadata.typeFile isEqualToString: k_metadataTypeFile_video])) {
                
                NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
                
                if (serverUrl) {
                    
                    metadata.session = k_download_session;
                    metadata.sessionError = @"";
                    metadata.sessionSelector = selectorSave;
                    metadata.status = k_metadataStatusWaitDownload;
                    
                    // Add Metadata for Download
                    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
                    [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
                }
                
            }
        }
        
        [_hud hideHud];
    });
    
    [self tableViewSelect:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== View Notification  ====
#pragma --------------------------------------------------------------------------------------------

- (void)viewNotification
{
    if ([appDelegate.listOfNotifications count] > 0) {
        
        CCNotification *notificationVC = [[UIStoryboard storyboardWithName:@"CCNotification" bundle:nil] instantiateViewControllerWithIdentifier:@"CCNotification"];
        
        [notificationVC setModalPresentationStyle:UIModalPresentationFormSheet];
        
        [self presentViewController:notificationVC animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate Login ===
#pragma --------------------------------------------------------------------------------------------

- (void)loginSuccess:(NSInteger)loginType
{
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        // go to home sweet home
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil];
        
        [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
    });
}

- (void)loginClose
{
    appDelegate.activeLogin = nil;
}

- (void)loginWebClose
{
    appDelegate.activeLoginWeb = nil;
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Peek & Pop  =====
#pragma --------------------------------------------------------------------------------------------

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    CGPoint convertedLocation = [self.view convertPoint:location toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:convertedLocation];
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata.thumbnailExists && _metadataFolder.e2eEncrypted == NO) {
        CCCellMain *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        if (cell) {
            previewingContext.sourceRect = cell.frame;
            CCPeekPop *vc = [[UIStoryboard storyboardWithName:@"CCPeekPop" bundle:nil] instantiateViewControllerWithIdentifier:@"PeekPopImagePreview"];
            
            vc.delegate = self;
            vc.metadata = metadata;
            
            return vc;
        }
    }
    
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:previewingContext.sourceRect.origin];
    
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnail:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl indexPath:(NSIndexPath *)indexPath
{
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];
    [ocNetworking downloadThumbnailWithDimOfThumbnail:@"m" fileID:metadata.fileID fileNamePath:[CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:appDelegate.activeUrl] fileNameView:metadata.fileNameView completion:^(NSString *message, NSInteger errorCode) {
        if (errorCode == 0 && [[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]] && [[NCMainCommon sharedInstance] isValidIndexPath:indexPath tableView:self.tableView]) {
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadStart:(NSString *)fileID account:(NSString *)account task:(NSURLSessionDownloadTask *)task serverUrl:(NSString *)serverUrl
{
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];
    
    [appDelegate updateApplicationIconBadgeNumber];
}

- (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode
{
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
    if (metadata == nil)
        return;
    
    if (errorCode == 0) {
        
        // Synchronized
        if ([selector isEqualToString:selectorDownloadSynchronize]) {
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];
        }
        
        // open View File
        if ([selector isEqualToString:selectorLoadFileView] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];

            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_compress]) {
                
                selector = selectorOpenIn;
                //[self performSelector:@selector(unZipFile:) withObject:metadata.fileID];
                
            } else if ([metadata.typeFile isEqualToString: k_metadataTypeFile_unknown]) {
                
                selector = selectorOpenIn;
                
            } else {
                
                _metadata = metadata;
                
                if ([self shouldPerformSegue])
                    [self performSegueWithIdentifier:@"segueDetail" sender:self];
            }
        }
        
        // Open with...
        if ([selector isEqualToString:selectorOpenIn] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];

            NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView]];
            
            _docController = [UIDocumentInteractionController interactionControllerWithURL:url];
            _docController.delegate = self;
            
            [_docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
        }
        
        // Save to Photo Album
        if ([selector isEqualToString:selectorSave] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            
            NSString *fileNamePath = [CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView];
            PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] && status == PHAuthorizationStatusAuthorized) {
                
                UIImage *image = [UIImage imageWithContentsOfFile:fileNamePath];
                
                if (image)
                    UIImageWriteToSavedPhotosAlbum(image, self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
                else
                    [appDelegate messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video] && status == PHAuthorizationStatusAuthorized) {
                
                if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileNamePath)) {
                    
                    UISaveVideoAtPathToSavedPhotosAlbum(fileNamePath, self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
                } else {
                    [appDelegate messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
                }
            }
            
            if (status != PHAuthorizationStatusAuthorized) {
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];
        }
        
        // Copy File
        if ([selector isEqualToString:selectorLoadCopy]) {
            
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];

            [self copyFileToPasteboard:metadata];
        }
        
        //selectorLoadViewImage
        if ([selector isEqualToString:selectorLoadViewImage]) {
            
            // Detail
            if (appDelegate.activeDetail)
                [appDelegate.activeDetail downloadPhotoBrowserSuccessFailure:metadata selector:selector errorCode:0];
            
            // Photos
            if (appDelegate.activePhotos)
                [appDelegate.activePhotos downloadFileSuccessFailure:metadata.fileName fileID:metadata.fileID serverUrl:serverUrl selector:selector errorMessage:errorMessage errorCode:errorCode];
            
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];
        }
        
        // Auto Download Upload
        [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
        
    } else {
        
        // File do not exists on server, remove in local
        if (errorCode == kOCErrorServerPathNotFound || errorCode == kCFURLErrorBadServerResponse) {
            
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageFileID:fileID] error:nil];
            
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID] clearDateReadDirectoryID:nil];
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
            [[NCManageDatabase sharedInstance] deletePhotosWithFileID:fileID];
        }
        
        if ([selector isEqualToString:selectorLoadViewImage]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Updating Detail
                if (appDelegate.activeDetail)
                    [appDelegate.activeDetail downloadPhotoBrowserSuccessFailure:metadata selector:selector errorCode:errorCode];
                
                // Updating Photos
                if (appDelegate.activePhotos)
                    [appDelegate.activePhotos downloadFileSuccessFailure:metadata.fileName fileID:metadata.fileID serverUrl:serverUrl selector:selector errorMessage:errorMessage errorCode:errorCode];
            });
            
        }
        
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];
    }
}

- (void)downloadSelectedFilesFolders
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;

    NSLog(@"[LOG] Start download selected ...");
    
    [_hud visibleHudTitle:NSLocalizedString(@"_downloading_progress_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (tableMetadata *metadata in selectedMetadatas) {
            
            if (metadata.directory) {
                
                NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
                    
                if (serverUrl) {
                    serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName];
                    [[CCSynchronize sharedSynchronize] readFolder:serverUrl selector:selectorReadFolderWithDownload];
                }
                    
            } else {
                    
                [[CCSynchronize sharedSynchronize] readFile:metadata selector:selectorReadFileWithDownload];
            }
        }
        
        [_hud hideHud];
    });
    
    [self tableViewSelect:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Upload new Photos/Videos =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadStart:(NSString *)fileID account:(NSString *)account task:(NSURLSessionUploadTask *)task serverUrl:(NSString *)serverUrl
{
    [self reloadDatasource:serverUrl];
    
    [appDelegate updateApplicationIconBadgeNumber];
}

- (void)uploadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID assetLocalIdentifier:(NSString *)assetLocalIdentifier serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode
{    
    if (errorCode == 0) {
        
        // Auto Download Upload
        [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
        
    } else {
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:errorMessage type:k_activityTypeFailure verbose:k_activityVerboseDefault  activeUrl:appDelegate.activeUrl];
        
        if (errorCode != -999 && errorCode != kCFURLErrorCancelled && errorCode != kOCErrorServerUnauthorized)
            [appDelegate messageNotification:@"_upload_file_" description:errorMessage visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    }
    
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl];
}

//
// This procedure with performSelectorOnMainThread it's necessary after (Bridge) for use the function "Sync" in OCNetworking
//
- (void)uploadFileAsset:(NSMutableArray *)assets serverUrl:(NSString *)serverUrl useSubFolder:(BOOL)useSubFolder session:(NSString *)session
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
 
        NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:appDelegate.activeUrl];

        // if request create the folder for Photos & the subfolders
        if ([autoUploadPath isEqualToString:serverUrl])
            if (![[NCAutoUpload sharedInstance] createAutoUploadFolderPhotosWithSubFolder:useSubFolder assets:(PHFetchResult *)assets selector:selectorUploadFile])
                return;
    
        dispatch_async(dispatch_get_main_queue(), ^{
            [self uploadFileAsset:assets serverUrl:serverUrl autoUploadPath:autoUploadPath useSubFolder:useSubFolder session:session];
        });
    });
}

- (void)uploadFileAsset:(NSArray *)assets serverUrl:(NSString *)serverUrl autoUploadPath:(NSString *)autoUploadPath useSubFolder:(BOOL)useSubFolder session:(NSString *)session
{
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    
    for (PHAsset *asset in assets) {
        
        NSString *fileName = [CCUtility createFileName:[asset valueForKey:@"filename"] fileDate:asset.creationDate fileType:asset.mediaType keyFileName:k_keyFileNameMask keyFileNameType:k_keyFileNameType keyFileNameOriginal:k_keyFileNameOriginal];
        
        NSDate *assetDate = asset.creationDate;
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        
        // Create serverUrl if use sub folder
        if (useSubFolder) {
            
            [formatter setDateFormat:@"yyyy"];
            NSString *yearString = [formatter stringFromDate:assetDate];
        
            [formatter setDateFormat:@"MM"];
            NSString *monthString = [formatter stringFromDate:assetDate];
            
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        }
        
        // Check if is in upload
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"directoryID == %@ AND fileName == %@ AND session != ''", directoryID, fileName];
        NSArray *isRecordInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:predicate sorted:nil ascending:NO];
        if ([isRecordInSessions count] > 0)
            continue;
        
        // Prepare record metadata
        tableMetadata *metadataForUpload = [tableMetadata new];

        metadataForUpload.account = appDelegate.activeAccount;
        metadataForUpload.assetLocalIdentifier = asset.localIdentifier;
        metadataForUpload.date = [NSDate new];
        metadataForUpload.directoryID = directoryID;
        metadataForUpload.fileID = [directoryID stringByAppendingString:fileName];
        metadataForUpload.fileName = fileName;
        metadataForUpload.fileNameView = fileName;
        metadataForUpload.session = session;
        metadataForUpload.sessionSelector = selectorUploadFile;
        metadataForUpload.size = [[NCUtility sharedInstance] getFileSizeWithAsset:asset];
        metadataForUpload.status = k_metadataStatusWaitUpload;
        
        // Check il file already exists
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND fileNameView == %@", directoryID, fileName]];
        if (metadata) {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:fileName message:NSLocalizedString(@"_file_already_exists_", nil) preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                // NO OVERWITE
            }];
            UIAlertAction *overwriteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_overwrite_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                
                // Remove record metadata
                [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:metadata.directoryID];

                // Add Medtadata for upload
                (void)[[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
            }];
            
            [alertController addAction:cancelAction];
            [alertController addAction:overwriteAction];
           
            UIWindow *alertWindow = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
            alertWindow.rootViewController = [[UIViewController alloc]init];
            alertWindow.windowLevel = UIWindowLevelAlert + 1;
            [alertWindow makeKeyAndVisible];
            [alertWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
                
        } else {
            
            // Add Medtadata for upload
            (void)[[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
            [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read File ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFileSuccessFailure:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    if (errorCode == 0) {
    
        // Read Folder
        if ([metadataNet.selector isEqualToString:selectorReadFileReloadFolder]) {
            
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", metadataNet.account, metadataNet.serverUrl]];
            
            // Change etag, read folder
            if ([metadata.etag isEqualToString:directory.etag] == NO) {
                [self readFolder:metadataNet.serverUrl];
            }
        }
        
    } else {
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized)
            [appDelegate openLoginView:self loginType:k_login_Modify_Password selector:k_intro_login];
    }
}

- (void)readFileReloadFolder
{
    if (!_serverUrl || !appDelegate.activeAccount || appDelegate.maintenanceMode)
        return;
    
    // Load Datasource
    [self reloadDatasource];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];

    metadataNet.action = actionReadFile;
    metadataNet.priority = NSOperationQueuePriorityHigh;
    metadataNet.selector = selectorReadFileReloadFolder;
    metadataNet.serverUrl = _serverUrl;

    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read Folder ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolderSuccessFailure:(CCMetadataNet *)metadataNet metadataFolder:(tableMetadata *)metadataFolder metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // stoprefresh
    [_refreshControl endRefreshing];
    
    // Check Active Account
    if (![metadataNet.account isEqualToString:metadataNet.account])
        return;
    
    // ERROR
    if (errorCode != 0) {
        
        _loadingFolder = NO;
        
        // Check Active Account
        if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
            return;
        
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            [appDelegate openLoginView:self loginType:k_login_Modify_Password selector:k_intro_login];
            
        } else {
            [self tableViewReloadData];
            
            [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
            
            [appDelegate messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
            
            [self reloadDatasource:metadataNet.serverUrl];
        }
        
        return;
    }
    
    // save metadataFolder
    _metadataFolder = metadataFolder;
    
    if (_isSearchMode == NO) {
        
        [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:metadataNet.serverUrl serverUrlTo:nil etag:metadataFolder.etag fileID:metadataFolder.fileID encrypted:metadataFolder.e2eEncrypted];
        
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND (status == %d OR status == %d)", metadataNet.directoryID, k_metadataStatusNormal, k_metadataStatusHide] clearDateReadDirectoryID:metadataNet.directoryID];
        
        [[NCManageDatabase sharedInstance] setDateReadDirectoryWithDirectoryID:metadataNet.directoryID];
    }
    
    NSArray *metadatasInDownload = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", metadataNet.directoryID, k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusDownloadError] sorted:nil ascending:NO];
    
    // insert in Database
    NSMutableArray *metadatasToInsertInDB = (NSMutableArray *)[[NCManageDatabase sharedInstance] addMetadatas:metadatas serverUrl:metadataNet.serverUrl];
    // reinsert metadatas in Download
    if (metadatasInDownload) {
        (void)[[NCManageDatabase sharedInstance] addMetadatas:metadatasInDownload serverUrl:metadataNet.serverUrl];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        // File is changed ??
        if (!_isSearchMode && metadatasToInsertInDB)
            [[CCSynchronize sharedSynchronize] verifyChangeMedatas:metadatasToInsertInDB serverUrl:metadataNet.serverUrl account:appDelegate.activeAccount withDownload:NO];
    });
    
    // Search Mode
    if (_isSearchMode) {
        
        // Fix managed -> Unmanaged _searchResultMetadatas
        if (metadatasToInsertInDB)
            _searchResultMetadatas = [[NSMutableArray alloc] initWithArray:metadatasToInsertInDB];
        
        [self reloadDatasource:metadataNet.serverUrl];
    }
    
    // this is the same directory
    if ([metadataNet.serverUrl isEqualToString:_serverUrl] && !_isSearchMode) {
        
        // reload
        [self reloadDatasource:metadataNet.serverUrl];
    
        // Enable change user
        [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
                
        _loadingFolder = NO;
        [self tableViewReloadData];
    }
    
    // E2EE Is encrypted folder get metadata
    if (_metadataFolder.e2eEncrypted) {
        
        // Read Metadata
        if ([CCUtility isEndToEndEnabled:appDelegate.activeAccount]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{                
                NSString *metadata;
                NSError *error = [[NCNetworkingEndToEnd sharedManager] getEndToEndMetadata:&metadata fileID:metadataFolder.fileID user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        if (error.code != 404)
                            [appDelegate messageNotification:@"_e2e_error_get_metadata_" description:error.localizedDescription visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                    } else {
                        if ([[NCEndToEndMetadata sharedInstance] decoderMetadata:metadata privateKey:[CCUtility getEndToEndPrivateKey:appDelegate.activeAccount] serverUrl:self.serverUrl account:appDelegate.activeAccount url:appDelegate.activeUrl] == false)
                            [appDelegate messageNotification:@"_error_e2ee_" description:@"_e2e_error_decode_metadata_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                        else
                            [self reloadDatasource];
                    }
                });
            });
        } else {
            [appDelegate messageNotification:@"_info_" description:@"_e2e_goto_settings_for_enable_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        }
    }
    
    // rewrite title
    [self setTitle];
}

- (void)readFolder:(NSString *)serverUrl
{
    // init control
    if (!serverUrl || !appDelegate.activeAccount || appDelegate.maintenanceMode) {
        
        [_refreshControl endRefreshing];
        return;
    }
    
    // Search Mode
    if (_isSearchMode) {
        
        [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:serverUrl directoryID:nil];
            
        _searchFileName = @"";                          // forced reload searchg
        
        [self updateSearchResultsForSearchController:self.searchController];
        
        return;
    }
    
    _loadingFolder = YES;
    [self tableViewReloadData];
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, serverUrl]];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];

    metadataNet.action = actionReadFolder;
    metadataNet.date = [NSDate date];
    metadataNet.depth = @"1";
    metadataNet.directoryID = directory.directoryID;
    metadataNet.priority = NSOperationQueuePriorityHigh;
    metadataNet.selector = selectorReadFolder;
    metadataNet.serverUrl = serverUrl;
    
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Search =====
#pragma --------------------------------------------------------------------------------------------

- (void)searchEnabled:(BOOL)enabled
{
    if (enabled) {
    
        if (self.tableView.tableHeaderView != nil)
            return;
        
        self.definesPresentationContext = YES;
        self.searchController.searchResultsUpdater = self;
        self.searchController.dimsBackgroundDuringPresentation = NO;
        self.searchController.searchBar.translucent = NO;
        [self.searchController.searchBar sizeToFit];
        self.searchController.searchBar.delegate = self;
        self.searchController.searchBar.barTintColor = [NCBrandColor sharedInstance].brand;
        self.searchController.searchBar.backgroundColor = [NCBrandColor sharedInstance].brand;
        self.searchController.searchBar.backgroundImage = [UIImage new];
        // color searchbbar button text (cancel)
        UIButton *searchButton = self.searchController.searchBar.subviews.firstObject.subviews.lastObject;
        if (searchButton && [searchButton isKindOfClass:[UIButton class]]) {
            [searchButton setTitleColor:[NCBrandColor sharedInstance].brandText forState:UIControlStateNormal];
        }
        
        self.tableView.tableHeaderView = self.searchController.searchBar;
        [self.tableView setContentOffset:CGPointMake(0, self.searchController.searchBar.frame.size.height - self.tableView.contentOffset.y)];
        
    } else {
        
        self.tableView.tableHeaderView = nil;
    }
}

- (void)searchStartTimer
{
    NSString *startDirectory = [CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl];
    
    [[CCActions sharedInstance] search:startDirectory fileName:_searchFileName etag:@"" depth:@"infinity" date:nil contenType:nil selector:selectorSearchFiles delegate:self];

    _noFilesSearchTitle = @"";
    _noFilesSearchDescription = NSLocalizedString(@"_search_in_progress_", nil);
    
    [self.tableView reloadEmptyDataSet];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    // Color text "Cancel"
    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]] setTintColor:[NCBrandColor sharedInstance].brandText];

    _isSearchMode = YES;
    [self deleteRefreshControl];
    
    NSString *fileName = [CCUtility removeForbiddenCharactersServer:searchController.searchBar.text];
    
    if (fileName.length >= k_minCharsSearch && [fileName isEqualToString:_searchFileName] == NO) {
        
        _searchFileName = fileName;
        
        // First : filter
            
        NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
        if (!directoryID) return;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"directoryID == %@ AND fileNameView CONTAINS[cd] %@", directoryID, fileName];
        NSArray *records = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:predicate sorted:nil ascending:NO];
            
        [_searchResultMetadatas removeAllObjects];
        for (tableMetadata *record in records)
            [_searchResultMetadatas addObject:record];
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
            
        metadataNet.account = appDelegate.activeAccount;
        metadataNet.directoryID = directoryID;
        metadataNet.selector = selectorSearchFiles;
        metadataNet.serverUrl = _serverUrl;

        [self readFolderSuccessFailure:metadataNet metadataFolder:nil metadatas:_searchResultMetadatas message:nil errorCode:0];
    
        // Version >= 12
        if ([[NCManageDatabase sharedInstance] getServerVersion] >= 12) {
            
            [_timerWaitInput invalidate];
            _timerWaitInput = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(searchStartTimer) userInfo:nil repeats:NO];
        }
    }
    
    if (_searchResultMetadatas.count == 0 && fileName.length == 0) {

        [self reloadDatasource];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self cancelSearchBar];
    
    [self readFolder:_serverUrl];
}

- (void)searchSuccessFailure:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    if (errorCode == 0) {
    
        _searchResultMetadatas = [[NSMutableArray alloc] initWithArray:metadatas];
        [self readFolderSuccessFailure:metadataNet metadataFolder:nil metadatas:metadatas message:nil errorCode:0];
        
    } else {
        
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized)
            [appDelegate openLoginView:self loginType:k_login_Modify_Password selector:k_intro_login];
        else
            [appDelegate messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
        
        _searchFileName = @"";
    }
}

- (void)cancelSearchBar
{
    if (self.searchController.active) {
        
        [self.searchController setActive:NO];
        [self createRefreshControl];
    
        _isSearchMode = NO;
        _searchFileName = @"";
        _dateReadDataSource = nil;
        _searchResultMetadatas = [NSMutableArray new];
        
        [self reloadDatasource];
    }
    
    //[self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete File or Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFile
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;
     
    NSArray *metadatas;
    if ([_selectedFileIDsMetadatas count] > 0) {
        metadatas = [_selectedFileIDsMetadatas allValues];
    } else {
        metadatas = [[NSArray alloc] initWithObjects:_metadata, nil];
    }
    
    // remove optimization
    _dateReadDataSource = nil;
    
    [[NCMainCommon sharedInstance ] deleteFileWithMetadatas:metadatas e2ee:_metadataFolder.e2eEncrypted serverUrl:self.serverUrl folderFileID:_metadataFolder.fileID completion:^(NSInteger errorCode, NSString *message) {
        
        // Reload
        if (_isSearchMode)
            [self readFolder:self.serverUrl];
        else
            [self reloadDatasource:self.serverUrl];
    }];
    
    // End Select Table View
    [self tableViewSelect:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Rename / Move =====
#pragma --------------------------------------------------------------------------------------------

- (void)renameSuccess:(CCMetadataNet *)metadataNet
{
    [self reloadDatasource:metadataNet.serverUrl];
}

- (void)renameFile:(NSArray *)arguments
{
    tableMetadata* metadata = [arguments objectAtIndex:0];
    NSString *fileName = [arguments objectAtIndex:1];
    
    // E2EE
    if (_metadataFolder.e2eEncrypted) {
        
        // verify if exists the new fileName
        if ([[NCManageDatabase sharedInstance] getE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.activeAccount, self.serverUrl, fileName]]) {
            [appDelegate messageNotification:@"_error_e2ee_" description:@"_file_already_exists_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
            return;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            NSError *error = [[NCNetworkingEndToEnd sharedManager] sendEndToEndMetadataOnServerUrl:self.serverUrl fileNameRename:metadata.fileName fileNameNewRename:fileName account:appDelegate.activeAccount user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl];
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [appDelegate messageNotification:@"_error_e2ee_" description:@"_e2e_error_send_metadata_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                });
            } else {
                [[NCManageDatabase sharedInstance] setMetadataFileNameViewWithDirectoryID:metadata.directoryID fileName:metadata.fileName newFileNameView:fileName];
                
                // Move file system
                NSString *atPath = [NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorageFileID:metadata.fileID], metadata.fileNameView];
                NSString *toPath = [NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorageFileID:metadata.fileID], fileName];
                [[NSFileManager defaultManager] moveItemAtPath:atPath toPath:toPath error:nil];
                [[NSFileManager defaultManager] moveItemAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView] toPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:fileName] error:nil];
            }
                
            // Unlock
            tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:self.serverUrl];

            if (tableLock != nil) {
                NSError *error = [[NCNetworkingEndToEnd sharedManager] unlockEndToEndFolderEncryptedOnServerUrl:self.serverUrl fileID:_metadataFolder.fileID token:tableLock.token user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl];
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [appDelegate messageNotification:@"_e2e_error_unlock_" description:error.localizedDescription visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                    });
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self reloadDatasource];
            });
        });
        
    } else  {
        
        // Plain
        [[CCActions sharedInstance] renameFileOrFolder:metadata fileName:fileName delegate:self];
    }
}

- (void)renameMoveFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if ([metadataNet.selector isEqualToString:selectorMove]) {
        
        [_hud hideHud];
    
        if (message && errorCode != kOCErrorServerUnauthorized)
            [appDelegate messageNotification:@"_move_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
                
        // End Select Table View
        [self tableViewSelect:NO];
        
        // reload Datasource
        if (_isSearchMode)
            [self readFolder:metadataNet.serverUrl];
        else
            [self reloadDatasource];
    }
}

- (void)moveSuccess:(CCMetadataNet *)metadataNet
{
    [_queueSelector removeObject:metadataNet.selector];
    
    if ([_queueSelector count] == 0) {
    
        [_hud hideHud];
        
        NSString *fileName = metadataNet.fileName;
        NSString *directoryID = metadataNet.directoryID;
        NSString *directoryIDTo = metadataNet.directoryIDTo;
        NSString *serverUrlTo = [[NCManageDatabase sharedInstance] getServerUrl:directoryIDTo];
        if (!serverUrlTo) return;
        
        // FILE -> Metadata
        if (metadataNet.directory == NO)
            [[NCManageDatabase sharedInstance] moveMetadataWithFileName:fileName directoryID:directoryID directoryIDTo:directoryIDTo];
    
        // DIRECTORY ->  Directory - CCMetadata
        if (metadataNet.directory == YES) {
        
            // delete all dir / subdir
            [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:[CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:fileName]];
            
            // move metadata
            [[NCManageDatabase sharedInstance] moveMetadataWithFileName:fileName directoryID:directoryID directoryIDTo:directoryIDTo];
            
            // Add new directory
            NSString *newDirectory = [NSString stringWithFormat:@"%@/%@", serverUrlTo, fileName];
            (void) [[NCManageDatabase sharedInstance] addDirectoryWithEncrypted:false favorite:false fileID:nil permissions:nil serverUrl:newDirectory];
        }
    
        // next
        [_selectedFileIDsMetadatas removeObjectForKey:metadataNet.fileID];
        
        if ([_selectedFileIDsMetadatas count] > 0) {
        
            NSArray *metadatas = [_selectedFileIDsMetadatas allValues];
            
            [self performSelectorOnMainThread:@selector(moveFileOrFolderMetadata:) withObject:@[[metadatas objectAtIndex:0], serverUrlTo, [NSNumber numberWithInteger:[_selectedFileIDsMetadatas count]], [NSNumber numberWithInteger:_numSelectedFileIDsMetadatas]] waitUntilDone:NO];
            
        } else {
            
            // End Select Table View
            [self tableViewSelect:NO];
            
            // reload Datasource
            if (_isSearchMode)
                [self readFolder:metadataNet.serverUrl];
            else
                [self reloadDatasource];
        }
    }
}

- (void)moveFileOrFolderMetadata:(NSArray *)arguments
{
    tableMetadata *metadata = [arguments objectAtIndex:0];
    NSString *serverUrlTo = [arguments objectAtIndex:1];
    NSInteger numFile = [[arguments objectAtIndex:2] integerValue];
    NSInteger ofFile = [[arguments objectAtIndex:3] integerValue];
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (!serverUrl) return;
    
    NSString *directoryIDTo = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrlTo];
    if (!directoryIDTo) return;
    
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];

    [ocNetworking readFile:metadata.fileName serverUrl:serverUrlTo account:appDelegate.activeAccount success:^(tableMetadata *metadata) {
    
        UIAlertController * alert= [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_file_already_exists_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        }];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
        
        // End Select Table View
        [self tableViewSelect:NO];
        
        // reload Datasource
        [self readFileReloadFolder];
        
    } failure:^(NSString *message, NSInteger errorCode) {
    
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
        
        metadataNet.action = actionMoveFileOrFolder;
        metadataNet.directory = metadata.directory;
        metadataNet.fileID = metadata.fileID;
        metadataNet.directoryID = metadata.directoryID;
        metadataNet.directoryIDTo = directoryIDTo;
        metadataNet.fileName = metadata.fileName;
        metadataNet.fileNameView = metadata.fileNameView;
        metadataNet.fileNameTo = metadata.fileName;
        metadataNet.etag = metadata.etag;
        metadataNet.selector = selectorMove;
        metadataNet.serverUrl = serverUrl;
        metadataNet.serverUrlTo = serverUrlTo;
        
        [_queueSelector addObject:metadataNet.selector];
        
        [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
        
        [_hud visibleHudTitle:[NSString stringWithFormat:NSLocalizedString(@"_move_file_n_", nil), ofFile - numFile + 1, ofFile] mode:MBProgressHUDModeIndeterminate color:nil];
    }];
}

// DELEGATE : Move
- (void)dismissMove
{
    [self reloadDatasource];

}

// DELEGATE : Move
- (void)moveServerUrlTo:(NSString *)serverUrlTo title:(NSString *)title
{
    [_queueSelector removeAllObjects];
    
    // E2EE DENIED
    if ([CCUtility isFolderEncrypted:serverUrlTo account:appDelegate.activeAccount]) {
        
        [appDelegate messageNotification:@"_move_" description:@"Not possible move files to encrypted directory" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        return;
    }
    
    if ([_selectedFileIDsMetadatas count] > 0) {
            
        _numSelectedFileIDsMetadatas = [_selectedFileIDsMetadatas count];
        NSArray *metadatas = [_selectedFileIDsMetadatas allValues];
            
        [self performSelectorOnMainThread:@selector(moveFileOrFolderMetadata:) withObject:@[[metadatas objectAtIndex:0], serverUrlTo, [NSNumber numberWithInteger:[_selectedFileIDsMetadatas count]], [NSNumber numberWithInteger:_numSelectedFileIDsMetadatas]] waitUntilDone:NO];
            
    } else {
        
        _numSelectedFileIDsMetadatas = 1;
        [self performSelectorOnMainThread:@selector(moveFileOrFolderMetadata:) withObject:@[_metadata, serverUrlTo, [NSNumber numberWithInteger:1], [NSNumber numberWithInteger:_numSelectedFileIDsMetadatas]] waitUntilDone:NO];
    }
}

- (void)moveOpenWindow:(NSArray *)indexPaths
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;
    
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMove"];
    
    CCMove *viewController = (CCMove *)navigationController.topViewController;

    viewController.delegate = self;
    viewController.move.title = NSLocalizedString(@"_move_", nil);
    viewController.tintColor = [NCBrandColor sharedInstance].brandText;
    viewController.barTintColor = [NCBrandColor sharedInstance].brand;
    viewController.tintColorTitle = [NCBrandColor sharedInstance].brandText;
    viewController.networkingOperationQueue = appDelegate.netQueue;
    // E2EE
    viewController.includeDirectoryE2EEncryption = NO;
    
    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)createFolder:(NSString *)fileNameFolder serverUrl:(NSString *)serverUrl
{
    fileNameFolder = [CCUtility removeForbiddenCharactersServer:fileNameFolder];
    if (![fileNameFolder length]) return;
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    NSString *fileIDTemp = [[NSUUID UUID] UUIDString];
    
    // Create Directory (temp) on metadata
    tableMetadata *metadata = [CCUtility createMetadataWithAccount:appDelegate.activeAccount date:[NSDate date] directory:YES fileID:fileIDTemp directoryID:directoryID fileName:fileNameFolder etag:@"" size:0 status:k_metadataStatusNormal];
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
    
    [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:serverUrl directoryID:nil];
    [self reloadDatasource];
    
    // Creeate folder Networking
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];
    
    [ocNetworking createFolder:fileNameFolder serverUrl:serverUrl account:appDelegate.activeAccount success:^(NSString *fileID, NSDate *date) {

        // Delete Temp Dir
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileIDTemp] clearDateReadDirectoryID:nil];

        NSString *newDirectory = [NSString stringWithFormat:@"%@/%@", serverUrl, fileNameFolder];
        
        if (_metadataFolder.e2eEncrypted) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = [[NCNetworkingEndToEnd sharedManager] markEndToEndFolderEncryptedOnServerUrl:newDirectory fileID:fileID user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        [appDelegate messageNotification:@"_e2e_error_mark_folder_" description:error.localizedDescription visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                    }
                    [self readFolder:self.serverUrl];
                });
            });
            
        } else {
            
            [self readFolder:self.serverUrl];
        }
        
    } failure:^(NSString *message, NSInteger errorCode) {
        
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized)
            [appDelegate openLoginView:self loginType:k_login_Modify_Password selector:k_intro_login];
        else
            [appDelegate messageNotification:@"_create_folder_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
        
        // Delete Temp Dir
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileIDTemp] clearDateReadDirectoryID:nil];
        
        [self reloadDatasource];
        
        // We are in directory fail ?
        CCMain *vc = [appDelegate.listMainVC objectForKey:[CCUtility stringAppendServerUrl:_serverUrl addFileName:fileNameFolder]];
        if (vc)
            [vc.navigationController popViewControllerAnimated:YES];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    [[NCMainCommon sharedInstance] triggerProgressTask:notification sectionDataSourceFileIDIndexPath:sectionDataSource.fileIDIndexPath tableView:self.tableView];
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if ([self indexPathIsValid:indexPath]) {
        
        tableMetadata *metadataSection = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        
        if (metadataSection) {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadataSection.fileID]];
            if (metadata)
                [[NCMainCommon sharedInstance] cancelTransferMetadata:metadata reloadDatasource:true];
        }
    }
}

- (void)cancelAllTask:(id)sender
{
    CGPoint location = [sender locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_all_task_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NCMainCommon sharedInstance] cancelAllTransfer];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Shared =====
#pragma --------------------------------------------------------------------------------------------

- (void)readSharedSuccess:(CCMetadataNet *)metadataNet items:(NSDictionary *)items openWindow:(BOOL)openWindow
{
    [_hud hideHud];
    
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    NSArray *result = [[NCManageDatabase sharedInstance] updateShare:items activeUrl:appDelegate.activeUrl];
    if (result) {
        appDelegate.sharesLink = result[0];
        appDelegate.sharesUserAndGroup = result[1];
    }
    
    // Notify Shares View
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"SharesReloadDatasource" object:nil userInfo:nil];
    
    if (openWindow) {
            
        if (_shareOC) {
                
            [_shareOC reloadData];
                
        } else {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadataNet.fileID]];
            
            // Apriamo la view
            _shareOC = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCShareOC"];
            
            _shareOC.delegate = self;
            _shareOC.metadata = metadata;
            _shareOC.serverUrl = metadataNet.serverUrl;
            
            _shareOC.shareLink = [appDelegate.sharesLink objectForKey:metadata.fileID];
            _shareOC.shareUserAndGroup = [appDelegate.sharesUserAndGroup objectForKey:metadata.fileID];
            
            [_shareOC setModalPresentationStyle:UIModalPresentationFormSheet];
            [self presentViewController:_shareOC animated:YES completion:nil];
        }
    }

    [self tableViewReloadData];
}

- (void)shareFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];

    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    // Unauthorized
    if (errorCode == kOCErrorServerUnauthorized)
        [appDelegate openLoginView:self loginType:k_login_Modify_Password selector:k_intro_login];
    else
        [appDelegate messageNotification:@"_share_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];

    if (_shareOC)
        [_shareOC reloadData];
    
    [self tableViewReloadData];
}

- (void)share:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionShare;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:appDelegate.activeUrl];
    metadataNet.fileNameView = metadata.fileNameView;
    metadataNet.password = password;
    metadataNet.selector = selectorShare;
    metadataNet.serverUrl = serverUrl;
        
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];

    [_hud visibleHudTitle:NSLocalizedString(@"_creating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)unShareSuccess:(CCMetadataNet *)metadataNet
{
    [_hud hideHud];
    
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    // rimuoviamo la condivisione da db
    NSArray *result = [[NCManageDatabase sharedInstance] unShare:metadataNet.share fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl sharesLink:appDelegate.sharesLink sharesUserAndGroup:appDelegate.sharesUserAndGroup];
    
    if (result) {
        appDelegate.sharesLink = result[0];
        appDelegate.sharesUserAndGroup = result[1];
    }
    
    if (_shareOC)
        [_shareOC reloadData];
    
    [self tableViewReloadData];
}

- (void)unShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionUnShare;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNameView = metadata.fileNameView;
    metadataNet.selector = selectorUnshare;
    metadataNet.serverUrl = serverUrl;
    metadataNet.share = share;
   
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleHudTitle:NSLocalizedString(@"_updating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)updateShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password expirationTime:(NSString *)expirationTime permission:(NSInteger)permission
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionUpdateShare;
    metadataNet.fileID = metadata.fileID;
    metadataNet.expirationTime = expirationTime;
    metadataNet.password = password;
    metadataNet.selector = selectorUpdateShare;
    metadataNet.serverUrl = serverUrl;
    metadataNet.share = share;
    metadataNet.sharePermission = permission;
        
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];

    [_hud visibleHudTitle:NSLocalizedString(@"_updating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)getUserAndGroupSuccess:(CCMetadataNet *)metadataNet items:(NSArray *)items
{
    [_hud hideHud];
    
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    if (_shareOC)
        [_shareOC reloadUserAndGroup:items];
}

- (void)getUserAndGroupFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    // Unauthorized
    if (errorCode == kOCErrorServerUnauthorized)
        [appDelegate openLoginView:self loginType:k_login_Modify_Password selector:k_intro_login];
    else
        [appDelegate messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
}

- (void)getUserAndGroup:(NSString *)find
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionGetUserAndGroup;
    metadataNet.optionAny = find;
    metadataNet.selector = selectorGetUserAndGroup;
        
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleIndeterminateHud];
}

- (void)shareUserAndGroup:(NSString *)user shareeType:(NSInteger)shareeType permission:(NSInteger)permission metadata:(tableMetadata *)metadata directoryID:(NSString *)directoryID serverUrl:(NSString *)serverUrl
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];

    metadataNet.action = actionShareWith;
    metadataNet.fileID = metadata.fileID;
    metadataNet.directoryID = directoryID;
    metadataNet.fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:appDelegate.activeUrl];
    metadataNet.fileNameView = metadata.fileNameView;
    metadataNet.serverUrl = serverUrl;
    metadataNet.selector = selectorShare;
    metadataNet.share = user;
    metadataNet.shareeType = shareeType;
    metadataNet.sharePermission = permission;

    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleHudTitle:NSLocalizedString(@"_creating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)openWindowShare:(tableMetadata *)metadata
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (!serverUrl) return;
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionReadShareServer;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNameView = metadata.fileNameView;
    metadataNet.selector = selectorOpenWindowShare;
    metadataNet.serverUrl = serverUrl;
    
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleIndeterminateHud];
}

- (void)tapActionShared:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata)
        [self openWindowShare:metadata];
}

- (void)tapActionConnectionMounted:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata) {
        
        CCShareInfoCMOC *vc = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCShareInfoCMOC"];
        
        vc.metadata = metadata;
        
        [vc setModalPresentationStyle:UIModalPresentationFormSheet];
        [self presentViewController:vc animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Favorite =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingFavorite:(tableMetadata *)metadata favorite:(BOOL)favorite
{
    NSString *fileNameServerUrl = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:self.serverUrl activeUrl:appDelegate.activeUrl];
    
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];
    [ocNetworking settingFavorite:fileNameServerUrl favorite:favorite completion:^(NSString *message, NSInteger errorCode) {
        if (errorCode == 0) {
            
            [[NCManageDatabase sharedInstance] setMetadataFavoriteWithFileID:metadata.fileID favorite:favorite];

            _dateReadDataSource = nil;
            if (_isSearchMode)
                [self readFolder:self.serverUrl];
            else
                [self reloadDatasource:self.serverUrl];
            
            if (metadata.directory && favorite) {
                NSString *dir = [CCUtility stringAppendServerUrl:self.serverUrl addFileName:metadata.fileName];
                [appDelegate.activeFavorites addFavoriteFolder:dir];
            }
            
            if (!metadata.directory && favorite && [CCUtility getFavoriteOffline]) {
                
                metadata.favorite = favorite;
                metadata.session = k_download_session;
                metadata.sessionError = @"";
                metadata.sessionSelector = selectorDownloadSynchronize;
                metadata.status = k_metadataStatusWaitDownload;
                    
                // Add Metadata for Download
                (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
                [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
            }
            
        } else {
            if (errorCode == kOCErrorServerUnauthorized)
                [appDelegate openLoginView:self loginType:k_login_Modify_Password selector:k_intro_login];
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Open in... =====
#pragma --------------------------------------------------------------------------------------------

- (void)openIn:(tableMetadata *)metadata
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (!serverUrl) return;

    metadata.session = k_download_session;
    metadata.sessionError = @"";
    metadata.sessionSelector = selectorOpenIn;
    metadata.status = k_metadataStatusWaitDownload;
    
    // Add Metadata for Download
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
    [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
    
    NSIndexPath *indexPath = [sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    if ([self indexPathIsValid:indexPath])
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Order Table & GroupBy & DirectoryOnTop =====
#pragma --------------------------------------------------------------------------------------------

- (void)orderTable:(NSString *)order
{
    [CCUtility setOrderSettings:order];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

- (void)ascendingTable:(BOOL)ascending
{
    [CCUtility setAscendingSettings:ascending];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

- (void)directoryOnTop:(BOOL)directoryOnTop
{
    [CCUtility setDirectoryOnTop:directoryOnTop];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

- (void)tableGroupBy:(NSString *)groupBy
{
    [CCUtility setGroupBySettings:groupBy];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Menu LOGO ====
#pragma --------------------------------------------------------------------------------------------

- (void)menuLogo:(UIGestureRecognizer *)theGestureRecognizer
{
    if (appDelegate.reSelectMenu.isOpen || appDelegate.reMainMenu.isOpen)
        return;
    
    // Brand
    if ([NCBrandOptions sharedInstance].disable_multiaccount)
        return;
    
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
    
    NSMutableArray *menuArray = [NSMutableArray new];
    
    for (NSString *account in listAccount) {
    
        CCMenuItem *item = [[CCMenuItem alloc] init];
        
        item.title = [account stringByTruncatingToWidth:self.view.bounds.size.width - 100 withFont:[UIFont systemFontOfSize:12.0] atEnd:YES];
        item.argument = account;
        
        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ ", account]];
        NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@-avatar.png", [CCUtility getDirectoryUserData], [CCUtility getStringUser:tableAccount.user activeUrl:tableAccount.url]];
        
        UIImage *avatar = [UIImage imageWithContentsOfFile:fileNamePath];
        if (avatar) {
            
            avatar = [CCGraphics scaleImage:avatar toSize:CGSizeMake(25, 25) isAspectRation:YES];
            
            CCAvatar *avatarImageView = [[CCAvatar alloc] initWithImage:avatar borderColor:[UIColor lightGrayColor] borderWidth:0.5];
            
            CGSize imageSize = avatarImageView.bounds.size;
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [avatarImageView.layer renderInContext:context];
            avatar = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
        } else {
            
            avatar = [UIImage imageNamed:@"menuLogoUser"];
        }
        
        item.image = avatar;
        item.target = self;
        
        if ([account isEqualToString:appDelegate.activeAccount]) {
            
            item.action = nil;
            [menuArray insertObject:item atIndex:0];
            
        } else {
        
            item.action = @selector(changeDefaultAccount:);
            [menuArray addObject:item];
        }
    }
    
    // Add + new account
    CCMenuItem *item = [[CCMenuItem alloc] init];
    
    item.title = NSLocalizedString(@"_add_account_", nil);
    item.argument = @"";
    item.image = [UIImage imageNamed:@"add"];
    item.target = self;
    item.action = @selector(addNewAccount:);
    
    [menuArray addObject:item];
    
    OptionalConfiguration options;
    Color textColor, backgroundColor;
    
    textColor.R = 0;
    textColor.G = 0;
    textColor.B = 0;
    
    backgroundColor.R = 1;
    backgroundColor.G = 1;
    backgroundColor.B = 1;
    
    options.arrowSize = 9;
    options.marginXSpacing = 7;
    options.marginYSpacing = 10;
    options.intervalSpacing = 20;
    options.menuCornerRadius = 6.5;
    options.maskToBackground = NO;
    options.shadowOfMenu = YES;
    options.hasSeperatorLine = YES;
    options.seperatorLineHasInsets = YES;
    options.textColor = textColor;
    options.menuBackgroundColor = backgroundColor;
    
    CGRect rect = self.view.frame;
    CGFloat locationY = [theGestureRecognizer locationInView: self.navigationController.navigationBar].y;
    CGFloat safeAreaTop = 0;
    CGFloat offsetY = 35;
    if (@available(iOS 11, *)) {
        safeAreaTop = [UIApplication sharedApplication].delegate.window.safeAreaInsets.top / 2;
    }
    rect.origin.y = locationY + safeAreaTop + offsetY;
    rect.size.height = rect.size.height - locationY - safeAreaTop - offsetY;
    
    [CCMenuAccount setTitleFont:[UIFont systemFontOfSize:12.0]];
    [CCMenuAccount showMenuInView:self.navigationController.view fromRect:rect menuItems:menuArray withOptions:options];    
}

- (void)changeDefaultAccount:(CCMenuItem *)sender
{
    NSInteger transferInprogress = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", appDelegate.activeAccount, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusInUpload, k_metadataStatusUploading] sorted:@"fileName" ascending:true] count];
    
    if (transferInprogress > 0) {
        [JDStatusBarNotification showWithStatus:NSLocalizedString(@"_transfers_in_queue_", nil) dismissAfter:k_dismissAfterSecond styleName:JDStatusBarStyleDefault];
        return;
    }
    
    [appDelegate.netQueue cancelAllOperations];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:[sender argument]];
        if (tableAccount) {
            
            [appDelegate settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activeUserID:tableAccount.userID activePassword:tableAccount.password];
    
            // go to home sweet home
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil];        
        }
    });
}

- (void)addNewAccount:(CCMenuItem *)sender
{
    NSInteger transferInprogress = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", appDelegate.activeAccount, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusInUpload, k_metadataStatusUploading] sorted:@"fileName" ascending:true] count];
    
    if (transferInprogress > 0) {
        [JDStatusBarNotification showWithStatus:NSLocalizedString(@"_transfers_in_queue_", nil) dismissAfter:k_dismissAfterSecond styleName:JDStatusBarStyleDefault];
        return;
    }
    
    [appDelegate.netQueue cancelAllOperations];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [appDelegate openLoginView:self loginType:k_login_Add selector:k_intro_login];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== ReMenu ====
#pragma --------------------------------------------------------------------------------------------

- (void)createReMenuBackgroundView:(REMenu *)menu
{
    CGFloat safeAreaBottom = 0;
    CGFloat safeAreaTop = 0;
    CGFloat statusBar = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaTop = [UIApplication sharedApplication].delegate.window.safeAreaInsets.top;
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    if ([UIApplication sharedApplication].isStatusBarHidden) {
        statusBar = 13;
    }
    
    CGFloat computeNavigationBarOffset = [menu computeNavigationBarOffset];
    UIViewController *rootController = [[[[UIApplication sharedApplication]delegate] window] rootViewController];
    CGRect globalPositionMenu = [menu.menuView convertRect:menu.menuView.bounds toView:rootController.view];

    _reMenuBackgroundView.frame = CGRectMake(0, computeNavigationBarOffset, globalPositionMenu.size.width,  rootController.view.frame.size.height);

    [UIView animateWithDuration:0.2 animations:^{

        CGFloat minimum = safeAreaBottom + self.tabBarController.tabBar.frame.size.height;
        CGFloat y =  rootController.view.frame.size.height - menu.menuView.frame.size.height - globalPositionMenu.origin.y + statusBar;
        
        if (y>minimum) {
            
            _reMenuBackgroundView.frame = CGRectMake(0, rootController.view.frame.size.height, globalPositionMenu.size.width, - y);
            [self.tabBarController.view addSubview:_reMenuBackgroundView];
        }
    }];
}

- (void)createReMainMenu
{
    NSString *ordinamento;
    NSString *groupBy = _directoryGroupBy;
    __block NSString *nuovoOrdinamento;
    NSString *titoloNuovo, *titoloAttuale;
    BOOL ascendente;
    __block BOOL nuovoAscendente;
    UIImage *image;
    
    // ITEM SELECT ----------------------------------------------------------------------------------------------------
    
    appDelegate.selezionaItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_select_", nil)subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"select"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            if ([sectionDataSource.allRecordsDataSource count] > 0) {
                [self tableViewSelect:YES];
            }
    }];

    // ITEM ORDER ----------------------------------------------------------------------------------------------------
    
    ordinamento = _directoryOrder;
    if ([ordinamento isEqualToString:@"fileName"]) {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrdeyByDate"] multiplier:2 color:[NCBrandColor sharedInstance].icon];
        titoloNuovo = NSLocalizedString(@"_order_by_date_", nil);
        titoloAttuale = NSLocalizedString(@"_current_order_name_", nil);
        nuovoOrdinamento = @"date";
    }
    
    if ([ordinamento isEqualToString:@"date"]) {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrderByFileName"] multiplier:2 color:[NCBrandColor sharedInstance].icon];
        titoloNuovo = NSLocalizedString(@"_order_by_name_", nil);
        titoloAttuale = NSLocalizedString(@"_current_order_date_", nil);
        nuovoOrdinamento = @"fileName";
    }
    
    appDelegate.ordinaItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:titoloAttuale image:image highlightedImage:nil action:^(REMenuItem *item) {
        [self orderTable:nuovoOrdinamento];
    }];
    
    // ITEM ASCENDING -----------------------------------------------------------------------------------------------------
    
    ascendente = [CCUtility getAscendingSettings];
    
    if (ascendente)  {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrdinamentoDiscendente"] multiplier:2 color:[NCBrandColor sharedInstance].icon];
        titoloNuovo = NSLocalizedString(@"_sort_descending_", nil);
        titoloAttuale = NSLocalizedString(@"_current_sort_ascending_", nil);
        nuovoAscendente = false;
    }
    
    if (!ascendente) {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrdinamentoAscendente"] multiplier:2 color:[NCBrandColor sharedInstance].icon];
        titoloNuovo = NSLocalizedString(@"_sort_ascending_", nil);
        titoloAttuale = NSLocalizedString(@"_current_sort_descending_", nil);
        nuovoAscendente = true;
    }
    
    appDelegate.ascendenteItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:titoloAttuale image:image highlightedImage:nil action:^(REMenuItem *item) {
        [self ascendingTable:nuovoAscendente];
    }];
    
    
    // ITEM ALPHABETIC -----------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"alphabetic"])  { titoloNuovo = NSLocalizedString(@"_group_alphabetic_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_alphabetic_no_", nil); }
    
    appDelegate.alphabeticItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuGroupByAlphabetic"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            if ([groupBy isEqualToString:@"alphabetic"]) [self tableGroupBy:@"none"];
            else [self tableGroupBy:@"alphabetic"];
    }];
    
    // ITEM TYPEFILE -------------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"typefile"])  { titoloNuovo = NSLocalizedString(@"_group_typefile_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_typefile_no_", nil); }
    
    appDelegate.typefileItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            if ([groupBy isEqualToString:@"typefile"]) [self tableGroupBy:@"none"];
            else [self tableGroupBy:@"typefile"];
    }];
   

    // ITEM DATE -------------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"date"])  { titoloNuovo = NSLocalizedString(@"_group_date_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_date_no_", nil); }
    
    appDelegate.dateItem = [[REMenuItem alloc] initWithTitle:titoloNuovo   subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuGroupByDate"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            if ([groupBy isEqualToString:@"date"]) [self tableGroupBy:@"none"];
            else [self tableGroupBy:@"date"];
    }];
    
    // ITEM DIRECTORY ON TOP ------------------------------------------------------------------------------------------------
    
    if ([CCUtility getDirectoryOnTop])  { titoloNuovo = NSLocalizedString(@"_directory_on_top_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_directory_on_top_no_", nil); }
    
    appDelegate.directoryOnTopItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            if ([CCUtility getDirectoryOnTop])
                [self directoryOnTop:NO];
            else
                [self directoryOnTop:YES];
    }];
    

    // REMENU --------------------------------------------------------------------------------------------------------------

    appDelegate.reMainMenu = [[REMenu alloc] initWithItems:@[appDelegate.selezionaItem, appDelegate.ordinaItem, appDelegate.ascendenteItem, appDelegate.alphabeticItem, appDelegate.typefileItem, appDelegate.dateItem, appDelegate.directoryOnTopItem]];
    
    appDelegate.reMainMenu.imageOffset = CGSizeMake(5, -1);
    
    appDelegate.reMainMenu.separatorOffset = CGSizeMake(50.0, 0.0);
    appDelegate.reMainMenu.imageOffset = CGSizeMake(0, 0);
    appDelegate.reMainMenu.waitUntilAnimationIsComplete = NO;
    
    appDelegate.reMainMenu.separatorHeight = 0.5;
    appDelegate.reMainMenu.separatorColor = [NCBrandColor sharedInstance].seperator;
    
    appDelegate.reMainMenu.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
    appDelegate.reMainMenu.textColor = [UIColor blackColor];
    appDelegate.reMainMenu.textAlignment = NSTextAlignmentLeft;
    appDelegate.reMainMenu.textShadowColor = nil;
    appDelegate.reMainMenu.textOffset = CGSizeMake(50, 0.0);
    appDelegate.reMainMenu.font = [UIFont systemFontOfSize:14.0];
    
    appDelegate.reMainMenu.highlightedBackgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
    appDelegate.reMainMenu.highlightedSeparatorColor = nil;
    appDelegate.reMainMenu.highlightedTextColor = [UIColor blackColor];
    appDelegate.reMainMenu.highlightedTextShadowColor = nil;
    appDelegate.reMainMenu.highlightedTextShadowOffset = CGSizeMake(0, 0);
    
    appDelegate.reMainMenu.subtitleTextColor = [UIColor colorWithWhite:0.425 alpha:1];
    appDelegate.reMainMenu.subtitleTextAlignment = NSTextAlignmentLeft;
    appDelegate.reMainMenu.subtitleTextShadowColor = nil;
    appDelegate.reMainMenu.subtitleTextShadowOffset = CGSizeMake(0, 0.0);
    appDelegate.reMainMenu.subtitleTextOffset = CGSizeMake(50, 0.0);
    appDelegate.reMainMenu.subtitleFont = [UIFont systemFontOfSize:12.0];
    
    appDelegate.reMainMenu.subtitleHighlightedTextColor = [UIColor lightGrayColor];
    appDelegate.reMainMenu.subtitleHighlightedTextShadowColor = nil;
    appDelegate.reMainMenu.subtitleHighlightedTextShadowOffset = CGSizeMake(0, 0);
    
    appDelegate.reMainMenu.borderWidth = 0.3;
    appDelegate.reMainMenu.borderColor =  [UIColor lightGrayColor];
    
    appDelegate.reMainMenu.animationDuration = 0.2;
    appDelegate.reMainMenu.closeAnimationDuration = 0.2;
    
    appDelegate.reMainMenu.bounce = NO;
    
    __weak typeof(self) weakSelf = self;
    [appDelegate.reMainMenu setClosePreparationBlock:^{
        
        // Backgroun reMenu (Gesture)
        [weakSelf.reMenuBackgroundView removeFromSuperview];
        [weakSelf.reMenuBackgroundView removeGestureRecognizer:weakSelf.singleFingerTap];
    }];
}

- (void)toggleReMainMenu
{
    if (appDelegate.reMainMenu.isOpen) {
        
        [appDelegate.reMainMenu close];
        
    } else {
        
        [self createReMainMenu];
        [appDelegate.reMainMenu showFromNavigationController:self.navigationController];
        
        // Backgroun reMenu & (Gesture)
        [self createReMenuBackgroundView:appDelegate.reMainMenu];
        
        _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleReMainMenu)];
        [_reMenuBackgroundView addGestureRecognizer:_singleFingerTap];
    }
}

- (void)createReSelectMenu
{
    // ITEM SELECT ALL --------------------------------------------------------------------------------------------------
    
    appDelegate.selectAllItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_select_all_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"selectAll"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
        [self didSelectAll];
    }];
    
    // ITEM MOVE --------------------------------------------------------------------------------------------------------
    
    appDelegate.moveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_move_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"move"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            [self moveOpenWindow:[self.tableView indexPathsForSelectedRows]];
    }];
    
    // ITEM DOWNLOAD ----------------------------------------------------------------------------------------------------
    
    appDelegate.downloadItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_download_selected_files_folders_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"downloadSelectedFiles"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            [self downloadSelectedFilesFolders];
    }];
    
    // ITEM SAVE IMAGE & VIDEO -------------------------------------------------------------------------------------------
    
    appDelegate.saveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_save_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"saveSelectedFiles"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
            [self saveSelectedFiles];
    }];
    
    // ITEM DELETE ------------------------------------------------------------------------------------------------------
    
    appDelegate.deleteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_delete_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"delete"] multiplier:2 color:[NCBrandColor sharedInstance].icon] highlightedImage:nil action:^(REMenuItem *item) {
        [self deleteFile];
    }];

    // E2EE
    if (_metadataFolder.e2eEncrypted) {
        appDelegate.reSelectMenu = [[REMenu alloc] initWithItems:@[appDelegate.selectAllItem, appDelegate.downloadItem, appDelegate.saveItem, appDelegate.deleteItem]];
    } else {
        appDelegate.reSelectMenu = [[REMenu alloc] initWithItems:@[appDelegate.selectAllItem, appDelegate.moveItem, appDelegate.downloadItem, appDelegate.saveItem, appDelegate.deleteItem]];
    }
    
    appDelegate.reSelectMenu.imageOffset = CGSizeMake(5, -1);
    
    appDelegate.reSelectMenu.separatorOffset = CGSizeMake(50.0, 0.0);
    appDelegate.reSelectMenu.imageOffset = CGSizeMake(0, 0);
    appDelegate.reSelectMenu.waitUntilAnimationIsComplete = NO;
    
    appDelegate.reSelectMenu.separatorHeight = 0.5;
    appDelegate.reSelectMenu.separatorColor = [NCBrandColor sharedInstance].seperator;
    
    appDelegate.reSelectMenu.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
    appDelegate.reSelectMenu.textColor = [UIColor blackColor];
    appDelegate.reSelectMenu.textAlignment = NSTextAlignmentLeft;
    appDelegate.reSelectMenu.textShadowColor = nil;
    appDelegate.reSelectMenu.textOffset = CGSizeMake(50, 0.0);
    appDelegate.reSelectMenu.font = [UIFont systemFontOfSize:14.0];
    
    appDelegate.reSelectMenu.highlightedBackgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
    appDelegate.reSelectMenu.highlightedSeparatorColor = nil;
    appDelegate.reSelectMenu.highlightedTextColor = [UIColor blackColor];
    appDelegate.reSelectMenu.highlightedTextShadowColor = nil;
    appDelegate.reSelectMenu.highlightedTextShadowOffset = CGSizeMake(0, 0);
    
    appDelegate.reSelectMenu.subtitleTextColor = [UIColor colorWithWhite:0.425 alpha:1.000];
    appDelegate.reSelectMenu.subtitleTextAlignment = NSTextAlignmentLeft;
    appDelegate.reSelectMenu.subtitleTextShadowColor = nil;
    appDelegate.reSelectMenu.subtitleTextShadowOffset = CGSizeMake(0, 0.0);
    appDelegate.reSelectMenu.subtitleTextOffset = CGSizeMake(50, 0.0);
    appDelegate.reSelectMenu.subtitleFont = [UIFont systemFontOfSize:12.0];
    
    appDelegate.reSelectMenu.subtitleHighlightedTextColor = [UIColor lightGrayColor];
    appDelegate.reSelectMenu.subtitleHighlightedTextShadowColor = nil;
    appDelegate.reSelectMenu.subtitleHighlightedTextShadowOffset = CGSizeMake(0, 0);
    
    appDelegate.reSelectMenu.borderWidth = 0.3;
    appDelegate.reSelectMenu.borderColor =  [UIColor lightGrayColor];
    
    appDelegate.reSelectMenu.closeAnimationDuration = 0.2;
    appDelegate.reSelectMenu.animationDuration = 0.2;

    appDelegate.reSelectMenu.bounce = NO;
    
    __weak typeof(self) weakSelf = self;
    [appDelegate.reSelectMenu setClosePreparationBlock:^{
        
        // Backgroun reMenu (Gesture)
        [weakSelf.reMenuBackgroundView removeFromSuperview];
        [weakSelf.reMenuBackgroundView removeGestureRecognizer:weakSelf.singleFingerTap];
    }];
}

- (void)toggleReSelectMenu
{
    if (appDelegate.reSelectMenu.isOpen) {
        
        [appDelegate.reSelectMenu close];
        
    } else {
        
        [self createReSelectMenu];
        [appDelegate.reSelectMenu showFromNavigationController:self.navigationController];
        
        // Backgroun reMenu & (Gesture)
        [self createReMenuBackgroundView:appDelegate.reSelectMenu];
        
        _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleReSelectMenu)];
        [_reMenuBackgroundView addGestureRecognizer:_singleFingerTap];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Long Press Recognized Table View / Menu Controller =====
#pragma --------------------------------------------------------------------------------------------

- (void)onLongPressTableView:(UILongPressGestureRecognizer*)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint touchPoint = [recognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
        
        if ([self indexPathIsValid:indexPath])
            _metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        else
            _metadata = nil;
        
        [self becomeFirstResponder];
        
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        UIMenuItem *copyFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_file_", nil) action:@selector(copyFile:)];
        UIMenuItem *copyFilesItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_files_", nil) action:@selector(copyFiles:)];

        UIMenuItem *openinFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_open_in_", nil) action:@selector(openinFile:)];
        
        UIMenuItem *pasteFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_file_", nil) action:@selector(pasteFile:)];
        
        UIMenuItem *pasteFilesItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_files_", nil) action:@selector(pasteFiles:)];
        
        [menuController setMenuItems:[NSArray arrayWithObjects:copyFileItem, copyFilesItem, openinFileItem, pasteFileItem, pasteFilesItem, nil]];
        
        [menuController setTargetRect:CGRectMake(touchPoint.x, touchPoint.y, 0.0f, 0.0f) inView:self.tableView];
        [menuController setMenuVisible:YES animated:YES];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    // For copy file, copy files, Open in ... :
    //
    // NO Directory
    // NO Error Passcode
    // NO In Session mode (download/upload)
    // NO Template
    
    if (@selector(copyFile:) == action || @selector(openinFile:) == action) {
        
        if (_isSelectedMode == NO && _metadata && !_metadata.directory && _metadata.status == k_metadataStatusNormal) return YES;
        else return NO;
    }
    
    if (@selector(copyFiles:) == action) {
        
        if (_isSelectedMode) {
            
            NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
            
            for (tableMetadata *metadata in selectedMetadatas) {
                
                if (!metadata.directory && metadata.status == k_metadataStatusNormal)
                    return YES;
            }
        }
        return NO;
    }

    if (@selector(pasteFile:) == action) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] == 1) {
            
            // Value : (NSData) fileID
            
            NSDictionary *dic = [items objectAtIndex:0];
            
            NSData *dataFileID = [dic objectForKey: k_metadataKeyedUnarchiver];
            NSString *fileID = [NSKeyedUnarchiver unarchiveObjectWithData:dataFileID];
            
            if (fileID) {
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
                if (metadata) {
                    return [CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView];
                } else {
                    return NO;
                }
            }
        }
            
        return NO;
    }
    
    if (@selector(pasteFiles:) == action) {
        
        BOOL isValid = NO;
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] <= 1) return NO;
        
        for (NSDictionary *dic in items) {
            
            // Value : (NSData) fileID
            
            NSData *dataFileID = [dic objectForKey: k_metadataKeyedUnarchiver];
            NSString *fileID = [NSKeyedUnarchiver unarchiveObjectWithData:dataFileID];

            if (fileID) {
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
                if (metadata) {
                    if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView]) {
                        isValid = YES;
                    } else {
                        isValid = NO;
                        break;
                    }
                } else {
                    isValid = NO;
                    break;
                }
            } else {
                isValid = NO;
                break;
            }
        }
        
        return isValid;
    }
    
    return NO;
}

/************************************ COPY ************************************/

- (void)copyFile:(id)sender
{
    // Remove all item
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.items = [[NSArray alloc] init];
    
    if ([CCUtility fileProviderStorageExists:_metadata.fileID fileName:_metadata.fileNameView]) {
        
        [self copyFileToPasteboard:_metadata];
        
    } else {
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
        
        if (serverUrl) {
            
            _metadata.session = k_download_session;
            _metadata.sessionError = @"";
            _metadata.sessionSelector = selectorLoadCopy;
            _metadata.status = k_metadataStatusWaitDownload;
            
            // Add Metadata for Download
            (void)[[NCManageDatabase sharedInstance] addMetadata:_metadata];
            [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
        }
    }
}

- (void)copyFiles:(id)sender
{
    // Remove all item
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.items = [[NSArray alloc] init];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    for (tableMetadata *metadata in selectedMetadatas) {
        
        if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView]) {
            
            [self copyFileToPasteboard:metadata];
            
        } else {

            NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];

            if (serverUrl) {
                
                metadata.session = k_download_session;
                metadata.sessionError = @"";
                metadata.sessionSelector = selectorLoadCopy;
                metadata.status = k_metadataStatusWaitDownload;
                
                // Add Metadata for Download
                (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
                [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
            }
        }
    }
    
    [self tableViewSelect:NO];
}

- (void)copyFileToPasteboard:(tableMetadata *)metadata
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:pasteboard.items];
    
    // Value : (NSData) fileID
    
    NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:[NSKeyedArchiver archivedDataWithRootObject:metadata.fileID], k_metadataKeyedUnarchiver,nil];
    [items addObject:item];
    
    [pasteboard setItems:items];
}

/************************************ OPEN IN ... ******************************/

- (void)openinFile:(id)sender
{
    [self openIn:_metadata];
}

/************************************ PASTE ************************************/

- (void)pasteFile:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items]];
}

- (void)pasteFiles:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items]];
}

- (void)uploadFilePasteArray:(NSArray *)items
{
    for (NSDictionary *dic in items) {
        
        // Value : (NSData) fileID
        
        NSData *dataFileID = [dic objectForKey: k_metadataKeyedUnarchiver];
        NSString *fileID = [NSKeyedUnarchiver unarchiveObjectWithData:dataFileID];
        NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:self.serverUrl];

        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
        
        if (metadata) {
            
            if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView]) {
                
                NSString *fileName = [[NCUtility sharedInstance] createFileName:metadata.fileNameView directoryID:directoryID];
                NSString *fileID = [directoryID stringByAppendingString:fileName];
                    
                [CCUtility copyFileAtPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView] toPath:[CCUtility getDirectoryProviderStorageFileID:fileID fileName:fileName]];
                    
                tableMetadata *metadataForUpload = [tableMetadata new];
                        
                metadataForUpload.account = appDelegate.activeAccount;
                metadataForUpload.date = [NSDate new];
                metadataForUpload.directoryID = directoryID;
                metadataForUpload.fileID = fileID;
                metadataForUpload.fileName = fileName;
                metadataForUpload.fileNameView = fileName;
                metadataForUpload.session = k_upload_session;
                metadataForUpload.sessionSelector = selectorUploadFile;
                metadataForUpload.size = metadata.size;
                metadataForUpload.status = k_metadataStatusWaitUpload;
                            
                // Add Medtadata for upload
                (void)[[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
            }
        }
    }
    
    [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];

    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Lock Passcode =====
#pragma --------------------------------------------------------------------------------------------

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(CCBKPasscode *)aViewController
{
    return _failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(CCBKPasscode *)aViewController
{
    return _lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if (aViewController.fromType == CCBKPasscodeFromLockScreen || aViewController.fromType == CCBKPasscodeFromLockDirectory || aViewController.fromType == CCBKPasscodeFromDisactivateDirectory ) {
        if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
            _lockUntilDate = nil;
            _failedAttempts = 0;
            aResultHandler(YES);
        } else aResultHandler(NO);
    } else aResultHandler(YES);
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    switch (aViewController.type) {
            
        case BKPasscodeViewControllerCheckPasscodeType: {
            
            if (aViewController.fromType == CCBKPasscodeFromLockDirectory) {
                
                // possiamo procedere alla prossima directory
                [self performSegueDirectoryWithControlPasscode:false];
                
                // avviamo la sessione Passcode Lock con now
                appDelegate.sessionePasscodeLock = [NSDate date];
            }
            
            // disattivazione lock cartella
            if (aViewController.fromType == CCBKPasscodeFromDisactivateDirectory) {
                
                NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
                if (!serverUrl)
                    return;
                NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileName];
                
                if (![[NCManageDatabase sharedInstance] setDirectoryLockWithServerUrl:lockServerUrl lock:NO]) {
                
                    [appDelegate messageNotification:@"_error_" description:@"_error_operation_canc_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
                }
                
                [self tableViewReloadData];
            }
        }
            break;
        default:
            break;
    }
}

- (void)comandoLockPassword
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    if (!serverUrl) return;
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileName];

    // se non è abilitato il Lock Passcode esci
    if ([[CCUtility getBlockCode] length] == 0) {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_warning_", nil) message:NSLocalizedString(@"_only_lock_passcode_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];

        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    // se è richiesta la disattivazione si chiede la password
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl]];
    
    if (directory.lock) {
        
        CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
        viewController.delegate = self;
        viewController.fromType = CCBKPasscodeFromDisactivateDirectory;
        viewController.type = BKPasscodeViewControllerCheckPasscodeType;
        viewController.inputViewTitlePassword = YES;
        
        if ([CCUtility getSimplyBlockCode]) {
            
            viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 6;
            
        } else {
            
            viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 64;
        }
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;

        viewController.title = NSLocalizedString(@"_passcode_protection_", nil);
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = [UIColor blackColor];
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        return;
    }
    
    // ---------------- ACTIVATE PASSWORD
    
    if ([[NCManageDatabase sharedInstance] setDirectoryLockWithServerUrl:lockServerUrl lock:YES]) {
        
        NSIndexPath *indexPath = [sectionDataSource.fileIDIndexPath objectForKey:_metadata.fileID];
        if ([self indexPathIsValid:indexPath])
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
        
    } else {
        
        [appDelegate messageNotification:@"_error_" description:@"_error_operation_canc_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
    }
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== menu action : Favorite, More, Delete [swipe] =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)canOpenMenuAction:(tableMetadata *)metadata
{
    if (!metadata || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata])
        return NO;
    
    if (metadata == nil || metadata.status != k_metadataStatusNormal)
        return NO;
    
    // E2EE
    if (_metadataFolder.e2eEncrypted && [CCUtility isEndToEndEnabled:appDelegate.activeAccount] == NO)
        return NO;
    
    return YES;
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    return [self canOpenMenuAction:metadata];
}

-(void)swipeTableCell:(nonnull MGSwipeTableCell *)cell didChangeSwipeState:(MGSwipeState)state gestureIsActive:(BOOL)gestureIsActive
{
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
   _metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        [self actionDelete:indexPath];
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        if (_metadata.favorite)
            [self settingFavorite:_metadata favorite:NO];
        else
            [self settingFavorite:_metadata favorite:YES];
    }
    
    return YES;
}

- (void)actionDelete:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    // Directory locked ?
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:[[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID] addFileName:metadata.fileName];
    if (!lockServerUrl) return;
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl]];
    tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
    
    if (directory.lock && [[CCUtility getBlockCode] length] && appDelegate.sessionePasscodeLock == nil) {
        
        [appDelegate messageNotification:@"_error_" description:@"_folder_blocked_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self performSelector:@selector(deleteFile) withObject:nil];
    }]];
    
    if (localFile) {
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_remove_local_file_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID] error:nil];
            [self reloadDatasource];
            
        }]];
    }
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)actionMore:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint touch = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touch];
    
    _metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    if (!serverUrl) return;
    
    NSString *titoloLock, *titleFavorite;
    
    if (_metadata.favorite) {
        titleFavorite = NSLocalizedString(@"_remove_favorites_", nil);
    } else {
        titleFavorite = NSLocalizedString(@"_add_favorites_", nil);
    }
    
    if (_metadata.directory) {
        
        // calcolo lockServerUrl
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileName];
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl]];
        
        if (directory.lock)
            titoloLock = [NSString stringWithFormat:NSLocalizedString(@"_remove_passcode_", nil)];
        else
            titoloLock = [NSString stringWithFormat:NSLocalizedString(@"_protect_passcode_", nil)];
    }
    
    // ******************************************* AHKActionSheet *******************************************
    
    AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.tabBarController.view title:nil];
    
    actionSheet.animationDuration = 0.2;
        
    actionSheet.buttonHeight = 50.0;
    actionSheet.cancelButtonHeight = 50.0f;
    actionSheet.separatorHeight = 5.0f;
    
    actionSheet.automaticallyTintButtonImages = @(NO);
    
    actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].encrypted };
    actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor blackColor] };
    actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont boldSystemFontOfSize:17], NSForegroundColorAttributeName:[UIColor blackColor] };
    actionSheet.disableButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor darkGrayColor] };
    
    actionSheet.separatorColor =  [NCBrandColor sharedInstance].seperator;
    actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);
    
    // ******************************************* DIRECTORY *******************************************
    
    if (_metadata.directory) {
        
        BOOL lockDirectory = NO;
        NSString *dirServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileName];
        BOOL isFolderEncrypted = [CCUtility isFolderEncrypted:[NSString stringWithFormat:@"%@/%@", self.serverUrl, _metadata.fileName] account:appDelegate.activeAccount];
        
        // Directory bloccata ?
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, dirServerUrl]];
        
        if (directory.lock && [[CCUtility getBlockCode] length] && appDelegate.sessionePasscodeLock == nil) lockDirectory = YES;
        
        [actionSheet addButtonWithTitle:_metadata.fileNameView
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement]
                        backgroundColor:[NCBrandColor sharedInstance].tabBar
                                 height:50.0
                                   type:AHKActionSheetButtonTypeDisabled
                                handler:nil
        ];
        
        [actionSheet addButtonWithTitle: titleFavorite
                                  image: [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] multiplier:2 color:[NCBrandColor sharedInstance].yellowFavorite]
                        backgroundColor: [NCBrandColor sharedInstance].backgroundView
                                 height: 50.0
                                   type: AHKActionSheetButtonTypeDefault
                                handler: ^(AHKActionSheet *as) {
                                    if (_metadata.favorite) [self settingFavorite:_metadata favorite:NO];
                                    else [self settingFavorite:_metadata favorite:YES];
                                }];
        
        if (!lockDirectory && !isFolderEncrypted) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"share"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        [self openWindowShare:_metadata];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:_autoUploadFileName] == YES && [serverUrl isEqualToString:_autoUploadDirectory] == YES) && !lockDirectory && !_metadata.e2eEncrypted) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"rename"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_rename_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
                                        
                                        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                                            textField.text = _metadata.fileNameView;
                                            //textField.selectedTextRange = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument];
                                            //textField.delegate = self;
                                            [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                                        }];
                                        
                                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                            NSLog(@"[LOG] Cancel action");
                                        }];
                                        
                                        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                            
                                            UITextField *fileName = alertController.textFields.firstObject;
                                            
                                            [self performSelectorOnMainThread:@selector(renameFile:) withObject:[NSMutableArray arrayWithObjects:_metadata,fileName.text, nil] waitUntilDone:NO];
                                        }];
                                        
                                        okAction.enabled = NO;
                                        
                                        [alertController addAction:cancelAction];
                                        [alertController addAction:okAction];
                                        
                                        [self presentViewController:alertController animated:YES completion:nil];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:_autoUploadFileName] == YES && [serverUrl isEqualToString:_autoUploadDirectory] == YES) && !lockDirectory && !isFolderEncrypted) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"move"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:_autoUploadFileName] == YES && [serverUrl isEqualToString:_autoUploadDirectory] == YES)) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_folder_automatic_upload_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderPhotos"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // Settings new folder Automatatic upload
                                        [[NCManageDatabase sharedInstance] setAccountAutoUploadFileName:_metadata.fileName];
                                        [[NCManageDatabase sharedInstance] setAccountAutoUploadDirectory:serverUrl activeUrl:appDelegate.activeUrl];
                                        
                                        // Clear data (old) Auto Upload
                                        [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:_autoUploadDirectory directoryID:nil];
                                                                                
                                        [self readFolder:serverUrl];
                                    }];
        }

        if (!([_metadata.fileName isEqualToString:_autoUploadFileName] == YES && [serverUrl isEqualToString:_autoUploadDirectory] == YES)) {
            
            [actionSheet addButtonWithTitle:titoloLock
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"settingsPasscodeYES"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        [self performSelector:@selector(comandoLockPassword) withObject:nil];
                                    }];
        }
        
        if (!_metadata.e2eEncrypted && [CCUtility isEndToEndEnabled:appDelegate.activeAccount]) {

            [actionSheet addButtonWithTitle:NSLocalizedString(@"_e2e_set_folder_encrypted_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"lock"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                            NSError *error = [[NCNetworkingEndToEnd sharedManager] markEndToEndFolderEncryptedOnServerUrl:[NSString stringWithFormat:@"%@/%@", self.serverUrl, _metadata.fileName] fileID:_metadata.fileID user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl];
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                if (error) {
                                                    [appDelegate messageNotification:@"_e2e_error_mark_folder_" description:error.localizedDescription visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                                                } else {
                                                    [[NCManageDatabase sharedInstance] deleteE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, [NSString stringWithFormat:@"%@/%@", self.serverUrl, _metadata.fileName]]];
                                                    [self readFolder:self.serverUrl];
                                                }
                                            });
                                        });
                                    }];
        }
        
        if (_metadata.e2eEncrypted && [CCUtility isEndToEndEnabled:appDelegate.activeAccount]) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_e2e_remove_folder_encrypted_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"lock"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                            NSError *error = [[NCNetworkingEndToEnd sharedManager] deletemarkEndToEndFolderEncryptedOnServerUrl:[NSString stringWithFormat:@"%@/%@", self.serverUrl, _metadata.fileName] fileID:_metadata.fileID user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl];
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                if (error) {
                                                    [appDelegate messageNotification:@"_e2e_error_delete_mark_folder_" description:error.localizedDescription visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                                                } else {
                                                    [[NCManageDatabase sharedInstance] deleteE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, [NSString stringWithFormat:@"%@/%@", self.serverUrl, _metadata.fileName]]];
                                                    [self readFolder:self.serverUrl];
                                                }
                                            });
                                        });
                                    }];
        }
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_delete_", nil)
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"delete"] multiplier:2 color:[UIColor redColor]]
                        backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                 height:50.0
                                   type:AHKActionSheetButtonTypeDestructive
                                handler:^(AHKActionSheet *as) {
                                    [self actionDelete:indexPath];
                                }];

        [actionSheet show];
    }
    
    // ******************************************* FILE *******************************************
    
    if (!_metadata.directory) {
        
        UIImage *iconHeader;

        // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
        if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:_metadata.fileID fileNameView:_metadata.fileNameView]])
            iconHeader = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:_metadata.fileID fileNameView:_metadata.fileNameView]];
        else
            iconHeader = [UIImage imageNamed:_metadata.iconName];
        
        [actionSheet addButtonWithTitle: _metadata.fileNameView
                                  image: iconHeader
                        backgroundColor: [NCBrandColor sharedInstance].tabBar
                                 height: 50.0
                                   type: AHKActionSheetButtonTypeDisabled
                                handler: nil
        ];
        
        
        [actionSheet addButtonWithTitle: titleFavorite
                                  image: [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] multiplier:2 color:[NCBrandColor sharedInstance].yellowFavorite]
                        backgroundColor: [NCBrandColor sharedInstance].backgroundView
                                 height: 50.0
                                   type: AHKActionSheetButtonTypeDefault
                                handler: ^(AHKActionSheet *as) {
                                    if (_metadata.favorite) [self settingFavorite:_metadata favorite:NO];
                                    else [self settingFavorite:_metadata favorite:YES];
                                }];
        
        if (!_metadataFolder.e2eEncrypted) {

            [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"share"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                                backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                        height: 50.0
                                        type:AHKActionSheetButtonTypeDefault
                                        handler:^(AHKActionSheet *as) {
                                            [self openWindowShare:_metadata];
                                        }];
        }
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_open_in_", nil)
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"openFile"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                        backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    [self performSelector:@selector(openIn:) withObject:_metadata];
                                }];
        
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"rename"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                        backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_rename_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
                                    
                                    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                                        textField.text = _metadata.fileNameView;
                                        [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                                    }];
                                    
                                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                        NSLog(@"[LOG] Cancel action");
                                    }];
                                    
                                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                        UITextField *fileName = alertController.textFields.firstObject;
                                        [self performSelectorOnMainThread:@selector(renameFile:) withObject:[NSMutableArray arrayWithObjects:_metadata,fileName.text, nil] waitUntilDone:NO];
                                    }];
                                    
                                    okAction.enabled = NO;
                                    
                                    [alertController addAction:cancelAction];
                                    [alertController addAction:okAction];
                                    
                                    [self presentViewController:alertController animated:YES completion:nil];
                                }];
        
        if (!_metadataFolder.e2eEncrypted) {

            [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"move"] multiplier:2 color:[NCBrandColor sharedInstance].icon]
                            backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                     height:50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                    }];
        }
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_delete_", nil)
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"delete"] multiplier:2 color:[UIColor redColor]]
                        backgroundColor:[NCBrandColor sharedInstance].backgroundView
                                 height:50.0
                                   type:AHKActionSheetButtonTypeDestructive
                                handler:^(AHKActionSheet *as) {
                                    [self actionDelete:indexPath];
                                }];
        
        [actionSheet show];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)clearDateReadDataSource:(NSNotification *)notification
{
    _dateReadDataSource = Nil;
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    [self reloadDatasource:_serverUrl];
}

- (void)reloadDatasource:(NSString *)serverUrl
{
    // test
    if (appDelegate.activeAccount.length == 0 || serverUrl.length == 0 || serverUrl == nil)
        return;
    
    // Search Mode
    if (_isSearchMode) {
        
        // Create metadatas
        NSMutableArray *metadatas = [NSMutableArray new];
        for (tableMetadata *resultMetadata in _searchResultMetadatas) {
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", resultMetadata.fileID]];
            if (metadata) {
                [metadatas addObject:metadata];
            }
        }
        
        sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:metadatas listProgressMetadata:nil groupByField:_directoryGroupBy filterFileID:appDelegate.filterFileID activeAccount:appDelegate.activeAccount];

        [self tableViewReloadData];
        
        if ([sectionDataSource.allRecordsDataSource count] == 0 && [_searchFileName length] >= k_minCharsSearch) {
            
            _noFilesSearchTitle = NSLocalizedString(@"_search_no_record_found_", nil);
            _noFilesSearchDescription = @"";
        }
        
        if ([sectionDataSource.allRecordsDataSource count] == 0 && [_searchFileName length] < k_minCharsSearch) {
            
            _noFilesSearchTitle = @"";
            _noFilesSearchDescription = NSLocalizedString(@"_search_instruction_", nil);
        }
    
        [self.tableView reloadEmptyDataSet];
        
        return;
    }
    
    // Reload -> Self se non siamo nella dir appropriata cercala e se è in memoria reindirizza il reload
    if ([serverUrl isEqualToString:_serverUrl] == NO || _serverUrl == nil) {
        
        CCMain *main = [appDelegate.listMainVC objectForKey:serverUrl];
        if (main) {
            [main reloadDatasource];
        } else {
            [self tableViewReloadData];
        }
        
        return;
    }
        
    // Settaggio variabili per le ottimizzazioni
    _directoryGroupBy = [CCUtility getGroupBySettings];
    _directoryOrder = [CCUtility getOrderSettings];
    
    // Remove optimization for encrypted directory
    if (_metadataFolder.e2eEncrypted)
        _dateReadDataSource = nil;
    
    // current directoryID
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];

    // Controllo data lettura Data Source
    tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, serverUrl]];
    // Get MetadataFolder
    if (![serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]])
        _metadataFolder = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", tableDirectory.fileID]];
    
    NSDate *dateDateRecordDirectory = tableDirectory.dateReadDirectory;
    
    if ([dateDateRecordDirectory compare:_dateReadDataSource] == NSOrderedDescending || dateDateRecordDirectory == nil || _dateReadDataSource == nil) {
        
        NSLog(@"[LOG] Rebuild Data Source File : %@", _serverUrl);

        _dateReadDataSource = [NSDate date];
    
        // Data Source
        
        NSString *sorted = _directoryOrder;
        if ([sorted isEqualToString:@"fileName"])
            sorted = @"fileName";
        
        if (directoryID) {
        
            NSArray *recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND status != %i", directoryID, k_metadataStatusHide] sorted:sorted ascending:[CCUtility getAscendingSettings]];
                                                  
            sectionDataSource = [CCSectionDataSourceMetadata new];
            sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:_directoryGroupBy filterFileID:appDelegate.filterFileID activeAccount:appDelegate.activeAccount];
            
            // get auto upload folder
            _autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
            _autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:appDelegate.activeUrl];
        }
        
    } else {
        
         NSLog(@"[LOG] [OPTIMIZATION] Rebuild Data Source File : %@ - %@", _serverUrl, _dateReadDataSource);
    }
    
    [self tableViewReloadData];
}

- (NSArray *)getMetadatasFromSelectedRows:(NSArray *)selectedRows
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    if (selectedRows.count > 0) {
    
        for (NSIndexPath *selectionIndex in selectedRows) {
            
            NSString *fileID = [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:selectionIndex.section]] objectAtIndex:selectionIndex.row];
            tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:fileID];

            [metadatas addObject:metadata];
        }
    }
    
    return metadatas;
}

- (NSArray *)getMetadatasFromSectionDataSource:(NSInteger)section
{
    NSInteger totSections =[sectionDataSource.sections count] ;
    
    if ((totSections < (section + 1)) || ((section + 1) > totSections)) {
        return nil;
    }
    
    id valueSection = [sectionDataSource.sections objectAtIndex:section];
    
    return [sectionDataSource.sectionArrayRow objectForKey:valueSection];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Table ==== 
#pragma --------------------------------------------------------------------------------------------

- (void)tableViewSelect:(BOOL)edit
{
    // chiudiamo eventuali swipe aperti
    if (edit)
        [self.tableView setEditing:NO animated:NO];
    
    [self.tableView setAllowsMultipleSelectionDuringEditing:edit];
    [self.tableView setEditing:edit animated:YES];
    _isSelectedMode = edit;
    
    if (edit)
        [self setUINavigationBarSelected];
    else
        [self setUINavigationBarDefault];
    
    [_selectedFileIDsMetadatas removeAllObjects];
    
    [self setTitle];
}

- (void)tableViewReloadData
{
    // store selected cells before relod
    NSArray *indexPaths = [self.tableView indexPathsForSelectedRows];
    
    // reload table view
    [self.tableView reloadData];
    
    // selected cells stored
    for (NSIndexPath *path in indexPaths)
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    
    [self setTableViewFooter];
    
    if (self.tableView.editing)
        [self setTitle];
    
    //
    [self.tableView reloadEmptyDataSet];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{    
    if (tableView.editing == 1) {
        
        tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        
        if (!metadata || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata])
            return NO;
        
        if (metadata == nil || metadata.status != k_metadataStatusNormal)
            return NO;
        else
            return YES;
        
    } else {
        
        [_selectedFileIDsMetadatas removeAllObjects];
    }
    
    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:section]] count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSArray *sections = [sectionDataSource.sectionArrayRow allKeys];
    NSString *sectionTitle = [sections objectAtIndex:section];
    
    if ([sectionTitle isKindOfClass:[NSString class]] && [sectionTitle rangeOfString:@"download"].location != NSNotFound) return 18.f;
    if ([sectionTitle isKindOfClass:[NSString class]] && [sectionTitle rangeOfString:@"upload"].location != NSNotFound) return 18.f;
    
    if ([_directoryGroupBy isEqualToString:@"none"] && [sections count] <= 1) return 0.0f;
    
    return 20.f;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    float shift;
    UIVisualEffectView *visualEffectView;
    
    NSString *titleSection;
    
    if (![self indexPathIsValid:[NSIndexPath indexPathForRow:0 inSection:section]])
        return nil;
    
    if ([[sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]])
        titleSection = [sectionDataSource.sections objectAtIndex:section];
    
    if ([[sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSDate class]])
        titleSection = [CCUtility getTitleSectionDate:[sectionDataSource.sections objectAtIndex:section]];
    
    if ([titleSection isEqualToString:@"_none_"]) titleSection = @"";
    else if ([titleSection rangeOfString:@"download"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_download_",nil);
    else if ([titleSection rangeOfString:@"upload"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_upload_",nil);
    else titleSection = NSLocalizedString(titleSection,nil);
    
    // Format title
    NSString *currentDevice = [CCUtility currentDevice];
    if ([currentDevice rangeOfString:@"iPad3"].location != NSNotFound) {
        
        visualEffectView = [[UIVisualEffectView alloc] init];
        visualEffectView.backgroundColor = [[NCBrandColor sharedInstance].brand colorWithAlphaComponent:0.3];
        
    } else {
        
        UIVisualEffect *blurEffect;
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        visualEffectView.backgroundColor = [[NCBrandColor sharedInstance].brand colorWithAlphaComponent:0.2];
    }
    
    if ([_directoryGroupBy isEqualToString:@"alphabetic"]) {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            shift = - 35;
        else
            shift =  - 20;
        
    } else shift = - 10;
    
    // Title
    UILabel *titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(10, -12, 0, 44)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont systemFontOfSize:12];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleSection;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    [visualEffectView.contentView addSubview:titleLabel];
    
    // Elements
    UILabel *elementLabel= [[UILabel alloc]initWithFrame:CGRectMake(shift, -12, 0, 44)];
    elementLabel.backgroundColor = [UIColor clearColor];
    elementLabel.textColor = [UIColor blackColor];;
    elementLabel.font = [UIFont systemFontOfSize:12];
    elementLabel.textAlignment = NSTextAlignmentRight;
    elementLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    NSArray *metadatas = [self getMetadatasFromSectionDataSource:section];
    NSUInteger rowsCount = [metadatas count];
    
    if (rowsCount == 0) return nil;
    if (rowsCount == 1) elementLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rowsCount,  NSLocalizedString(@"_element_",nil)];
    if (rowsCount > 1) elementLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rowsCount,  NSLocalizedString(@"_elements_",nil)];
    
    [visualEffectView.contentView addSubview:elementLabel];
    
    return visualEffectView;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [sectionDataSource.sections indexOfObject:title];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if ([_directoryGroupBy isEqualToString:@"alphabetic"])
        return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
    else
        return nil;
}

/*
-(void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([indexPath row] == ((NSIndexPath*)[[tableView indexPathsForVisibleRows] lastObject]).row){
        
    }
}
*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata == nil || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata]) {
        return [CCCellMain new];
    }
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (serverUrl == nil) {
        return [CCCellMain new];
    }
    
    // Download thumbnail
    if (metadata.thumbnailExists && ![[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]] && !_metadataFolder.e2eEncrypted) {
        [self downloadThumbnail:metadata serverUrl:serverUrl indexPath:indexPath];
    }
    
    UITableViewCell *cell = [[NCMainCommon sharedInstance] cellForRowAtIndexPath:indexPath tableView:tableView metadata:metadata metadataFolder:_metadataFolder serverUrl:self.serverUrl autoUploadFileName:_autoUploadFileName autoUploadDirectory:_autoUploadDirectory];
    
    // NORMAL - > MAIN
    
    if ([cell isKindOfClass:[CCCellMain class]]) {
        
        NSString *shareLink = [appDelegate.sharesLink objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];
        NSString *shareUserAndGroup = [appDelegate.sharesUserAndGroup objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];
        BOOL isShare = false;
        BOOL isMounted = false;
        
        if (_metadataFolder) {
            isShare = [metadata.permissions containsString:k_permission_shared] && ![_metadataFolder.permissions containsString:k_permission_shared];
            isMounted = [metadata.permissions containsString:k_permission_mounted] && ![_metadataFolder.permissions containsString:k_permission_mounted];
        }
        
        // Share add Tap
        if (isShare || isMounted || shareLink != nil || shareUserAndGroup != nil) {
            
            if (isShare || isMounted) {
                
                // Shared with you
                
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionConnectionMounted:)];
                [tap setNumberOfTapsRequired:1];
                ((CCCellMain *)cell).shared.userInteractionEnabled = YES;
                [((CCCellMain *)cell).shared addGestureRecognizer:tap];
                
            } else if (shareLink != nil || shareUserAndGroup != nil) {
                
                // You share
                
                if (metadata.directory) {
                    ((CCCellMain *)cell).shared.userInteractionEnabled = NO;
                } else {
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionShared:)];
                    [tap setNumberOfTapsRequired:1];
                    ((CCCellMain *)cell).shared.userInteractionEnabled = YES;
                    [((CCCellMain *)cell).shared addGestureRecognizer:tap];
                }
            }
        }
        
        // More
        if ([self canOpenMenuAction:metadata]) {
            
            UITapGestureRecognizer *tapMore = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionMore:)];
            [tapMore setNumberOfTapsRequired:1];
            ((CCCellMain *)cell).more.userInteractionEnabled = YES;
            [((CCCellMain *)cell).more addGestureRecognizer:tapMore];
        }
        
        // MGSwipeButton
        ((CCCellMain *)cell).delegate = self;

        // LEFT
        ((CCCellMain *)cell).leftButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] multiplier:2 color:[UIColor whiteColor]] backgroundColor:[NCBrandColor sharedInstance].yellowFavorite padding:25]];
        
        ((CCCellMain *)cell).leftExpansion.buttonIndex = 0;
        ((CCCellMain *)cell).leftExpansion.fillOnTrigger = NO;
        
        //centerIconOverText
        MGSwipeButton *favoriteButton = (MGSwipeButton *)[((CCCellMain *)cell).leftButtons objectAtIndex:0];
        [favoriteButton centerIconOverText];
        
        // RIGHT
        ((CCCellMain *)cell).rightButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"delete"] multiplier:2 color:[UIColor whiteColor]] backgroundColor:[UIColor redColor] padding:25]];
        
        ((CCCellMain *)cell).rightExpansion.buttonIndex = 0;
        ((CCCellMain *)cell).rightExpansion.fillOnTrigger = NO;
        
        //centerIconOverText
        MGSwipeButton *deleteButton = (MGSwipeButton *)[((CCCellMain *)cell).rightButtons objectAtIndex:0];
        [deleteButton centerIconOverText];
    }
    
    // TRANSFER
    
    if ([cell isKindOfClass:[CCCellMainTransfer class]]) {
        
        // gesture Transfer
        [((CCCellMainTransfer *)cell).transferButton.stopButton addTarget:self action:@selector(cancelTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer *stopLongGesture = [UILongPressGestureRecognizer new];
        [stopLongGesture addTarget:self action:@selector(cancelAllTask:)];
        [((CCCellMainTransfer *)cell).transferButton.stopButton addGestureRecognizer:stopLongGesture];
    }
    
    return cell;
    
}

- (void)setTableViewFooter
{
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    [footerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    [footerLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    UIFont *appFont = [UIFont systemFontOfSize:12];
    
    footerLabel.font = appFont;
    footerLabel.textColor = [UIColor grayColor];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    
    NSString *folders;
    NSString *files;
    NSString *footerText;
    
    if (sectionDataSource.directories > 1) {
        folders = [NSString stringWithFormat:@"%ld %@", (long)sectionDataSource.directories, NSLocalizedString(@"_folders_", nil)];
    } else if (sectionDataSource.directories == 1){
        folders = [NSString stringWithFormat:@"%ld %@", (long)sectionDataSource.directories, NSLocalizedString(@"_folder_", nil)];
    } else {
        folders = @"";
    }
    
    if (sectionDataSource.files > 1) {
        files = [NSString stringWithFormat:@"%ld %@ %@", (long)sectionDataSource.files, NSLocalizedString(@"_files_", nil), [CCUtility transformedSize:sectionDataSource.totalSize]];
    } else if (sectionDataSource.files == 1){
        files = [NSString stringWithFormat:@"%ld %@ %@", (long)sectionDataSource.files, NSLocalizedString(@"_file_", nil), [CCUtility transformedSize:sectionDataSource.totalSize]];
    } else {
        files = @"";
    }
    
    if ([folders isEqualToString:@""]) {
        footerText = files;
    } else if ([files isEqualToString:@""]) {
        footerText = folders;
    } else {
        footerText = [NSString stringWithFormat:@"%@, %@", folders, files];
    }
    
    footerLabel.text = footerText;
    
    [footerView addSubview:footerLabel];
    [self.tableView setTableFooterView:footerView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
    CCCellMain *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    // settiamo il record file.
    _metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (!_metadata)
        return;
    
    // se non può essere selezionata deseleziona
    if ([cell isEditing] == NO)
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // se siamo in modalità editing impostiamo il titolo dei selezioati e usciamo subito
    if (self.tableView.editing) {
        
        [_selectedFileIDsMetadatas setObject:_metadata forKey:_metadata.fileID];
        [self setTitle];
        return;
    }
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    if (!serverUrl) return;
    
    // se è in corso una sessione
    if (_metadata.status != k_metadataStatusNormal)
        return;
    
    // file
    if (_metadata.directory == NO) {
        
        // se il file esiste andiamo direttamente al delegato altrimenti carichiamolo
        if ([CCUtility fileProviderStorageExists:_metadata.fileID fileName:_metadata.fileNameView]) {
            
            [self downloadFileSuccessFailure:_metadata.fileName fileID:_metadata.fileID serverUrl:serverUrl selector:selectorLoadFileView errorMessage:@"" errorCode:0];
            
        } else {
            
            if (_metadataFolder.e2eEncrypted && ![CCUtility isEndToEndEnabled:appDelegate.activeAccount]) {
                
                [appDelegate messageNotification:@"_info_" description:@"_e2e_goto_settings_for_enable_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
                
            } else {
            
                if (([_metadata.typeFile isEqualToString: k_metadataTypeFile_video] || [_metadata.typeFile isEqualToString: k_metadataTypeFile_audio]) && _metadataFolder.e2eEncrypted == NO) {
                    
                    if ([self shouldPerformSegue])
                        [self performSegueWithIdentifier:@"segueDetail" sender:self];
                    
                } else {
                   
                    _metadata.session = k_download_session;
                    _metadata.sessionError = @"";
                    _metadata.sessionSelector = selectorLoadFileView;
                    _metadata.status = k_metadataStatusWaitDownload;
                    
                    // Add Metadata for Download
                    (void)[[NCManageDatabase sharedInstance] addMetadata:_metadata];
                    [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
                    
                    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        }
    }
    
    if (_metadata.directory) {
        
        imageTitleSegue = cell.imageTitleSegue;
        [self performSegueDirectoryWithControlPasscode:true];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    [_selectedFileIDsMetadatas removeObjectForKey:metadata.fileID];
    
    [self setTitle];
}

- (void)didSelectAll
{
    for (int i = 0; i < self.tableView.numberOfSections; i++) {
        for (int j = 0; j < [self.tableView numberOfRowsInSection:i]; j++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:j inSection:i];
            tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
            [_selectedFileIDsMetadatas setObject:metadata forKey:metadata.fileID];
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
    [self setTitle];
}

- (BOOL)indexPathIsValid:(NSIndexPath *)indexPath
{
    if (!indexPath)
        return NO;
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSInteger lastSectionIndex = [self numberOfSectionsInTableView:self.tableView] - 1;
    
    if (section > lastSectionIndex || lastSectionIndex < 0)
        return NO;
    
    NSInteger rowCount = [self.tableView numberOfRowsInSection:indexPath.section] - 1;
    
    if (rowCount < 0)
        return NO;
    
    return row <= rowCount;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue
{
    // if background return
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return NO;
    
    if (self.view.window == NO)
        return NO;
    
    // Collapsed ma siamo già in detail esci
    if (self.splitViewController.isCollapsed)
        if (_detailViewController.isViewLoaded && _detailViewController.view.window) return NO;
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id viewController = segue.destinationViewController;
    tableMetadata *metadata;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController *nav = viewController;
        _detailViewController = (CCDetail *)nav.topViewController;
        
    } else {
        
        _detailViewController = segue.destinationViewController;
    }
    
    NSMutableArray *photoDataSource = [NSMutableArray new];
    
    if ([sender isKindOfClass:[tableMetadata class]]) {
    
        metadata = sender;
        [photoDataSource addObject:sender];
        
    } else {
        
        metadata = _metadata;
        
        for (NSString *fileID in sectionDataSource.allFileID) {
            tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:fileID];
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
                [photoDataSource addObject:metadata];
        }
    }
    
    _detailViewController.metadataDetail = metadata;
    _detailViewController.photoDataSource = photoDataSource;
    _detailViewController.dateFilterQuery = nil;
    
    [_detailViewController setTitle:metadata.fileNameView];
}

// can i go to next viewcontroller
- (void)performSegueDirectoryWithControlPasscode:(BOOL)controlPasscode
{
    NSString *nomeDir;

    if (self.tableView.editing == NO) {
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
        if (!serverUrl) return;
        
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileName];
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl]];
        
        // SE siamo in presenza di una directory bloccata E è attivo il block E la sessione password Lock è senza data ALLORA chiediamo la password per procedere
        if (directory.lock && [[CCUtility getBlockCode] length] && appDelegate.sessionePasscodeLock == nil && controlPasscode) {
            
            CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
            viewController.delegate = self;
            viewController.fromType = CCBKPasscodeFromLockDirectory;
            viewController.type = BKPasscodeViewControllerCheckPasscodeType;
            viewController.inputViewTitlePassword = YES;
            
            if ([CCUtility getSimplyBlockCode]) {
                
                viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
                viewController.passcodeInputView.maximumLength = 6;
                
            } else {
                
                viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
                viewController.passcodeInputView.maximumLength = 64;
            }

            BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
            touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
            viewController.touchIDManager = touchIDManager;
            
            viewController.title = NSLocalizedString(@"_folder_blocked_", nil);
            viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
            viewController.navigationItem.leftBarButtonItem.tintColor = [UIColor blackColor];
            
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            [self presentViewController:navController animated:YES completion:nil];
            
            return;
        }
        
        // E2EE Check enable
        if (_metadata.e2eEncrypted && [CCUtility isEndToEndEnabled:appDelegate.activeAccount] == NO) {
            
            [appDelegate messageNotification:@"_info_" description:@"_e2e_goto_settings_for_enable_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
            return;
        }
        
        nomeDir = _metadata.fileName;
        
        NSString *serverUrlPush = [CCUtility stringAppendServerUrl:serverUrl addFileName:nomeDir];
    
        CCMain *viewController = [appDelegate.listMainVC objectForKey:serverUrlPush];
        
        if (!viewController) {
            
            viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMain"];
            
            viewController.serverUrl = serverUrlPush;
            viewController.titleMain = _metadata.fileName;
            viewController.imageTitle = imageTitleSegue;
            
            // save self
            [appDelegate.listMainVC setObject:viewController forKey:serverUrlPush];
            
            [self.navigationController pushViewController:viewController animated:YES];
        
        } else {
           
            if (viewController.isViewLoaded) {
                
                viewController.titleMain = _metadata.fileName;
                viewController.imageTitle = imageTitleSegue;
                
                // Fix : Application tried to present modally an active controller
                if ([self.navigationController isBeingPresented]) {
                    // being presented
                } else if ([self.navigationController isMovingToParentViewController]) {
                    // being pushed
                } else {
                    [self.navigationController pushViewController:viewController animated:YES];
                }
            }
        }
    }
}

@end
