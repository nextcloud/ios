//
//  NCCommunicationCertificate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/10/19.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import Foundation
import OpenSSL

class NCCommunicationCertificate: NSObject {
    @objc static let sharedInstance: NCCommunicationCertificate = {
        let instance = NCCommunicationCertificate()
        return instance
    }()

    // Returns the leaf certificate from a SecTrust object (that is always the
    // certificate at index 0).
    static func secTrustGetLeafCertificate(_ trust: SecTrust) -> SecCertificate? {
        
        let result: SecCertificate?
        
        if SecTrustGetCertificateCount(trust) > 0 {
            result = SecTrustGetCertificateAtIndex(trust, 0)!
            assert(result != nil);
        } else {
            result = nil
        }
        
        return result
    }
    
    /*
     - (BOOL)checkTrustedChallenge:(NSURLAuthenticationChallenge *)challenge
     {
         
             
             [self saveCertificate:trust withName:@"tmp.der"];
             
             NSString *localCertificatesFolder = [CCUtility getDirectoryCerificates];
             
             NSArray *listCertificateLocation = [[NCManageDatabase sharedInstance] getCertificatesLocation:[CCUtility getDirectoryCerificates]];
             
             for (int i = 0 ; i < [listCertificateLocation count] ; i++) {
              
                 NSString *currentLocalCertLocation = [listCertificateLocation objectAtIndex:i];
                 
                 NSFileManager *fileManager = [ NSFileManager defaultManager];
                 
                 if([fileManager contentsEqualAtPath:[NSString stringWithFormat:@"%@/%@",localCertificatesFolder,@"tmp.der"] andPath:[NSString stringWithFormat:@"%@",currentLocalCertLocation]]) {
                     
                     NSLog(@"[LOG] Is the same certificate!!!");
                     trusted = YES;
                 }
             }
             
         } else
             trusted = NO;
         
         return trusted;
     }

     */
    
    @objc func checkTrustedChallenge(challenge: URLAuthenticationChallenge, directoryCertificate: String) -> Bool {
        
        var trusted = false
        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificateUrl = URL.init(fileURLWithPath: directoryCertificate)

        
        if let trust: SecTrust = protectionSpace.serverTrust {
            
            saveCertificate(trust, certName: "tmp.der", directoryCertificate: directoryCertificate)
            
            do {
                // Get the directory contents urls (including subfolders urls)
                let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryCertificateUrl, includingPropertiesForKeys: nil)
                print(directoryContents)
                
                for file in directoryContents {
                    if FileManager.default.contentsEqual(atPath: directoryCertificate+"/"+"tmp.der", andPath: file.absoluteString) {
                        trusted = true
                    }
                }
                
            } catch { print(error) }
        }
        
        return trusted
    }
    
    private func saveCertificate(_ trust: SecTrust, certName: String, directoryCertificate: String) {
        
    }
    
    /*
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
                
                certName = [NSString stringWithFormat:@"%@/%@",localCertificatesFolder,certName];
                
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
    */

    
}
