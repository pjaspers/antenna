//
//  Antenna.m
//  10to1
//
//  Created by Piet Jaspers on 02/03/12.
//

#import <netinet/in.h>
#import "Antenna.h"

NSString * const AntennaReachabilityDidChangeNotification = @"be.10to1.antenna.reachability.change";

typedef SCNetworkReachabilityRef AntennaNetworkReachabilityRef;

@interface Antenna ()

- (void)startMonitoring;
- (void)stopMonitoring;
- (AntennaStatus)currentStatus;
- (AntennaStatus) networkStatusForFlags: (SCNetworkReachabilityFlags) flags;

@property (readwrite, nonatomic, assign) AntennaNetworkReachabilityRef reachability;
@property (readwrite, nonatomic, copy) AntennaReachabilityStatusBlock reachabilityStatusBlock;
@end

@implementation Antenna
@synthesize reachability = _reachability;
@synthesize reachabilityStatusBlock = _reachabilityStatusBlock;

// Highly modelled after `AFNetworking`'s support for Reachability
static void AntennaReachabilityCallback(SCNetworkReachabilityRef __unused target, SCNetworkReachabilityFlags flags, void *info) {
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL isNetworkReachable = (isReachable && !needsConnection);

    AntennaReachabilityStatusBlock block = (__bridge AntennaReachabilityStatusBlock)info;
    if (block) {
        block(isNetworkReachable);
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:AntennaReachabilityDidChangeNotification object:[NSNumber numberWithBool:isNetworkReachable]];
}

+ (Antenna *)antenna {
    Antenna *antenna = [[self alloc] init];
    [antenna startMonitoring];
    return antenna;
}

+ (Antenna *)antennaOnChange:(AntennaReachabilityStatusBlock)block {
    Antenna *antenna = [[self alloc] init];
    antenna.reachabilityStatusBlock = block;
    [antenna startMonitoring];
    return antenna;
}

- (void)startMonitoring {
    [self stopMonitoring];

    struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;

    self.reachability  = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
    SCNetworkReachabilityContext context = {0,  (__bridge void *) self.reachabilityStatusBlock, NULL, NULL, NULL};
    SCNetworkReachabilitySetCallback(self.reachability, AntennaReachabilityCallback, &context);
    SCNetworkReachabilityScheduleWithRunLoop(self.reachability, CFRunLoopGetMain(), (CFStringRef)NSRunLoopCommonModes);
}

- (void)stopMonitoring {
    if (!_reachability) return;

    SCNetworkReachabilityUnscheduleFromRunLoop(_reachability, CFRunLoopGetMain(), (CFStringRef)NSRunLoopCommonModes);
    CFRelease(_reachability);
}

# pragma mark - Status methods

- (BOOL)isReachable {
    return (kNotReachable != [self currentStatus]);
}

- (BOOL)isReachableViaWWAN {
    return (kReachableViaWWAN == [self currentStatus]);
}

- (BOOL)isReachableViaWiFi {
    return (kReachableViaWiFi == [self currentStatus]);
}

- (AntennaStatus)currentStatus {
    NSAssert(_reachability, @"isReachableViaWiFi called with NULL reachabilityRef");
	SCNetworkReachabilityFlags flags = 0;
	if (SCNetworkReachabilityGetFlags(_reachability, &flags)) {
		return [self networkStatusForFlags:flags];
	}
    return kNotReachable;
}

#pragma mark - Network Flag Handling Methods

// Taken directly from Reachability 2
// Credit here: http://blog.ddg.com/?p=24
//
// iPhone condition codes as reported by a 3GS running iPhone OS v3.0.
// Airplane Mode turned on:  Reachability Flag Status: -- -------
// WWAN Active:              Reachability Flag Status: WR -t-----
// WWAN Connection required: Reachability Flag Status: WR ct-----
//         WiFi turned on:   Reachability Flag Status: -R ------- Reachable.
// Local   WiFi turned on:   Reachability Flag Status: -R xxxxxxd Reachable.
//         WiFi turned on:   Reachability Flag Status: -R ct----- Connection down. (Non-intuitive, empirically determined answer.)
const SCNetworkReachabilityFlags kConnectionDown =  kSCNetworkReachabilityFlagsConnectionRequired |
kSCNetworkReachabilityFlagsTransientConnection;
//         WiFi turned on:   Reachability Flag Status: -R ct-i--- Reachable but it will require user intervention (e.g. enter a WiFi password).
//         WiFi turned on:   Reachability Flag Status: -R -t----- Reachable via VPN.
//
// In the below method, an 'x' in the flag status means I don't care about its value.
//
// This method differs from Apple's by testing explicitly for empirically observed values.
// This gives me more confidence in it's correct behavior. Apple's code covers more cases
// than mine. My code covers the cases that occur.
//
- (AntennaStatus) networkStatusForFlags: (SCNetworkReachabilityFlags) flags {

	if (flags & kSCNetworkReachabilityFlagsReachable) {
		// Observed WWAN Values:
		// WWAN Active:              Reachability Flag Status: WR -t-----
		// WWAN Connection required: Reachability Flag Status: WR ct-----
		//
		// Test Value: Reachability Flag Status: WR xxxxxxx
		if (flags & kSCNetworkReachabilityFlagsIsWWAN) { return kReachableViaWWAN; }

		// Clear moot bits.
		flags &= ~kSCNetworkReachabilityFlagsReachable;
		flags &= ~kSCNetworkReachabilityFlagsIsDirect;
		flags &= ~kSCNetworkReachabilityFlagsIsLocalAddress; // kInternetConnection is local.

		// Reachability Flag Status: -R ct---xx Connection down.
		if (flags == kConnectionDown) { return kNotReachable; }

		// Reachability Flag Status: -R -t---xx Reachable. WiFi + VPN(is up) (Thank you Ling Wang)
		if (flags & kSCNetworkReachabilityFlagsTransientConnection)  { return kReachableViaWiFi; }

		// Reachability Flag Status: -R -----xx Reachable.
		if (flags == 0) { return kReachableViaWiFi; }

		// Apple's code tests for dynamic connection types here. I don't.
		// If a connection is required, regardless of whether it is on demand or not, it is a WiFi connection.
		// If you care whether a connection needs to be brought up,   use -isConnectionRequired.
		// If you care about whether user intervention is necessary,  use -isInterventionRequired.
		// If you care about dynamically establishing the connection, use -isConnectionIsOnDemand.

		// Reachability Flag Status: -R cxxxxxx Reachable.
		if (flags & kSCNetworkReachabilityFlagsConnectionRequired) { return kReachableViaWiFi; }

		// Required by the compiler. Should never get here. Default to not connected.
		return kNotReachable;
    }

	// Reachability Flag Status: x- xxxxxxx
	return kNotReachable;
}

@end
