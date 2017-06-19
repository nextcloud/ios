//
//  CCQuickActions.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 30/06/16.
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

#import "CCQuickActions.h"
#import "CTAssetCheckmark.h"
#import "CCHud.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "NCBridgeSwift.h"

@interface CCQuickActions ()
{
    BOOL _cryptated;
    
    long _numTaskUploadInProgress;
    CTAssetsPickerController *_picker;
    CCMove *_move;
    CCMain *_mainVC;
    NSMutableArray *_assets;
}
@end

@implementation CCQuickActions

+ (instancetype)quickActionsManager
{
    static dispatch_once_t once;
    static CCQuickActions *__quickActionsManager;
    
    dispatch_once(&once, ^{
        __quickActionsManager = [[CCQuickActions alloc] init];
    });
    
    return __quickActionsManager;
}

- (instancetype)init
{
    if (self = [super init]) {
        
        _cryptated = NO;
        _numTaskUploadInProgress = 0;
    }
    
    return self;
}

- (void)startQuickActionsEncrypted:(BOOL)cryptated viewController:(UITableViewController *)viewController
{
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND session CONTAINS 'upload' AND (sessionTaskIdentifier >= 0 OR sessionTaskIdentifierPlist >= 0)", app.activeAccount] sorted:nil ascending:NO];
    
    _numTaskUploadInProgress = [metadatas count];
    
    _cryptated = cryptated;
    _mainVC = (CCMain *)viewController;
    
    [self openAssetsPickerController];
}

- (void)closeAll
{
    if (_picker)
        [_picker dismissViewControllerAnimated:NO completion:nil];
    
    if (_move)
        [_move dismissViewControllerAnimated:NO completion:nil];
    
    _cryptated = NO;
    _numTaskUploadInProgress = 0;
    
    _picker = nil;
    _move = nil;
    _assets = nil;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Assets Picker =====
#pragma --------------------------------------------------------------------------------------------

- (void)openAssetsPickerController
{
    CTAssetCheckmark *checkmark = [CTAssetCheckmark appearance];
    checkmark.tintColor = [NCBrandColor sharedInstance].brand;
    [checkmark setMargin:0.0 forVerticalEdge:NSLayoutAttributeRight horizontalEdge:NSLayoutAttributeTop];
    
    UINavigationBar *navBar = [UINavigationBar appearanceWhenContainedIn:[CTAssetsPickerController class], nil];
    [app aspectNavigationControllerBar:navBar encrypted:NO online:YES hidden:NO];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // init picker
            _picker = [[CTAssetsPickerController alloc] init];
            
            // set delegate
            _picker.delegate = self;
            
            // to present picker as a form sheet in iPad
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                _picker.modalPresentationStyle = UIModalPresentationFormSheet;
            
            // present picker
            [_mainVC presentViewController:_picker animated:YES completion:nil];
        });
    }];
}

- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldSelectAsset:(PHAsset *)asset
{
    __block float imageSize;
    
    PHImageRequestOptions *option = [PHImageRequestOptions new];
    option.synchronous = YES;
    
    // self Asset
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
        imageSize = imageData.length;
    }];
    
    // Add selected Asset
    for (PHAsset *asset in picker.selectedAssets) {
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            imageSize = imageData.length + imageSize;
        }];
    }
    
    if (picker.selectedAssets.count >= (k_pickerControllerMax - _numTaskUploadInProgress)) {
        
        [app messageNotification:@"_info_" description:@"_limited_dimension_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        
        return NO;
    }
    
    return YES;
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSArray *)assets
{
    [picker dismissViewControllerAnimated:YES completion:^{
                
        _assets = [[NSMutableArray alloc] initWithArray:assets];
        
        if ([assets count] > 0)
            [self moveOpenWindow:nil];
    }];
}

- (void)assetsPickerControllerDidCancel:(CTAssetsPickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Move =====
#pragma --------------------------------------------------------------------------------------------

- (void)moveServerUrlTo:(NSString *)serverUrlTo title:(NSString *)title
{    
    [_mainVC uploadFileAsset:_assets serverUrl:serverUrlTo cryptated:_cryptated useSubFolder:NO session:k_upload_session];
}

- (void)moveOpenWindow:(NSArray *)indexPaths
{
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMove"];
    
    _move = (CCMove *)navigationController.topViewController;
    
    if (_cryptated)
        _move.move.title = NSLocalizedString(@"_upload_encrypted_file_", nil);
    else
        _move.move.title = NSLocalizedString(@"_upload_file_", nil);

    _move.delegate = self;
    _move.tintColor = [NCBrandColor sharedInstance].navigationBarText;
    _move.barTintColor = [NCBrandColor sharedInstance].brand;
    _move.tintColorTitle = [NCBrandColor sharedInstance].navigationBarText;
    _move.networkingOperationQueue = app.netQueue;
    
    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    
    [_mainVC presentViewController:navigationController animated:YES completion:nil];
}

@end
