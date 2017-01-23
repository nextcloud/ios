//
//  OCXMLNotificationsParser.h
//  ownCloud iOS library
//
//  Created by Marino Faggiana on 23/01/17.
//  Copyright © 2017 ownCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCNotifications.h"

@interface OCXMLNotificationsParser : NSObject <NSXMLParserDelegate> {

    NSMutableString *_xmlChars;
    NSMutableDictionary *_xmlBucket;
    NSMutableArray *_notificationsList;
    OCNotifications *_currentNotifications;
    BOOL isNotFirstFileOfList;
}

@property(nonatomic,strong) NSMutableArray *notificationsList;
@property(nonatomic,strong) OCNotifications *currentNotifications;

- (void)initParserWithData: (NSData*)data;


@end
