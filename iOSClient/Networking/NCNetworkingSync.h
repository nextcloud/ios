//
//  NCNetworkingSync.h
//  Nextcloud
//
//  Created by Marino Faggiana on 29/10/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CCNetworking.h"

@interface NCNetworkingSync : NSObject

+ (NCNetworkingSync *)sharedManager;

- (NSString *)lockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID token:(NSString *)token;
- (NSError *)unlockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID token:(NSString *)token;

- (NSError *)markEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID;
- (NSError *)deletemarkEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID;
@end
