//
//  NCPushNotification.m
//  VideoCalls
//
//  Created by Ivan Sein on 24.11.17.
//  Copyright © 2017 struktur AG. All rights reserved.
//

#import "NCPushNotification.h"

@implementation NCPushNotification

NSString * const kNCPNAppKey            = @"app";
NSString * const kNCPNTypeKey           = @"type";
NSString * const kNCPNSubjectKey        = @"subject";
NSString * const kNCPNIdKey             = @"id";
NSString * const kNCPNTypeCallKey       = @"call";
NSString * const kNCPNTypeRoomKey       = @"room";
NSString * const kNCPNTypeChatKey       = @"chat";
NSString * const kNCPNTypeCommentKey    = @"comment";

+ (instancetype)pushNotificationFromDecryptedString:(NSString *)decryptedString
{
    if (!decryptedString) {
        return nil;
    }
    
    NSData *data = [decryptedString dataUsingEncoding:NSUTF8StringEncoding];
    id jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    NCPushNotification *pushNotification = [NCPushNotification new];
    pushNotification.app = [jsonDict objectForKey:kNCPNAppKey];
    pushNotification.subject = [jsonDict objectForKey:kNCPNSubjectKey];
    pushNotification.pnId = [[jsonDict objectForKey:kNCPNIdKey] integerValue];
    
    NSString *type = [jsonDict objectForKey:kNCPNTypeKey];
    pushNotification.type = NCPushNotificationTypeUnknown;
    
    if ([type isEqualToString:kNCPNTypeCallKey]) {
        pushNotification.type = NCPushNotificationTypeCall;
    } else if ([type isEqualToString:kNCPNTypeRoomKey]) {
        pushNotification.type = NCPushNotificationTypeRoom;
    } else if ([type isEqualToString:kNCPNTypeChatKey]) {
        pushNotification.type = NCPushNotificationTypeChat;
    } else if ([type isEqualToString:kNCPNTypeCommentKey]) {
        pushNotification.type = NCPushNotificationTypeComment;
    } else {
        pushNotification.type = NCPushNotificationTypeUnknown;
    }
    
    return pushNotification;
}

- (NSString *)bodyForRemoteAlerts
{
    switch (_type) {
        case NCPushNotificationTypeCall:
            return [NSString stringWithFormat:@"📞 %@", _subject];
            break;
        case NCPushNotificationTypeRoom:
            return [NSString stringWithFormat:@"🔔 %@", _subject];
            break;
        case NCPushNotificationTypeChat:
            return [NSString stringWithFormat:@"💬 %@", _subject];
            break;
        case NCPushNotificationTypeComment:
            return [NSString stringWithFormat:@"💬 %@", _subject];
            break;
        case NCPushNotificationTypeUnknown:
            return _subject;
            break;
    }
}

@end
