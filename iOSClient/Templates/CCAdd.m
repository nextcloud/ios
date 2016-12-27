//
//  CCAdd.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 27/10/14.
//  Copyright (c) 2014 TWS. All rights reserved.
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

#import "CCAdd.h"

@implementation CCAdd

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"_cancel_", nil);
    self.title = NSLocalizedString(@"_add_", nil);
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar  hidden:NO];    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == IBAction ==
#pragma --------------------------------------------------------------------------------------------

- (IBAction)Annula:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == tableView ==
#pragma --------------------------------------------------------------------------------------------

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    UILabel *nameLabel;
   
    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];

    switch (section)
    {
        case 0:
            if (row == 0) { nameLabel = (UILabel *)[cell viewWithTag:100]; nameLabel.text = NSLocalizedString(@"_add_folder_", nil); }
            if (row == 1) { nameLabel = (UILabel *)[cell viewWithTag:101]; nameLabel.text = NSLocalizedString(@"_add_photos_videos_", nil); }
            if (row == 2) { nameLabel = (UILabel *)[cell viewWithTag:102]; nameLabel.text = NSLocalizedString(@"_add_photos_videos_", nil); }
            break;
        case 1:
            if (row == 0) { nameLabel = (UILabel *)[cell viewWithTag:200]; nameLabel.text = NSLocalizedString(@"_add_folder_encryptated_", nil); }
            if (row == 1) { nameLabel = (UILabel *)[cell viewWithTag:201]; nameLabel.text = NSLocalizedString(@"_add_encrypted_photo_video_", nil); }
            if (row == 2) { nameLabel = (UILabel *)[cell viewWithTag:202]; nameLabel.text = NSLocalizedString(@"_add_encrypted_photo_video_", nil); }
            break;
        case 2:
            if (row == 0) { nameLabel = (UILabel *)[cell viewWithTag:300]; nameLabel.text = NSLocalizedString(@"_add_notes_", nil); }
            if (row == 1) { nameLabel = (UILabel *)[cell viewWithTag:301]; nameLabel.text = NSLocalizedString(@"_add_web_account_", nil); }
            break;
        case 3:
            if (row == 0) { nameLabel = (UILabel *)[cell viewWithTag:400]; nameLabel.text = NSLocalizedString(@"_add_credit_card_", nil); }
            if (row == 1) { nameLabel = (UILabel *)[cell viewWithTag:401]; nameLabel.text = NSLocalizedString(@"_add_atm_", nil); }
            if (row == 2) { nameLabel = (UILabel *)[cell viewWithTag:402]; nameLabel.text = NSLocalizedString(@"_add_bank_account_", nil); }
            break;
        case 4:
            if (row == 0) { nameLabel = (UILabel *)[cell viewWithTag:500]; nameLabel.text = NSLocalizedString(@"_add_driving_license_", nil); }
            if (row == 1) { nameLabel = (UILabel *)[cell viewWithTag:501]; nameLabel.text = NSLocalizedString(@"_add_id_card_", nil); }
            if (row == 2) { nameLabel = (UILabel *)[cell viewWithTag:502]; nameLabel.text = NSLocalizedString(@"_add_passport_", nil); }
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];
    
    switch (section) {
        case 0:
            if (row == 0) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCreateFolderPlain];
                }];
            }
            if (row == 1) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCreateFotoVideoPlain];
                }];
            }
            if (row == 2) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCreateFilePlain];
                }];
            }
            break;
        case 1: 
            if (row == 0) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCreateFolderEncrypted];
                }];
            }
            if (row == 1) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCreateFotoVideoEncrypted];
                }];
            }
            if (row == 2) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCreateFileEncrypted];
                }];
            }
            break;
        case 2:
            if (row == 0) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnNote];
                }];
            }
            if (row == 1) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnAccountWeb];
                }];
            }
            break;
        case 3:
            if (row == 0) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCartaDiCredito];
                }];
            }
            if (row == 1) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnBancomat];
                }];
            }
            if (row == 2) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnContoCorrente];
                }];
            }
            break;
               case 4:
            if (row == 0) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnPatenteGuida];
                }];
            }
            if (row == 1) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnCartaIdentita];
                }];
            }
            if (row == 2) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [_delegate returnCreate:returnPassaporto];
                }];
            }
            break;
    }
}

@end
