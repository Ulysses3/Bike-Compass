//
//  StationsRepository.m
//  BikeCompass
//
//  Created by Raúl Riera on 27/08/2014.
//  Copyright (c) 2014 Raúl Riera. All rights reserved.
//

#import "StationsRepository.h"
#import "SpotlightRespository.h"

@implementation StationsRepository

static NSString * const CurrentStationKey = @"com.raulriera.bikecompass.currentStation";

+ (instancetype)sharedRepository
{
    static StationsRepository *sharedRepository = nil;
    if (sharedRepository == nil)
    {
        sharedRepository = [[self alloc] init];
    }
    return sharedRepository;
}

- (Station *)currentStation
{
    NSUserDefaults *sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:AppGroupKey];
    NSData *data = [sharedUserDefaults objectForKey:CurrentStationKey];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

- (void)setCurrentStation:(Station *)currentStation
{
    NSUserDefaults *sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:AppGroupKey];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:currentStation];
    [sharedUserDefaults setObject:data forKey:CurrentStationKey];
}

- (void)stationsForNetwork:(Network *)network withCompletionBlock:(void (^)(NSArray *stations, NSError *error))block
{
    NSString *resource = [RepositoryBaseURL stringByAppendingString:network.href];
    
    [Repository taskWithURL:[NSURL URLWithString:resource] withCompletionBlock:^(NSDictionary *json, NSError *error) {
        if (error) {
            block(nil, error);
        }
        
        NSArray *stations = [MTLJSONAdapter modelsOfClass:[Station class] fromJSONArray:[[json valueForKey:@"network"] valueForKey:@"stations"] error:&error];
        
        // Index the stations with Spotlight if needed
        if ([SpotlightRespository indexStatusForNetwork:network] == SpotlightIndexStatusMissing) {
            [SpotlightRespository indexStations:stations andNetwork:network];
        }
        
        block(stations, error);
    }];
}

- (void)closestStationForNetwork:(Network *)network toLocation:(CLLocation *)location withCompletionBlock:(void (^)(Station *, NSError *))completionBlock
{
    // Get all the stations of the first network
    [self stationsForNetwork:network withCompletionBlock:^(NSArray *stations, NSError *error) {
        
        Station *station = [[self sortStations:stations closestToLocation:location withMoreThanBikes:0] firstObject];
        
        completionBlock(station, error);
    }];
}

- (NSArray *)sortStations:(NSArray *)stations closestToLocation:(CLLocation *)location withMoreThanBikes:(NSInteger)bikes
{
    stations = [self sortStations:stations withMoreThanBikes:bikes];
    stations = [self sortStations:stations closestToLocation:location];
    
    return stations;
}

- (NSArray *)sortStations:(NSArray *)stations closestToLocation:(CLLocation *)location
{

    stations = [stations sortedArrayUsingComparator: ^(Station *a, Station *b) {
        
        CLLocation *aLocation = [[CLLocation alloc] initWithLatitude:a.latitude longitude:a.longitude];
        CLLocation *bLocation = [[CLLocation alloc] initWithLatitude:b.latitude longitude:b.longitude];
        
        CLLocationDistance aDistance = [aLocation distanceFromLocation:location];
        CLLocationDistance bDistance = [bLocation distanceFromLocation:location];
        if ( aDistance < bDistance ) {
            return (NSComparisonResult)NSOrderedAscending;
        } else if ( aDistance > bDistance) {
            return (NSComparisonResult)NSOrderedDescending;
        } else {
            return (NSComparisonResult)NSOrderedSame;
        }
    }];
        
    return stations;
}

- (NSArray *)sortStations:(NSArray *)stations withMoreThanBikes:(NSInteger)bikes
{
    stations = [stations sortedArrayUsingComparator: ^(Station *a, Station *b) {
        
        if (a.numberOfBikes > bikes) {
            return (NSComparisonResult)NSOrderedAscending;
        } else {
            return (NSComparisonResult)NSOrderedDescending;
        }
    }];
    
    return stations;
}

@end
