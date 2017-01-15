//
//  CCFavorite.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 11/11/14.
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

#import "CCFavorite.h"

#import "AppDelegate.h"
#import "CCSynchronization.h"

#pragma GCC diagnostic ignored "-Wundeclared-selector"

@interface CCFavorite ()
{
    NSMutableArray *dataSource;
}

@end

@implementation CCFavorite


#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"reloadTableFavorite" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronizedFavorites) name:@"synchronizedFavorites" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initToHome) name:@"initToHomeCCPreferitiViewController" object:nil];
        
        app.activeFavorite = self;
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellFavorite" bundle:nil] forCellReuseIdentifier:@"FavoriteCell"];
        
    // Settings initial dir
    if (![self.serverUrlLocal length]) self.serverUrlLocal = @"favorite";
    
    // dataSource
    dataSource = [[NSMutableArray alloc] init];
    
    // Metadata
    self.metadata = [[CCMetadata alloc] init];
    
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.tableView.tableFooterView = [UIView new];
    
    // button
    UIImage *image;
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) {
        image = [UIImage imageNamed:image_navBarLocal];
        self.textView = NSLocalizedString(@"_favorites_", nil);
    } else image = [UIImage imageNamed:image_navBarFavorite];
    UIBarButtonItem *_btn=[[UIBarButtonItem alloc]initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(switchFavoriteLocal)];
    self.navigationItem.rightBarButtonItem=_btn;
    
    [self reloadTable];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // title
    self.title = self.textView;
    
    [self reloadTable];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Effetti Grafici =====
#pragma --------------------------------------------------------------------------------------------

- (void)forcedSwitchFavorite
{
     if ([self.serverUrlLocal isEqualToString:@"favorite"] == NO)
         [self switchFavoriteLocal];
}

- (void)switchFavoriteLocal
{
    UIImage *imageBarButton;
    
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) {
        
        self.textView = NSLocalizedString(@"_local_storage_", nil);
        imageBarButton = [UIImage imageNamed:@"navBarFavorite"];
        
        // img Tab Bar
        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex:1];
        
        item.selectedImage = [UIImage imageNamed:@"tabBarLocal"];
        item.image = [UIImage imageNamed:@"tabBarLocal"];

        self.serverUrlLocal = [CCUtility getDirectoryLocal];
        app.isLocalStorage = true;
        
    } else {
        
        self.textView = NSLocalizedString(@"_favorites_", nil);
        imageBarButton = [UIImage imageNamed:@"navBarLocal"];
        
        // Image Tab Bar
        UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex:1];
        
        item.selectedImage = [UIImage imageNamed:@"tabBarFavorite"];
        item.image = [UIImage imageNamed:@"tabBarFavorite"];

        self.serverUrlLocal = @"favorite";
        app.isLocalStorage = false;
    }
    
    UIBarButtonItem *_btn=[[UIBarButtonItem alloc]initWithImage:imageBarButton style:UIBarButtonItemStylePlain target:self action:@selector(switchFavoriteLocal)];
    self.navigationItem.rightBarButtonItem=_btn;
    
    // init of Navigation Control
    [self.navigationController popToRootViewControllerAnimated:NO];
    
    // refresh
    if ([self.serverUrlLocal isEqualToString:@"favorite"])
        [[NSNotificationCenter defaultCenter] postNotificationName:@"initToHomeCCPreferitiViewController" object:nil];
    else
        [self reloadTable];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource Methods ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    if ([self.serverUrlLocal isEqualToString:@"favorite"] || [self.serverUrlLocal isEqualToString:[CCUtility getDirectoryLocal]]) return YES;
    else return NO;
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView
{
    return 0.0f;
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView
{
    return - self.navigationController.navigationBar.frame.size.height;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) return [UIImage imageNamed:image_brandFavorite];
    else return [UIImage imageNamed:image_brandLocal];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) text = NSLocalizedString(@"_no_files_uploaded_", nil);
    else text = NSLocalizedString(@"_no_files_uploaded_", nil);
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:COLOR_BRAND};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) text = NSLocalizedString(@"_tutorial_favorite_view_", nil);
    else text = NSLocalizedString(@"_tutorial_local_view_", nil);
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== UIDocumentInteractionControllerDelegate =====
#pragma --------------------------------------------------------------------------------------------

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
    // evitiamo il rimando della eventuale photo e/o video
    if ([CCCoreData getCameraUploadActiveAccount:app.activeAccount]) {
        
        [CCCoreData setCameraUploadDatePhoto:[NSDate date]];
        [CCCoreData setCameraUploadDateVideo:[NSDate date]];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Comandi ====
#pragma --------------------------------------------------------------------------------------------

- (void)openModel:(CCMetadata *)metadata
{
    UIViewController *viewController;
    
    if ([metadata.model isEqualToString:@"cartadicredito"])
        viewController = [[CCCartaDiCredito alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
    
    if ([metadata.model isEqualToString:@"bancomat"])
        viewController = [[CCBancomat alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
    
    if ([metadata.model isEqualToString:@"contocorrente"])
        viewController = [[CCContoCorrente alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
    
    if ([metadata.model isEqualToString:@"accountweb"])
        viewController = [[CCAccountWeb alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
    
    if ([metadata.model isEqualToString:@"patenteguida"])
        viewController = [[CCPatenteGuida alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
    
    if ([metadata.model isEqualToString:@"cartaidentita"])
        viewController = [[CCCartaIdentita alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
    
    if ([metadata.model isEqualToString:@"passaporto"])
        viewController = [[CCPassaporto alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
    
    if ([metadata.model isEqualToString:@"note"]) {
        
        viewController = [[CCNote alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:app.isLocalStorage];
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [self presentViewController:navigationController animated:YES completion:nil];
        
    } else {
        
         UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)openWith:(CCMetadata *)metadata
{
    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", self.serverUrlLocal, metadata.fileNamePrint]];
    
    self.docController = [UIDocumentInteractionController interactionControllerWithURL:url];
    
    self.docController.delegate = self;
    
    [self.docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Synchronized favorite =====
#pragma---------------------------------------------------------------------------------------------

- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // error
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(CCMetadata *)metadata
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        [[CCSynchronization sharedSynchronization] verifyChangeMedatas:[[NSArray alloc] initWithObjects:metadata, nil] serverUrl:metadataNet.serverUrl directoryID:metadataNet.directoryID account:app.activeAccount synchronization:NO];
    });
    
    [self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.1];
}

- (void)synchronizedFavorites
{
    if (app.activeAccount == nil || [CCUtility getHomeServerUrlActiveUrl:app.activeUrl typeCloud:app.typeCloud] == nil) return;
    
    NSArray *metadatas = [[NSArray alloc] init];
    
    metadatas = [CCCoreData getFavoriteWithControlZombie:YES activeAccount:app.activeAccount directoryUser:app.directoryUser];
    
    for (CCMetadata *metadata in metadatas) {
        
        NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
        if (serverUrl == nil) continue;
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionReadFile;
        metadataNet.fileName = metadata.fileName;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.serverUrl = serverUrl;
        metadataNet.selector = selectorReadFileFavorite;
        metadataNet.priority = NSOperationQueuePriorityVeryLow;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Swipe Table -> menu =====
#pragma--------------------------------------------------------------------------------------------

// more
- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.serverUrlLocal isEqualToString:@"favorite"] == NO) {
        
        NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
        NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
        
        CCMetadata *metadata = [CCUtility insertFileSystemInMetadata:[dataSource objectAtIndex:indexPath.row] directory:self.serverUrlLocal activeAccount:app.activeAccount cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath];
        
        if (metadata.directory)
            return nil;
        else
            return NSLocalizedString(@"_more_", nil);
        
    } else return nil;
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIImage *iconHeader;
    
    NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
    NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];

    self.metadata = [CCUtility insertFileSystemInMetadata:[dataSource objectAtIndex:indexPath.row] directory:self.serverUrlLocal activeAccount:app.activeAccount cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath];
    
    [self setEditing:NO animated:YES];
    
    AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.view title:nil];
    
    actionSheet.animationDuration = 0.2;
    
    actionSheet.blurRadius = 0.0f;
    actionSheet.blurTintColor = [UIColor colorWithWhite:0.0f alpha:0.50f];
    
    actionSheet.buttonHeight = 50.0;
    actionSheet.cancelButtonHeight = 50.0f;
    actionSheet.separatorHeight = 5.0f;
        
    actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_ENCRYPTED };
    actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_GRAY };
    actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:COLOR_BRAND };
    actionSheet.disableButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:12], NSForegroundColorAttributeName:COLOR_GRAY };
    
    actionSheet.separatorColor = COLOR_SEPARATOR_TABLE;
    actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);

    // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/.%@.ico", self.serverUrlLocal, self.metadata.fileNamePrint]])
        iconHeader = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/.%@.ico", self.serverUrlLocal, self.metadata.fileNamePrint]];
    else
        iconHeader = [UIImage imageNamed:self.metadata.iconName];
    
    [actionSheet addButtonWithTitle: _metadata.fileNamePrint
                              image: iconHeader
                    backgroundColor: COLOR_NAVBAR_IOS7
                             height: 50.0
                               type: AHKActionSheetButtonTypeDisabled
                            handler: nil
    ];
    
    [actionSheet addButtonWithTitle: NSLocalizedString(@"_open_in_", nil)
                              image: [UIImage imageNamed:image_actionSheetOpenIn]
                    backgroundColor: [UIColor whiteColor]
                             height: 50.0
                               type: AHKActionSheetButtonTypeDefault
                            handler: ^(AHKActionSheet *as) {
                                [self performSelector:@selector(openWith:) withObject:self.metadata];
                            }];

    [actionSheet show];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // close swip
    [self setEditing:NO animated:YES];
    
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) {
        
        NSManagedObject *record = [dataSource objectAtIndex:indexPath.row];
        [CCCoreData removeFavoriteFromFileID:[record valueForKey:@"fileID"] activeAccount:app.activeAccount];
    }
    
    if ([self.serverUrlLocal isEqualToString:@"favorite"] == NO) {
        
        NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", self.serverUrlLocal,[dataSource objectAtIndex:indexPath.row]];
        NSString *iconPath = [NSString stringWithFormat:@"%@/.%@.ico", self.serverUrlLocal,[dataSource objectAtIndex:indexPath.row]];
        
        [[NSFileManager defaultManager] removeItemAtPath:fileNamePath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:iconPath error:nil];
    }
    
    [self reloadTable];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (void)initToHome
{
    self.serverUrlLocal = @"favorite";
    self.textView = NSLocalizedString(@"_favorites_", nil);
    
    UIBarButtonItem *_btn=[[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:image_navBarLocal] style:UIBarButtonItemStylePlain target:self action:@selector(switchFavoriteLocal)];
    self.navigationItem.rightBarButtonItem=_btn;
    
    [self reloadTable];
}

- (void)reloadTable
{
    // Datasource
    if ([self.serverUrlLocal isEqualToString:@"favorite"])
        dataSource = (NSMutableArray *)[CCCoreData getFavoriteWithControlZombie:YES activeAccount:app.activeAccount directoryUser:app.directoryUser];
    
    if ([self.serverUrlLocal isEqualToString:@"favorite"] == NO) {
        
        [dataSource removeAllObjects];
        
        NSArray *subpaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.serverUrlLocal error:nil];
        
        for (NSString *subpath in subpaths)
            if (![[subpath lastPathComponent] hasPrefix:@"."]) [dataSource addObject:subpath];
    }
    
    // title
    self.title = self.textView;
    
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [dataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CCCellFavorite *cell = (CCCellFavorite *)[tableView dequeueReusableCellWithIdentifier:@"FavoriteCell" forIndexPath:indexPath];
    
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = COLOR_SELECT_BACKGROUND;
    cell.selectedBackgroundView = selectionColor;

    // i am in favorite
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) {
    
        self.metadata = [dataSource objectAtIndex:indexPath.row];
        cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, self.metadata.fileID]];
    }
    
    // i am in local
    if ([self.serverUrlLocal isEqualToString:@"favorite"] == NO) {
        
        NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
        NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
        
        self.metadata = [CCUtility insertFileSystemInMetadata:[dataSource objectAtIndex:indexPath.row] directory:self.serverUrlLocal activeAccount:app.activeAccount cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath];
        
        cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/.%@.ico", self.serverUrlLocal, self.metadata.fileNamePrint]];
        
        if (!cell.fileImageView.image) {
                        
            UIImage *icon = [CCGraphics createNewImageFrom:self.metadata.fileID directoryUser:self.serverUrlLocal fileNameTo:self.metadata.fileID fileNamePrint:self.metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:self.metadata.typeFile writePreview:NO optimizedFileName:[CCUtility getOptimizedPhoto]];
            
            if (icon) {
                [CCGraphics saveIcoWithFileID:self.metadata.fileNamePrint image:icon writeToFile:[NSString stringWithFormat:@"%@/.%@.ico", self.serverUrlLocal, self.metadata.fileNamePrint] copy:NO move:NO fromPath:nil toPath:nil];
                cell.fileImageView.image = icon;
            }
        }
    }
    
    // color and font
    if (self.metadata.cryptated) {
        cell.labelTitle.textColor = COLOR_ENCRYPTED;
        //nameLabel.font = RalewayLight(13.0f);
        cell.labelInfoFile.textColor = [UIColor blackColor];
        //detailLabel.font = RalewayLight(9.0f);
    } else {
        cell.labelTitle.textColor = COLOR_CLEAR;
        //nameLabel.font = RalewayLight(13.0f);
        cell.labelInfoFile.textColor = [UIColor blackColor];
        //detailLabel.font = RalewayLight(9.0f);
    }

    if (self.metadata.directory) {
        cell.labelInfoFile.text = [CCUtility dateDiff:self.metadata.date];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    // File name
    cell.labelTitle.text = self.metadata.fileNamePrint;
    cell.labelInfoFile.text = @"";
    
    // Immagine del file, se non c'è l'anteprima mettiamo quella standard
    if (cell.fileImageView.image == nil)
        cell.fileImageView.image = [UIImage imageNamed:self.metadata.iconName];
    
    cell.statusImageView.image = nil;
    
    // it's encrypted ???
    if (self.metadata.cryptated && [self.metadata.type isEqualToString:metadataType_model] == NO)
        cell.statusImageView.image = [UIImage imageNamed:image_lock];
    
    // it's in download mode
    if ([self.metadata.session length] > 0 && [self.metadata.session rangeOfString:@"download"].location != NSNotFound)
        cell.statusImageView.image = [UIImage imageNamed:image_attention];
    
    // text and length
    if (self.metadata.directory) {
        
        cell.labelInfoFile.text = [CCUtility dateDiff:self.metadata.date];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else {
        
        NSString *date = [CCUtility dateDiff:self.metadata.date];
        NSString *length = [CCUtility transformedSize:self.metadata.size];
        
        if ([self.metadata.type isEqualToString:metadataType_model])
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", date];
        
        if ([self.metadata.type isEqualToString:metadataType_file] || [self.metadata.type isEqualToString:metadataType_local])
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@, %@", date, length];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
        
    if ([self.serverUrlLocal isEqualToString:@"favorite"]) {
        
        NSManagedObject *record = [dataSource objectAtIndex:indexPath.row];
        self.fileIDPhoto = [record valueForKey:@"fileID"];
        self.directoryIDPhoto = nil;
        self.metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", self.fileIDPhoto, app.activeAccount] context:nil];
    }
    
    if ([self.serverUrlLocal isEqualToString:@"favorite"] == NO) {
        
        NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
        NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
        
        self.metadata = [CCUtility insertFileSystemInMetadata:[dataSource objectAtIndex:indexPath.row] directory:self.serverUrlLocal activeAccount:app.activeAccount cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath];
        self.fileIDPhoto = self.metadata.fileID;
        self.directoryIDPhoto = self.serverUrlLocal;
    }
    
    // if is in download [do not touch]
    if ([self.metadata.session length] > 0 && [self.metadata.session rangeOfString:@"download"].location != NSNotFound) return;
    
    if (([self.metadata.type isEqualToString:metadataType_file] || [self.metadata.type isEqualToString:metadataType_local]) && self.metadata.directory == NO) {
        
        if ([self shouldPerformSegue])
            [self performSegueWithIdentifier:@"segueDetail" sender:self];
    }
    
    if ([self.metadata.type isEqualToString:metadataType_model]) [self openModel:self.metadata];
    
    if (self.metadata.directory) [self performSegueDirectoryWithControlPasscode];
}

-(void)performSegueDirectoryWithControlPasscode
{
    CCFavorite *viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCFavoriteVC"];
    
    viewController.serverUrlLocal = [CCUtility stringAppendServerUrl:self.serverUrlLocal addServerUrl:self.metadata.fileName];
    viewController.textView = self.metadata.fileName;

    [self.navigationController pushViewController:viewController animated:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue
{
    // if i am in background -> exit
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return NO;
    
    // if i am not window -> exit
    if (self.view.window == NO)
        return NO;

    // Collapsed but i am in detail -> exit
    if (self.splitViewController.isCollapsed)
        if (self.detailViewController.isViewLoaded && self.detailViewController.view.window) return NO;
    
    // Video in run -> exit
    if (self.detailViewController.photoBrowser.currentVideoPlayerViewController.isViewLoaded && self.detailViewController.photoBrowser.currentVideoPlayerViewController.view.window) return NO;
    
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id viewController = segue.destinationViewController;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = viewController;
        self.detailViewController = (CCDetail *)nav.topViewController;
    } else {
        self.detailViewController = segue.destinationViewController;
    }
    
    self.detailViewController.metadataDetail = self.metadata;
    
    if (app.isLocalStorage) self.detailViewController.sourceDirectory = sorceDirectoryLocal;
    else self.detailViewController.sourceDirectory = sorceDirectoryFavorite;
    
    self.detailViewController.dateFilterQuery = nil;
    self.detailViewController.isCameraUpload = NO;
    
    [self.detailViewController setTitle:self.metadata.fileNamePrint];
}

@end
