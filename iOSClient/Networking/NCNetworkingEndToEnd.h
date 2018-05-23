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

- (NSError *)createEndToEndFolder:(NSString *)folderPathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url encrypted:(BOOL)encrypted fileID:(NSString **)fileID;

- (NSError *)markEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl;
- (NSError *)deletemarkEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl;

- (NSError *)getEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString **)metadata;
- (NSError *)deleteEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID unlock:(BOOL)unlock;
- (NSError *)storeEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID metadata:(NSString *)metadata unlock:(BOOL)unlock;
- (NSError *)updateEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID metadata:(NSString *)metadata unlock:(BOOL)unlock;

- (NSError *)lockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID;
- (NSError *)unlockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID token:(NSString  *)token;

- (NSError *)sendEndToEndMetadataOnServerUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileNameRename:(NSString *)fileName fileNameNewRename:(NSString *)fileNameNew;
- (NSError *)rebuildAndSendEndToEndMetadataOnServerUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url;

@end
