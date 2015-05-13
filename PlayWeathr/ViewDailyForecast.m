//
//  ViewDailyForecast.m
//  PlayWeathr
//
//  Created by Hannah Carney on 5/13/15.
//  Copyright (c) 2015 Hannah Carney. All rights reserved.
//

#import "ViewDailyForecast.h"

@implementation ViewDailyForecast

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *paths = [[super JSONKeyPathsByPropertyKey] mutableCopy];
    paths[@"tempHigh"] = @"temp.max";
    paths[@"tempLow"] = @"temp.min";
    
    return paths;
}

@end
