//
//  CCPeekPop.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 26/08/16.
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
    
    self.fileName.text = self.metadata.fileNameView;
    
    if (self.metadata.hasPreview) {
        
        if ([CCUtility fileProviderStorageIconExists:self.metadata.fileID fileNameView:self.metadata.fileNameView]) {
            
            self.imagePreview.image = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:self.metadata.fileID fileNameView:self.metadata.fileNameView]];
        
            self.imagePreview.contentMode = UIViewContentModeScaleToFill;
            self.preferredContentSize = CGSizeMake(self.imagePreview.image.size.width, self.imagePreview.image.size.height);
            
        } else {
            
            NSURL *url = [[NSBundle mainBundle] URLForResource:@"loading" withExtension:@"gif"];
            self.imagePreview.image = [UIImage animatedImageWithAnimatedGIFURL:url];
            
            self.imagePreview.contentMode = UIViewContentModeCenter;
            
            [self downloadThumbnail];
        }
        
    } else {
        
        if (self.metadata.directory) {
            
            self.imagePreview.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement];
            
            self.imagePreview.contentMode = UIViewContentModeScaleToFill;
            self.preferredContentSize = CGSizeMake(self.imagePreview.image.size.width, self.imagePreview.image.size.height);
            
        } else {
            
            if (self.metadata.iconName.length > 0) {
                self.imagePreview.image = [UIImage imageNamed:self.metadata.iconName];
            } else {
                self.imagePreview.image = [UIImage imageNamed:@"file"];
            }
            
            self.imagePreview.contentMode = UIViewContentModeCenter;
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    UIPreviewAction *previewAction1 = [UIPreviewAction actionWithTitle:NSLocalizedString(@"_open_in_", nil) style:UIPreviewActionStyleDefault handler:^(UIPreviewAction *action,  UIViewController *previewViewController){
        
        self.metadata.session = k_download_session;
        self.metadata.sessionError = @"";
        self.metadata.sessionSelector = selectorOpenIn;
        self.metadata.status = k_metadataStatusWaitDownload;
            
        // Add Metadata for Download
        (void)[[NCManageDatabase sharedInstance] addMetadata:_metadata];
        [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
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
    
    [[OCNetworking sharedManager] downloadPreviewWithAccount:appDelegate.activeAccount metadata:_metadata withWidth:width andHeight:height completion:^(NSString *account, UIImage *image, NSString *message, NSInteger errorCode) {
     
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            
            self.imagePreview.image = image;
            
            self.imagePreview.contentMode = UIViewContentModeScaleToFill;
            self.preferredContentSize = CGSizeMake(self.imagePreview.image.size.width, self.imagePreview.image.size.height);
            
        } else {
            
            if (errorCode != 0)  {
                [appDelegate messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
            } else {
                NSLog(@"[LOG] It has been changed user during networking process, error.");
            }
            
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

@end
