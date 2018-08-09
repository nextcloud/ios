//
//  CCPeekPop.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 26/08/16.
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

#import "CCPeekPop.h"

#import "AppDelegate.h"
#import "CCGraphics.h"
#import "NCBridgeSwift.h"

@interface CCPeekPop ()
{
    AppDelegate *appDelegate;
}
@end

@implementation CCPeekPop

- (void)setMetadata:(tableMetadata *)newMetadata
{
    if (_metadata != newMetadata)
        _metadata = newMetadata;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    self.preferredContentSize = CGSizeMake(self.view.frame.size.width - 50, self.view.frame.size.width - 50);
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"loading" withExtension:@"gif"];
    
    _imagePreview.image = [UIImage animatedImageWithAnimatedGIFURL:url];
    
    _imagePreview.contentMode = UIViewContentModeCenter;

    [self downloadThumbnail];
}

// E' apparso

-(void) viewDidAppear:(BOOL)animated{
    
    [super viewDidAppear:animated];    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    //__weak typeof(self) weakSelf = self;
    
    UIPreviewAction *previewAction1 = [UIPreviewAction actionWithTitle:NSLocalizedString(@"_open_in_", nil) style:UIPreviewActionStyleDefault handler:^(UIPreviewAction *action,  UIViewController *previewViewController){
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
        
        if (serverUrl) {
            
            _metadata.session = k_download_session;
            _metadata.sessionError = @"";
            _metadata.sessionSelector = selectorOpenIn;
            _metadata.status = k_metadataStatusWaitDownload;
            
            // Add Metadata for Download
            (void)[[NCManageDatabase sharedInstance] addMetadata:_metadata];
            [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
        }
    }];
    
    return @[previewAction1];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnail
{
    CGFloat width = [[NCUtility sharedInstance] getScreenWidthForPreview];
    CGFloat height = [[NCUtility sharedInstance] getScreenHeightForPreview];
    
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];
    
    [ocNetworking downloadPreviewWithMetadata:_metadata serverUrl:appDelegate.activeMain.serverUrl withWidth:width andHeight:height completion:^(NSString *message, NSInteger errorCode) {
        
        if (errorCode == 0) {
            
            UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", [CCUtility getDirectoryProviderStorageFileID:_metadata.fileID], _metadata.fileNameView]];
            
            _imagePreview.image = image;
            _imagePreview.contentMode = UIViewContentModeScaleToFill;
            
            self.preferredContentSize = CGSizeMake(image.size.width, image.size.height);
            
        } else {
            
            [appDelegate messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

@end
