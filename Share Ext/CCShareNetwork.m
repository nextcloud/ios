//
//  CCShareNetwork.m
//  Crypto Cloud / Nextcloud Project
//
//  Created by Marino Faggiana on 13/02/16.
//  Copyright © 2016 TWS. All rights reserved.
//

#import "CCShareNetwork.h"

@implementation CCShareNetwork

- (id)init
{
    self =[super init];
    
    if (self) {
       
            }
    return self;
}

+ (DBSession*)sharedDBSession
{
    static DBSession* sharedDBSession= nil;
    if (sharedDBSession == nil) {
        
        NSString *appKey = appKeyCryptoCloud;
        NSString *appSecret = appSecretCryptoCloud;
      
        sharedDBSession = [[DBSession alloc] initWithAppKey:appKey appSecret:appSecret root:kDBRootDropbox];
    }
    return sharedDBSession;
}

@end
