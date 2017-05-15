//
//  CCCertificate.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 10/08/16.
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CCCertificateDelegate <NSObject>

@optional - (void)trustedCerticateAccepted;
@optional - (void)trustedCerticateDenied;

@end

@interface CCCertificate : NSObject

@property (weak) id<CCCertificateDelegate> delegate;

+ (id)sharedManager;

- (BOOL)checkTrustedChallenge:(NSURLAuthenticationChallenge *)challenge;
- (BOOL)acceptCertificate;
- (void)saveCertificate:(SecTrustRef) trust withName:(NSString *) certName;

- (void)presentViewControllerCertificateWithTitle:(NSString *)title viewController:(UIViewController *)viewController delegate:(id)delegate;

@end

