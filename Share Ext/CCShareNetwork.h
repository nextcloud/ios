//
//  CCShareNetwork.h
//  Crypto Cloud / Nextcloud Project
//
//  Created by Marino Faggiana on 13/02/16.
//  Copyright © 2016 TWS. All rights reserved.
//

#import "DropboxSDK.h"

@interface CCShareNetwork : NSObject



+ (DBSession *)sharedDBSession;

@end
