# EUMTouchPointView

[![CI Status](http://img.shields.io/travis/Shawn Xiao/EUMTouchPointView.svg?style=flat)](https://travis-ci.org/Shawn Xiao/EUMTouchPointView)
[![Version](https://img.shields.io/cocoapods/v/EUMTouchPointView.svg?style=flat)](http://cocoadocs.org/docsets/EUMTouchPointView)
[![License](https://img.shields.io/cocoapods/l/EUMTouchPointView.svg?style=flat)](http://cocoadocs.org/docsets/EUMTouchPointView)
[![Platform](https://img.shields.io/cocoapods/p/EUMTouchPointView.svg?style=flat)](http://cocoadocs.org/docsets/EUMTouchPointView)

**EUMTouchPointView** shows your finger touches on the screen. It solves these problems:

* You want to make a video for iTunes Store **App Preview Video**.
* You want to show your users how to use your App, but recording iOS screen by using **QuickTime** doesn't show your finger touches.
* You mirror your app to the projector though AirPlay or cable, you want to show your audiences how you use the app.

Watch demo video here:

[![EUMTouchPointView Demo Video](http://img.youtube.com/vi/B7mpseXKMpo/0.jpg)](http://www.youtube.com/watch?v=B7mpseXKMpo)


## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements
iOS 7.x or greater

## Installation

EUMTouchPointView is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "EUMTouchPointView"

And add following codes into your **AppDelegate**

```
- (EUMShowTouchWindow *)window
{
    static EUMShowTouchWindow *customWindow = nil;
    
    if (!customWindow) {
        customWindow = [[EUMShowTouchWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    }
    
    return customWindow;
}
```

## Author

Shawn Xiao, shawn@eumlab.com

## License

EUMTouchPointView is available under the MIT license. See the LICENSE file for more info.

