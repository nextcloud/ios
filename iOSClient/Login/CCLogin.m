//
//  CCLogin.m
//  Nextcloud
//
//  Created by Marino Faggiana on 09/04/15.
//  Copyright (c) 2015 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

@interface CCLogin () <NCLoginQRCodeDelegate>
{
    AppDelegate *appDelegate;
    UIView *rootView;
    UIColor *textColor;
    UIColor *textColorOpponent;
    UIBarButtonItem *cancelButton;
}
@end

@implementation CCLogin

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    Ivar ivar =  class_getInstanceVariable([UITextField class], "_placeholderLabel");

    // Background color
    self.view.backgroundColor = NCBrandColor.sharedInstance.customer;
    
    // Text Color
    BOOL isTooLight = NCBrandColor.sharedInstance.customer.isTooLight;
    BOOL isTooDark = NCBrandColor.sharedInstance.customer.isTooDark;
    if (isTooLight) {
        textColor = [UIColor blackColor];
        textColorOpponent = [UIColor whiteColor];
    } else if (isTooDark) {
        textColor = [UIColor whiteColor];
        textColorOpponent = [UIColor blackColor];
    } else {
        textColor = [UIColor whiteColor];
        textColorOpponent = [UIColor blackColor];
    }
    
    // Image Brand
    self.imageBrand.image = [UIImage imageNamed:@"logo"];
    
    // Annulla
    cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(handleAnnulla:)];
    cancelButton.tintColor = textColor;
    
    // Base URL
    _imageBaseUrl.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"loginURL"] multiplier:2 color:textColor];
    _baseUrl.textColor = textColor;
    _baseUrl.tintColor = textColor;
    _baseUrl.placeholder = NSLocalizedString(@"_login_url_", nil);
    UILabel *baseUrlPlaceholder = object_getIvar(_baseUrl, ivar);
    baseUrlPlaceholder.textColor = [textColor colorWithAlphaComponent:0.5];
    [self.baseUrl setFont:[UIFont systemFontOfSize:13]];
    [self.baseUrl setDelegate:self];
    
    // User
    _imageUser.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"loginUser"] multiplier:2 color:textColor];
    _user.textColor = textColor;
    _user.tintColor = textColor;
    _user.placeholder = NSLocalizedString(@"_username_", nil);
    UILabel *userPlaceholder = object_getIvar(_user, ivar);
    userPlaceholder.textColor = [textColor colorWithAlphaComponent:0.5];

    [self.user setFont:[UIFont systemFontOfSize:13]];
    [self.user setDelegate:self];

    // Password
    _imagePassword.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"loginPassword"] multiplier:2 color:textColor];
    _password.textColor = textColor;
    _password.tintColor = textColor;
    _password.placeholder = NSLocalizedString(@"_password_", nil);
    UILabel *passwordPlaceholder = object_getIvar(_password, ivar);
    passwordPlaceholder.textColor = [textColor colorWithAlphaComponent:0.5];
    [self.password setFont:[UIFont systemFontOfSize:13]];
    [self.password setDelegate:self];

    [self.toggleVisiblePassword setImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"visiblePassword"] multiplier:2 color:textColor] forState:UIControlStateNormal];
    
    // Login
    [self.login setTitle:NSLocalizedString(@"_login_", nil) forState:UIControlStateNormal] ;
    self.login.backgroundColor = textColor;
    self.login.tintColor = textColorOpponent;
    self.login.layer.cornerRadius = 20;
    self.login.clipsToBounds = YES;
    
    // Type view
    [self.loginTypeView setTitle:NSLocalizedString(@"_traditional_login_", nil) forState:UIControlStateNormal];
    [self.loginTypeView setTitleColor:[textColor colorWithAlphaComponent:0.5] forState:UIControlStateNormal];

    // Brand
    if ([NCBrandOptions sharedInstance].disable_request_login_url) {
        _baseUrl.text = [NCBrandOptions sharedInstance].loginBaseUrl;
        _imageBaseUrl.hidden = YES;
        _baseUrl.hidden = YES;
    }
    
    // QrCode image
    [self.qrCode setImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"qrcode"] width:100 height:100 color:textColor] forState:UIControlStateNormal];
    
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
    if ([listAccount count] == 0) {
        _imageUser.hidden = YES;
        _user.hidden = YES;
        _imagePassword.hidden = YES;
        _password.hidden = YES;
    } else {
        _imageUser.hidden = YES;
        _user.hidden = YES;
        _imagePassword.hidden = YES;
        _password.hidden = YES;
        self.navigationItem.leftBarButtonItem = cancelButton;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Stop timer error network
    [appDelegate.timerErrorNetworking invalidate];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Start timer
    [appDelegate startTimerErrorNetworking];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Chech Server URL ==
#pragma --------------------------------------------------------------------------------------------

- (void)testUrl
{
    self.login.enabled = NO;
    [self.activity startAnimating];
    
    // Check whether baseUrl contain protocol. If not add https:// by default.
    if(![self.baseUrl.text hasPrefix:@"https"] && ![self.baseUrl.text hasPrefix:@"http"]) {
      self.baseUrl.text = [NSString stringWithFormat:@"https://%@",self.baseUrl.text];
    }
    
    // Remove trailing slash
    if ([self.baseUrl.text hasSuffix:@"/"])
        self.baseUrl.text = [self.baseUrl.text substringToIndex:[self.baseUrl.text length] - 1];
        
    [[NCCommunication shared] getServerStatusWithServerUrl:self.baseUrl.text customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *serverProductName, NSString *serverVersion, NSInteger versionMajor, NSInteger versionMinor, NSInteger versionMicro, BOOL extendedSupport, NSInteger errorCode, NSString *errorDescription) {
        
        if (errorCode == 0) {
            
            [self.activity stopAnimating];
            self.login.enabled = YES;
            
            // Login Flow V2
            [[NCCommunication shared] getLoginFlowV2WithServerUrl:self.baseUrl.text completionHandler:^(NSString *token, NSString *endpoint, NSString *login, NSInteger errorCode, NSString *errorDescription) {
                
                // Login Flow V2
                if (errorCode == 0 && [[NCBrandOptions sharedInstance] use_loginflowv2] && token != nil && endpoint != nil && login != nil) {
                    
                    NCLoginWeb *activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
                    
                    activeLoginWeb.urlBase = self.baseUrl.text;
                    activeLoginWeb.loginFlowV2Available = true;
                    activeLoginWeb.loginFlowV2Token = token;
                    activeLoginWeb.loginFlowV2Endpoint = endpoint;
                    activeLoginWeb.loginFlowV2Login = login;
                    
                    [self.navigationController pushViewController:activeLoginWeb animated:true];
                }
                
                // Login Flow
                else if (_user.hidden && _password.hidden && versionMajor >= k_flow_version_available) {
                    
                    NCLoginWeb *activeLoginWeb = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"NCLoginWeb"];
                    activeLoginWeb.urlBase = self.baseUrl.text;
                    
                    [self.navigationController pushViewController:activeLoginWeb animated:true];
                }
                
                // NO Login Flow available
                else if (versionMajor < k_flow_version_available) {
                    
                    [self.loginTypeView setHidden:YES];
                    
                    _imageUser.hidden = NO;
                    _user.hidden = NO;
                    _imagePassword.hidden = NO;
                    _password.hidden = NO;
                    
                    [_user becomeFirstResponder];
                }
            }];
            
        } else {
            
            [self.activity stopAnimating];
            self.login.enabled = YES;
            
            if (errorCode == NSURLErrorServerCertificateUntrusted) {
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_ssl_certificate_untrusted_", nil) message:NSLocalizedString(@"_connect_server_anyway_", nil)  preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_yes_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [[NCNetworking shared] wrtiteCertificateWithDirectoryCertificate:[CCUtility getDirectoryCerificates]];
                    [appDelegate startTimerErrorNetworking];
                }]];
                               
                [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_no_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    [appDelegate startTimerErrorNetworking];
                }]];
                [self presentViewController:alertController animated:YES completion:^{
                    // Stop timer error network
                    [appDelegate.timerErrorNetworking invalidate];
                }];
                
            } else {
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_connection_error_", nil) message:errorDescription preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
        }
        
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == TextField ==
#pragma --------------------------------------------------------------------------------------------

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.password) {
        self.toggleVisiblePassword.hidden = NO;
        self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName:textColor};
    }
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.password) {
        self.toggleVisiblePassword.hidden = YES;
        self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName:textColor};
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === NCLoginQRCodeDelegate ===
#pragma --------------------------------------------------------------------------------------------

- (void)dismissQRCode:(NSString *)value metadataType:(NSString *)metadataType
{
    NSString *protocolLogin = [[NCBrandOptions sharedInstance].webLoginAutenticationProtocol stringByAppendingString:@"login/"];
    
    if (value != nil && [value hasPrefix:protocolLogin] && [value containsString:@"user:"] && [value containsString:@"password:"] && [value containsString:@"server:"]) {
        
        value = [value stringByReplacingOccurrencesOfString:protocolLogin withString:@""];
        
        NSArray *valueArray = [value componentsSeparatedByString: @"&"];
        
        if (valueArray.count == 3) {
            
            _imageUser.hidden = NO;
            _user.hidden = NO;
            _imagePassword.hidden = NO;
            _password.hidden = NO;
            
            [self.loginTypeView setTitle:NSLocalizedString(@"_web_login_", nil) forState:UIControlStateNormal];
            
            self.user.text = [valueArray[0] stringByReplacingOccurrencesOfString:@"user:" withString:@""];
            self.password.text = [valueArray[1] stringByReplacingOccurrencesOfString:@"password:" withString:@""];
            self.baseUrl.text = [valueArray[2] stringByReplacingOccurrencesOfString:@"server:" withString:@""];
            
            // Check whether baseUrl contain protocol. If not add https:// by default.
            if(![self.baseUrl.text hasPrefix:@"https"] && ![self.baseUrl.text hasPrefix:@"http"]) {
                self.baseUrl.text = [NSString stringWithFormat:@"https://%@",self.baseUrl.text];
            }
            
            NSString *url = self.baseUrl.text;
            NSString *user = self.user.text;
            NSString *token = self.password.text;
            
            self.login.enabled = NO;
            [self.activity startAnimating];
            
            NSString *webDAV = [[NCUtility shared] getWebDAVWithAccount:appDelegate.account];
            NSString *serverUrl = [NSString stringWithFormat:@"%@/%@", url, webDAV];
            
            [[NCCommunication shared] checkServerWithServerUrl:serverUrl completionHandler:^(NSInteger errorCode, NSString *errorDescription) {
                
                [self.activity stopAnimating];
                self.login.enabled = YES;
                
                [self AfterLoginWithUrl:url user:user token:token errorCode:errorCode message:errorDescription];
            }];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Login ==
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
        
        self.login.enabled = NO;
        [self.activity startAnimating];

        [[NCCommunication shared] getAppPasswordWithServerUrl:url username:user password:password customUserAgent:nil completionHandler:^(NSString *token, NSInteger errorCode, NSString *errorDescription) {
            
            [self.activity stopAnimating];
            self.login.enabled = YES;
            
            [self AfterLoginWithUrl:url user:user token:token errorCode:errorCode message:errorDescription];
        }];
    }
}

- (void)AfterLoginWithUrl:(NSString *)url user:(NSString *)user token:(NSString *)token errorCode:(NSInteger)errorCode message:(NSString *)message
{
    if (errorCode == 0) {
        
        NSString *account = [NSString stringWithFormat:@"%@ %@", user, url];
        
        // NO account found, clear
        if ([NCManageDatabase.sharedInstance getAccounts] == nil) { [NCUtility.shared removeAllSettings]; }
        
        [[NCManageDatabase sharedInstance] deleteAccount:account];
        [[NCManageDatabase sharedInstance] addAccount:account urlBase:url user:user password:token];
        
        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:account];
        
        // Setting appDelegate active account
        [appDelegate settingAccount:tableAccount.account urlBase:tableAccount.urlBase user:tableAccount.user userID:tableAccount.userID password:[CCUtility getPassword:tableAccount.account]];
        
        if ([CCUtility getIntro]) {
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            [CCUtility setIntro:YES];
            if (self.presentingViewController == nil) {
                UISplitViewController *splitController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateInitialViewController];
                splitController.modalPresentationStyle = UIModalPresentationFullScreen;
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
                appDelegate.window.rootViewController = splitController;
                [appDelegate.window makeKeyWindow];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        }
    } else {
        if (errorCode != NSURLErrorServerCertificateUntrusted) {
            NSString *messageAlert = [NSString stringWithFormat:@"%@.\n%@", NSLocalizedString(@"_not_possible_connect_to_server_", nil), message];
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:messageAlert preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
            [alertController addAction:okAction];
            [self presentViewController:alertController animated:YES completion:nil];
        }
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
    self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName: textColor};
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

- (IBAction)handleQRCode:(id)sender
{
    NCLoginQRCode *qrCode = [[NCLoginQRCode alloc] initWithDelegate:self];
    
    [qrCode scan];
}

@end
