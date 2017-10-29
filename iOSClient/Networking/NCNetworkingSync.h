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

+ (CCNetworking *)sharedNetworking;

+ (NSString *)lockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString *)token delegate:(UIViewController *)delegate;

@end
