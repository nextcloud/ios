//
//  NCManageDatabase.h
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCDatabase.h"
#import "OCActivity.h"

@interface NCManageDatabase : NSObject

+ (NCManageDatabase *)sharedManageDatabase;

//
- (void)addActivityServer:(OCActivity *)activity account:(NSString *)account;

@end
