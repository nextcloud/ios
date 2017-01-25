//
//  JSAlertView.m
//  JSAlertView
//
//  Created by Jitendra Singh on 10/12/16.
//  Copyright © 2016 Jitendra Singh. All rights reserved.
//

#import "JSAlertView.h"

@interface JSAlertView ()

@property (nonatomic, copy) void(^completionBlock)(NSInteger buttonIndex, NSString *buttonTitle);
@property (nonatomic, copy) void(^confirmationBlock)(BOOL accepted);
@property (nonatomic, strong) UIWindow *thisAlertWindow;
@property (nonatomic, strong) NSMutableArray *allAlertWindows;

@end

@implementation JSAlertView

+ (instancetype)sharedInstance {
    static dispatch_once_t predicate;
    static JSAlertView *instance = nil;
    dispatch_once(&predicate, ^{
        instance = [[self alloc] init];
        [instance initalization];
    });
    return instance;
}

- (void)initalization
{
    // do write all initalization code here
    self.allAlertWindows = [NSMutableArray arrayWithCapacity:0];
    
}

+ (instancetype)alert:(NSString*)message
{
    return [self alert:message withTitle:nil buttons:@[@"Ok"] withCompletionHandler:nil];
}
+ (instancetype)confirm:(NSString*)message withCompletionHandler:(void(^)(BOOL accepted))completionHandler
{
    return [self confirm:message withTitle:nil withCompletionHandler:completionHandler];
}

+ (instancetype)confirm:(NSString*)message withTitle:(NSString*)title  withCompletionHandler:(void(^)(BOOL accepted))completionHandler
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    
    JSAlertView *alert = [JSAlertView alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* noButton = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
        if (completionHandler) {
            completionHandler(NO);
        }
    }];
    [alert addAction:noButton];
    
    UIAlertAction* yesButton = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
        if (completionHandler) {
            completionHandler(YES);
        }
    }];
    [alert addAction:yesButton];
    
    [alert show];
    
    return alert;
#else
    JSAlertView *alert = [[JSAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
    __weak __typeof__(alert) alert_weak_ = (alert);
    [alert setDelgate:alert_weak_];
    
    [alert addButtonWithTitle:@"No"];
    [alert addButtonWithTitle:@"Yes"];
    
    alert.confirmationBlock = completionHandler;
    [alert show];
    return alert;
#endif
}

+ (instancetype)alert:(NSString*)message withTitle:(NSString*)title buttons:(NSArray*)buttonTitles withCompletionHandler:(void(^)(NSInteger buttonIndex, NSString *buttonTitle))completionHandler
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    
    JSAlertView *alert = [JSAlertView alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    for (NSString *btnTitle in buttonTitles) {
        UIAlertAction* button = [UIAlertAction actionWithTitle:btnTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [alert dismissViewControllerAnimated:YES completion:nil];
            if (completionHandler) {
                completionHandler([buttonTitles indexOfObject:btnTitle], btnTitle);
            }
        }];
        [alert addAction:button];
    }
    [alert show];
    
    return alert;
#else
    JSAlertView *alert = [[JSAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
    __weak __typeof__(alert) alert_weak_ = (alert);
    [alert setDelgate:alert_weak_];
    __block NSInteger index = 0;
    for (NSString *btnTitle in buttonTitles) {
        [alert addButtonWithTitle:btnTitle];
    }
    alert.completionBlock = completionHandler;
    [alert show];
    return alert;
#endif
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (self.completionBlock) {
        self.completionBlock(buttonIndex, [alertView buttonTitleAtIndex:buttonIndex]);
    }
    else if (self.confirmationBlock) {
        self.confirmationBlock(!(buttonIndex == 0));
    }
}



/***********************************************************************
 *
 *  Following methods will be used for iOS 8 or later for UIAlertController
 *
 ***********************************************************************/

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0

- (void)show {
    [self show:YES];
}

- (void)show:(BOOL)animated {
    
    //create a new window for the alert
    self.thisAlertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.thisAlertWindow.rootViewController = [[UIViewController alloc] init];
    
    // set this window on top in stack
    UIWindow *topWindow = [UIApplication sharedApplication].windows.lastObject;
    self.thisAlertWindow.windowLevel = topWindow.windowLevel + 1;
    
    // make it visible and show alert
    [self.thisAlertWindow makeKeyAndVisible];
    [self.thisAlertWindow.rootViewController presentViewController:self animated:animated completion:nil];
    
    // set alpha 0.0 for last alert to make it transparent, this will give feel of single alert displayed on screen
    [[JSAlertView sharedInstance].allAlertWindows.lastObject setAlpha:0.0];
    [[JSAlertView sharedInstance].allAlertWindows addObject:self.thisAlertWindow];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // remove this window from stack
    [[JSAlertView sharedInstance].allAlertWindows removeObject:self.thisAlertWindow];
    // set alpha 1.0 for last alert to make it appear
    [UIView animateWithDuration:0.3 animations:^{
        [[JSAlertView sharedInstance].allAlertWindows.lastObject setAlpha:1.0];
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // once the alert is disappeared set window property to nil, else it will create retain cycle
    self.thisAlertWindow.hidden = YES;
    self.thisAlertWindow = nil;
}


#endif
@end
