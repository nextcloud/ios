//
//  JSAlertView.h
//  JSAlertView
//
//  Created by Jitendra Singh on 10/12/16.
//  Copyright © 2016 Jitendra Singh. All rights reserved.
//

#import <UIKit/UIKit.h>
#define ALERT(x) [JSAlertView alert:x]

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
@interface JSAlertView : UIAlertController
#else
@interface JSAlertView : UIAlertView
#endif
// Displays simple alert message (no title) with 'Ok' button
+ (instancetype)alert:(NSString*)message;

// Displays message (no title) with 'Yes' and 'No' button. It can be used to display confirmirmation alert.
+ (instancetype)confirm:(NSString*)message withCompletionHandler:(void(^)(BOOL accepted))completionHandler;

// Same as previous one with addition option to show title
+ (instancetype)confirm:(NSString*)message withTitle:(NSString*)title  withCompletionHandler:(void(^)(BOOL accepted))completionHandler;

// Standard menthod for displaying alert, fully customizable.
+ (instancetype)alert:(NSString*)message withTitle:(NSString*)title buttons:(NSArray*)buttonTitles withCompletionHandler:(void(^)(NSInteger buttonIndex, NSString *buttonTitle))completionHandler;

// Nextcloud
+ (BOOL)isOpenAlertWindows;

@end
