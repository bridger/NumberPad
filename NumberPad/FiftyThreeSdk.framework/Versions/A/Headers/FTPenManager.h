//
//  FTPenManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//  Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"

#pragma once

#import <Foundation/Foundation.h>

#import "FiftyThreeSdk/FTTouchClassifier.h"

// This describes the potential connection states of the pen. Using the Pairing UI provided should
// insulate most apps from needing to know the details of this information.
// See also: FTPenManagerStateIsConnected & FTPenManagerStateIsDisconnected.
typedef NS_ENUM(NSInteger, FTPenManagerState)
{
    FTPenManagerStateUninitialized,
    FTPenManagerStateUnpaired,
    FTPenManagerStateSeeking,
    FTPenManagerStateConnecting,
    FTPenManagerStateConnected,
    FTPenManagerStateConnectedLongPressToUnpair,
    FTPenManagerStateDisconnected,
    FTPenManagerStateDisconnectedLongPressToUnpair,
    FTPenManagerStateReconnecting,
    FTPenManagerStateUpdatingFirmware
};

typedef NS_ENUM(NSInteger, FTPenBatteryLevel)
{
    FTPenBatteryLevelUnknown,           // This is reported initially until the actual battery level can be returned.
                                        // It can take up to 20 seconds to read the battery level off the stylus.
    FTPenBatteryLevelHigh,
    FTPenBatteryLevelMediumHigh,
    FTPenBatteryLevelMediumLow,
    FTPenBatteryLevelLow,
    FTPenBatteryLevelCriticallyLow,     // If we're reporting critically low, you should prompt the user to
                                        // recharge.
};

#ifdef __cplusplus
extern "C"
{
#endif

    // Returns YES if the given FTPenManagerState is a state in which the pen is connected:
    //   * FTPenManagerStateConnected
    //   * FTPenManagerStateConnectedLongPressToUnpair
    //   * FTPenManagerStateUpdatingFirmware
    ///
    //  @param state The current state.
    ///
    //  @return YES if the pen is connected.
    BOOL FTPenManagerStateIsConnected(FTPenManagerState state);

    // Returns true if the given FTPenManagerState is a state in which the pen is disconnected:
    //   * FTPenManagerStateDisconnected
    //   * FTPenManagerStateDisconnectedLongPressToUnpair
    //   * FTPenManagerStateReconnecting
    ///
    //  @param state The current state.
    ///
    //  @return returns YES if the state is disconnected.
    BOOL FTPenManagerStateIsDisconnected(FTPenManagerState state);

    NSString *FTPenManagerStateToString(FTPenManagerState state);

#ifdef __cplusplus
}
#endif

// This contains some meta data you might show in a settings or details view.
// Since this is read via BTLE, it will be populated asynchronously. These values may be nil.
// See FTPenManagerDelegate. The FTPenInformation object is on the FTPenManager singleton.
@interface FTPenInformation : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) FTPenBatteryLevel batteryLevel;
// This is nil if we've not yet read the firmware revision.
@property (nonatomic, readonly) NSString *firmwareRevision;
// We only recommend using these properties for diagnostics. For example, showing a dot in the settings UI
// to indicate the tip is pressed and show the user that the application is correctly communicating with
// the pen.
@property (nonatomic, readonly) BOOL isTipPressed;
@property (nonatomic, readonly) BOOL isEraserPressed;

@end

@protocol FTPenManagerDelegate <NSObject>
@required
// Invoked when the state property of PenManager is changed.
// This typically occures during the connection flow.  However it
// can also happen if the battery module is removed from the stylus or
// Core Bluetooth drops the BTLE connection.
// See also FTPenManagerStateIsDisconnected & FTPenManagerStateIsConnected
- (void)penManagerStateDidChange:(FTPenManagerState)state;

@optional
// Invoked when any of the BTLE information is read off the pen. See FTPenInformation.
// This is also invoked if tip or eraser state is changed.
- (void)penInformationDidChange;

// See FTPenManager (FirmwareUpdateSupport)
- (void)penManagerFirmwareUpdateIsAvailableDidChange;
@end

@class UIView;
@class UIColor;

typedef NS_ENUM(NSInteger, FTPairingUIStyle) {
    // You should use this in release builds.
    FTPairingUIStyleDefault,
    // This turns on two additional views that show if the tip or eraser are pressed.
    FTPairingUIStyleDebug
};

#pragma mark -  FTPenManager

//  This singleton deals with connection functions of the pen.
@interface FTPenManager : NSObject

// Connection State.
@property (nonatomic, readonly) FTPenManagerState state;

// Meta data about the pen.
@property (nonatomic, readonly) FTPenInformation *info;

// Primary API to query information about UITouch objects.
@property (nonatomic, readonly) FTTouchClassifier *classifier;

// Register to get connection related notifications.
@property (nonatomic, weak) id<FTPenManagerDelegate> delegate;

// Use this to get at the instance. Note, this will initialize CoreBluetooth and
// potentially trigger the system UIAlertView for enabling Bluetooth LE.
//
// Please note that you need to be running on iOS 7 or higher to use any of this SDK. You can safely *link*
// against this SDK and not call it on iOS 6.
+ (FTPenManager *)sharedInstance;

// This provides a view that implements our BTLE pairing UI. The control is 81x101 points.
//
// This must be called on the UI thread.
- (UIView *)pairingButtonWithStyle:(FTPairingUIStyle)style;

// Call this to tear down the API. This also will shut down any CoreBluetooth activity.
// You'll also need to release any views that FTPenManager has handed you. The next access to
// [FTPenManager sharedInstance] will re-setup CoreBluetooth.
//
// This must be called on the UI thread.
- (void)shutdown;

#pragma mark - SurfacePressure APIs iOS8+

// Returns a normalized value that corresponds to physical touch size in MM. This signal
// is very heavily quantized.
//
// Returns nil if you are not on iOS 8 or pencil isn't connected.
- (NSNumber *)normalizedRadiusForTouch:(UITouch *)uiTouch;

// Returns a smoothed normalized value that is suitable for rendering variable width ink.
//
// Returns nil if you are not on iOS 8+ or pencil isn't connected.
- (NSNumber *)smoothedRadiusForTouch:(UITouch *)uiTouch;

// Unnormalized smoothed radius the value is CGPoints.
- (NSNumber *)smoothedRadiusInCGPointsForTouch:(UITouch *)uiTouch;

#pragma mark -  FTPenManager - Support & Marketing URLs

// This provides a link the FiftyThree's marketing page about Pencil.
@property (nonatomic, readonly) NSURL *learnMoreURL;
// This provides a link the FiftyThree's general support page about Pencil.
@property (nonatomic, readonly) NSURL *pencilSupportURL;

#pragma mark -  FTPenManager - FirmwareUpdateSupport

// Defaults to NO. If YES the SDK will notify via the delegate if a firmware update for Pencil
// is available. This *does* use WiFi to make a webservice request periodically.
@property (nonatomic) BOOL shouldCheckForFirmwareUpdates;

// Indicates if a firmware update can be installed on the connected Pencil. This is done
// via Paper by FiftyThree. This is either YES, NO or nil (if it's unknown.)
//
// See also shouldCheckForFirmwareUpdates
// See also penManagerFirmwareUpdateIsAvailableDidChange
@property (nonatomic, readonly) NSNumber *firmwareUpdateIsAvailable;

// Provides a link to the firmware release notes.
@property (nonatomic, readonly) NSURL *firmwareUpdateReleaseNotesLink;

// Provides a link to the FiftyThree support page on firmware upgrades.
@property (nonatomic, readonly) NSURL *firmwareUpdateSupportLink;

// Returns NO if you're on an iphone or a device without Paper installed. (Or an older build of Paper that
// doesn't support Pencil firmware upgrades.)
@property (nonatomic, readonly) BOOL canInvokePaperToUpdatePencilFirmware;

// This invokes Paper via x-callback-urls to upgrade the firmware.
//
// You can provide error, success, and cancel URLs so that Paper
// can return to your application after the Firmware upgrade is complete.
// Returns NO if Paper can't be invoked.
- (BOOL)invokePaperToUpdatePencilFirmware:(NSString *)source           // This should be a human readable application name.
                                   success:(NSURL*)successCallbackUrl // e.g., YourApp://x-callback-url/success
                                     error:(NSURL*)errorCallbackUrl   // e.g., YourApp://x-callback-url/error
                                    cancel:(NSURL*)cancelCallbackUrl; // e.g., YourApp://x-callback-url/cancel
@end
