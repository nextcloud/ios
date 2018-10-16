//
//  CCLogin.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 09/04/15.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCLogin.h"
#import "AppDelegate.h"
#import "CCUtility.h"
#import "NCBridgeSwift.h"
#import "NCNetworkingEndToEnd.h"

@interface CCLogin () <CCLoginDelegateWeb>
{
    AppDelegate *appDelegate;
    UIView *rootView;
}
@end

@implementation CCLogin

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    // Background color
    self.view.backgroundColor = [NCBrandColor sharedInstance].customer;
    
    // Image Brand
    self.imageBrand.image = [UIImage imageNamed:@"loginLogo"];
    
    // Annulla
    [self.annulla setTitle:NSLocalizedString(@"_cancel_", nil) forState:UIControlStateNormal];
    self.annulla.tintColor = [NCBrandColor sharedInstance].customerText;
    
    // Base URL
    _imageBaseUrl.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"loginURL"] multiplier:2 color:[NCBrandColor sharedInstance].customerText];
    _baseUrl.textColor = [NCBrandColor sharedInstance].customerText;
    _baseUrl.tintColor = [NCBrandColor sharedInstance].customerText;
    _baseUrl.placeholder = NSLocalizedString(@"_login_url_", nil);
    [_baseUrl setValue:[UIColor lightGrayColor] forKeyPath:@"_placeholderLabel.textColor"];
    [self.baseUrl setFont:[UIFont systemFontOfSize:13]];
    [self.baseUrl setDelegate:self];

    // Loading Base Utl GIF
    self.loadingBaseUrl.image = [UIImage animatedImageWithAnimatedGIFURL:[[NSBundle mainBundle] URLForResource: @"loading@2x" withExtension:@"gif"]];
    self.loadingBaseUrl.hidden = YES;
    
    // User
    _imageUser.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"loginUser"] multiplier:2 color:[NCBrandColor sharedInstance].customerText];
    _user.textColor = [NCBrandColor sharedInstance].customerText;
    _user.tintColor = [NCBrandColor sharedInstance].customerText;
    _user.placeholder = NSLocalizedString(@"_username_", nil);
    [_user setValue:[UIColor lightGrayColor] forKeyPath:@"_placeholderLabel.textColor"];
    [self.user setFont:[UIFont systemFontOfSize:13]];
    [self.user setDelegate:self];

    // Password
    _imagePassword.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"loginPassword"] multiplier:2 color:[NCBrandColor sharedInstance].customerText];
    _password.textColor = [NCBrandColor sharedInstance].customerText;
    _password.tintColor = [NCBrandColor sharedInstance].customerText;
    _password.placeholder = NSLocalizedString(@"_password_", nil);
    [_password setValue:[UIColor lightGrayColor] forKeyPath:@"_placeholderLabel.textColor"];
    [self.password setFont:[UIFont systemFontOfSize:13]];
    [self.password setDelegate:self];

    // Login
    [self.login setTitle:[NSLocalizedString(@"_login_", nil) uppercaseString] forState:UIControlStateNormal] ;
    self.login.backgroundColor = [NCBrandColor sharedInstance].customerText;
    self.login.tintColor = [UIColor blackColor];
//    self.login.layer.cornerRadius = 3;
//    self.login.clipsToBounds = YES;
    
    // Type view
    [self.loginTypeView setTitle:NSLocalizedString(@"_traditional_login_", nil) forState:UIControlStateNormal];
    [self.loginTypeView setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];

   
    if (self.view.frame.size.width == ([[UIScreen mainScreen] bounds].size.width*([[UIScreen mainScreen] bounds].size.width<[[UIScreen mainScreen] bounds].size.height))+([[UIScreen mainScreen] bounds].size.height*([[UIScreen mainScreen] bounds].size.width>[[UIScreen mainScreen] bounds].size.height))) {
        
        // Portrait
        self.loginTypeView.hidden = NO;
        
    } else {
        
        // Landscape
        if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
            self.loginTypeView.hidden = YES;
        }
    }
    
    // Brand
    if ([NCBrandOptions sharedInstance].disable_request_login_url) {
        _baseUrl.text = [NCBrandOptions sharedInstance].loginBaseUrl;
        _imageBaseUrl.hidden = YES;
        _baseUrl.hidden = YES;
    }

    if (_loginType == k_login_Add ) {
        // Login Flow ?
        _imageUser.hidden = YES;
        _user.hidden = YES;
        _imagePassword.hidden = YES;
        _password.hidden = YES;
    }
    
    if (_loginType == k_login_Add_Forced) {
        _annulla.hidden = YES;
        // Login Flow ?
        _imageUser.hidden = YES;
        _user.hidden = YES;
        _imagePassword.hidden = YES;
        _password.hidden = YES;
    }
    
    if (_loginType == k_login_Modify_Password) {
        _baseUrl.text = appDelegate.activeUrl;
        _baseUrl.userInteractionEnabled = NO;
        _baseUrl.textColor = [UIColor lightGrayColor];
        _user.text = appDelegate.activeUser;
        _user.userInteractionEnabled = NO;
        _user.textColor = [UIColor lightGrayColor];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // verify URL
    if (_loginType == k_login_Modify_Password && [self.baseUrl.text length] > 0)
        [self testUrl];
}

// E' apparsa
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

//
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        if (self.view.frame.size.width == ([[UIScreen mainScreen] bounds].size.width*([[UIScreen mainScreen] bounds].size.width<[[UIScreen mainScreen] bounds].size.height))+([[UIScreen mainScreen] bounds].size.height*([[UIScreen mainScreen] bounds].size.width>[[UIScreen mainScreen] bounds].size.height))) {
            
            // Portrait
            self.loginTypeView.hidden = NO;
            
        } else {
            
            // Landscape
            if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
                self.loginTypeView.hidden = YES;
            }
        }
    }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Chech Server URL ==
#pragma --------------------------------------------------------------------------------------------

- (void)testUrl
{
    self.login.enabled = NO;
    self.loadingBaseUrl.hidden = NO;
    
    // Check whether baseUrl contain protocol. If not add https:// by default.
    if(![self.baseUrl.text hasPrefix:@"https"] && ![self.baseUrl.text hasPrefix:@"http"]) {
      self.baseUrl.text = [NSString stringWithFormat:@"https://%@",self.baseUrl.text];
    }
    
    // Remove trailing slash
    if ([self.baseUrl.text hasSuffix:@"/"])
        self.baseUrl.text = [self.baseUrl.text substringToIndex:[self.baseUrl.text length] - 1];
    
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:self metadataNet:nil withUser:@"" withUserID:@"" withPassword:@"" withUrl:nil];
    [ocNetworking serverStatus:self.baseUrl.text success:^(NSString *serverProductName, NSInteger versionMajor, NSInteger versionMicro, NSInteger versionMinor) {
        
        self.loadingBaseUrl.hidden = YES;
        self.login.enabled = YES;
        
        // Login Flow
        if (_user.hidden && _password.hidden && versionMajor >= k_flow_version_available) {
            
            appDelegate.activeLoginWeb = [CCLoginWeb new];
            appDelegate.activeLoginWeb.loginType = _loginType;
            appDelegate.activeLoginWeb.delegate = self;
            appDelegate.activeLoginWeb.urlBase = self.baseUrl.text;
            
            [appDelegate.activeLoginWeb open:self];
        }
        
        // NO Login Flow available
        if (versionMajor < k_flow_version_available) {
            
            [self.loginTypeView setHidden:YES];
            
            _imageUser.hidden = NO;
            _user.hidden = NO;
            _imagePassword.hidden = NO;
            _password.hidden = NO;
            
            [_user becomeFirstResponder];
        }
        
    } failure:^(NSString *message, NSInteger errorCode) {
        
        self.loadingBaseUrl.hidden = YES;
        self.login.enabled = YES;
        
        if (errorCode == NSURLErrorServerCertificateUntrusted) {
            
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:message viewController:self delegate:self];
            
        } else {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_connection_error_", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
            
            [alertController addAction:okAction];
            [self presentViewController:alertController animated:YES completion:nil];
        }
        
    }];
}

- (void)trustedCerticateAccepted
{
    NSLog(@"[LOG] Certificate trusted");
}

- (void)trustedCerticateDenied
{
    if (_loginType == k_login_Modify_Password)
        [self handleAnnulla:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == TextField ==
#pragma --------------------------------------------------------------------------------------------

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.password) {
        self.toggleVisiblePassword.hidden = NO;
        self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].customerText};
    }
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.password) {
        self.toggleVisiblePassword.hidden = YES;
        self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].customerText};
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === CCLoginDelegateWeb ===
#pragma --------------------------------------------------------------------------------------------

- (void)loginSuccess:(NSInteger)loginType
{
    [self.delegate loginSuccess:_loginType];
}

- (void)webDismiss
{   
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Action ==
#pragma --------------------------------------------------------------------------------------------

- (IBAction)handlebaseUrlchange:(id)sender
{
    if ([self.baseUrl.text length] > 0 && !_user.hidden && !_password.hidden)
        [self performSelector:@selector(testUrl) withObject:nil];
}

- (IBAction)handleButtonLogin:(id)sender
{
    if ([self.baseUrl.text length] > 0 && _user.hidden && _password.hidden) {
        [self testUrl];
        return;
    }
    
    if ([self.baseUrl.text length] > 0 && [self.user.text length] && [self.password.text length]) {
        
        // remove last char if /
        if ([[self.baseUrl.text substringFromIndex:[self.baseUrl.text length] - 1] isEqualToString:@"/"])
            self.baseUrl.text = [self.baseUrl.text substringToIndex:[self.baseUrl.text length] - 1];
        
        NSString *url = self.baseUrl.text;
        NSString *user = self.user.text;
        NSString *password = self.password.text;
        OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:self metadataNet:nil withUser:user withUserID:user withPassword:password withUrl:nil];

        self.login.enabled = NO;
        self.loadingBaseUrl.hidden = NO;

        [ocNetworking checkServer:[NSString stringWithFormat:@"%@%@", url, k_webDAV] success:^{
            
            // account
            NSString *account = [NSString stringWithFormat:@"%@ %@", user, url];
            
            if (_loginType == k_login_Modify_Password) {
                
                // Change Password
                tableAccount *tbAccount = [[NCManageDatabase sharedInstance] setAccountPassword:account password:password];
                
                // Setting appDelegate active account
                [appDelegate settingActiveAccount:tbAccount.account activeUrl:tbAccount.url activeUser:tbAccount.user activeUserID:tbAccount.userID activePassword:tbAccount.password];
                
                [self.delegate loginSuccess:_loginType];
                
                [self dismissViewControllerAnimated:YES completion:nil];
                
            } else {

                // STOP Intro
                [CCUtility setIntro:YES];
                
                // LOGOUT
                [appDelegate unsubscribingNextcloudServerPushNotification];
                
                [[NCManageDatabase sharedInstance] deleteAccount:account];
                [[NCManageDatabase sharedInstance] addAccount:account url:url user:user password:password loginFlow:false];
                
                tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:account];
                
                // Setting appDelegate active account
                [appDelegate settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activeUserID:tableAccount.userID activePassword:tableAccount.password];
                
                [self.delegate loginSuccess:_loginType];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self dismissViewControllerAnimated:YES completion:nil];
                });
            }
            
        } failure:^(NSString *message, NSInteger errorCode) {
            
            if (errorCode != NSURLErrorServerCertificateUntrusted) {
                
                NSString *messageAlert = [NSString stringWithFormat:@"%@.\n%@", NSLocalizedString(@"_not_possible_connect_to_server_", nil), message];
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:messageAlert preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            
            self.login.enabled = YES;
            self.loadingBaseUrl.hidden = YES;
        }];

    }
}

- (IBAction)handleAnnulla:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)handleToggleVisiblePassword:(id)sender
{
    NSString *currentPassword = self.password.text;
    
    self.password.secureTextEntry = ! self.password.secureTextEntry;
    
    self.password.text = @"";
    self.password.text = currentPassword;
    self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName: [NCBrandColor sharedInstance].customerText};
}

- (IBAction)handleLoginTypeView:(id)sender
{
    if (_user.hidden && _password.hidden) {
        
        _imageUser.hidden = NO;
        _user.hidden = NO;
        _imagePassword.hidden = NO;
        _password.hidden = NO;
        
        [self.loginTypeView setTitle:NSLocalizedString(@"_web_login_", nil) forState:UIControlStateNormal];
        
    } else {
        
        _imageUser.hidden = YES;
        _user.hidden = YES;
        _imagePassword.hidden = YES;
        _password.hidden = YES;
        
        [self.loginTypeView setTitle:NSLocalizedString(@"_traditional_login_", nil) forState:UIControlStateNormal];
    }
}

-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    // The pinnning check
    if ([[CCCertificate sharedManager] checkTrustedChallenge:challenge]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

@end
