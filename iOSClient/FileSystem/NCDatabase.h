//
//  NCDatabase.h
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <Realm/Realm.h>

@interface DBActivity : RLMObject
    
    @property NSString *account;
    @property NSString *action;
    @property NSDate *date;
    @property NSString *file;
    @property NSString *fileID;
    @property long long idActivity;
    @property NSString *link;
    @property NSString *note;
    @property NSString *selector;
    @property NSString *type;
    @property BOOL verbose;

@end

// This protocol enables typed collections. i.e.:
// RLMArray<NCDatabase *><NCDatabase>
RLM_ARRAY_TYPE(DBActivity)
