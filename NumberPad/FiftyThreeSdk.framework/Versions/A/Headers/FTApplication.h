//
//  FTApplication.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//  Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"

#pragma once

@class UIApplication;

// Subclass your application class from this to send touch data for classification by FiftyThree's touch
// classification system.
//
// If you aren't using a custom UIApplication object just alter main.m to inject this class
// into the event processing pipeline via the 3rd argument to UIApplicationMain.
//
// For example, if FTAAppDelegate is your app delegate, you'd add #include <FiftyThreeSdk/FiftyThreeSdk.h>
// then alter main as follows:
//
//    @autoreleasepool {
//          return UIApplicationMain(argc,
//                                   argv,
//                                   NSStringFromClass([FTApplication class]),
//                                   NSStringFromClass([FTAAppDelegate class]));
//     }
@interface FTApplication : UIApplication
@end
