//
//  NCManageDatabase.m
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "NCManageDatabase.h"

@implementation NCManageDatabase

+ (NCManageDatabase *)sharedManageDatabase {
    static NCManageDatabase *sharedManageDatabase;
    @synchronized(self)
    {
        if (!sharedManageDatabase) {
            
            sharedManageDatabase = [NCManageDatabase new];
        }
        return sharedManageDatabase;
    }
}

- (id)init
{
    self = [super init];
    
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:k_capabilitiesGroups];
    
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    
    config.fileURL = [dirGroup URLByAppendingPathComponent:[appDatabaseNextcloud stringByAppendingPathComponent:k_databaseDefault]];
    
    // Set this as the configuration used for the default Realm
    [RLMRealmConfiguration setDefaultConfiguration:config];
    
    return self;
}

- (void)addActivityServer:(OCActivity *)activity account:(NSString *)account
{
    DBActivity *dbActivity = [DBActivity new];
    
    dbActivity.account = account;
    dbActivity.action = @"Activity";
    dbActivity.date = activity.date;
    dbActivity.file = activity.file;
    dbActivity.idActivity = activity.idActivity;
    dbActivity.link = activity.link;
    dbActivity.note = activity.subject;
    dbActivity.type = k_activityTypeInfo;
    dbActivity.verbose = k_activityVerboseDefault;

    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    [realm addObject:dbActivity];
    [realm commitWriteTransaction];
}

@end
