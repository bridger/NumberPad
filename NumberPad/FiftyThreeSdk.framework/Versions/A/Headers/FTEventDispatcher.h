//
//  FTEventDispatcher.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//  Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"

#pragma once

#import <Foundation/Foundation.h>

@class UIEvent;

//  This singleton handles event dispatch for
//  FiftyThree's classification system. It is used internally by FTApplication
//  This *does not* touch any Bluetooth-related functionality.  
//  Its role is to process touch data for gesture & classification purposes.
//
@interface FTEventDispatcher : NSObject

//   Only use this from the main thread.
+ (FTEventDispatcher *)sharedInstance;

//  Invoke this to pass events to FiftyThree's classification system.
//  For example:
//  [[FTEventDispatcher sharedInstance] sendEvent:event];
//
//  @param  UIEvent from a UIApplication (typically a touch event.)
//
- (void)sendEvent:(UIEvent *)event;
@end
