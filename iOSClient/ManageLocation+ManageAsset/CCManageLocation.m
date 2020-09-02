//
//  CCManageLocation.m
//  Nextcloud
//
//  Created by Marino Faggiana on 23/07/15.
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

#import "CCManageLocation.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@implementation CCManageLocation

+ (CCManageLocation *)sharedInstance
{
    static CCManageLocation *sharedInstance;

    @synchronized(self)
    {
        if (!sharedInstance){
            sharedInstance = [CCManageLocation new];
        }
        return sharedInstance;
    }
}

- (void)startSignificantChangeUpdates
{
    if (self.locationManager == nil) {
        
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        if([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)])
            [self.locationManager requestAlwaysAuthorization];
    }
    
    [self.locationManager startMonitoringSignificantLocationChanges];
}

- (void)stopSignificantChangeUpdates
{
    
    [self.locationManager stopMonitoringSignificantLocationChanges];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    CLLocation* location = [locations lastObject];
    
    [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"update location manager: latitude %+.6f, longitude %+.6f", location.coordinate.latitude, location.coordinate.longitude]];
    
    appDelegate.currentLatitude = location.coordinate.latitude;
    appDelegate.currentLongitude = location.coordinate.longitude;
    
    [self.delegate changedLocation];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self.delegate statusAuthorizationLocationChanged];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Location manager didFailWithError: Unable to start location manager, %@", [error description]]];
    
    [self.delegate statusAuthorizationLocationChanged];
}

@end
