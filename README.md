# antenna

Lightweight replacement for `Reachability` to do the basics of network connectivity.

## How to install:

- Copy these files to your project
- Add SystemConfiguration.framework
- Import the <SystemConfiguration> in your prefix file

## How to use:

Either use `[Antenna antenna]` and listen for the `AntennaReachabilityDidChangeNotification` notification or use the `[Antenna antennaOnChange:^{}]` and handle the notification in the block.

It's handy to keep a reference of the antenna around, so you can always check the status.