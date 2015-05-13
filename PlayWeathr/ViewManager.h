//
//  ViewManager.h
//  PlayWeathr
//
//  Created by Hannah Carney on 5/13/15.
//  Copyright (c) 2015 Hannah Carney. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa/ReactiveCocoa.h>

#import "ViewCondition.h"

@import Foundation;
@import CoreLocation;

@interface ViewManager : NSObject
<CLLocationManagerDelegate>

+ (instancetype)sharedManager;

@property (nonatomic, strong, readonly) CLLocation *currentLocation;
@property (nonatomic, strong, readonly) ViewCondition *currentCondition;
@property (nonatomic, strong, readonly) NSArray *hourlyForecast;
@property (nonatomic, strong, readonly) NSArray *dailyForecast;

- (void)findCurrentLocation;

@end
