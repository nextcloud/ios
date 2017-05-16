//
//  CCTemplates.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 24/11/14.
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

#import "CCTemplates.h"
#import "NCBridgeSwift.h"

@implementation CCTemplates

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Effetti Grafici =====
#pragma --------------------------------------------------------------------------------------------

- (void)setImageTitle:(NSString*)titolo conNavigationItem:(UINavigationItem *)navItem reachability:(BOOL)reachability
{
    UILabel* label=[[UILabel alloc] initWithFrame:CGRectMake(0,0, navItem.titleView.frame.size.width, 40)];
    label.text=titolo;
    if (!reachability) label.textColor = [NCBrandColor sharedInstance].connectionNo;
    else label.textColor = [NCBrandColor sharedInstance].navigationBarText;
    label.backgroundColor = [NCBrandColor sharedInstance].brand;
    label.textAlignment = NSTextAlignmentCenter;
    navItem.titleView=label;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Form =====
#pragma --------------------------------------------------------------------------------------------

- (NSString *)salvaForm:(XLFormDescriptor *)form fileName:(NSString *)fileName uuid:(NSString *)uuid modello:(NSString *)modello icona:(NSString *)icona
{
    NSString *fileNameModel = nil;
    NSData *data;
    
    NSMutableDictionary * result = [NSMutableDictionary dictionary];
    for (XLFormSectionDescriptor * section in form.formSections) {
        if (!section.isMultivaluedSection){
            for (XLFormRowDescriptor * row in section.formRows) {
                if (row.tag && ![row.tag isEqualToString:@""]){
                    [result setObject:(row.value ?: [NSNull null]) forKey:row.tag];
                }
            }
        }
        else{
            NSMutableArray * multiValuedValuesArray = [NSMutableArray new];
            for (XLFormRowDescriptor * row in section.formRows) {
                if (row.value){
                    [multiValuedValuesArray addObject:row.value];
                }
            }
            [result setObject:multiValuedValuesArray forKey:section.multivaluedTag];
        }
    }
    
    // save the result
    NSString *title = [AESCrypt encrypt:[result objectForKey:@"titolo"] password:[[CCCrypto sharedManager] getKeyPasscode:uuid]];
    if (fileName) {
        fileNameModel = fileName;
        // copy in memory for failure write
        data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", uuid, fileName]];
    } else {
        fileNameModel = [NSString stringWithFormat:@"%@.plist", [[CCCrypto sharedManager] createFilenameEncryptor:[result objectForKey:@"titolo"] uuid:uuid]];
    }
    if ([[CCCrypto sharedManager] createTemplatesPlist:fileNameModel title:title uuid:uuid icon:icona model:modello dictionary:result] == NO) {
        
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_read_file_error_", nil) message:NSLocalizedString(@"_reload_folder_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
        
        fileNameModel = nil;
    }
    
    return fileNameModel;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Note =====
#pragma --------------------------------------------------------------------------------------------

- (NSString *)salvaNote:(NSString *)html titolo:(NSString *)titolo fileName:(NSString *)fileName uuid:(NSString *)uuid
{
    NSString *fileNameModel = nil;
    NSData *data;
    NSMutableDictionary * result = [NSMutableDictionary dictionary];
    
    [result setObject:(titolo ?: [NSNull null]) forKey:@"titolo"];
    [result setObject:(html ?: [NSNull null]) forKey:@"note"];
    
    // save the result
    NSString *title = [AESCrypt encrypt:[result objectForKey:@"titolo"] password:[[CCCrypto sharedManager] getKeyPasscode:uuid]];
    if (fileName) {
        fileNameModel = fileName;
        // copy in memory for failure write
        data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", uuid, fileName]];
    } else {
        fileNameModel = [NSString stringWithFormat:@"%@.plist",[[CCCrypto sharedManager] createFilenameEncryptor:[result objectForKey:@"titolo"] uuid:uuid]];
    }
    
    if ([[CCCrypto sharedManager] createTemplatesPlist:fileNameModel title:title uuid:uuid icon:@"note" model:@"note" dictionary:result] == NO) {
        
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_read_file_error_", nil) message:NSLocalizedString(@"_reload_folder_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
        
        fileNameModel = nil;
    }
    
    return fileNameModel;
}

@end


