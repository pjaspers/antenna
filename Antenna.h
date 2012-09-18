//
//  Antenna.h
//  10to1
//
//  Created by Piet Jaspers on 02/03/12.
//

#import <Foundation/Foundation.h>

NSString *const AntennaReachabilityDidChangeNotification;

typedef enum {
	kNotReachable = 0,
	kReachableViaWWAN,
	kReachableViaWiFi
} AntennaStatus;

typedef void (^AntennaReachabilityStatusBlock)(BOOL isNetworkReachable);

// Antenna
//
// What is it?
//
// Lightweight replacement for `Reachability` to do the basics of network connectivity.
//
// How to install:
//
//      - Copy these files to your project
//      - Add SystemConfiguration.framework
//      - Import the <SystemConfiguration> in your prefix file
//
// How to use:
//
// Either use `[Antenna antenna]` and listen for the `AntennaReachabilityDidChangeNotification` notification
// or use the `[Antenna antennaOnChange:^{}]` and handle the notification in the block.
//
// It's handy to keep a reference of the antenna around, so you can always check the status.
//

@interface Antenna : NSObject

+ (Antenna *)antenna;
+ (Antenna *)antennaOnChange:(AntennaReachabilityStatusBlock)block;

- (BOOL)isReachable;
- (BOOL)isReachableViaWWAN;
- (BOOL)isReachableViaWiFi;

@end
