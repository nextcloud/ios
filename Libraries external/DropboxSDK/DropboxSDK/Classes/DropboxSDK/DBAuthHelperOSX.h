//
//  DBAuthHelperOSX.h
//  DropboxSDK
//
//  Created by Brian Smith on 3/26/12.
//  Copyright (c) 2012 Dropbox, Inc. All rights reserved.
//

#import "DBRestClient+OSX.h"
#import "DBSession.h"

// You should register for this notification from the screen that allows you to link your Dropbox and update the state
// of your "Link Dropbox" button based on the value of -[DBAuthHelperOSX isLoading]
extern NSString *DBAuthHelperOSXStateChangedNotification;

@interface DBAuthHelperOSX : NSObject {
	BOOL loading;
	DBRestClient *restClient;
}

+ (DBAuthHelperOSX *)sharedHelper;

// Call this any time the user clicks on your "Link Dropbox" button
- (void)authenticate;

// If loading, you should disable your "Link Dropbox" button and optionally show an activity indicator
@property (nonatomic, readonly, getter=isLoading) BOOL loading;


@end
