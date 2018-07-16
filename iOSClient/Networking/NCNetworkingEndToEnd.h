//
//  NCNetworkingEndToEnd.h
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 29/10/17.
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

#import <Foundation/Foundation.h>
#import "CCNetworking.h"

@interface NCNetworkingEndToEnd : NSObject

+ (NCNetworkingEndToEnd *)sharedManager;

// ===== End-to-End Encryption =====

- (void)createEndToEndFolder:(NSString *)folderPathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url encrypted:(BOOL)encrypted fileID:(NSString **)fileID error:(NSError **)error;

- (NSError *)markEndToEndFolderEncryptedOnServerUrl:(NSString *)serverUrl fileID:(NSString *)fileID user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;
- (NSError *)deletemarkEndToEndFolderEncryptedOnServerUrl:(NSString *)serverUrl fileID:(NSString *)fileID user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;

- (NSError *)getEndToEndMetadata:(NSString **)metadata fileID:(NSString *)fileID user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;
- (NSError *)deleteEndToEndMetadataOnServerUrl:(NSString *)serverUrl fileID:(NSString *)fileID unlock:(BOOL)unlock user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;
- (NSError *)storeEndToEndMetadata:(NSString *)metadata serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID unlock:(BOOL)unlock user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;
- (NSError *)updateEndToEndMetadata:(NSString *)metadata serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID unlock:(BOOL)unlock user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;

- (NSError *)lockEndToEndFolderEncryptedOnServerUrl:(NSString *)serverUrl fileID:(NSString *)fileID user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;
- (NSError *)unlockEndToEndFolderEncryptedOnServerUrl:(NSString *)serverUrl fileID:(NSString *)fileID token:(NSString  *)token user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;

- (NSError *)sendEndToEndMetadataOnServerUrl:(NSString *)serverUrl fileNameRename:(NSString *)fileName fileNameNewRename:(NSString *)fileNameNew account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;
- (NSError *)rebuildAndSendEndToEndMetadataOnServerUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;

@end
