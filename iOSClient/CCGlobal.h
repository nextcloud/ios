//
//  CCGlobal.h
//  Nextcloud
//
//  Created by Marino Faggiana on 13/10/14.
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

#import <UIKit/UIKit.h>

//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//dispatch_async(dispatch_get_main_queue(), ^{
//dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {

//#if TARGET_OS_SIMULATOR
//#endif

// Constants to identify the different permissions of a file
#define k_permission_shared                             @"S"
#define k_permission_can_share                          @"R"
#define k_permission_mounted                            @"M"
#define k_permission_file_can_write                     @"W"
#define k_permission_can_create_file                    @"C"
#define k_permission_can_create_folder                  @"K"
#define k_permission_can_delete                         @"D"
#define k_permission_can_rename                         @"N"
#define k_permission_can_move                           @"V"

// Selector
#define selectorDownloadFile                            @"downloadFile"
#define selectorDownloadAllFile                         @"downloadAllFile"
#define selectorReadFile                                @"readFile"
#define selectorListingFavorite                         @"listingFavorite"
#define selectorLoadFileView                            @"loadFileView"
#define selectorLoadFileQuickLook                       @"loadFileQuickLook"
#define selectorLoadCopy                                @"loadCopy"
#define selectorLoadOffline                             @"loadOffline"
#define selectorOpenIn                                  @"openIn"
#define selectorUploadAutoUpload                        @"uploadAutoUpload"
#define selectorUploadAutoUploadAll                     @"uploadAutoUploadAll"
#define selectorUploadFile                              @"uploadFile"
#define selectorSaveAlbum                               @"saveAlbum"

// Filename Mask and Type
#define k_keyFileNameMask                               @"fileNameMask"
#define k_keyFileNameType                               @"fileNameType"
#define k_keyFileNameAutoUploadMask                     @"fileNameAutoUploadMask"
#define k_keyFileNameAutoUploadType                     @"fileNameAutoUploadType"
#define k_keyFileNameOriginal                           @"fileNameOriginal"
#define k_keyFileNameOriginalAutoUpload                 @"fileNameOriginalAutoUpload"

//Share permission
//permissions - (int) 1 = read; 2 = update; 4 = create; 8 = delete; 16 = share; 31 = all (default: 31, for public shares: 1)
#define k_read_share_permission                         1
#define k_update_share_permission                       2
#define k_create_share_permission                       4
#define k_delete_share_permission                       8
#define k_share_share_permission                        16

#define k_min_file_share_permission                     1
#define k_max_file_share_permission                     19
#define k_min_folder_share_permission                   1
#define k_max_folder_share_permission                   31
#define k_default_file_remote_share_permission_no_support_share_option      3
#define k_default_folder_remote_share_permission_no_support_share_option    15
