//
//  CCCertificate.m
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

#import "CCUtility.h"
#import "CCCertificate.h"
#import "NCBridgeSwift.h"

#import <openssl/x509.h>
#import <openssl/bio.h>
#import <openssl/err.h>
#import <openssl/pem.h>

@implementation CCCertificate

//Singleton
+ (id)sharedManager {
    static CCCertificate *CCCertificate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CCCertificate = [[self alloc] init];
    });
    return CCCertificate;
}

static SecCertificateRef SecTrustGetLeafCertificate(SecTrustRef trust)
// Returns the leaf certificate from a SecTrust object (that is always the 
// certificate at index 0).
{
    SecCertificateRef   result;
    
    assert(trust != NULL);
    
    if (SecTrustGetCertificateCount(trust) > 0) {
        result = SecTrustGetCertificateAtIndex(trust, 0);
        assert(result != NULL);
    } else {
        result = NULL;
    }
    return result;
}

- (BOOL)checkTrustedChallenge:(NSURLAuthenticationChallenge *)challenge
{
    BOOL trusted = NO;
    SecTrustRef trust;
    NSURLProtectionSpace *protectionSpace;
    
    protectionSpace = [challenge protectionSpace];
    trust = [protectionSpace serverTrust];
        
    if(trust != nil) {
        
        [self saveCertificate:trust withName:@"tmp.der"];
        
        NSString *localCertificatesFolder = [CCUtility getDirectoryCerificates];
        
        NSArray *listCertificateLocation = [[NCManageDatabase sharedInstance] getCertificatesLocation:[CCUtility getDirectoryCerificates]];
        
        for (int i = 0 ; i < [listCertificateLocation count] ; i++) {
         
            NSString *currentLocalCertLocation = [listCertificateLocation objectAtIndex:i];
            
            NSFileManager *fileManager = [ NSFileManager defaultManager];
            
            if([fileManager contentsEqualAtPath:[NSString stringWithFormat:@"%@%@",localCertificatesFolder,@"tmp.der"] andPath:[NSString stringWithFormat:@"%@",currentLocalCertLocation]]) {
                
                NSLog(@"[LOG] Is the same certificate!!!");
                trusted = YES;
            }
        }
        
    } else
        trusted = NO;
    
    return trusted;
}

- (void)saveCertificate:(SecTrustRef)trust withName:(NSString *)certName
{
    SecCertificateRef currentServerCert = SecTrustGetLeafCertificate(trust);
    
    CFDataRef data = SecCertificateCopyData(currentServerCert);
    X509 *x509cert = NULL;
    if (data) {
        BIO *mem = BIO_new_mem_buf((void *)CFDataGetBytePtr(data), (int)CFDataGetLength(data));
        x509cert = d2i_X509_bio(mem, NULL);
        BIO_free(mem);
        CFRelease(data);
        
        if (!x509cert) {
            
            NSLog(@"[LOG] OpenSSL couldn't parse X509 Certificate");
            
        } else {
            
            NSString *localCertificatesFolder = [CCUtility getDirectoryCerificates];
            
            certName = [NSString stringWithFormat:@"%@%@",localCertificatesFolder,certName];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:certName]) {
                NSError *error;
                [[NSFileManager defaultManager] removeItemAtPath:certName error:&error];
            }
            
            FILE *file;
            file = fopen([certName UTF8String], "w");
            if (file) {
                PEM_write_X509(file, x509cert);
            }
            fclose(file);
        }
    
    } else {
        
        NSLog(@"[LOG] Failed to retrieve DER data from Certificate Ref");
    }
    
    //Free
    X509_free(x509cert);
}

- (void)presentViewControllerCertificateWithTitle:(NSString *)title viewController:(UIViewController *)viewController delegate:(id)delegate
{    
    if (![viewController isKindOfClass:[UIViewController class]])
        return;
    
    _delegate = delegate;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:NSLocalizedString(@"_connect_server_anyway_", nil)  preferredStyle:UIAlertControllerStyleAlert];
    
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_yes_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                           
            [[CCCertificate sharedManager] acceptCertificate];
            
            if([self.delegate respondsToSelector:@selector(trustedCerticateAccepted)])
                [self.delegate trustedCerticateAccepted];
        }]];
    
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_no_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                                           
            if([self.delegate respondsToSelector:@selector(trustedCerticateDenied)])
                [self.delegate trustedCerticateDenied];
        }]];
        
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)viewCertificate:(SecTrustRef)trust
{
    SecCertificateRef currentServerCert = SecTrustGetLeafCertificate(trust);
    
    CFDataRef data = SecCertificateCopyData(currentServerCert);
    X509 *x509cert = NULL;
    if (data) {
        BIO *mem = BIO_new_mem_buf((void *)CFDataGetBytePtr(data), (int)CFDataGetLength(data));
        x509cert = d2i_X509_bio(mem, NULL);
        BIO_free(mem);
        CFRelease(data);
        
        if (!x509cert) {
            
            NSLog(@"[LOG] OpenSSL couldn't parse X509 Certificate");
            
        } else {
            
            NSString *issuer = CertificateGetIssuerName(x509cert);
            NSDate *expiryDate = CertificateGetExpiryDate(x509cert);
            
            NSLog(@"[LOG] %@ %@", issuer, expiryDate);
        }
        
    } else {
        
        NSLog(@"[LOG] Failed to retrieve DER data from Certificate Ref");
    }
    
    //Free
    X509_free(x509cert);
}

- (BOOL)acceptCertificate
{
    NSString *localCertificatesFolder = [CCUtility getDirectoryCerificates];
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSTimeInterval dateCertificate = [[NSDate date] timeIntervalSince1970];
    NSString *currentCertLocation = [NSString stringWithFormat:@"%@%f.der",localCertificatesFolder, dateCertificate];
    
    NSLog(@"[LOG] currentCertLocation: %@", currentCertLocation);
    
    if(![fm moveItemAtPath:[NSString stringWithFormat:@"%@%@",localCertificatesFolder, @"tmp.der"] toPath:currentCertLocation error:&error]) {
        
        NSLog(@"[LOG] Error: %@", [error localizedDescription]);
        return NO;
        
    } else {
        
        [[NCManageDatabase sharedInstance] addCertificates:[NSString stringWithFormat:@"%f.der", dateCertificate]];
    }
    
    return YES;
}

static NSString * CertificateGetIssuerName(X509 *certificateX509)
{
    NSString *issuer = nil;
    if (certificateX509 != NULL) {
        X509_NAME *issuerX509Name = X509_get_issuer_name(certificateX509);
        
        if (issuerX509Name != NULL) {
            int nid = OBJ_txt2nid("O"); // organization
            int index = X509_NAME_get_index_by_NID(issuerX509Name, nid, -1);
            
            X509_NAME_ENTRY *issuerNameEntry = X509_NAME_get_entry(issuerX509Name, index);
            
            if (issuerNameEntry) {
                ASN1_STRING *issuerNameASN1 = X509_NAME_ENTRY_get_data(issuerNameEntry);
                
                if (issuerNameASN1 != NULL) {
                    unsigned char *issuerName = ASN1_STRING_data(issuerNameASN1);
                    issuer = [NSString stringWithUTF8String:(char *)issuerName];
                }
            }
        }
    }
    
    return issuer;
}

static NSDate *CertificateGetExpiryDate(X509 *certificateX509)
{
    NSDate *expiryDate = nil;
    
    if (certificateX509 != NULL) {
        ASN1_TIME *certificateExpiryASN1 = X509_get_notAfter(certificateX509);
        if (certificateExpiryASN1 != NULL) {
            ASN1_GENERALIZEDTIME *certificateExpiryASN1Generalized = ASN1_TIME_to_generalizedtime(certificateExpiryASN1, NULL);
            if (certificateExpiryASN1Generalized != NULL) {
                unsigned char *certificateExpiryData = ASN1_STRING_data(certificateExpiryASN1Generalized);
                
                // ASN1 generalized times look like this: "20131114230046Z"
                //                                format:  YYYYMMDDHHMMSS
                //                               indices:  01234567890123
                //                                                   1111
                // There are other formats (e.g. specifying partial seconds or
                // time zones) but this is good enough for our purposes since
                // we only use the date and not the time.
                //
                // (Source: http://www.obj-sys.com/asn1tutorial/node14.html)
                
                NSString *expiryTimeStr = [NSString stringWithUTF8String:(char *)certificateExpiryData];
                NSDateComponents *expiryDateComponents = [[NSDateComponents alloc] init];
                
                expiryDateComponents.year   = [[expiryTimeStr substringWithRange:NSMakeRange(0, 4)] intValue];
                expiryDateComponents.month  = [[expiryTimeStr substringWithRange:NSMakeRange(4, 2)] intValue];
                expiryDateComponents.day    = [[expiryTimeStr substringWithRange:NSMakeRange(6, 2)] intValue];
                expiryDateComponents.hour   = [[expiryTimeStr substringWithRange:NSMakeRange(8, 2)] intValue];
                expiryDateComponents.minute = [[expiryTimeStr substringWithRange:NSMakeRange(10, 2)] intValue];
                expiryDateComponents.second = [[expiryTimeStr substringWithRange:NSMakeRange(12, 2)] intValue];
                
                NSCalendar *calendar = [NSCalendar currentCalendar];
                expiryDate = [calendar dateFromComponents:expiryDateComponents];
            }
        }
    }
    
    return expiryDate;
}

@end
