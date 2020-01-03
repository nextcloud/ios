//
//  CCDetail.m
//  Nextcloud
//
//  Created by Marino Faggiana on 16/01/15.
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

#import "CCDetail.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "NCUchardet.h"
#import "NCBridgeSwift.h"

#import "NCBridgeSwift.h"

#define TOOLBAR_HEIGHT 49.0f

#define alertRequestPasswordPDF 1

@interface CCDetail () <NCTextDelegate, UIDocumentInteractionControllerDelegate>
{
    AppDelegate *appDelegate;
    
    UIDocumentInteractionController *docController;
    
    UIBarButtonItem *buttonModifyTxt;
    UIBarButtonItem *buttonShare;
    UIBarButtonItem *buttonDelete;
    
    NSInteger indexNowVisible;
    NSString *ocIdNowVisible;
    
    NSString *fileNameExtension;
}
@end

@implementation CCDetail

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];

        self.metadataDetail = [[tableMetadata alloc] init];
        self.photos = [[NSMutableArray alloc] init];
        self.photoDataSource = [NSMutableArray new];
        indexNowVisible = -1;
        ocIdNowVisible = nil;

        appDelegate.activeDetail = self;
    }
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(insertGeocoderLocation:) name:@"insertGeocoderLocation" object:nil];
        
    [self changeTheming];
    
    // Open View
    if ([self.metadataDetail.fileNameView length] > 0 || [self.metadataDetail.serverUrl length] > 0 || [self.metadataDetail.ocId length] > 0) {        
        [self viewFile];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.tabBarController.tabBar.hidden = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    self.navigationController.navigationBarHidden = NO;
    self.tabBarController.tabBar.hidden = NO;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // If AVPlayer in play -> Stop
    if (appDelegate.player != nil && appDelegate.player.rate != 0) {
        [appDelegate.player pause];
    }
    
    // remove Observer AVPlayer
    if (self.isMediaObserver) {
        self.isMediaObserver = NO;
        @try{
            [[NCViewerMedia sharedInstance] removeObserver];
        }@catch(id anException) { }
    }
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:nil collectionView:nil form:false];
    
    if (self.toolbar) {
        self.toolbar.barTintColor = NCBrandColor.sharedInstance.tabBar;
        self.toolbar.tintColor = NCBrandColor.sharedInstance.brandElement;
    }
    
    // Logo
    self.imageBackground.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"logo"] multiplier:2 color:[NCBrandColor.sharedInstance.brand colorWithAlphaComponent:0.4]];

    // reload image
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_image]) {
        
        self.edgesForExtendedLayout = UIRectEdgeAll;
        [self viewImage];
    }
}

- (void)changeToDisplayMode
{
    if (_readerPDFViewController) {
        [self.readerPDFViewController updateContentViews];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View File  =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewFile
{
    // Remove all subview except ..
    //for (UIView *view in self.view.superview.subviews) {
    //    NSInteger tag = view.tag;
    //}
    
    // Title
    self.navigationController.navigationBar.topItem.title = _metadataDetail.fileNameView;

    // verifico se esiste l'icona e se la posso creare
    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:self.metadataDetail.ocId fileNameView:self.metadataDetail.fileNameView]] == NO) {
        [CCGraphics createNewImageFrom:self.metadataDetail.fileNameView ocId:self.metadataDetail.ocId extension:[self.metadataDetail.fileNameView pathExtension] filterGrayScale:NO typeFile:self.metadataDetail.typeFile writeImage:YES];
    }
    
    // remove Observer AVPlayer
    if (self.isMediaObserver) {
        self.isMediaObserver = NO;
        [[NCViewerMedia sharedInstance] removeObserver];
    }
    
    // IMAGE
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_image]) {
        
        self.edgesForExtendedLayout = UIRectEdgeAll;
        [self viewImage];
    }
    
    // AUDIO VIDEO
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_video] || [self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_audio]) {
        
        self.edgesForExtendedLayout = UIRectEdgeAll;
        [self createToolbar];
        [[NCViewerMedia sharedInstance] viewMedia:self.metadataDetail detail:self];
    }
    
    // DOCUMENT - INTERNAL VIEWER
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_document] && [self.selectorDetail isEqualToString:selectorLoadFileInternalView]) {
        
        self.edgesForExtendedLayout = UIRectEdgeBottom;
        [self createToolbar];
        [[NCViewerDocumentWeb sharedInstance] viewDocumentWebAt:self.metadataDetail detail:self];
        
        return;
    }
    
    // DOCUMENT
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_document]) {
                
        fileNameExtension = [[self.metadataDetail.fileNameView pathExtension] uppercaseString];
        
        if ([fileNameExtension isEqualToString:@"PDF"]) {
            
            self.edgesForExtendedLayout = UIRectEdgeBottom;
            [self createToolbar];
            [self viewPDF:@""];
            
            return;
        }
        
        // Direct Editing NextcloudText
        if ([[NCUtility sharedInstance] isDirectEditing:self.metadataDetail] != nil && appDelegate.reachability.isReachable) {
            
            NSString *editor = [[NCUtility sharedInstance] isDirectEditing:self.metadataDetail];
            if ([editor.lowercaseString isEqualToString:@"nextcloud text"]) {
            
                if([self.metadataDetail.url isEqualToString:@""]) {
                    
                    [[NCUtility sharedInstance] startActivityIndicatorWithView:self.view bottom:0];
                    
                    NSString *fileNamePath = [CCUtility returnFileNamePathFromFileName:self.metadataDetail.fileName serverUrl:self.metadataDetail.serverUrl activeUrl:appDelegate.activeUrl];
                    [[NCCommunication sharedInstance] NCTextOpenFileWithUrlString:appDelegate.activeUrl fileNamePath:fileNamePath editor: @"text" account:self.metadataDetail.account completionHandler:^(NSString *account, NSString *url, NSInteger errorCode, NSString *errorMessage) {
                        
                        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
                            
                            self.nextcloudText = [[NCViewerNextcloudText alloc] initWithFrame:self.view.bounds configuration:[WKWebViewConfiguration new]];
                            [self.view addSubview:self.nextcloudText];
                            [self.nextcloudText viewNextcloudTextAt:url detail:self metadata:self.metadataDetail];
                            
                        } else {
                            
                            if (errorCode != 0) {
                                [[NCContentPresenter shared] messageNotification:@"_error_" description:errorMessage delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
                            } else {
                                NSLog(@"[LOG] It has been changed user during networking process, error.");
                            }
                            
                            [self.navigationController popViewControllerAnimated:YES];
                        }
                    }];
                    
                } else {
                    
                    self.nextcloudText = [[NCViewerNextcloudText alloc] initWithFrame:self.view.bounds configuration:[WKWebViewConfiguration new]];
                    [self.view addSubview:self.nextcloudText];
                    [self.nextcloudText viewNextcloudTextAt:self.metadataDetail.url detail:self metadata:self.metadataDetail];
                }
            }
            
            return;
        }
        
        // RichDocument
        if ([[NCUtility sharedInstance] isRichDocument:self.metadataDetail] && appDelegate.reachability.isReachable) {
            
            [[NCUtility sharedInstance] startActivityIndicatorWithView:self.view bottom:0];
            
            if ([self.metadataDetail.url isEqualToString:@""]) {
                [[OCNetworking sharedManager] createLinkRichdocumentsWithAccount:appDelegate.activeAccount fileId:self.metadataDetail.fileId completion:^(NSString *account, NSString *link, NSString *message, NSInteger errorCode) {
                    
                    if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
                        
                        self.richDocument = [[NCViewerRichdocument alloc] initWithFrame:self.view.bounds configuration:[WKWebViewConfiguration new]];
                        [self.view addSubview:self.richDocument];
                        [self.richDocument viewRichDocumentAt:link detail:self metadata:self.metadataDetail];

                    } else {
                        
                        [[NCUtility sharedInstance] stopActivityIndicator];
                        
                        if (errorCode != 0) {
                            [[NCContentPresenter shared] messageNotification:@"_error_" description:message delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
                        } else {
                            NSLog(@"[LOG] It has been changed user during networking process, error.");
                        }
                        
                        [self.navigationController popViewControllerAnimated:YES];
                    }
                }];
                
            } else {
                
                self.richDocument = [[NCViewerRichdocument alloc] initWithFrame:self.view.bounds configuration:[WKWebViewConfiguration new]];
                [self.view addSubview:self.richDocument];
                [self.richDocument viewRichDocumentAt:self.metadataDetail.url detail:self metadata:self.metadataDetail];
            }
            
            return;
        }
        
        self.edgesForExtendedLayout = UIRectEdgeBottom;
        [self createToolbar];
        [[NCViewerDocumentWeb sharedInstance] viewDocumentWebAt:self.metadataDetail detail:self];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Toolbar  =====
#pragma --------------------------------------------------------------------------------------------

- (void)createToolbar
{
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
    
    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem *fixedSpaceMini = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpaceMini.width = 25;
    
    buttonModifyTxt = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"actionSheetModify"] style:UIBarButtonItemStylePlain target:self action:@selector(modifyTxtButtonPressed:)];
    if (![NCBrandOptions sharedInstance].disable_openin_file) {
        self.buttonAction = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"openFile"] style:UIBarButtonItemStylePlain target:self action:@selector(actionButtonPressed:)];
    }
    buttonShare  = [[UIBarButtonItem alloc] initWithImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"share"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] style:UIBarButtonItemStylePlain target:self action:@selector(shareButtonPressed:)];
    buttonDelete = [[UIBarButtonItem alloc] initWithImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] style:UIBarButtonItemStylePlain target:self action:@selector(deleteButtonPressed:)];
    
    if ([CCUtility isDocumentModifiableExtension:fileNameExtension]) {
        if ([CCUtility isFolderEncrypted:_metadataDetail.serverUrl account:appDelegate.activeAccount]) // E2EE
            [self.toolbar setItems:[NSArray arrayWithObjects: buttonModifyTxt, flexible, buttonDelete, fixedSpaceMini, self.buttonAction,  nil]];
        else
            [self.toolbar setItems:[NSArray arrayWithObjects: buttonModifyTxt, flexible, buttonDelete, fixedSpaceMini, buttonShare, fixedSpaceMini, self.buttonAction,  nil]];
    } else {
        if ([CCUtility isFolderEncrypted:_metadataDetail.serverUrl account:appDelegate.activeAccount]) // E2EE
            [self.toolbar setItems:[NSArray arrayWithObjects: flexible, buttonDelete, fixedSpaceMini, self.buttonAction,  nil]];
        else
            [self.toolbar setItems:[NSArray arrayWithObjects: flexible, buttonDelete, fixedSpaceMini, buttonShare, fixedSpaceMini, self.buttonAction,  nil]];
    }
    
    [self.toolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    self.toolbar.barTintColor = NCBrandColor.sharedInstance.tabBar;
    self.toolbar.tintColor = NCBrandColor.sharedInstance.brandElement;

    [self.view addSubview:self.toolbar];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View Image =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewImage
{
    self.photoBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    indexNowVisible = -1;
    ocIdNowVisible = nil;
    
    [self.photos removeAllObjects];
    
    // if not images, exit
    if ([self.photoDataSource count] == 0)
        return;

    NSUInteger index = 0;
    for (tableMetadata *metadata in self.photoDataSource) {
        
        // start from here ?
        if (self.metadataDetail.ocId && [metadata.ocId isEqualToString:self.metadataDetail.ocId])
            [self.photoBrowser setCurrentPhotoIndex:index];
        
        [self.photos addObject:[MWPhoto photoWithImage:nil]];
        
        // add directory
        index++;
    }
    
    // PhotoBrowser
    if ([NCBrandOptions sharedInstance].disable_openin_file) {
        self.photoBrowser.displayActionButton = NO;
    } else {
        self.photoBrowser.displayActionButton = YES;
    }
    self.photoBrowser.displayDeleteButton = YES;
    if ([CCUtility isFolderEncrypted:_metadataDetail.serverUrl account:appDelegate.activeAccount]) // E2EE
        self.photoBrowser.displayShareButton = NO;
    else
        self.photoBrowser.displayShareButton = YES;
    self.photoBrowser.displayNavArrows = YES;
    self.photoBrowser.displaySelectionButtons = NO;
    self.photoBrowser.alwaysShowControls = NO;
    self.photoBrowser.zoomPhotosToFill = NO;
    self.photoBrowser.autoPlayOnAppear = NO;
    self.photoBrowser.delayToHideElements = 15;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        self.photoBrowser.enableSwipeToDismiss = NO;
    
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        
        [self addChildViewController:self.photoBrowser];
        [self.view addSubview:self.photoBrowser.view];
        [self.photoBrowser didMoveToParentViewController:self];
        
    } else {
        
        [self.navigationController pushViewController:self.photoBrowser animated:NO];
    }
    
    self.navigationController.navigationBar.topItem.title = _metadataDetail.fileNameView;
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser
{
    return [self.photoDataSource count];
}

- (NSString *)photoBrowser:(MWPhotoBrowser *)photoBrowser titleForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    
    NSString *titleDir = metadata.fileNameView;
    self.title = titleDir;
    
    return titleDir;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    
    indexNowVisible = index;
    ocIdNowVisible = metadata.ocId;
    
    photoBrowser.toolbar.hidden = NO;
    
    // Download image ?
    if (metadata) {
        
        NSInteger status;
        tableMetadata *metadataDB = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
        if (metadataDB) {
            status = metadataDB.status;
        } else {
            status = k_metadataStatusNormal;
        }
        
        if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView] == NO && status == k_metadataStatusNormal) {
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]] == NO && metadata.hasPreview) {
                
                [CCGraphics addImageToTitle:NSLocalizedString(@"_...loading..._", nil) colorTitle:NCBrandColor.sharedInstance.brandText imageTitle:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"load"] multiplier:2 color:NCBrandColor.sharedInstance.brandText] imageRight:NO navigationItem:self.navigationItem];
                
                CGFloat width = [[NCUtility sharedInstance] getScreenWidthForPreview];
                CGFloat height = [[NCUtility sharedInstance] getScreenHeightForPreview];

                [[OCNetworking sharedManager] downloadPreviewWithAccount:appDelegate.activeAccount metadata:metadata withWidth:width andHeight:height completion:^(NSString *account, UIImage *image, NSString *message, NSInteger errorCode) {

                    self.navigationItem.titleView = nil;
                    self.title = metadata.fileNameView;
                    
                    if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
                        [self.photoBrowser reloadData];
                    }
                }];
            } else {
                [self downloadPhotoBrowser:metadata];
            }
        }
    }
    
    // Title
    if (metadata)
        self.title = metadata.fileNameView;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index
{
    UIImage *image;

    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    
    if (index < self.photos.count) {
        
        if (metadata.ocId) {
            
            UIImage *imagePreview = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]];
//            if (!imagePreview) imagePreview = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file_photo"] multiplier:3 color:[NCBrandColor.sharedInstance icon]];
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image]) {
                
                NSString *fileImage = [CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView];
                NSString *ext = [CCUtility getExtension:metadata.fileNameView];
                
                if ([ext isEqualToString:@"GIF"]) image = [UIImage animatedImageWithAnimatedGIFURL:[NSURL fileURLWithPath:fileImage]];
                else image = [UIImage imageWithContentsOfFile:fileImage];
                
                if (image) {
                    
                    MWPhoto *photo = [MWPhoto photoWithImage:image];
                    
                    // Location ??
                    [self setLocationCaptionPhoto:photo ocId:metadata.ocId];
                    
                    [self.photos replaceObjectAtIndex:index withObject:photo];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        if (imagePreview)
                            [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) {
                
                if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
                    
                    NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView]];
                    
                    MWPhoto *video = [MWPhoto photoWithImage:[CCGraphics thumbnailImageForVideo:url atTime:1.0]];
                    video.videoURL = url;
                    
                    [self.photos replaceObjectAtIndex:index withObject:video];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        if (imagePreview)
                            [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_audio]) {
                
                if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
                    
                    MWPhoto *audio;
                    UIImage *audioImage;
                    
                    NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView]];
                    
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]]) {
                        audioImage = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]];
                    } else {
                        audioImage = [UIImage imageNamed:@"notaMusic"]; //[CCGraphics scaleImage:[UIImage imageNamed:@"notaMusic"] toSize:CGSizeMake(200, 200) isAspectRation:YES];
                    }
                    
                    audio = [MWPhoto photoWithImage:audioImage];
                    audio.videoURL = url;
                    [self.photos replaceObjectAtIndex:index withObject:audio];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        if (imagePreview)
                            [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
        }
        
        // energy saving memory
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            int iPrev = (int)index - 2;
            if (iPrev >= 0) {
                if ([self.photos objectAtIndex:iPrev] != nil)
                    [self.photos replaceObjectAtIndex:iPrev withObject:[MWPhoto photoWithImage:nil]];
            }
        
            int iNext = (int)index + 2;
            if (iNext < _photos.count) {
                if ([self.photos objectAtIndex:iNext] != nil)
                    [self.photos replaceObjectAtIndex:iNext withObject:[MWPhoto photoWithImage:nil]];
            }
        });
        
        return [self.photos objectAtIndex:index];
    }
    
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    if (metadata == nil) return;

    docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView]]];
    
    docController.delegate = self;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [docController presentOptionsMenuFromRect:photoBrowser.view.frame inView:photoBrowser.view animated:YES];
    
    [docController presentOptionsMenuFromBarButtonItem:photoBrowser.actionButton animated:YES];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser shareButtonPressedForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    [[NCMainCommon sharedInstance] openShareWithViewController:self metadata:metadata indexPage:2];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButtonPressedForPhotoAtIndex:(NSUInteger)index deleteButton:(UIBarButtonItem *)deleteButton
{
    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    if (metadata == nil || [CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView] == NO) {        
        [[NCContentPresenter shared] messageNotification:@"_info_" description:@"_file_not_found_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [self deleteFile:metadata];
                                                       }]];

    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = deleteButton;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self.parentViewController presentViewController:alertController animated:YES completion:NULL];
}

- (void)photoBrowserDidFinishPresentation:(MWPhotoBrowser *)photoBrowser
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)downloadPhotoBrowserSuccessFailure:(tableMetadata *)metadata selector:(NSString *)selector errorCode:(NSInteger)errorCode
{
    // if a message for a directory of these
    if (![metadata.ocId isEqualToString:ocIdNowVisible])
        return;
 
    // Title
    self.navigationItem.titleView = nil;
    self.title = metadata.fileNameView;
    
    if (errorCode == 0) {
        
        // verifico se esiste l'icona e se la posso creare
        if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]] == NO) {
            [CCGraphics createNewImageFrom:metadata.fileNameView ocId:metadata.ocId extension:[metadata.fileNameView pathExtension] filterGrayScale:NO typeFile:metadata.typeFile writeImage:YES];
        }
        
        [self.photoBrowser reloadData];

    } else {
        [[NCContentPresenter shared] messageNotification:@"_download_selected_files_" description:@"_error_download_photobrowser_" delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
        
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)downloadPhotoBrowser:(tableMetadata *)metadata
{
    tableMetadata *metadataForDownload = [[NCManageDatabase sharedInstance] initNewMetadata:metadata];
    
    metadataForDownload.session = k_download_session;
    metadataForDownload.sessionError = @"";
    metadataForDownload.sessionSelector = selectorLoadViewImage;
    metadataForDownload.status = k_metadataStatusWaitDownload;
        
    // Add Metadata for Download
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadataForDownload];
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadata.serverUrl ocId:metadataForDownload.ocId action:k_action_MOD];
    
    [appDelegate startLoadAutoDownloadUpload];

    [CCGraphics addImageToTitle:NSLocalizedString(@"_...loading..._", nil) colorTitle:NCBrandColor.sharedInstance.brandText imageTitle:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"load"] multiplier:2 color:NCBrandColor.sharedInstance.brandText] imageRight:NO navigationItem:self.navigationItem];
}

- (void)insertGeocoderLocation:(NSNotification *)notification
{
    if (notification.userInfo.count == 0)
        return;
    
    NSString *ocId = [[notification.userInfo allKeys] objectAtIndex:0];
    //NSDate *date = [[notification.userInfo allValues] objectAtIndex:0];
 
    // test [Chrash V 1.14,15]
    if (indexNowVisible >= [self.photos count])
        return;
    
    if ([ocId isEqualToString:ocIdNowVisible]) {
            
        MWPhoto *photo = [self.photos objectAtIndex:indexNowVisible];
            
        [self setLocationCaptionPhoto:photo ocId:ocId];
        
        [self.photoBrowser reloadData];
    }
}

- (void)setLocationCaptionPhoto:(MWPhoto *)photo ocId:(NSString *)ocId
{
    tableLocalFile *localFile;

    // read Geocoder
    localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
    
    if ([localFile.exifLatitude doubleValue] != 0 || [localFile.exifLongitude doubleValue] != 0) {
        
        // Fix BUG Geo latitude & longitude
        if ([localFile.exifLatitude doubleValue] == 9999 || [localFile.exifLongitude doubleValue] == 9999) {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
            if (metadata) {
                [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata];
            }
        }
        
        [[CCExifGeo sharedInstance] setGeocoderEtag:ocId exifDate:localFile.exifDate latitude:localFile.exifLatitude longitude:localFile.exifLongitude];
        
        localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
        
        if ([localFile.exifLatitude floatValue] != 0 || [localFile.exifLongitude floatValue] != 0) {
                        
            NSString *location = [[NCManageDatabase sharedInstance] getLocationFromGeoLatitude:localFile.exifLatitude longitude:localFile.exifLongitude];
            
            if ([localFile.exifDate isEqualToDate:[NSDate distantPast]] == NO && location) {
                
                NSString *localizedDateTime = [NSDateFormatter localizedStringFromDate:localFile.exifDate dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
                
                photo.caption = [NSString stringWithFormat:NSLocalizedString(@"%@\n%@", nil), localizedDateTime, location];
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  View PDF =====
#pragma --------------------------------------------------------------------------------------------

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
    
    [[alertView textFieldAtIndex:0] resignFirstResponder];
    
    if (alertView.tag == alertRequestPasswordPDF) [self performSelector:@selector(viewPDF:) withObject:[alertView textFieldAtIndex:0].text afterDelay:0.3];
}

- (void)viewPDF:(NSString *)password
{
    // remove cache PDF
    NSString *filePlistReader = [NSString stringWithFormat:@"%@/%@.plist", [CCUtility getDirectoryReaderMetadata], self.metadataDetail.fileNameView.stringByDeletingPathExtension];
    [CCUtility removeFileAtPath:filePlistReader];
    
    NSString *fileNamePath = [CCUtility getDirectoryProviderStorageOcId:self.metadataDetail.ocId fileNameView:self.metadataDetail.fileNameView];
    
    if ([CCUtility fileProviderStorageExists:self.metadataDetail.ocId fileNameView:self.metadataDetail.fileNameView] == NO) {
        
        // read file error
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)[NSURL fileURLWithPath:fileNamePath]);
    
    if (pdf) {
        
        // Encrypted
        if (CGPDFDocumentIsEncrypted(pdf) == YES) {
            
            // Try a blank password first, per Apple's Quartz PDF example
            if (CGPDFDocumentUnlockWithPassword(pdf, "") == YES) {
                
                // blank password
                [self readerPDF:fileNamePath password:@""];
                
            } else {
                
                if ([password length] == 0) {
                    
                    // password request
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_insert_password_pfd_",nil) message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                    [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
                    alertView.tag = alertRequestPasswordPDF;
                    [alertView show];
                    
                } else {
                    
                    const char *key = [password UTF8String];
                    
                    // failure
                    if (CGPDFDocumentUnlockWithPassword(pdf, key) == NO) {
                        
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_password_pdf_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                        
                        [alertController addAction:okAction];
                        [self presentViewController:alertController animated:YES completion:nil];
                        
                    } else {
                        
                        // pdf with password
                        [self readerPDF:fileNamePath password:password];
                    }
                }
            }
            
        } else{
            
            // No password
            [self readerPDF:fileNamePath password:@""];
        }
        
    } else {
        
        // read file error
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)readerPDF:(NSString *)fileName password:(NSString *)password
{
    ReaderDocument *documentPDF = [ReaderDocument withDocumentFilePath:fileName password:password];
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    if (documentPDF != nil) {
        
        self.readerPDFViewController = [[ReaderViewController alloc] initWithReaderDocument:documentPDF];
        self.readerPDFViewController.delegate = self;
        self.readerPDFViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom);
        [self.readerPDFViewController updateContentViews];

        [self addChildViewController:self.readerPDFViewController];
        [self.view addSubview:self.readerPDFViewController.view];
        [self.readerPDFViewController didMoveToParentViewController:self];
        
    } else {

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)handleSingleTapReader
{
    UILayoutGuide *layoutGuide;
    CGFloat safeAreaTop = 0;
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        layoutGuide = [UIApplication sharedApplication].delegate.window.safeAreaLayoutGuide;
        safeAreaTop = [UIApplication sharedApplication].delegate.window.safeAreaInsets.top;
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    self.navigationController.navigationBarHidden = !self.navigationController.navigationBarHidden;
    self.toolbar.hidden = !self.toolbar.isHidden;
    
    if (self.toolbar.isHidden) {
        self.readerPDFViewController.view.frame = CGRectMake(0, safeAreaTop, self.view.bounds.size.width, self.view.bounds.size.height - safeAreaTop - safeAreaBottom);
    } else {
        self.readerPDFViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom);
    }
    [self.readerPDFViewController updateContentViews];
}

- (void)handleSwipeUpDown
{
    // REMOVE IT'S UNUSABLE
    /*
    self.navigationController.navigationBarHidden = false;  // iOS App is unusable after swipe up or down with PDF in fullscreen #526

    [self removeAllView];
    [self.navigationController popViewControllerAnimated:YES];
    */
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFile:(tableMetadata *)metadata
{
    tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND e2eEncrypted == 1 AND serverUrl == %@", appDelegate.activeAccount, metadata.serverUrl]];
    
    [[NCMainCommon sharedInstance ] deleteFileWithMetadatas:[[NSArray alloc] initWithObjects:metadata, nil] e2ee:tableDirectory.e2eEncrypted serverUrl:tableDirectory.serverUrl folderocId:tableDirectory.ocId completion:^(NSInteger errorCode, NSString *message) {
        
        if (errorCode == 0) {
            
            // reload data source
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:tableDirectory.serverUrl ocId:metadata.ocId action:k_action_DEL];
            
            // Not image
            if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_image] == NO) {
            
                // exit
                [self.navigationController popViewControllerAnimated:YES];
            
            } else {
                
                for (NSUInteger index=0; index < [self.photoDataSource count] && _photoBrowser; index++ ) {
                    
                    tableMetadata *metadataTemp = [self.photoDataSource objectAtIndex:index];
                    
                    if ([metadata isInvalidated] || [metadataTemp.ocId isEqualToString:metadata.ocId]) {
                        
                        [self.photoDataSource removeObjectAtIndex:index];
                        [self.photos removeObjectAtIndex:index];
                        [self.photoBrowser reloadData];
                        
                        // exit
                        if ([self.photoDataSource count] == 0) {
                            [self.navigationController popViewControllerAnimated:YES];
                        }
                    }
                }
            }
        } else {
            NSLog(@"[LOG] DeleteFileOrFolder failure error %d, %@", (int)errorCode, message);
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== ButtonPressed =====
#pragma --------------------------------------------------------------------------------------------

- (void)dismissTextView
{
    if (self.webView) {
        
        NSString *fileNamePath = [NSTemporaryDirectory() stringByAppendingString:self.metadataDetail.fileNameView];
        
        [[NSFileManager defaultManager] removeItemAtPath:fileNamePath error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:[CCUtility getDirectoryProviderStorageOcId:self.metadataDetail.ocId fileNameView:self.metadataDetail.fileNameView] toPath:fileNamePath error:nil];
        
        [self.webView reload];
    }
}

- (void)modifyTxtButtonPressed:(UIBarButtonItem *)sender
{
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", self.metadataDetail.ocId]];
    if (metadata) {
        
        UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"NCText" bundle:nil] instantiateViewControllerWithIdentifier:@"NCText"];
        
        NCText *viewController = (NCText *)navigationController.topViewController;
        
        viewController.metadata = metadata;
        viewController.delegate = self;
        
        navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
        navigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)actionButtonPressed:(UIBarButtonItem *)sender
{
    if ([self.metadataDetail.fileNameView length] == 0) return;
    
    NSString *filePath = [CCUtility getDirectoryProviderStorageOcId:self.metadataDetail.ocId fileNameView:self.metadataDetail.fileNameView];

    docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];

    docController.delegate = self;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
    else
        [docController presentOptionsMenuFromBarButtonItem:sender animated:YES];
}

- (void)shareButtonPressed:(UIBarButtonItem *)sender
{
    [[NCMainCommon sharedInstance] openShareWithViewController:self metadata:self.metadataDetail indexPage:2];
}

- (void)deleteButtonPressed:(UIBarButtonItem *)sender
{
    if ([self.metadataDetail.fileNameView length] == 0) return;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [self deleteFile:self.metadataDetail];
                                                       }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [alertController dismissViewControllerAnimated:YES completion:nil];
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = buttonDelete;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];

    [self presentViewController:alertController animated:YES completion:NULL];
}

@end
